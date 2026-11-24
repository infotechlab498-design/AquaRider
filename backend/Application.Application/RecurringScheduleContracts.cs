using RouteLedger.Domain;

namespace RouteLedger.Application;

public sealed class SaveScheduleRequest
{
    public Guid CustomerId { get; set; }
    public string? RiderId { get; set; }
    public string Frequency { get; set; } = ScheduleFrequency.Weekly;
    public int Interval { get; set; } = 1;
    public List<int> Weekdays { get; set; } = [];
    public List<int> MonthDays { get; set; } = [];
    public List<DateOnly> CustomDates { get; set; } = [];
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public string TimeWindow { get; set; } = "Morning";
    public string TimeZoneId { get; set; } = "Asia/Karachi";
    public bool AutoPublish { get; set; } = true;
    public string PublicationTime { get; set; } = "05:00";
    public string AssignmentMode { get; set; } = "Fixed";
    public string? Instructions { get; set; }
    public int? Version { get; set; }
    public bool Activate { get; set; }
    public List<ScheduleLineRequest> Lines { get; set; } = [];
}

public sealed class ScheduleLineRequest
{
    public Guid ProductId { get; set; }
    public int Quantity { get; set; }
    public int ExpectedEmpties { get; set; }
}

public sealed class PauseScheduleRequest
{
    public string Mode { get; set; } = "schedule";
    public DateOnly? StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public string Reason { get; set; } = "";
    public bool LeaveDispatched { get; set; }
}

public sealed class OccurrenceDateRequest
{
    public DateOnly Date { get; set; }
}

public sealed class OccurrenceRiderRequest
{
    public string RiderId { get; set; } = "";
}

public sealed class OccurrenceQuantityRequest
{
    public int Quantity { get; set; }
}

public sealed record RecurringTabCounts(int All, int Weekly, int Monthly, int Paused, int Expiring, int Exceptions, int Unassigned);

public sealed record RecurringBoardDto(
    int ActivePlans,
    int DeliveriesThisMonth,
    int Paused,
    int Unassigned,
    int RidersAssigned,
    int Total,
    int Page,
    int PageSize,
    RecurringTabCounts Tabs,
    IReadOnlyList<RecurringScheduleRowDto> Rows,
    IReadOnlyList<ScheduleDepotOptionDto> Depots);

public sealed record ScheduleDepotOptionDto(Guid Id, string Name);

public sealed record RecurringScheduleRowDto(
    Guid Id,
    string ScheduleCode,
    Guid CustomerId,
    string CustomerName,
    string CustomerCode,
    string Phone,
    string Address,
    string ProductSummary,
    int QuantityPerVisit,
    string Frequency,
    int MonthlyCount,
    string? RiderId,
    string? RiderName,
    string? RiderCode,
    DateOnly? NextDate,
    string Status,
    int Version);

public sealed record RecurringScheduleDetailDto(
    Guid Id,
    string ScheduleCode,
    string Status,
    int Version,
    Guid CustomerId,
    string CustomerName,
    string CustomerCode,
    string Phone,
    string Address,
    decimal? Latitude,
    decimal? Longitude,
    string RouteName,
    string DepotName,
    Guid DepotId,
    string? RiderId,
    string? RiderName,
    string? RiderCode,
    bool RiderActive,
    bool ShiftOpen,
    int RiderWorkload,
    string Frequency,
    int Interval,
    IReadOnlyList<int> Weekdays,
    IReadOnlyList<int> MonthDays,
    IReadOnlyList<DateOnly> CustomDates,
    DateOnly StartDate,
    DateOnly? EndDate,
    string TimeWindow,
    string TimeZoneId,
    bool AutoPublish,
    string PublicationTime,
    string AssignmentMode,
    string? Instructions,
    int MonthlyCount,
    int MonthlyBottles,
    IReadOnlyList<ScheduleLineDto> Lines,
    IReadOnlyList<ScheduleExceptionDto> Exceptions,
    string MonthDayRule);

public sealed record ScheduleLineDto(Guid ProductId, string Name, string Sku, string UnitLabel, int Quantity, int ExpectedEmpties, decimal UnitPrice);

public sealed record ScheduleExceptionDto(Guid Id, string ExceptionType, DateOnly StartDate, DateOnly EndDate, string Reason, string Status);

public sealed record SchedulePreviewDto(
    IReadOnlyList<DateOnly> Dates,
    int TotalDeliveries,
    int TotalBottles,
    string MonthDayRule);

public sealed record ScheduleCalendarDto(int Year, int Month, IReadOnlyList<ScheduleCalendarDayDto> Days);

public sealed record ScheduleCalendarDayDto(
    DateOnly Date,
    int Deliveries,
    int Bottles,
    IReadOnlyList<ScheduleCalendarItemDto> Items);

public sealed record ScheduleCalendarItemDto(
    Guid OccurrenceId,
    Guid ScheduleId,
    string ScheduleCode,
    string CustomerName,
    string CustomerCode,
    string Address,
    string ProductSummary,
    int Quantity,
    string TimeWindow,
    string? RiderId,
    string? RiderName,
    string? RiderCode,
    string Status);

public interface IRecurringScheduleService
{
    Task<ServiceResult<RecurringBoardDto>> BoardAsync(string? search, string? tab, Guid? depotId, Guid? productId, string? riderId, int page, int pageSize, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> SaveAsync(Guid? id, SaveScheduleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<SchedulePreviewDto>> PreviewAsync(SaveScheduleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> PauseAsync(Guid id, PauseScheduleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> ResumeAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> CancelAsync(Guid id, string reason, CancellationToken cancellationToken);
    Task<ServiceResult<RecurringScheduleDetailDto>> DuplicateAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<ScheduleCalendarDto>> CalendarAsync(int year, int month, Guid? scheduleId, string? riderId, CancellationToken cancellationToken);
    Task<ServiceResult<ScheduleCalendarItemDto>> SkipAsync(Guid occurrenceId, CancellationToken cancellationToken);
    Task<ServiceResult<ScheduleCalendarItemDto>> RescheduleAsync(Guid occurrenceId, DateOnly date, CancellationToken cancellationToken);
    Task<ServiceResult<ScheduleCalendarItemDto>> ReassignAsync(Guid occurrenceId, string riderId, CancellationToken cancellationToken);
    Task<ServiceResult<ScheduleCalendarItemDto>> ChangeQuantityAsync(Guid occurrenceId, int quantity, CancellationToken cancellationToken);
    Task RunDueAsync(CancellationToken cancellationToken);
}
