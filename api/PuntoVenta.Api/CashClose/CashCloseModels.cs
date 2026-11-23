namespace PuntoVenta.Api.CashClose;

public sealed record CashCloseResponse(
    DateOnly Day,
    long TotalCents,
    Dictionary<string, long> ByPaymentMethod);
