namespace RouteLedger.Domain;

public static class ScheduleFrequency
{
    public const string Weekly = "Weekly";
    public const string Monthly = "Monthly";
    public const string Custom = "Custom";
}

public static class ScheduleStatus
{
    public const string Draft = "Draft";
    public const string Active = "Active";
    public const string Paused = "Paused";
    public const string Cancelled = "Cancelled";
}

public static class OccurrenceStatus
{
    public const string Scheduled = "Scheduled";
    public const string Published = "Published";
    public const string Completed = "Completed";
    public const string Skipped = "Skipped";
    public const string Cancelled = "Cancelled";
}

/// <summary>
/// A customer's repeating delivery plan. Each visit is a separate <see cref="DeliveryOccurrence"/>.
/// A month day that does not exist, such as the 31st in February, is skipped.
/// </summary>
public sealed class RecurringSchedule : Entity
{
    public string ScheduleCode { get; set; } = "";
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public Guid DepotId { get; set; }
    public Depot Depot { get; set; } = null!;
    public string? DefaultRiderId { get; set; }
    public string Status { get; set; } = ScheduleStatus.Draft;
    public string Frequency { get; set; } = ScheduleFrequency.Weekly;
    public int Interval { get; set; } = 1;
    public int WeekdayMask { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public string TimeWindow { get; set; } = "Morning";
    public string TimeZoneId { get; set; } = "Asia/Karachi";
    public bool AutoPublish { get; set; } = true;
    public TimeOnly PublicationTime { get; set; } = new(5, 0);
    public string AssignmentMode { get; set; } = "Fixed";
    public string? Instructions { get; set; }
    public string? DeliveryCity { get; set; }
    public string? DeliveryArea { get; set; }
    public string? DeliveryStreet { get; set; }
    public int Version { get; set; } = 1;
    public string CreatedBy { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public List<RecurringScheduleLine> Lines { get; set; } = [];
    public List<RecurringScheduleMonthDay> MonthDays { get; set; } = [];
    public List<RecurringScheduleCustomDate> CustomDates { get; set; } = [];
    public List<ScheduleException> Exceptions { get; set; } = [];
    public List<DeliveryOccurrence> Occurrences { get; set; } = [];
}

public sealed class RecurringScheduleLine : Entity
{
    public Guid ScheduleId { get; set; }
    public RecurringSchedule Schedule { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int Quantity { get; set; }
    public int ExpectedEmpties { get; set; }
}

public sealed class RecurringScheduleMonthDay : Entity
{
    public Guid ScheduleId { get; set; }
    public RecurringSchedule Schedule { get; set; } = null!;
    public int Day { get; set; }
}

public sealed class RecurringScheduleCustomDate : Entity
{
    public Guid ScheduleId { get; set; }
    public RecurringSchedule Schedule { get; set; } = null!;
    public DateOnly ServiceDate { get; set; }
}

public sealed class ScheduleException : Entity
{
    public Guid ScheduleId { get; set; }
    public RecurringSchedule Schedule { get; set; } = null!;
    public string ExceptionType { get; set; } = "Pause";
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public string Reason { get; set; } = "";
    public string Status { get; set; } = "Open";
    public string CreatedBy { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class DeliveryOccurrence : Entity
{
    public Guid ScheduleId { get; set; }
    public RecurringSchedule Schedule { get; set; } = null!;
    public Guid CustomerId { get; set; }
    public Guid DepotId { get; set; }
    public string? AssignedRiderId { get; set; }
    public DateOnly ServiceDate { get; set; }
    public string TimeWindow { get; set; } = "Morning";
    public int Quantity { get; set; }
    public string Status { get; set; } = OccurrenceStatus.Scheduled;
    /// <summary>Set when this visit was changed on its own, so a later rule edit does not undo that change.</summary>
    public bool Detached { get; set; }
    public Guid? OrderId { get; set; }
    public string? FailureReason { get; set; }
    /// <summary>Address copied when this visit was created. Empty on older visits.</summary>
    public string? AddressSnapshot { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class OccurrenceAssignment : Entity
{
    public Guid OccurrenceId { get; set; }
    public DeliveryOccurrence Occurrence { get; set; } = null!;
    public string RiderId { get; set; } = "";
    public string? PreviousRiderId { get; set; }
    public string AssignedBy { get; set; } = "";
    public string Reason { get; set; } = "";
    public DateTime AssignedAt { get; set; } = DateTime.UtcNow;
}

public sealed class SchedulePublicationLog : Entity
{
    public Guid OccurrenceId { get; set; }
    public string RiderId { get; set; } = "";
    public string Status { get; set; } = "";
    public string? FailureReason { get; set; }
    public int Attempt { get; set; } = 1;
    public DateTime PublishedAt { get; set; } = DateTime.UtcNow;
}
