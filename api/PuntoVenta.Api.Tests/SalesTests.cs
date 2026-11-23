using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;
using PuntoVenta.Api.Sales;

namespace PuntoVenta.Api.Tests;

public sealed class SalesTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public SalesTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private async Task<string> AuthenticateAsync(Guid tenantId)
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        const string password = "Pass123!";
        await _factory.SeedUserAsync(tenantId, email, password, Roles.Cajero);
        return (await _factory.LoginOkAsync(_client, email, password)).AccessToken;
    }

    private Task AddProductAsync(Guid tenantId, Guid productId, int stock) =>
        _factory.WithDbAsync(async db =>
        {
            db.Products.Add(new Product
            {
                Id = productId,
                TenantId = tenantId,
                Name = "Producto de prueba",
                PriceCents = 125,
                Stock = stock,
                UpdatedAt = _factory.Clock.GetUtcNow().UtcDateTime
            });
            await db.SaveChangesAsync();
            return true;
        });

    private async Task<HttpResponseMessage> PostSaleAsync(string token, SaleInput sale)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/sales")
        {
            Content = JsonContent.Create(sale)
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await _client.SendAsync(request);
    }

    private async Task<HttpResponseMessage> GetSalesAsync(string token, string? query = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "/sales" + (query ?? string.Empty));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return await _client.SendAsync(request);
    }

    private static async Task AssertError(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        Assert.Equal(status, response.StatusCode);
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(code, json.GetProperty("code").GetString());
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("message").GetString()));
    }

    [Fact]
    public async Task CreateSale_descuenta_stock_y_repetir_guid_no_duplica_ni_descuenta_dos_veces()
    {
        var tenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(tenantId);
        var productId = Guid.NewGuid();
        await AddProductAsync(tenantId, productId, stock: 10);
        var sale = new SaleInput(
            Guid.NewGuid(),
            "cash",
            [new SaleItemInput(Guid.NewGuid(), productId, "Producto de prueba", 2, 125)]);

        var firstResponse = await PostSaleAsync(token, sale);
        Assert.Equal(HttpStatusCode.Created, firstResponse.StatusCode);
        var first = (await firstResponse.Content.ReadFromJsonAsync<SaleResponse>())!;
        Assert.Equal(250, first.TotalCents);
        Assert.Equal("active", first.Status);
        Assert.Single(first.Items);

        var replayResponse = await PostSaleAsync(token, sale);
        Assert.Equal(HttpStatusCode.Created, replayResponse.StatusCode);
        var replay = (await replayResponse.Content.ReadFromJsonAsync<SaleResponse>())!;
        Assert.Equal(first.Id, replay.Id);
        Assert.Equal(first.TotalCents, replay.TotalCents);

        var (stock, saleCount, itemCount) = await _factory.WithDbAsync(async db =>
        {
            var storedStock = await db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync();
            var storedSales = await db.Sales.CountAsync(s => s.TenantId == tenantId);
            var storedItems = await db.SaleItems.CountAsync(i => i.TenantId == tenantId);
            return (storedStock, storedSales, storedItems);
        });
        Assert.Equal(8, stock);
        Assert.Equal(1, saleCount);
        Assert.Equal(1, itemCount);
    }

    [Fact]
    public async Task CreateSale_con_stock_insuficiente_revierte_venta_y_cambios_de_stock()
    {
        var tenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(tenantId);
        var productId = Guid.NewGuid();
        await AddProductAsync(tenantId, productId, stock: 4);
        var sale = new SaleInput(
            Guid.NewGuid(),
            "debit",
            [
                new SaleItemInput(Guid.NewGuid(), productId, "Primera línea", 3, 125),
                new SaleItemInput(Guid.NewGuid(), productId, "Segunda línea", 2, 125)
            ]);

        await AssertError(await PostSaleAsync(token, sale), HttpStatusCode.BadRequest, "insufficient_stock");

        var (stock, saleCount) = await _factory.WithDbAsync(async db =>
        {
            var storedStock = await db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync();
            var storedSales = await db.Sales.CountAsync(s => s.TenantId == tenantId);
            return (storedStock, storedSales);
        });
        Assert.Equal(4, stock);
        Assert.Equal(0, saleCount);
    }

    [Fact]
    public async Task CreateSale_con_producto_de_otro_tenant_es_rechazada()
    {
        var ownerTenantId = Guid.NewGuid();
        var otherTenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(ownerTenantId);
        var productId = Guid.NewGuid();
        await _factory.SeedUserAsync(otherTenantId, $"{Guid.NewGuid():N}@example.com", "Pass123!", Roles.Admin);
        await AddProductAsync(otherTenantId, productId, stock: 5);
        var sale = new SaleInput(
            Guid.NewGuid(),
            "cash",
            [new SaleItemInput(Guid.NewGuid(), productId, "Producto ajeno", 1, 125)]);

        await AssertError(await PostSaleAsync(token, sale), HttpStatusCode.BadRequest, "product_not_found");

        var saleCount = await _factory.WithDbAsync(db => db.Sales.CountAsync(s => s.TenantId == ownerTenantId));
        Assert.Equal(0, saleCount);
    }

    [Fact]
    public async Task CreateSale_con_total_que_desborda_el_entero_de_64_bits_es_rechazada()
    {
        var tenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(tenantId);
        var sale = new SaleInput(
            Guid.NewGuid(),
            "cash",
            [new SaleItemInput(Guid.NewGuid(), null, "Precio libre", 2, long.MaxValue)]);

        await AssertError(await PostSaleAsync(token, sale), HttpStatusCode.BadRequest, "invalid_request");

        var saleCount = await _factory.WithDbAsync(db => db.Sales.CountAsync(s => s.TenantId == tenantId));
        Assert.Equal(0, saleCount);
    }

    [Fact]
    public async Task CreateSale_sin_precio_unitario_requerido_retorna_400()
    {
        var tenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(tenantId);
        var request = new HttpRequestMessage(HttpMethod.Post, "/sales")
        {
            Content = JsonContent.Create(new
            {
                id = Guid.NewGuid(),
                paymentMethod = "cash",
                items = new[]
                {
                    new
                    {
                        id = Guid.NewGuid(),
                        productId = (Guid?)null,
                        description = "Precio libre",
                        quantity = 1
                    }
                }
            })
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        await AssertError(await _client.SendAsync(request), HttpStatusCode.BadRequest, "invalid_request");
    }

    [Fact]
    public async Task ListSales_filtra_por_tenant_y_rango_de_fechas()
    {
        var tenantId = Guid.NewGuid();
        var otherTenantId = Guid.NewGuid();
        var token = await AuthenticateAsync(tenantId);
        var otherToken = await AuthenticateAsync(otherTenantId);

        var sale = new SaleInput(
            Guid.NewGuid(),
            "transfer",
            [new SaleItemInput(Guid.NewGuid(), null, "Precio libre", 1, 500)]);
        var created = (await (await PostSaleAsync(token, sale)).Content.ReadFromJsonAsync<SaleResponse>())!;

        var otherSale = new SaleInput(
            Guid.NewGuid(),
            "other",
            [new SaleItemInput(Guid.NewGuid(), null, "Otro comercio", 1, 700)]);
        await PostSaleAsync(otherToken, otherSale);

        var from = Uri.EscapeDataString(created.Date.ToString("O"));
        var to = Uri.EscapeDataString(created.Date.ToString("O"));
        var response = await GetSalesAsync(token, $"?from={from}&to={to}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var listed = (await response.Content.ReadFromJsonAsync<List<SaleResponse>>())!;
        var onlySale = Assert.Single(listed);
        Assert.Equal(created.Id, onlySale.Id);
        Assert.Equal(500, onlySale.TotalCents);

        var future = Uri.EscapeDataString(created.Date.AddDays(1).ToString("O"));
        var emptyResponse = await GetSalesAsync(token, $"?from={future}");
        Assert.Empty((await emptyResponse.Content.ReadFromJsonAsync<List<SaleResponse>>())!);

        await AssertError(
            await GetSalesAsync(token, $"?from={future}&to={from}"),
            HttpStatusCode.BadRequest,
            "invalid_request");
    }
}
