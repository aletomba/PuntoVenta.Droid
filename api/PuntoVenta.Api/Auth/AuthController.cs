using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace PuntoVenta.Api.Auth;

[ApiController]
[Route("auth")]
[AllowAnonymous]
public sealed class AuthController(AuthService auth) : ControllerBase
{
    [HttpPost("login")]
    [ProducesResponseType<TokenResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<TokenResponse>> Login(LoginRequest request, CancellationToken ct) =>
        Ok(await auth.LoginAsync(request.Email!, request.Password!, ct));

    [HttpPost("refresh")]
    [ProducesResponseType<TokenResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<TokenResponse>> Refresh(RefreshRequest request, CancellationToken ct) =>
        Ok(await auth.RefreshAsync(request.RefreshToken!, ct));
}
