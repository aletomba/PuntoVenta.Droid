using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Sales;

public interface ISalesService
{
    Task<SaleResponse> CreateAsync(Guid tenantId, Guid userId, SaleInput input, CancellationToken ct);
    Task<List<SaleResponse>> ListAsync(
        Guid tenantId,
        DateTimeOffset? from,
        DateTimeOffset? to,
        CancellationToken ct);
}

public sealed class SalesService(AppDbContext db, TimeProvider clock) : ISalesService
{
    private static readonly HashSet<string> PaymentMethods =
        ["cash", "debit", "credit", "transfer", "other"];

    public async Task<SaleResponse> CreateAsync(
        Guid tenantId,
        Guid userId,
        SaleInput input,
        CancellationToken ct)
    {
        if (input.Id == Guid.Empty)
            throw new ApiException("invalid_request", "El id de la venta es obligatorio.");

        var existing = await FindSaleAsync(tenantId, input.Id, ct);
        if (existing is not null)
            return Map(existing);

        var totalCents = ValidateInput(input);
        var items = input.Items!.Select(item => item!).ToList();
        var quantitiesByProduct = GetProductQuantities(items);
        await EnsureProductsBelongToTenantAsync(tenantId, quantitiesByProduct.Keys, ct);

        var now = clock.GetUtcNow().UtcDateTime;
        var sale = new Sale
        {
            Id = input.Id,
            TenantId = tenantId,
            UserId = userId,
            Date = now,
            TotalCents = totalCents,
            PaymentMethod = input.PaymentMethod!,
            Status = "active",
            Items = items.Select(item => new SaleItem
            {
                Id = item.Id,
                TenantId = tenantId,
                SaleId = input.Id,
                ProductId = item.ProductId,
                Description = item.Description!,
                Quantity = item.Quantity,
                UnitPriceCents = item.UnitPriceCents
            }).ToList()
        };

        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            db.Sales.Add(sale);
            await db.SaveChangesAsync(ct);

            foreach (var (productId, quantity) in quantitiesByProduct)
            {
                var changed = await db.Products
                    .Where(p => p.Id == productId && p.TenantId == tenantId &&
                                !p.IsDeleted && p.Stock >= quantity)
                    .ExecuteUpdateAsync(update => update
                        .SetProperty(p => p.Stock, p => p.Stock - quantity)
                        .SetProperty(p => p.UpdatedAt, now), ct);

                if (changed == 0)
                {
                    var productExists = await db.Products.AnyAsync(
                        p => p.Id == productId && p.TenantId == tenantId && !p.IsDeleted, ct);
                    if (!productExists)
                        throw new ApiException("product_not_found", "Uno de los productos no existe.");

                    throw new ApiException("insufficient_stock", "El stock disponible no alcanza para completar la venta.");
                }
            }

            await transaction.CommitAsync(ct);
            return Map(sale);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            existing = await FindSaleAsync(tenantId, input.Id, ct);
            if (existing is not null)
                return Map(existing);

            throw;
        }
    }

    public async Task<List<SaleResponse>> ListAsync(
        Guid tenantId,
        DateTimeOffset? from,
        DateTimeOffset? to,
        CancellationToken ct)
    {
        if (from is not null && to is not null && from > to)
            throw new ApiException("invalid_request", "El parámetro from no puede ser posterior a to.");

        var query = db.Sales
            .AsNoTracking()
            .Include(s => s.Items)
            .Where(s => s.TenantId == tenantId);

        if (from is not null)
        {
            var fromUtc = from.Value.UtcDateTime;
            query = query.Where(s => s.Date >= fromUtc);
        }

        if (to is not null)
        {
            var toUtc = to.Value.UtcDateTime;
            query = query.Where(s => s.Date <= toUtc);
        }

        var sales = await query
            .OrderByDescending(s => s.Date)
            .ThenBy(s => s.Id)
            .ToListAsync(ct);
        return sales.Select(Map).ToList();
    }

    private async Task<Sale?> FindSaleAsync(Guid tenantId, Guid id, CancellationToken ct) =>
        await db.Sales
            .AsNoTracking()
            .Include(s => s.Items)
            .SingleOrDefaultAsync(s => s.TenantId == tenantId && s.Id == id, ct);

    private async Task EnsureProductsBelongToTenantAsync(
        Guid tenantId,
        IEnumerable<Guid> productIds,
        CancellationToken ct)
    {
        var ids = productIds.ToArray();
        if (ids.Length == 0)
            return;

        var found = await db.Products
            .Where(p => p.TenantId == tenantId && !p.IsDeleted && ids.Contains(p.Id))
            .Select(p => p.Id)
            .ToListAsync(ct);

        if (found.Count != ids.Length)
            throw new ApiException("product_not_found", "Uno de los productos no existe.");
    }

    private static Dictionary<Guid, int> GetProductQuantities(IEnumerable<SaleItemInput> items)
    {
        var quantities = new Dictionary<Guid, long>();
        foreach (var item in items)
        {
            if (item.ProductId is not { } productId)
                continue;

            quantities.TryGetValue(productId, out var current);
            var next = current + item.Quantity;
            if (next > int.MaxValue)
                throw new ApiException("invalid_request", "La cantidad total por producto es inválida.");
            quantities[productId] = next;
        }

        return quantities.ToDictionary(pair => pair.Key, pair => (int)pair.Value);
    }

    private static long CalculateTotal(IEnumerable<SaleItemInput> items)
    {
        long total = 0;
        foreach (var item in items)
        {
            if (item.UnitPriceCents > 0 && item.Quantity > long.MaxValue / item.UnitPriceCents)
                throw new ApiException("invalid_request", "El total de la venta excede el máximo permitido.");

            var lineTotal = item.UnitPriceCents * item.Quantity;
            if (lineTotal > long.MaxValue - total)
                throw new ApiException("invalid_request", "El total de la venta excede el máximo permitido.");
            total += lineTotal;
        }

        return total;
    }

    private static long ValidateInput(SaleInput input)
    {
        if (input.PaymentMethod is null || !PaymentMethods.Contains(input.PaymentMethod))
            throw new ApiException("invalid_request", "El medio de pago no es válido.");

        if (input.Items is null)
            throw new ApiException("invalid_request", "La lista de artículos es obligatoria.");

        if (input.Items.Any(item => item is null))
            throw new ApiException("invalid_request", "La lista contiene un artículo inválido.");

        var items = input.Items.Select(item => item!).ToList();
        if (items.Any(item =>
                item.Id == Guid.Empty ||
                item.ProductId == Guid.Empty ||
                item.Description is null ||
                item.Quantity < 1 ||
                item.UnitPriceCents < 0))
        {
            throw new ApiException("invalid_request", "Uno o más artículos de la venta son inválidos.");
        }

        if (items.Select(item => item.Id).Distinct().Count() != items.Count)
            throw new ApiException("invalid_request", "Los ids de artículos deben ser únicos dentro de la venta.");

        return CalculateTotal(items);
    }

    private static SaleResponse Map(Sale sale) =>
        new(
            sale.Id,
            sale.PaymentMethod,
            sale.Items.OrderBy(item => item.Id)
                .Select(item => new SaleItemResponse(
                    item.Id,
                    item.ProductId,
                    item.Description,
                    item.Quantity,
                    item.UnitPriceCents))
                .ToList(),
            sale.TotalCents,
            sale.Status,
            sale.Date,
            sale.VoidedAt,
            sale.VoidedByUserId,
            sale.VoidReason);
}
