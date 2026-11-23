using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace PuntoVenta.Api.Sales;

public sealed record SaleInput(
    Guid Id,
    [Required] string? PaymentMethod,
    [Required] List<SaleItemInput?>? Items);

public sealed record SaleItemInput(
    Guid Id,
    Guid? ProductId,
    [Required(AllowEmptyStrings = true)] string? Description,
    [Range(1, int.MaxValue)] int Quantity,
    [Range(0, long.MaxValue)]
    [property: JsonRequired] long UnitPriceCents);

public sealed record SaleItemResponse(
    Guid Id,
    Guid? ProductId,
    string Description,
    int Quantity,
    long UnitPriceCents);

public sealed record SaleResponse(
    Guid Id,
    string PaymentMethod,
    List<SaleItemResponse> Items,
    long TotalCents,
    string Status,
    DateTime Date,
    DateTime? VoidedAt,
    Guid? VoidedByUserId,
    string? VoidReason);
