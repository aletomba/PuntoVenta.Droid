using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.CashClose;

public interface ICashCloseService
{
    Task<CashCloseResponse> GetAsync(Guid tenantId, DateOnly day, CancellationToken ct);
}

public sealed class CashCloseService(AppDbContext db) : ICashCloseService
{
    public async Task<CashCloseResponse> GetAsync(Guid tenantId, DateOnly day, CancellationToken ct)
    {
        var startUtc = day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var endUtc = day == DateOnly.MaxValue
            ? (DateTime?)null
            : day.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);

        var query = db.Sales
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId && s.Status == "active" && s.Date >= startUtc);
        if (endUtc is not null)
            query = query.Where(s => s.Date < endUtc.Value);

        var totalsByMethod = await query
            .GroupBy(s => s.PaymentMethod)
            .Select(group => new
            {
                PaymentMethod = group.Key,
                TotalCents = group.Sum(s => s.TotalCents)
            })
            .ToListAsync(ct);

        var byPaymentMethod = totalsByMethod.ToDictionary(
            item => item.PaymentMethod,
            item => item.TotalCents);
        return new CashCloseResponse(day, byPaymentMethod.Values.Sum(), byPaymentMethod);
    }
}
