namespace PuntoVenta.Api.Data;

public static class Roles
{
    public const string Admin = "Admin";
    public const string Cajero = "Cajero";

    public static readonly string[] All = [Admin, Cajero];
}

public sealed class Tenant
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public sealed class User
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Tenant? Tenant { get; set; }

    /// <summary>Email normalizado (minúsculas); único globalmente porque el login no recibe tenant.</summary>
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = Roles.Cajero;
    public bool IsActive { get; set; } = true;
    public int FailedLoginAttempts { get; set; }
    public DateTime? LockoutEndUtc { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class RefreshToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>SHA-256 (hex) del token; el valor en claro nunca se guarda.</summary>
    public string TokenHash { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public Guid? ReplacedByTokenId { get; set; }

    /// <summary>Token de concurrencia para que una rotación concurrente solo gane una vez.</summary>
    public Guid ConcurrencyStamp { get; set; } = Guid.NewGuid();
}
