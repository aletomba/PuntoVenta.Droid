using PuntoVenta.Api.Auth;

namespace PuntoVenta.Api.Products;

public static class ProductsExtensions
{
    public static IServiceCollection AddPuntoVentaProducts(this IServiceCollection services)
    {
        services.AddScoped<IProductsService, ProductsService>();
        return services;
    }

    /// <summary>Traduce ApiException al formato {code,message}.</summary>
    public static IApplicationBuilder UseApiErrors(this IApplicationBuilder app) =>
        app.Use(async (ctx, next) =>
        {
            try
            {
                await next();
            }
            catch (ApiException ex) when (!ctx.Response.HasStarted)
            {
                ctx.Response.StatusCode = ex.Status;
                await ctx.Response.WriteAsJsonAsync(new ApiError(ex.Code, ex.Message));
            }
        });
}
