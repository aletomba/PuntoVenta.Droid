using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Tests;

public sealed class AuthTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory _factory;
    private readonly HttpClient _client;

    public AuthTests(ApiFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private static string NewEmail() => $"{Guid.NewGuid():N}@example.com";

    private static async Task AssertError(HttpResponseMessage res, HttpStatusCode status, string code)
    {
        Assert.Equal(status, res.StatusCode);
        var json = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(code, json.GetProperty("code").GetString());
        Assert.False(string.IsNullOrWhiteSpace(json.GetProperty("message").GetString()));
    }

    private static HttpRequestMessage Get(string url, string token)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return req;
    }

    [Fact]
    public async Task Login_ok_devuelve_tokens_y_hashea_el_refresh_token()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);

        var tokens = await _factory.LoginOkAsync(_client, email.ToUpperInvariant(), "Secreta123!");

        Assert.False(string.IsNullOrEmpty(tokens.AccessToken));
        Assert.True(tokens.ExpiresAt > _factory.Clock.GetUtcNow().UtcDateTime);
        var stored = await _factory.WithDbAsync(db => db.RefreshTokens.ToListAsync());
        Assert.DoesNotContain(stored, t => t.TokenHash == tokens.RefreshToken);
        Assert.Contains(stored, t => t.TokenHash == TokenService.HashRefreshToken(tokens.RefreshToken));
    }

    [Fact]
    public async Task Login_guarda_la_contrasena_con_hash()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Admin);
        var user = await _factory.WithDbAsync(db => db.Users.SingleAsync(u => u.Email == email));
        Assert.DoesNotContain("Secreta123!", user.PasswordHash);
        Assert.StartsWith("v1.", user.PasswordHash);
    }

    [Fact]
    public async Task Login_con_password_incorrecta_o_email_inexistente_da_401()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);

        await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email, password = "mala" }),
            HttpStatusCode.Unauthorized, "invalid_credentials");
        await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email = NewEmail(), password = "x" }),
            HttpStatusCode.Unauthorized, "invalid_credentials");
    }

    [Fact]
    public async Task Login_con_usuario_inactivo_da_401()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero, active: false);
        await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email, password = "Secreta123!" }),
            HttpStatusCode.Unauthorized, "invalid_credentials");
    }

    [Fact]
    public async Task Login_con_body_invalido_da_400_con_formato_de_error()
    {
        await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email = "no-es-email" }),
            HttpStatusCode.BadRequest, "invalid_request");
    }

    [Fact]
    public async Task Bloquea_tras_intentos_fallidos_incluso_con_password_correcta_y_se_libera_al_vencer()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);

        for (var i = 0; i < 5; i++)
        {
            await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email, password = "mala" }),
                HttpStatusCode.Unauthorized, "invalid_credentials");
        }

        await AssertError(await _client.PostAsJsonAsync("/auth/login", new { email, password = "Secreta123!" }),
            HttpStatusCode.Unauthorized, "account_locked");

        _factory.Clock.Advance(TimeSpan.FromMinutes(16));
        await _factory.LoginOkAsync(_client, email, "Secreta123!");
        var user = await _factory.WithDbAsync(db => db.Users.SingleAsync(u => u.Email == email));
        Assert.Equal(0, user.FailedLoginAttempts);
        Assert.Null(user.LockoutEndUtc);
    }

    [Fact]
    public async Task Login_exitoso_reinicia_el_contador_de_fallos()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);
        for (var i = 0; i < 4; i++)
        {
            await _client.PostAsJsonAsync("/auth/login", new { email, password = "mala" });
        }

        await _factory.LoginOkAsync(_client, email, "Secreta123!");
        for (var i = 0; i < 4; i++)
        {
            await _client.PostAsJsonAsync("/auth/login", new { email, password = "mala" });
        }

        await _factory.LoginOkAsync(_client, email, "Secreta123!");
    }

    [Fact]
    public async Task Refresh_rota_el_token_y_el_anterior_queda_invalido()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);
        var first = await _factory.LoginOkAsync(_client, email, "Secreta123!");

        var res = await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = first.RefreshToken });
        res.EnsureSuccessStatusCode();
        var second = (await res.Content.ReadFromJsonAsync<TokenResponse>())!;
        Assert.NotEqual(first.RefreshToken, second.RefreshToken);

        // Reutilizar el viejo es rechazado y revoca la sesión completa.
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = first.RefreshToken }),
            HttpStatusCode.Unauthorized, "invalid_refresh_token");
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = second.RefreshToken }),
            HttpStatusCode.Unauthorized, "invalid_refresh_token");
    }

    [Fact]
    public async Task Refresh_rechaza_token_desconocido_expirado_o_de_usuario_desactivado()
    {
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = "desconocido" }),
            HttpStatusCode.Unauthorized, "invalid_refresh_token");

        var email = NewEmail();
        var user = await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);
        var tokens = await _factory.LoginOkAsync(_client, email, "Secreta123!");
        await _factory.WithDbAsync(async db =>
        {
            (await db.Users.SingleAsync(u => u.Id == user.Id)).IsActive = false;
            return await db.SaveChangesAsync();
        });
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = tokens.RefreshToken }),
            HttpStatusCode.Unauthorized, "invalid_refresh_token");

        var email2 = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email2, "Secreta123!", Roles.Cajero);
        var t2 = await _factory.LoginOkAsync(_client, email2, "Secreta123!");
        _factory.Clock.Advance(TimeSpan.FromDays(31));
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { refreshToken = t2.RefreshToken }),
            HttpStatusCode.Unauthorized, "invalid_refresh_token");
    }

    [Fact]
    public async Task Refresh_con_body_invalido_da_400()
    {
        await AssertError(await _client.PostAsJsonAsync("/auth/refresh", new { }),
            HttpStatusCode.BadRequest, "invalid_request");
    }

    [Fact]
    public async Task Sin_token_o_con_token_invalido_da_401_con_formato_de_error()
    {
        await AssertError(await _client.GetAsync("/test/any"), HttpStatusCode.Unauthorized, "unauthorized");
        await AssertError(await _client.SendAsync(Get("/test/any", "basura")), HttpStatusCode.Unauthorized, "unauthorized");
    }

    [Fact]
    public async Task Permisos_por_rol_Admin_accede_a_todo()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Admin);
        var tokens = await _factory.LoginOkAsync(_client, email, "Secreta123!");

        Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(Get("/test/admin", tokens.AccessToken))).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(Get("/test/any", tokens.AccessToken))).StatusCode);
    }

    [Fact]
    public async Task Permisos_por_rol_Cajero_recibe_403_en_rutas_de_Admin()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Cajero);
        var tokens = await _factory.LoginOkAsync(_client, email, "Secreta123!");

        await AssertError(await _client.SendAsync(Get("/test/admin", tokens.AccessToken)),
            HttpStatusCode.Forbidden, "forbidden");
        Assert.Equal(HttpStatusCode.OK, (await _client.SendAsync(Get("/test/any", tokens.AccessToken))).StatusCode);
    }

    [Fact]
    public async Task El_tenant_sale_del_JWT()
    {
        var tenantA = Guid.NewGuid();
        var tenantB = Guid.NewGuid();
        var a = NewEmail();
        var b = NewEmail();
        await _factory.SeedUserAsync(tenantA, a, "Secreta123!", Roles.Admin);
        await _factory.SeedUserAsync(tenantB, b, "Secreta123!", Roles.Admin);

        var ta = await _factory.LoginOkAsync(_client, a, "Secreta123!");
        var tb = await _factory.LoginOkAsync(_client, b, "Secreta123!");

        var ja = await (await _client.SendAsync(Get("/test/any", ta.AccessToken))).Content.ReadFromJsonAsync<JsonElement>();
        var jb = await (await _client.SendAsync(Get("/test/any", tb.AccessToken))).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(tenantA, ja.GetProperty("tenantId").GetGuid());
        Assert.Equal(tenantB, jb.GetProperty("tenantId").GetGuid());
    }

    [Fact]
    public async Task Access_token_expirado_da_401()
    {
        var email = NewEmail();
        await _factory.SeedUserAsync(Guid.NewGuid(), email, "Secreta123!", Roles.Admin);
        var tokens = await _factory.LoginOkAsync(_client, email, "Secreta123!");
        _factory.Clock.Advance(TimeSpan.FromMinutes(20));
        await AssertError(await _client.SendAsync(Get("/test/any", tokens.AccessToken)),
            HttpStatusCode.Unauthorized, "unauthorized");
    }
}

public sealed class PasswordHasherTests
{
    [Fact]
    public void Hash_es_salado_y_verifica()
    {
        var h = new PasswordHasher();
        var a = h.Hash("clave");
        Assert.NotEqual(a, h.Hash("clave"));
        Assert.True(h.Verify("clave", a));
        Assert.False(h.Verify("otra", a));
        Assert.False(h.Verify("clave", "basura"));
    }
}
