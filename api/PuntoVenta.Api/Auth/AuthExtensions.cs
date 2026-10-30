using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Auth;

public static class AuthExtensions
{
    public const int MinSigningKeyBytes = 32;

    public static IServiceCollection AddPuntoVentaAuth(this IServiceCollection services, IConfiguration config)
    {
        services.AddOptions<JwtOptions>().Bind(config.GetSection(JwtOptions.Section))
            .Validate(o => Encoding.UTF8.GetByteCount(o.SigningKey) >= MinSigningKeyBytes,
                "Jwt:SigningKey es obligatoria y debe tener al menos 32 bytes (usar Jwt__SigningKey).")
            .ValidateOnStart();
        services.AddOptions<LockoutOptions>().Bind(config.GetSection(LockoutOptions.Section));

        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<PasswordHasher>();
        services.AddScoped<TokenService>();
        services.AddScoped<AuthService>();

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>, TimeProvider>((bearer, jwt, clock) =>
            {
                var o = jwt.Value;
                bearer.TimeProvider = clock;
                bearer.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = o.Issuer,
                    ValidateAudience = true,
                    ValidAudience = o.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(o.SigningKey)),
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(30),
                    LifetimeValidator = (notBefore, expires, _, p) =>
                    {
                        var now = clock.GetUtcNow().UtcDateTime;
                        return expires is not null && expires.Value.Add(p.ClockSkew) > now
                            && (notBefore is null || notBefore.Value.Subtract(p.ClockSkew) <= now);
                    }
                };
                bearer.Events = new JwtBearerEvents
                {
                    OnChallenge = async ctx =>
                    {
                        ctx.HandleResponse();
                        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
                        await ctx.Response.WriteAsJsonAsync(new ApiError("unauthorized", "Autenticación requerida o token inválido."));
                    },
                    OnForbidden = async ctx =>
                    {
                        ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
                        await ctx.Response.WriteAsJsonAsync(new ApiError("forbidden", "No tenés permisos para esta operación."));
                    }
                };
            });

        services.AddAuthorizationBuilder()
            .AddPolicy(AuthPolicies.AdminOnly, p => p.RequireAuthenticatedUser().RequireRole(Roles.Admin))
            .AddPolicy(AuthPolicies.AdminOrCajero, p => p.RequireAuthenticatedUser().RequireRole(Roles.Admin, Roles.Cajero));

        services.Configure<ApiBehaviorOptions>(o =>
            o.InvalidModelStateResponseFactory = _ =>
                new BadRequestObjectResult(new ApiError("invalid_request", "La solicitud es inválida.")));

        return services;
    }

    /// <summary>Traduce AuthException al formato {code,message}.</summary>
    public static IApplicationBuilder UseAuthErrors(this IApplicationBuilder app) =>
        app.Use(async (ctx, next) =>
        {
            try
            {
                await next();
            }
            catch (AuthException ex) when (!ctx.Response.HasStarted)
            {
                ctx.Response.StatusCode = ex.Status;
                await ctx.Response.WriteAsJsonAsync(new ApiError(ex.Code, ex.Message));
            }
        });
}
