namespace RouteLedger.Domain;

public static class CustomerRequestType
{
    public const string ScheduleChange = "ScheduleChange";
    public const string Pause = "Pause";
    public const string QuantityChange = "QuantityChange";
    public const string AddressChange = "AddressChange";
}

public static class CustomerRequestStatus
{
    public const string Pending = "Pending";
    public const string UnderReview = "UnderReview";
    public const string Approved = "Approved";
    public const string Rejected = "Rejected";
    public const string MoreInformationRequired = "MoreInformationRequired";
    public const string Applied = "Applied";
    public const string Cancelled = "Cancelled";
}

public sealed class CustomerSavedAddress : Entity
{
    public Guid CustomerAccountId { get; set; }
    public CustomerAccount Account { get; set; } = null!;
    public string Label { get; set; } = "Home";
    public string City { get; set; } = "";
    public string Area { get; set; } = "";
    public string Street { get; set; } = "";
    public string HouseNumber { get; set; } = "";
    public string? Landmark { get; set; }
    public string? Instructions { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public bool IsDefault { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// A customer request. It does not change the delivery schedule until an admin applies it.
/// </summary>
public sealed class CustomerServiceRequest : Entity
{
    public string Code { get; set; } = "";
    public Guid CustomerAccountId { get; set; }
    public CustomerAccount Account { get; set; } = null!;
    public Guid? DeliveryCustomerId { get; set; }
    public Guid? ScheduleId { get; set; }
    public string Type { get; set; } = "";
    public string Status { get; set; } = CustomerRequestStatus.Pending;
    public string CurrentSummary { get; set; } = "";
    public string RequestedSummary { get; set; } = "";
    public string Reason { get; set; } = "";
    public string? Notes { get; set; }
    public string? Frequency { get; set; }
    public int? WeekdayMask { get; set; }
    public string? MonthDays { get; set; }
    public string? TimeWindow { get; set; }
    public DateOnly? EffectiveDate { get; set; }
    public DateOnly? PauseStart { get; set; }
    public DateOnly? ResumeDate { get; set; }
    public int? CurrentQuantity { get; set; }
    public int? RequestedQuantity { get; set; }
    public string? AddressLabel { get; set; }
    public string? City { get; set; }
    public string? Area { get; set; }
    public string? Street { get; set; }
    public string? HouseNumber { get; set; }
    public string? Landmark { get; set; }
    public string? Instructions { get; set; }
    public string AffectedDates { get; set; } = "";
    public string? AdminComment { get; set; }
    public string? ReviewedBy { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class CustomerNotification : Entity
{
    public Guid CustomerAccountId { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public string Kind { get; set; } = "";
    public Guid? RequestId { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// An office alert that a customer request needs review. It stores the request code and type, not payment or contact details.
/// </summary>
public sealed class AdminRequestNotice : Entity
{
    public Guid RequestId { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public DateTime? ReadAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
