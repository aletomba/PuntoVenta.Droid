using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;
using PuntoVenta.Api.CashClose;

namespace PuntoVenta.Api.Tests;

public sealed class CashCloseTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public CashCloseTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private async Task<(string Token, Guid UserId)> AuthenticateAsync(Guid tenantId)
    {
        var email = $"{Guid.NewGuid():N}@example.com";
        const string password = "Pass123!";
        var user = await _factory.SeedUserAsync(tenantId, email, password, Roles.Cajero);
        var tokens = await _factory.LoginOkAsync(_client, email, password);
        return (tokens.AccessToken, user.Id);
    }

    private Task AddSaleAsync(
        Guid tenantId,
        Guid userId,
        DateTime date,
        long totalCents,
        string paymentMethod,
        string status = "active") =>
        _factory.WithDbAsync(async db =>
        {
            db.Sales.Add(new Sale
            {
                Id = Guid.NewGuid(),
                TenantId = tenantId,
                UserId = userId,
                Date = date,
                TotalCents = totalCents,
                PaymentMethod = paymentMethod,
                Status = status
            });
            await db.SaveChangesAsync();
            return true;
        });

    private async Task<HttpResponseMessage> GetCashCloseAsync(string token, string query)
    {
        var request = new HttpRequestMessage(HttpMethod.Get, "/cash-close" + query);
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
    public async Task GetCashClose_agrupa_ventas_activas_por_medio_y_aisla_tenant()
    {
        var tenantId = Guid.NewGuid();
        var otherTenantId = Guid.NewGuid();
        var (token, userId) = await AuthenticateAsync(tenantId);
        var (_, otherUserId) = await AuthenticateAsync(otherTenantId);
        var day = new DateOnly(2026, 1, 1);
        var start = day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

        await AddSaleAsync(tenantId, userId, start, 1200, "cash");
        await AddSaleAsync(tenantId, userId, start.AddHours(12), 800, "cash");
        await AddSaleAsync(tenantId, userId, start.AddHours(13), 500, "debit");
        await AddSaleAsync(tenantId, userId, start.AddHours(14), 9900, "cash", "voided");
        await AddSaleAsync(tenantId, userId, start.AddDays(1), 7000, "cash");
        await AddSaleAsync(otherTenantId, otherUserId, start, 4000, "cash");

        var response = await GetCashCloseAsync(token, "?day=2026-01-01");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var close = (await response.Content.ReadFromJsonAsync<CashCloseResponse>())!;
        Assert.Equal(day, close.Day);
        Assert.Equal(2500, close.TotalCents);
        Assert.Equal(2000, close.ByPaymentMethod["cash"]);
        Assert.Equal(500, close.ByPaymentMethod["debit"]);
        Assert.Equal(2, close.ByPaymentMethod.Count);
    }

    [Fact]
    public async Task GetCashClose_sin_ventas_retorna_totales_en_cero()
    {
        var tenantId = Guid.NewGuid();
        var (token, _) = await AuthenticateAsync(tenantId);

        var response = await GetCashCloseAsync(token, "?day=2026-01-02");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var close = (await response.Content.ReadFromJsonAsync<CashCloseResponse>())!;
        Assert.Equal(0, close.TotalCents);
        Assert.Empty(close.ByPaymentMethod);
    }

    [Fact]
    public async Task GetCashClose_requiere_un_dia_valido()
    {
        var tenantId = Guid.NewGuid();
        var (token, _) = await AuthenticateAsync(tenantId);

        await AssertError(
            await GetCashCloseAsync(token, string.Empty),
            HttpStatusCode.BadRequest,
            "invalid_request");
        await AssertError(
            await GetCashCloseAsync(token, "?day=no-es-fecha"),
            HttpStatusCode.BadRequest,
            "invalid_request");
    }
}
