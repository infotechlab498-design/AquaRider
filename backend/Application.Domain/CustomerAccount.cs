namespace RouteLedger.Domain;

/// <summary>
/// Self-registered customer login. Delivery customers on a rider route stay in Customer.
/// </summary>
public sealed class CustomerAccount : Entity
{
    public string UserId { get; set; } = "";
    public string Code { get; set; } = "";
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public string Phone { get; set; } = "";
    public string Email { get; set; } = "";
    public string City { get; set; } = "";
    public string Area { get; set; } = "";
    public string Street { get; set; } = "";
    public string HouseNumber { get; set; } = "";
    public string? Landmark { get; set; }
    public string? Instructions { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public string Status { get; set; } = "Active";
    /// <summary>Route customer this login manages. Empty until the office links the account.</summary>
    public Guid? DeliveryCustomerId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
