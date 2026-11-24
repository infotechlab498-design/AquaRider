using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Api.Data;

public sealed class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var connection = Environment.GetEnvironmentVariable("ROUTELEDGER_CONNECTION")
            ?? "Server=localhost\\SQLEXPRESS;Database=AquaRider;Trusted_Connection=True;TrustServerCertificate=True;";
        var options = new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(connection).Options;
        return new AppDbContext(options);
    }
}
