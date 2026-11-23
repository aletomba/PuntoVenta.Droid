using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PuntoVenta.Api.Auth;

namespace PuntoVenta.Api.Sales;

[ApiController]
[Route("sales")]
[Authorize(Policy = AuthPolicies.AdminOrCajero)]
public sealed class SalesController(ISalesService sales) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<List<SaleResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<List<SaleResponse>>> List(
        [FromQuery] DateTimeOffset? from,
        [FromQuery] DateTimeOffset? to,
        CancellationToken ct) =>
        Ok(await sales.ListAsync(User.GetTenantId()!.Value, from, to, ct));

    [HttpPost]
    [ProducesResponseType<SaleResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ApiError>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SaleResponse>> Create(SaleInput request, CancellationToken ct)
    {
        var sale = await sales.CreateAsync(
            User.GetTenantId()!.Value,
            User.GetUserId()!.Value,
            request,
            ct);
        return CreatedAtAction(nameof(List), null, sale);
    }
}
