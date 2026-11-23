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

public sealed class Product
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Tenant? Tenant { get; set; }

    /// <summary>Único por tenant, puede ser nulo (venta con precio libre).</summary>
    public string? Barcode { get; set; }
    public string Name { get; set; } = string.Empty;
    
    /// <summary>Precio en centavos.</summary>
    public int PriceCents { get; set; }
    public int Stock { get; set; }
    public DateTime UpdatedAt { get; set; }
    public bool IsDeleted { get; set; }
}

public sealed class Sale
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid UserId { get; set; }
    public DateTime Date { get; set; }
    public long TotalCents { get; set; }
    public string PaymentMethod { get; set; } = string.Empty;
    public string Status { get; set; } = "active";
    public DateTime? VoidedAt { get; set; }
    public Guid? VoidedByUserId { get; set; }
    public string? VoidReason { get; set; }
    public List<SaleItem> Items { get; set; } = [];
}

public sealed class SaleItem
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid SaleId { get; set; }
    public Sale? Sale { get; set; }
    public Guid? ProductId { get; set; }
    public Product? Product { get; set; }
    public string Description { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public long UnitPriceCents { get; set; }
}
