using System.ComponentModel.DataAnnotations;

namespace PuntoVenta.Api.Auth;

public sealed class JwtOptions
{
    public const string Section = "Jwt";

    public string Issuer { get; set; } = "PuntoVenta.Api";
    public string Audience { get; set; } = "PuntoVenta.App";

    /// <summary>Clave de firma HMAC. Debe venir de configuración/variable de entorno (Jwt__SigningKey); mínimo 32 bytes.</summary>
    public string SigningKey { get; set; } = string.Empty;
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;
}

public sealed class LockoutOptions
{
    public const string Section = "Lockout";

    public int MaxFailedAttempts { get; set; } = 5;
    public int LockoutMinutes { get; set; } = 15;
}

public sealed record LoginRequest(
    [Required, EmailAddress] string? Email,
    [Required] string? Password);

public sealed record RefreshRequest([Required] string? RefreshToken);

public sealed record TokenResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt);

public sealed record ApiError(string Code, string Message);
