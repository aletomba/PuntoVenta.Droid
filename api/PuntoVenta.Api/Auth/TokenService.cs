using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Auth;

public static class AuthClaims
{
    public const string TenantId = "tenant_id";

    public static Guid? GetTenantId(this ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirstValue(TenantId), out var id) ? id : null;

    public static Guid? GetUserId(this ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
}

public static class AuthPolicies
{
    public const string AdminOnly = "AdminOnly";
    public const string AdminOrCajero = "AdminOrCajero";
}

public sealed class TokenService(IOptions<JwtOptions> options, TimeProvider clock)
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTime ExpiresAt) CreateAccessToken(User user)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(_options.AccessTokenMinutes);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims:
            [
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email),
                new Claim(AuthClaims.TenantId, user.TenantId.ToString()),
                new Claim(ClaimTypes.Role, user.Role),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            ],
            notBefore: now,
            expires: expires,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }

    public static string GenerateRefreshToken() =>
        Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(48));

    public static string HashRefreshToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
