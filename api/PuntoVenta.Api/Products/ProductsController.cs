using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PuntoVenta.Api.Auth;

namespace PuntoVenta.Api.Products;

[ApiController]
[Route("products")]
[Authorize(Policy = AuthPolicies.AdminOrCajero)]
public sealed class ProductsController(IProductsService products) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<List<ProductResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<List<ProductResponse>>> List(CancellationToken ct)
    {
        var tenantId = User.GetTenantId()!.Value;
        return Ok(await products.ListAsync(tenantId, ct));
    }

    [HttpPost]
    [ProducesResponseType<ProductResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ApiError>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ProductResponse>> Create(ProductInput request, CancellationToken ct)
    {
        var tenantId = User.GetTenantId()!.Value;
        var product = await products.CreateAsync(tenantId, request, ct);
        return CreatedAtAction(nameof(Create), product);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType<ProductResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ApiError>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ApiError>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ProductResponse>> Update(Guid id, ProductInput request, CancellationToken ct)
    {
        var tenantId = User.GetTenantId()!.Value;
        var product = await products.UpdateAsync(tenantId, id, request, ct);
        return Ok(product);
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ApiError>(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ApiError>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var tenantId = User.GetTenantId()!.Value;
        await products.DeleteAsync(tenantId, id, ct);
        return NoContent();
    }
}
