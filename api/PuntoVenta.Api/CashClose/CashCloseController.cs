using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PuntoVenta.Api.Auth;

namespace PuntoVenta.Api.CashClose;

[ApiController]
[Route("cash-close")]
[Authorize(Policy = AuthPolicies.AdminOrCajero)]
public sealed class CashCloseController(ICashCloseService cashClose) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<CashCloseResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CashCloseResponse>> Get(
        [FromQuery, Required] DateOnly? day,
        CancellationToken ct) =>
        Ok(await cashClose.GetAsync(User.GetTenantId()!.Value, day!.Value, ct));
}
