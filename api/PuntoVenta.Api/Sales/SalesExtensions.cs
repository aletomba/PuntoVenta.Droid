namespace PuntoVenta.Api.Sales;

public static class SalesExtensions
{
    public static IServiceCollection AddPuntoVentaSales(this IServiceCollection services)
    {
        services.AddScoped<ISalesService, SalesService>();
        return services;
    }
}
