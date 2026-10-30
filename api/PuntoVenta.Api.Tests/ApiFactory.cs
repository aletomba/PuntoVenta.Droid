using System.Net.Http.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Tests;

public sealed class TestClock : TimeProvider
{
    private DateTimeOffset _now = new(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
    public override DateTimeOffset GetUtcNow() => _now;
    public void Advance(TimeSpan span) => _now += span;
}

/// <summary>Endpoints solo de prueba para verificar políticas por rol y tenant.</summary>
[ApiController]
[Route("test")]
public sealed class PermissionProbeController : ControllerBase
{
    [HttpGet("admin")]
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    public IActionResult AdminOnly() => Ok(new { tenantId = User.GetTenantId() });

    [HttpGet("any")]
    [Authorize(Policy = AuthPolicies.AdminOrCajero)]
    public IActionResult Any() => Ok(new { tenantId = User.GetTenantId() });
}

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public TestClock Clock { get; } = new();
    private readonly string _dbName = Guid.NewGuid().ToString();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, cfg) => cfg.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = "test-only-signing-key-0123456789-abcdefghijklmnop",
            ["ConnectionStrings:Default"] = "Host=unused"
        }));
        builder.ConfigureServices(services =>
        {
            foreach (var d in services.Where(d =>
                         d.ServiceType == typeof(DbContextOptions<AppDbContext>) ||
                         d.ServiceType == typeof(DbContextOptions) ||
                         (d.ServiceType.IsGenericType &&
                          d.ServiceType.GetGenericArguments().Contains(typeof(AppDbContext)))).ToList())
            {
                services.Remove(d);
            }

            services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase(_dbName));
            services.RemoveAll<TimeProvider>();
            services.AddSingleton<TimeProvider>(Clock);
            services.AddControllers().AddApplicationPart(typeof(PermissionProbeController).Assembly);
        });
    }

    public async Task<User> SeedUserAsync(Guid tenantId, string email, string password, string role, bool active = true)
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if (!await db.Tenants.AnyAsync(t => t.Id == tenantId))
        {
            db.Tenants.Add(new Tenant { Id = tenantId, Name = "Comercio " + tenantId, CreatedAt = DateTime.UtcNow });
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            TenantId = tenantId,
            Email = email.ToLowerInvariant(),
            PasswordHash = new PasswordHasher().Hash(password),
            Role = role,
            IsActive = active,
            CreatedAt = DateTime.UtcNow
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    public async Task<T> WithDbAsync<T>(Func<AppDbContext, Task<T>> action)
    {
        using var scope = Services.CreateScope();
        return await action(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    public async Task<TokenResponse> LoginOkAsync(HttpClient client, string email, string password)
    {
        var res = await client.PostAsJsonAsync("/auth/login", new { email, password });
        res.EnsureSuccessStatusCode();
        return (await res.Content.ReadFromJsonAsync<TokenResponse>())!;
    }
}
