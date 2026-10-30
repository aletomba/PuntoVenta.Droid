using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using PuntoVenta.Api.Auth;
using PuntoVenta.Api.Data;
using PuntoVenta.Api.Health;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddPuntoVentaAuth(builder.Configuration);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));
builder.Services
    .AddHealthChecks()
    .AddCheck<PostgresHealthCheck>("postgres", tags: ["ready"]);

builder.Host.UseSerilog((context, configuration) =>
    configuration
        .ReadFrom.Configuration(context.Configuration)
        .Enrich.FromLogContext()
        .WriteTo.Console());

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthErrors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = _ => false
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});

app.Run();

public partial class Program;
