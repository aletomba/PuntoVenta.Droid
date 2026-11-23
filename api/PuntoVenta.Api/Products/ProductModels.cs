using System.ComponentModel.DataAnnotations;

namespace PuntoVenta.Api.Products;

public sealed record ProductInput(
    [Required(AllowEmptyStrings = false), StringLength(100)]
    string? Barcode,
    [Required(AllowEmptyStrings = false), StringLength(200)]
    string? Name,
    [Required, Range(0, int.MaxValue)]
    int PriceCents,
    [Required, Range(0, int.MaxValue)]
    int Stock,
    string? UpdatedAt);

public sealed record ProductResponse(
    Guid Id,
    string? Barcode,
    string Name,
    int PriceCents,
    int Stock,
    DateTime UpdatedAt,
    bool IsDeleted);
