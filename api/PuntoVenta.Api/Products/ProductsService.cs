using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Products;

public interface IProductsService
{
    Task<List<ProductResponse>> ListAsync(Guid tenantId, CancellationToken ct);
    Task<ProductResponse> CreateAsync(Guid tenantId, ProductInput input, CancellationToken ct);
    Task<ProductResponse> UpdateAsync(Guid tenantId, Guid id, ProductInput input, CancellationToken ct);
    Task DeleteAsync(Guid tenantId, Guid id, CancellationToken ct);
}

public sealed class ProductsService(AppDbContext db, ILogger<ProductsService> logger) : IProductsService
{
    public async Task<List<ProductResponse>> ListAsync(Guid tenantId, CancellationToken ct)
    {
        var products = await db.Products
            .Where(p => p.TenantId == tenantId && !p.IsDeleted)
            .OrderBy(p => p.Name)
            .ToListAsync(ct);

        return products.Select(Map).ToList();
    }

    public async Task<ProductResponse> CreateAsync(Guid tenantId, ProductInput input, CancellationToken ct)
    {
        ValidateInput(input);

        if (!string.IsNullOrWhiteSpace(input.Barcode))
        {
            var exists = await db.Products
                .Where(p => p.TenantId == tenantId && p.Barcode == input.Barcode)
                .AnyAsync(ct);
            if (exists)
                throw new ApiException("barcode_already_exists", $"Barcode '{input.Barcode}' ya existe en este comercio");
        }

        var product = new Product
        {
            Id = Guid.NewGuid(),
            TenantId = tenantId,
            Barcode = string.IsNullOrWhiteSpace(input.Barcode) ? null : input.Barcode,
            Name = input.Name!,
            PriceCents = input.PriceCents,
            Stock = input.Stock,
            UpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        db.Products.Add(product);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Producto creado: {ProductId} en tenant {TenantId}", product.Id, tenantId);

        return Map(product);
    }

    public async Task<ProductResponse> UpdateAsync(Guid tenantId, Guid id, ProductInput input, CancellationToken ct)
    {
        ValidateInput(input);

        var product = await db.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.TenantId == tenantId, ct)
            ?? throw new ApiException("not_found", "Producto no encontrado", StatusCodes.Status404NotFound);

        if (product.IsDeleted)
            throw new ApiException("not_found", "Producto no encontrado", StatusCodes.Status404NotFound);

        // Si el barcode cambió, verificar que el nuevo no exista en el tenant
        if (input.Barcode != product.Barcode && !string.IsNullOrWhiteSpace(input.Barcode))
        {
            var exists = await db.Products
                .Where(p => p.TenantId == tenantId && p.Barcode == input.Barcode && p.Id != id)
                .AnyAsync(ct);
            if (exists)
                throw new ApiException("barcode_already_exists", $"Barcode '{input.Barcode}' ya existe en este comercio");
        }

        product.Barcode = string.IsNullOrWhiteSpace(input.Barcode) ? null : input.Barcode;
        product.Name = input.Name!;
        product.PriceCents = input.PriceCents;
        product.Stock = input.Stock;
        product.UpdatedAt = DateTime.UtcNow;

        await db.SaveChangesAsync(ct);
        logger.LogInformation("Producto actualizado: {ProductId} en tenant {TenantId}", id, tenantId);

        return Map(product);
    }

    public async Task DeleteAsync(Guid tenantId, Guid id, CancellationToken ct)
    {
        var product = await db.Products
            .FirstOrDefaultAsync(p => p.Id == id && p.TenantId == tenantId, ct)
            ?? throw new ApiException("not_found", "Producto no encontrado", StatusCodes.Status404NotFound);

        if (product.IsDeleted)
            throw new ApiException("not_found", "Producto no encontrado", StatusCodes.Status404NotFound);

        product.IsDeleted = true;
        product.UpdatedAt = DateTime.UtcNow;

        await db.SaveChangesAsync(ct);
        logger.LogInformation("Producto eliminado (lógico): {ProductId} en tenant {TenantId}", id, tenantId);
    }

    private static void ValidateInput(ProductInput input)
    {
        if (string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 200)
            throw new ApiException("invalid_request", "El nombre es requerido y debe tener máximo 200 caracteres");

        if (input.PriceCents < 0)
            throw new ApiException("invalid_request", "El precio no puede ser negativo");

        if (input.Stock < 0)
            throw new ApiException("invalid_request", "El stock no puede ser negativo");

        if (!string.IsNullOrWhiteSpace(input.Barcode) && input.Barcode.Length > 100)
            throw new ApiException("invalid_request", "El código de barras no puede tener más de 100 caracteres");
    }

    private static ProductResponse Map(Product p) =>
        new(p.Id, p.Barcode, p.Name, p.PriceCents, p.Stock, p.UpdatedAt, p.IsDeleted);
}
