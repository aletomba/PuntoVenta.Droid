using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Data;
using PuntoVenta.Api.Sales;

namespace PuntoVenta.Api.Tests;

public sealed class VoidSaleTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public VoidSaleTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private async Task<(string Token, Guid UserId)> LoginAsync(Guid tenant, string role)
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        const string password = "Pass123!";
        var user = await _factory.SeedUserAsync(tenant, email, password, role);
        var tokens = await _factory.LoginOkAsync(_client, email, password);
        return (tokens.AccessToken, user.Id);
    }

    private async Task<(Guid SaleId, Guid ProductId)> SeedSaleAsync(Guid tenant, Guid user)
    {
        var saleId = Guid.NewGuid();
        var productId = Guid.NewGuid();
        await _factory.WithDbAsync(async db =>
        {
            db.Products.Add(new Product
            {
                Id = productId,
                TenantId = tenant,
                Name = "Producto",
                Stock = 7,
                UpdatedAt = _factory.Clock.GetUtcNow().UtcDateTime,
                IsDeleted = true
            });
            db.Sales.Add(new Sale
            {
                Id = saleId,
                TenantId = tenant,
                UserId = user,
                Date = _factory.Clock.GetUtcNow().UtcDateTime,
                PaymentMethod = "cash",
                TotalCents = 400,
                Items =
                [
                    new SaleItem { Id = Guid.NewGuid(), ProductId = productId, Description = "A", Quantity = 1, UnitPriceCents = 100 },
                    new SaleItem { Id = Guid.NewGuid(), ProductId = productId, Description = "B", Quantity = 2, UnitPriceCents = 100 },
                    new SaleItem { Id = Guid.NewGuid(), Description = "Libre", Quantity = 1, UnitPriceCents = 100 }
                ]
            });
            await db.SaveChangesAsync();
            return true;
        });
        return (saleId, productId);
    }

    private Task<HttpResponseMessage> VoidAsync(Guid saleId, string? token, object body)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, $"/sales/{saleId}/void")
        {
            Content = JsonContent.Create(body)
        };
        if (token is not null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return _client.SendAsync(request);
    }

    [Fact]
    public async Task Admin_anula_y_reintenta_sin_reponer_dos_veces()
    {
        var tenant = Guid.NewGuid();
        var (token, userId) = await LoginAsync(tenant, Roles.Admin);
        var (saleId, productId) = await SeedSaleAsync(tenant, userId);

        var response = await VoidAsync(saleId, token, new { reason = "Error" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var sale = (await response.Content.ReadFromJsonAsync<SaleResponse>())!;
        Assert.Equal("voided", sale.Status);
        Assert.Equal(userId, sale.VoidedByUserId);
        Assert.Equal(_factory.Clock.GetUtcNow().UtcDateTime, sale.VoidedAt);
        Assert.Equal("Error", sale.VoidReason);
        Assert.Equal(3, sale.Items.Count);

        var replay = await VoidAsync(saleId, token, new { reason = "Otro motivo" });
        Assert.Equal(HttpStatusCode.OK, replay.StatusCode);
        var repeated = (await replay.Content.ReadFromJsonAsync<SaleResponse>())!;
        Assert.Equal(sale.VoidedAt, repeated.VoidedAt);
        Assert.Equal("Error", repeated.VoidReason);
        var stock = await _factory.WithDbAsync(db => db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync());
        Assert.Equal(10, stock);

        var closeRequest = new HttpRequestMessage(HttpMethod.Get, "/cash-close?day=2026-01-01");
        closeRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var close = await (await _client.SendAsync(closeRequest)).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(0, close.GetProperty("totalCents").GetInt64());
    }

    [Fact]
    public async Task Anulaciones_concurrentes_reponen_una_sola_vez()
    {
        var tenant = Guid.NewGuid();
        var (token, userId) = await LoginAsync(tenant, Roles.Admin);
        var (saleId, productId) = await SeedSaleAsync(tenant, userId);

        var responses = await Task.WhenAll(
            VoidAsync(saleId, token, new { reason = "A" }),
            VoidAsync(saleId, token, new { reason = "B" }));
        Assert.All(responses, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
        var results = await Task.WhenAll(responses.Select(response => response.Content.ReadFromJsonAsync<SaleResponse>()));
        Assert.Equal(results[0]!.VoidReason, results[1]!.VoidReason);
        var stock = await _factory.WithDbAsync(db => db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync());
        Assert.Equal(10, stock);
    }

    [Fact]
    public async Task Restringe_rol_tenant_y_motivo()
    {
        var tenant = Guid.NewGuid();
        var (admin, userId) = await LoginAsync(tenant, Roles.Admin);
        var (cajero, _) = await LoginAsync(tenant, Roles.Cajero);
        var (otherAdmin, _) = await LoginAsync(Guid.NewGuid(), Roles.Admin);
        var (saleId, productId) = await SeedSaleAsync(tenant, userId);

        Assert.Equal(HttpStatusCode.Unauthorized, (await VoidAsync(saleId, null, new { reason = "A" })).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await VoidAsync(saleId, cajero, new { reason = "A" })).StatusCode);
        var notFound = await VoidAsync(saleId, otherAdmin, new { reason = "A" });
        Assert.Equal(HttpStatusCode.NotFound, notFound.StatusCode);
        Assert.Equal("not_found", (await notFound.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        Assert.Equal(HttpStatusCode.NotFound, (await VoidAsync(Guid.NewGuid(), admin, new { reason = "A" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await VoidAsync(saleId, admin, new { })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await VoidAsync(saleId, admin, new { reason = "" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await VoidAsync(saleId, admin, new { reason = new string('x', 501) })).StatusCode);
        var stored = await _factory.WithDbAsync(async db => (
            await db.Sales.Where(s => s.TenantId == tenant && s.Id == saleId).Select(s => s.Status).SingleAsync(),
            await db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync()));
        Assert.Equal(("active", 7), stored);
    }

    [Fact]
    public async Task Acepta_motivo_de_un_caracter_segun_contrato()
    {
        var tenant = Guid.NewGuid();
        var (token, userId) = await LoginAsync(tenant, Roles.Admin);
        var (saleId, _) = await SeedSaleAsync(tenant, userId);

        var response = await VoidAsync(saleId, token, new { reason = " " });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(" ", (await response.Content.ReadFromJsonAsync<SaleResponse>())!.VoidReason);
    }

    [Fact]
    public async Task Si_stock_desborda_se_revierte_la_anulacion()
    {
        var tenant = Guid.NewGuid();
        var (token, userId) = await LoginAsync(tenant, Roles.Admin);
        var (saleId, productId) = await SeedSaleAsync(tenant, userId);
        await _factory.WithDbAsync(async db =>
        {
            await db.Products.Where(p => p.Id == productId)
                .ExecuteUpdateAsync(update => update.SetProperty(p => p.Stock, int.MaxValue));
            return true;
        });

        await Assert.ThrowsAsync<InvalidOperationException>(() => VoidAsync(saleId, token, new { reason = "A" }));
        var stored = await _factory.WithDbAsync(async db => (
            await db.Sales.Where(s => s.TenantId == tenant && s.Id == saleId).Select(s => s.Status).SingleAsync(),
            await db.Products.Where(p => p.Id == productId).Select(p => p.Stock).SingleAsync()));
        Assert.Equal(("active", int.MaxValue), stored);
    }
}
