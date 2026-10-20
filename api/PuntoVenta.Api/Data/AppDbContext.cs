using Microsoft.EntityFrameworkCore;

namespace PuntoVenta.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options);
