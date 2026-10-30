using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Auth;

public sealed class AuthException(int status, string code, string message) : Exception(message)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
}

public sealed class AuthService(
    AppDbContext db,
    PasswordHasher hasher,
    TokenService tokens,
    IOptions<JwtOptions> jwtOptions,
    IOptions<LockoutOptions> lockoutOptions,
    TimeProvider clock)
{
    // Hash ficticio para igualar el costo cuando el email no existe.
    private static readonly Lazy<string> DummyHash = new(() => new PasswordHasher().Hash("dummy-password"));

    private readonly JwtOptions _jwt = jwtOptions.Value;
    private readonly LockoutOptions _lockout = lockoutOptions.Value;

    public async Task<TokenResponse> LoginAsync(string email, string password, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var normalized = email.Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == normalized, ct);

        if (user is null)
        {
            hasher.Verify(password, DummyHash.Value);
            throw InvalidCredentials();
        }

        if (user.LockoutEndUtc is { } lockEnd && lockEnd > now)
        {
            throw new AuthException(StatusCodes.Status401Unauthorized, "account_locked",
                "La cuenta está bloqueada temporalmente por intentos fallidos.");
        }

        if (!user.IsActive || !hasher.Verify(password, user.PasswordHash))
        {
            if (user.IsActive)
            {
                // Si el bloqueo anterior ya venció, el contador reinicia.
                if (user.LockoutEndUtc is not null)
                {
                    user.FailedLoginAttempts = 0;
                    user.LockoutEndUtc = null;
                }

                user.FailedLoginAttempts++;
                if (user.FailedLoginAttempts >= _lockout.MaxFailedAttempts)
                {
                    user.LockoutEndUtc = now.AddMinutes(_lockout.LockoutMinutes);
                }

                await db.SaveChangesAsync(ct);
            }

            throw InvalidCredentials();
        }

        user.FailedLoginAttempts = 0;
        user.LockoutEndUtc = null;
        return await IssueAsync(user, now, ct);
    }

    public async Task<TokenResponse> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var hash = TokenService.HashRefreshToken(refreshToken);
        var stored = await db.RefreshTokens.Include(t => t.User).FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

        if (stored?.User is null)
        {
            throw InvalidRefresh();
        }

        if (stored.RevokedAt is not null)
        {
            // Reutilización de un token ya rotado: se asume robo y se revocan todas las sesiones del usuario.
            var active = await db.RefreshTokens
                .Where(t => t.UserId == stored.UserId && t.RevokedAt == null)
                .ToListAsync(ct);
            foreach (var t in active)
            {
                t.RevokedAt = now;
                t.ConcurrencyStamp = Guid.NewGuid();
            }

            await db.SaveChangesAsync(ct);
            throw InvalidRefresh();
        }

        if (stored.ExpiresAt <= now || !stored.User.IsActive)
        {
            throw InvalidRefresh();
        }

        stored.RevokedAt = now;
        stored.ConcurrencyStamp = Guid.NewGuid();
        try
        {
            return await IssueAsync(stored.User, now, ct, stored);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw InvalidRefresh();
        }
    }

    private async Task<TokenResponse> IssueAsync(User user, DateTime now, CancellationToken ct, RefreshToken? previous = null)
    {
        var (access, expiresAt) = tokens.CreateAccessToken(user);
        var raw = TokenService.GenerateRefreshToken();
        var entity = new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = TokenService.HashRefreshToken(raw),
            CreatedAt = now,
            ExpiresAt = now.AddDays(_jwt.RefreshTokenDays)
        };
        db.RefreshTokens.Add(entity);
        if (previous is not null)
        {
            previous.ReplacedByTokenId = entity.Id;
        }

        await db.SaveChangesAsync(ct);
        return new TokenResponse(access, raw, expiresAt);
    }

    private static AuthException InvalidCredentials() =>
        new(StatusCodes.Status401Unauthorized, "invalid_credentials", "Email o contraseña incorrectos.");

    private static AuthException InvalidRefresh() =>
        new(StatusCodes.Status401Unauthorized, "invalid_refresh_token", "El refresh token es inválido, expiró o ya fue usado.");
}
