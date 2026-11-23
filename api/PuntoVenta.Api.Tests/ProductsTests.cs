using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;
using PuntoVenta.Api.Products;

namespace PuntoVenta.Api.Tests;

public sealed class ProductsTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public ProductsTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private static string AuthHeader(string token) => $"Bearer {token}";

    private static async Task AssertError(HttpResponseMessage res, HttpStatusCode status, string code)
    {
        Assert.Equal(status, res.StatusCode);
        var json = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(code, json.GetProperty("code").GetString());
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("message").GetString()));
    }

    private async Task<string> AuthenticateAsync(Guid tenantId, string role)
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        const string password = "Pass123!";
        await _factory.SeedUserAsync(tenantId, email, password, role);
        var tokens = await _factory.LoginOkAsync(_client, email, password);
        return tokens.AccessToken;
    }

    [Fact]
    public async Task CreateProduct_ok_crea_producto_con_barcode_unico_por_tenant()
    {
        var tenant1 = Guid.NewGuid();
        var tenant2 = Guid.NewGuid();
        var token1 = await AuthenticateAsync(tenant1, Roles.Admin);
        var token2 = await AuthenticateAsync(tenant2, Roles.Admin);

        var req = new ProductInput("EAN123", "Producto A", 1000, 10, null);

        // Crear en tenant 1
        var req1 = new HttpRequestMessage(HttpMethod.Post, "/products") { Content = JsonContent.Create(req) };
        req1.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token1);
        var res1 = await _client.SendAsync(req1);
        Assert.Equal(HttpStatusCode.Created, res1.StatusCode);
        var prod1 = (await res1.Content.ReadFromJsonAsync<ProductResponse>())!;

        // Mismo barcode en tenant 2 debe funcionar
        var req2 = new HttpRequestMessage(HttpMethod.Post, "/products") { Content = JsonContent.Create(req) };
        req2.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token2);
        var res2 = await _client.SendAsync(req2);
        Assert.Equal(HttpStatusCode.Created, res2.StatusCode);
        var prod2 = (await res2.Content.ReadFromJsonAsync<ProductResponse>())!;

        // Productos distintos
        Assert.NotEqual(prod1.Id, prod2.Id);
        Assert.Equal("EAN123", prod1.Barcode);
        Assert.Equal("EAN123", prod2.Barcode);

        // Barcode duplicado en tenant 1 falla
        var req1Dup = new HttpRequestMessage(HttpMethod.Post, "/products") { Content = JsonContent.Create(req) };
        req1Dup.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token1);
        var resDup = await _client.SendAsync(req1Dup);
        await AssertError(resDup, HttpStatusCode.BadRequest, "barcode_already_exists");
    }

    [Fact]
    public async Task ListProducts_ok_retorna_solo_productos_del_tenant()
    {
        var tenant = Guid.NewGuid();
        var token = await AuthenticateAsync(tenant, Roles.Cajero);

        var req = new HttpRequestMessage(HttpMethod.Get, "/products");
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var res = await _client.SendAsync(req);

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var products = (await res.Content.ReadFromJsonAsync<List<ProductResponse>>())!;
        Assert.Empty(products);

        // Crear productos
        var reqCreate = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new ProductInput("BAR001", "Producto 1", 500, 5, null))
        };
        reqCreate.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        await _client.SendAsync(reqCreate);

        // Listar nuevamente
        var req2 = new HttpRequestMessage(HttpMethod.Get, "/products");
        req2.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var res2 = await _client.SendAsync(req2);
        var products2 = (await res2.Content.ReadFromJsonAsync<List<ProductResponse>>())!;
        Assert.Single(products2);
        Assert.Equal("Producto 1", products2[0].Name);
    }

    [Fact]
    public async Task DeleteProduct_ok_hace_borrado_logico()
    {
        var tenant = Guid.NewGuid();
        var token = await AuthenticateAsync(tenant, Roles.Admin);

        // Crear
        var reqCreate = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new ProductInput("DEL001", "Para borrar", 1000, 1, null))
        };
        reqCreate.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resCreate = await _client.SendAsync(reqCreate);
        var product = (await resCreate.Content.ReadFromJsonAsync<ProductResponse>())!;

        // Eliminar
        var reqDel = new HttpRequestMessage(HttpMethod.Delete, $"/products/{product.Id}");
        reqDel.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resDel = await _client.SendAsync(reqDel);
        Assert.Equal(HttpStatusCode.NoContent, resDel.StatusCode);

        // Verificar que quedó borrado lógicamente en la DB
        var deleted = await _factory.WithDbAsync(db =>
            db.Products.FirstOrDefaultAsync(p => p.Id == product.Id));
        Assert.NotNull(deleted);
        Assert.True(deleted.IsDeleted);

        // No aparece en lista
        var reqList = new HttpRequestMessage(HttpMethod.Get, "/products");
        reqList.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resList = await _client.SendAsync(reqList);
        var products = (await resList.Content.ReadFromJsonAsync<List<ProductResponse>>())!;
        Assert.DoesNotContain(products, p => p.Id == product.Id);

        // Acceder directamente retorna 404
        var reqGet = new HttpRequestMessage(HttpMethod.Put, $"/products/{product.Id}")
        {
            Content = JsonContent.Create(new ProductInput("NEW001", "Nuevo nombre", 2000, 2, null))
        };
        reqGet.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resGet = await _client.SendAsync(reqGet);
        await AssertError(resGet, HttpStatusCode.NotFound, "not_found");
    }

    [Fact]
    public async Task UpdateProduct_ok_modifica_y_permite_cambiar_barcode()
    {
        var tenant = Guid.NewGuid();
        var token = await AuthenticateAsync(tenant, Roles.Admin);

        // Crear
        var reqCreate = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new ProductInput("ORIG123", "Original", 1000, 10, null))
        };
        reqCreate.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resCreate = await _client.SendAsync(reqCreate);
        var product = (await resCreate.Content.ReadFromJsonAsync<ProductResponse>())!;

        // Actualizar
        var reqUpdate = new HttpRequestMessage(HttpMethod.Put, $"/products/{product.Id}")
        {
            Content = JsonContent.Create(new ProductInput("NEWBAR123", "Actualizado", 2000, 20, null))
        };
        reqUpdate.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var resUpdate = await _client.SendAsync(reqUpdate);
        Assert.Equal(HttpStatusCode.OK, resUpdate.StatusCode);
        var updated = (await resUpdate.Content.ReadFromJsonAsync<ProductResponse>())!;

        Assert.Equal("Actualizado", updated.Name);
        Assert.Equal(2000, updated.PriceCents);
        Assert.Equal(20, updated.Stock);
        Assert.Equal("NEWBAR123", updated.Barcode);
    }

    [Fact]
    public async Task CreateProduct_sin_autenticacion_retorna_401()
    {
        var req = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new ProductInput("BAR001", "Producto", 500, 1, null))
        };
        var res = await _client.SendAsync(req);
        Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
    }

    [Fact]
    public async Task CreateProduct_con_body_invalido_retorna_400()
    {
        var tenant = Guid.NewGuid();
        var token = await AuthenticateAsync(tenant, Roles.Admin);

        // Falta name
        var req = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new { barcode = "BAR001", priceCents = 500, stock = 1 })
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var res = await _client.SendAsync(req);
        await AssertError(res, HttpStatusCode.BadRequest, "invalid_request");
    }

    [Fact]
    public async Task CreateProduct_con_precio_negativo_retorna_400()
    {
        var tenant = Guid.NewGuid();
        var token = await AuthenticateAsync(tenant, Roles.Admin);

        var req = new HttpRequestMessage(HttpMethod.Post, "/products")
        {
            Content = JsonContent.Create(new ProductInput("BAR001", "Producto", -100, 1, null))
        };
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var res = await _client.SendAsync(req);
        await AssertError(res, HttpStatusCode.BadRequest, "invalid_request");
    }
}
