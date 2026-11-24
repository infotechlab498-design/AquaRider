using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Data;

public sealed class DevelopmentSeeder
{
    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _users;
    private readonly RoleManager<IdentityRole> _roles;
    private readonly IConfiguration _config;
    private readonly ILogger<DevelopmentSeeder> _logger;

    public DevelopmentSeeder(
        AppDbContext db,
        UserManager<ApplicationUser> users,
        RoleManager<IdentityRole> roles,
        IConfiguration config,
        ILogger<DevelopmentSeeder> logger)
    {
        _db = db;
        _users = users;
        _roles = roles;
        _config = config;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        foreach (var role in new[] { AppRoles.Rider, AppRoles.Admin })
        {
            if (!await _roles.RoleExistsAsync(role))
            {
                await _roles.CreateAsync(new IdentityRole(role));
            }
        }

        await EnsureHqAdminAsync(cancellationToken);

        // Existing environments already have catalog data. Empty DBs need a one-time bootstrap.
        if (await _db.Depots.AnyAsync(cancellationToken))
        {
            return;
        }

        var depot = new Depot
        {
            Name = "Warehouse Depot Hub 02",
            Gate = "Zone C - Bay 04",
            Address = "Satellite Town, Rawalpindi"
        };
        var vehicle = new Vehicle
        {
            Name = "Toyota HiAce",
            Plate = "LEA-8841",
            FleetCode = "PK-RAW-4482",
            CurrentOdometer = 45820
        };
        var zone = new Zone
        {
            Name = "Satellite Town",
            Sector = "4B",
            City = "Rawalpindi",
            Depot = depot,
            IsActive = true
        };
        var route = new DeliveryRoute
        {
            Name = "Satellite Town – Route 03",
            Sector = "4B",
            City = "Rawalpindi",
            Zone = zone,
            Depot = depot
        };

        var riderPassword = _config["Seed:RiderPassword"];
        if (string.IsNullOrWhiteSpace(riderPassword))
        {
            throw new InvalidOperationException("Set Seed:RiderPassword before seeding the development database.");
        }

        _db.Depots.Add(depot);
        _db.Vehicles.Add(vehicle);
        _db.Zones.Add(zone);
        _db.DeliveryRoutes.Add(route);
        await _db.SaveChangesAsync(cancellationToken);

        var rider = new ApplicationUser
        {
            UserName = "ahmed.khan",
            Email = "ahmed.khan@rider.local",
            EmailConfirmed = true,
            FullName = "Ahmed Khan",
            PhoneNumber = "03001234567",
            RiderCode = "RDR-1042",
            DepotId = depot.Id,
            VehicleId = vehicle.Id,
            RouteId = route.Id,
            IsActive = true
        };
        var riderResult = await _users.CreateAsync(rider, riderPassword);
        if (!riderResult.Succeeded)
        {
            throw new InvalidOperationException(string.Join("; ", riderResult.Errors.Select(error => error.Description)));
        }

        await _users.AddToRoleAsync(rider, AppRoles.Rider);
        await EnsureHqAdminAsync(cancellationToken);
    }

    /// <summary>
    /// Creates or updates the Locked V1 HQ admin used by the enterprise web console.
    /// </summary>
    public async Task EnsureHqAdminAsync(CancellationToken cancellationToken = default)
    {
        var password = _config["Seed:AdminPassword"];
        if (string.IsNullOrWhiteSpace(password))
        {
            _logger.LogWarning("Seed:AdminPassword is not set. HQ admin credentials were not updated.");
            return;
        }

        var email = (_config["Seed:AdminEmail"] ?? "infotechlab498@gmail.com").Trim();
        var userName = (_config["Seed:AdminUserName"] ?? email).Trim();
        var fullName = (_config["Seed:AdminFullName"] ?? "HQ Super Admin").Trim();

        _db.ChangeTracker.Clear();

        var admin = await _users.FindByEmailAsync(email)
            ?? await _users.FindByNameAsync(userName);

        if (admin is null)
        {
            admin = new ApplicationUser
            {
                UserName = userName,
                Email = email,
                EmailConfirmed = true,
                FullName = fullName,
                PhoneNumber = "0511234567",
                IsActive = true
            };
            var created = await _users.CreateAsync(admin, password);
            if (!created.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", created.Errors.Select(error => error.Description)));
            }
        }
        else
        {
            admin.FullName = fullName;
            admin.IsActive = true;
            admin.EmailConfirmed = true;

            var nameResult = await _users.SetUserNameAsync(admin, userName);
            if (!nameResult.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", nameResult.Errors.Select(error => error.Description)));
            }

            var emailResult = await _users.SetEmailAsync(admin, email);
            if (!emailResult.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", emailResult.Errors.Select(error => error.Description)));
            }

            if (await _users.HasPasswordAsync(admin))
            {
                var removed = await _users.RemovePasswordAsync(admin);
                if (!removed.Succeeded)
                {
                    throw new InvalidOperationException(string.Join("; ", removed.Errors.Select(error => error.Description)));
                }
            }

            var added = await _users.AddPasswordAsync(admin, password);
            if (!added.Succeeded)
            {
                throw new InvalidOperationException(string.Join("; ", added.Errors.Select(error => error.Description)));
            }
        }

        if (!await _users.IsInRoleAsync(admin, AppRoles.Admin))
        {
            await _users.AddToRoleAsync(admin, AppRoles.Admin);
        }

        if (await _users.IsInRoleAsync(admin, AppRoles.Rider))
        {
            await _users.RemoveFromRoleAsync(admin, AppRoles.Rider);
        }

        _db.ChangeTracker.Clear();
        admin = await _users.FindByIdAsync(admin.Id)
            ?? throw new InvalidOperationException("HQ admin disappeared after credential update.");
        if (!await _users.CheckPasswordAsync(admin, password))
        {
            throw new InvalidOperationException("HQ admin password verification failed immediately after seed.");
        }

        _logger.LogInformation("HQ admin ready for {Email} (password verified).", email);
    }
}
