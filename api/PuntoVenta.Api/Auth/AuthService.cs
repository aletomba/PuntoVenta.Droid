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
                await RegisterFailedAttemptAsync(user.Id, now, ct);
            }

            throw InvalidCredentials();
        }

        await db.Users.Where(u => u.Id == user.Id)
            .ExecuteUpdateAsync(s => s
                .SetProperty(u => u.FailedLoginAttempts, 0)
                .SetProperty(u => u.LockoutEndUtc, (DateTime?)null), ct);
        return await IssueAsync(user, now, ct);
    }

    /// <summary>
    /// Registra un fallo de forma atómica en la base (sin read-modify-write en memoria),
    /// para que solicitudes concurrentes no puedan eludir el bloqueo.
    /// </summary>
    private async Task RegisterFailedAttemptAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        // Si el bloqueo anterior ya venció, el contador reinicia.
        await db.Users
            .Where(u => u.Id == userId && u.LockoutEndUtc != null && u.LockoutEndUtc <= now)
            .ExecuteUpdateAsync(s => s
                .SetProperty(u => u.FailedLoginAttempts, 0)
                .SetProperty(u => u.LockoutEndUtc, (DateTime?)null), ct);

        await db.Users.Where(u => u.Id == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.FailedLoginAttempts, u => u.FailedLoginAttempts + 1), ct);

        var max = _lockout.MaxFailedAttempts;
        var lockoutEnd = now.AddMinutes(_lockout.LockoutMinutes);
        await db.Users
            .Where(u => u.Id == userId && u.FailedLoginAttempts >= max && u.LockoutEndUtc == null)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.LockoutEndUtc, (DateTime?)lockoutEnd), ct);
    }

    private async Task RevokeAllSessionsAsync(Guid userId, DateTime now, CancellationToken ct)
    {
        var stamp = Guid.NewGuid();
        await db.RefreshTokens
            .Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s
                .SetProperty(t => t.RevokedAt, (DateTime?)now)
                .SetProperty(t => t.ConcurrencyStamp, stamp), ct);
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
            await RevokeAllSessionsAsync(stored.UserId, now, ct);
            throw InvalidRefresh();
        }

        if (stored.ExpiresAt <= now || !stored.User.IsActive)
        {
            throw InvalidRefresh();
        }

        var newId = Guid.NewGuid();
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // Rotación atómica: solo una solicitud logra pasar el token de activo a revocado.
        var stamp = Guid.NewGuid();
        var rotated = await db.RefreshTokens
            .Where(t => t.Id == stored.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s
                .SetProperty(t => t.RevokedAt, (DateTime?)now)
                .SetProperty(t => t.ReplacedByTokenId, (Guid?)newId)
                .SetProperty(t => t.ConcurrencyStamp, stamp), ct);

        if (rotated == 0)
        {
            // Perdió la carrera: otra solicitud ya usó este token; se trata como reutilización.
            await RevokeAllSessionsAsync(stored.UserId, now, ct);
            await tx.CommitAsync(ct);
            throw InvalidRefresh();
        }

        var response = await IssueAsync(stored.User, now, ct, newId);
        await tx.CommitAsync(ct);
        return response;
    }

    private async Task<TokenResponse> IssueAsync(User user, DateTime now, CancellationToken ct, Guid? refreshId = null)
    {
        var (access, expiresAt) = tokens.CreateAccessToken(user);
        var raw = TokenService.GenerateRefreshToken();
        var entity = new RefreshToken
        {
            Id = refreshId ?? Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = TokenService.HashRefreshToken(raw),
            CreatedAt = now,
            ExpiresAt = now.AddDays(_jwt.RefreshTokenDays)
        };
        db.RefreshTokens.Add(entity);
        await db.SaveChangesAsync(ct);
        return new TokenResponse(access, raw, expiresAt);
    }

    private static AuthException InvalidCredentials() =>
        new(StatusCodes.Status401Unauthorized, "invalid_credentials", "Email o contraseña incorrectos.");

    private static AuthException InvalidRefresh() =>
        new(StatusCodes.Status401Unauthorized, "invalid_refresh_token", "El refresh token es inválido, expiró o ya fue usado.");
}
