using Microsoft.AspNetCore.Identity;
using RouteLedger.Domain;

namespace RouteLedger.Infrastructure.Identity;

public sealed class ApplicationUser : IdentityUser
{
    public string FullName { get; set; } = "";
    public string? RiderCode { get; set; }
    public Guid? RouteId { get; set; }
    public DeliveryRoute? Route { get; set; }
    public Guid? VehicleId { get; set; }
    public Vehicle? Vehicle { get; set; }
    public Guid? DepotId { get; set; }
    public Depot? Depot { get; set; }
    public Guid? ZoneId { get; set; }
    public Zone? Zone { get; set; }
    public string? WarehousePersonUserId { get; set; }
    public ApplicationUser? WarehousePerson { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastLoginAtUtc { get; set; }
}
