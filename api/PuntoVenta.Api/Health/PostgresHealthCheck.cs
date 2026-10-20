using Microsoft.Extensions.Diagnostics.HealthChecks;
using PuntoVenta.Api.Data;

namespace PuntoVenta.Api.Health;

public sealed class PostgresHealthCheck(AppDbContext dbContext) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var canConnect = await dbContext.Database.CanConnectAsync(cancellationToken);

        return canConnect
            ? HealthCheckResult.Healthy()
            : HealthCheckResult.Unhealthy("PostgreSQL is not reachable.");
    }
}
