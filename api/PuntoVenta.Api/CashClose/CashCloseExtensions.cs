namespace PuntoVenta.Api.CashClose;

public static class CashCloseExtensions
{
    public static IServiceCollection AddPuntoVentaCashClose(this IServiceCollection services)
    {
        services.AddScoped<ICashCloseService, CashCloseService>();
        return services;
    }
}
