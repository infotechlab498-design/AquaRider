namespace RouteLedger.Application;

public sealed class SubmitCustomerRequest
{
    public string Type { get; set; } = "";
    public Guid? ScheduleId { get; set; }
    public string Reason { get; set; } = "";
    public string? Notes { get; set; }
    public string? Frequency { get; set; }
    public List<int> Weekdays { get; set; } = [];
    public List<int> MonthDays { get; set; } = [];
    public string? TimeWindow { get; set; }
    public DateOnly? EffectiveDate { get; set; }
    public DateOnly? PauseStart { get; set; }
    public DateOnly? ResumeDate { get; set; }
    public int? Quantity { get; set; }
    public string? AddressLabel { get; set; }
    public string? City { get; set; }
    public string? Area { get; set; }
    public string? Street { get; set; }
    public string? HouseNumber { get; set; }
    public string? Landmark { get; set; }
    public string? Instructions { get; set; }
}

public sealed class SaveCustomerAddressRequest
{
    public string Label { get; set; } = "Home";
    public string City { get; set; } = "";
    public string Area { get; set; } = "";
    public string Street { get; set; } = "";
    public string HouseNumber { get; set; } = "";
    public string? Landmark { get; set; }
    public string? Instructions { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
}

public sealed class LinkCustomerAccountRequest
{
    public Guid? DeliveryCustomerId { get; set; }
}

public sealed class UpdateCustomerProfileRequest
{
    public string FirstName { get; set; } = "";
    public string LastName { get; set; } = "";
    public string Phone { get; set; } = "";
}

public sealed record CustomerInvoiceLineDto(string Product, int Quantity, decimal UnitPrice, decimal Amount);

public sealed record CustomerInvoiceDetailDto(
    string Number,
    string Date,
    decimal Amount,
    decimal Paid,
    decimal Remaining,
    string Status,
    IReadOnlyList<CustomerInvoiceLineDto> Lines,
    IReadOnlyList<CustomerPaymentRowDto> Payments,
    string PdfNote);

public sealed class CustomerAccountStatusRequest
{
    public string Status { get; set; } = "Active";
}

public sealed class ReviewCustomerRequest
{
    public string Action { get; set; } = "";
    public string? Comment { get; set; }
}

public sealed record CustomerMoneyDto(
    decimal TotalBilled,
    decimal TotalPaid,
    decimal Outstanding,
    decimal Overdue,
    string? LastPaymentDate,
    decimal? LastPaymentAmount,
    string Note);

public sealed record CustomerVisitDto(
    string Date,
    int Quantity,
    string Status,
    string Address,
    string TimeWindow,
    string Reference,
    string Product,
    string? CompletedAt,
    string? Proof,
    string Weekday = "",
    string AddressLabel = "Route address",
    string ScheduleCode = "",
    string ScheduleId = "",
    bool AddressFromSnapshot = false,
    string? Instructions = null);

public sealed record CustomerPlanDto(
    Guid ScheduleId,
    string Code,
    string Status,
    string Product,
    int Quantity,
    string Frequency,
    string StartDate,
    string? EndDate,
    string Address,
    string TimeWindow,
    string? RiderName,
    string DepotName,
    string ZoneName,
    string AddressLabel = "Route address");

public sealed record CustomerCountsDto(int Scheduled, int Completed, int Upcoming, int SkippedOrCancelled, int Total = 0);

public sealed record CustomerHomeDto(
    string FirstName,
    string FullName,
    string CustomerCode,
    string AccountStatus,
    bool Linked,
    string LinkMessage,
    CustomerPlanDto? Subscription,
    CustomerCountsDto Overview,
    CustomerMoneyDto Payments,
    IReadOnlyList<CustomerVisitDto> Upcoming,
    int UnreadNotifications,
    int ActiveSchedules = 0,
    string City = "",
    int PendingRequests = 0);

public sealed record CustomerMonthCountDto(string Month, int Count);

public sealed record CustomerOpsRowDto(string Date, string CustomerName, string ScheduleCode, int Quantity, string Status, string Address);

public sealed record CustomerOpsOverviewDto(
    int TotalCustomers,
    int ActiveCustomers,
    int WithSchedules,
    int UpcomingDeliveries,
    int CompletedDeliveries,
    int WithBalance,
    int PendingRequests,
    IReadOnlyList<CustomerMonthCountDto> Registrations,
    IReadOnlyList<CustomerMonthCountDto> Deliveries,
    IReadOnlyList<CustomerOpsRowDto> Upcoming);

public sealed record CustomerCalendarDayDto(string Date, string Status, int Count, IReadOnlyList<CustomerVisitDto> Items);

public sealed record CustomerCalendarDto(int Year, int Month, IReadOnlyList<CustomerCalendarDayDto> Days);

public sealed record CustomerPaymentRowDto(
    string Reference,
    string Date,
    decimal Amount,
    string Method,
    string Status,
    string? RelatedReference);

public sealed record CustomerInvoiceRowDto(
    string Number,
    string Date,
    decimal Amount,
    decimal Paid,
    decimal Remaining,
    string Status);

public sealed record CustomerPaymentsDto(
    CustomerMoneyDto Summary,
    IReadOnlyList<CustomerPaymentRowDto> Payments,
    IReadOnlyList<CustomerInvoiceRowDto> Invoices);

public sealed record CustomerRequestDto(
    Guid Id,
    string Code,
    string Type,
    string Status,
    string? ScheduleCode,
    string CurrentSummary,
    string RequestedSummary,
    string Reason,
    string? Notes,
    string? EffectiveDate,
    string? PauseStart,
    string? ResumeDate,
    string AffectedDates,
    string? AdminComment,
    string? ReviewedAt,
    string CreatedAt,
    string CustomerCode,
    string CustomerName,
    Guid? ScheduleId = null,
    int? CurrentQuantity = null,
    int? RequestedQuantity = null,
    string? City = null);

public sealed record CustomerRequestImpactDto(
    string Summary,
    int ScheduledCount,
    int PublishedCount,
    int CompletedCount,
    string DispatchedNote,
    string InventoryNote,
    string PricingNote);

public sealed record CustomerRequestPreviewDto(
    string Summary,
    string AffectedDates,
    int ScheduledCount,
    int PublishedCount,
    int CompletedCount,
    string DispatchedNote,
    string InventoryNote,
    string PricingNote);

public sealed record AdminRequestNoticeDto(Guid Id, string Title, string Body, bool Read, string CreatedAt);

public sealed class CustomerRequestReply
{
    public string Notes { get; set; } = "";
}

public sealed record CustomerAddressDto(
    Guid Id,
    string Label,
    string City,
    string Area,
    string Street,
    string HouseNumber,
    string? Landmark,
    string? Instructions,
    decimal? Latitude,
    decimal? Longitude,
    bool IsDefault,
    bool IsActive);

public sealed record CustomerProfileDto(
    string CustomerCode,
    string FirstName,
    string LastName,
    string Email,
    string Phone,
    string AccountStatus,
    string CreatedAt,
    bool Linked,
    string? DeliveryCustomerCode,
    string? DeliveryCustomerName,
    IReadOnlyList<CustomerAddressDto> Addresses);

public sealed record CustomerNotificationDto(Guid Id, string Title, string Body, string Kind, bool Read, string CreatedAt, Guid? RequestId = null);

public sealed record CustomerAccountRowDto(
    Guid Id,
    string Code,
    string Name,
    string Phone,
    string Email,
    string City,
    string Area,
    string Status,
    string CreatedAt,
    bool Linked,
    string? DeliveryCustomerId,
    string? DeliveryCustomerCode,
    string? DeliveryCustomerName,
    int ActiveSchedules,
    decimal Outstanding,
    int PendingRequests);

public sealed record CustomerAccountBoardDto(
    int Total,
    int Active,
    int Inactive,
    int WithSchedules,
    int WithBalance,
    int PendingRequests,
    IReadOnlyList<CustomerAccountRowDto> Rows);

public sealed record CustomerTimelineDto(string Action, string PreviousValue, string NewValue, string PerformedBy, string Timestamp, string Reason, string Reference);

public sealed record CustomerAccountDetailDto(
    CustomerAccountRowDto Account,
    CustomerProfileDto Profile,
    IReadOnlyList<CustomerPlanDto> Schedules,
    IReadOnlyList<CustomerVisitDto> History,
    CustomerPaymentsDto Payments,
    IReadOnlyList<CustomerRequestDto> Requests,
    IReadOnlyList<CustomerTimelineDto> Timeline);

public interface ICustomerPortalService
{
    Task<ServiceResult<CustomerHomeDto>> HomeAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerPlanDto>>> SchedulesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerCalendarDto>> CalendarAsync(Guid scheduleId, int year, int month, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerVisitDto>>> HistoryAsync(Guid? scheduleId, string? status, DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerPaymentsDto>> PaymentsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerInvoiceDetailDto>> InvoiceAsync(string number, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerRequestDto>>> RequestsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestDto>> RequestAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestDto>> SubmitAsync(SubmitCustomerRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestPreviewDto>> PreviewAsync(SubmitCustomerRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestDto>> CancelAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestDto>> ReplyAsync(Guid id, string notes, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerProfileDto>> ProfileAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerProfileDto>> UpdateProfileAsync(UpdateCustomerProfileRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAddressDto>> SaveAddressAsync(Guid? id, SaveCustomerAddressRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAddressDto>> DefaultAddressAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAddressDto>> DeactivateAddressAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerNotificationDto>>> NotificationsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<object>> ReadNotificationAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<object>> ReadAllNotificationsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerOpsOverviewDto>> OverviewAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAccountBoardDto>> AccountBoardAsync(string? search, string? status, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAccountDetailDto>> AccountAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAccountDetailDto>> LinkAsync(Guid id, Guid? deliveryCustomerId, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerAccountRowDto>>> UnlinkedAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerLinkReviewDto>>> LinkReviewsAsync(string? status, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerLinkReviewDto>> ProposeLinkAsync(Guid accountId, string email, string customerCode, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerLinkReviewDto>> ReviewLinkAsync(Guid reviewId, string action, string? comment, CancellationToken cancellationToken);
    Task<ServiceResult<PolicyDocumentDto>> PolicyAsync(string kind, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerAccountDetailDto>> SetStatusAsync(Guid id, string status, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CustomerRequestDto>>> QueueAsync(string? type, string? status, string? search, string? city, DateOnly? submittedFrom, DateOnly? submittedTo, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestImpactDto>> ImpactAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminRequestNoticeDto>>> NoticesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<object>> ReadNoticesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRequestDto>> ReviewAsync(Guid id, ReviewCustomerRequest request, CancellationToken cancellationToken);
}

public sealed record ProposeCustomerLinkRequest(string Email, string CustomerCode);

public sealed record ReviewCustomerLinkRequest(string Action, string? Comment);

public sealed record CustomerLinkReviewDto(
    Guid Id,
    Guid CustomerAccountId,
    string AccountCode,
    string AccountName,
    string AccountEmail,
    Guid DeliveryCustomerId,
    string CustomerCode,
    string CustomerName,
    string Status,
    string? Comment,
    string CreatedAt);

public sealed record PolicyDocumentDto(string Title, string Body);

public sealed record HqSettingsDto(
    string LegalName,
    string DisplayName,
    string SupportEmail,
    string SupportPhone,
    string SupportAddress,
    string Website,
    string ReceiptFooter);

public sealed record UpdateHqSettingsRequest(
    string LegalName,
    string DisplayName,
    string? SupportEmail,
    string? SupportPhone,
    string? SupportAddress,
    string? Website,
    string? ReceiptFooter);

public sealed record CashHandoverDto(
    Guid Id,
    string ReferenceNumber,
    string RiderId,
    Guid DepotId,
    string BusinessDate,
    decimal ExpectedAmount,
    decimal? ActualAmount,
    decimal? Difference,
    string Status,
    int CollectionCount,
    string SubmittedAt,
    string? ReceivedAt);

public sealed record SubmitCashHandoverRequest(DateOnly BusinessDate, Guid? DepotId);

public sealed record ConfirmCashHandoverRequest(decimal ActualAmount, string? Note);

public sealed record DocumentFileDto(string FileName, string ContentType, string ContentBase64);

public sealed record DuplicatePriceListRequest(string Code, string Name);

public sealed record AssignPriceListRequest(IReadOnlyList<Guid>? CustomerIds);

public sealed record CreateWarehouseRequest(string Name, string Gate, string Address);

public sealed record InventoryCountRequest(Guid DepotId, Guid ProductId, int CountedQuantity, string? Note);

public sealed record InventoryCountDto(
    Guid Id,
    Guid DepotId,
    Guid ProductId,
    string ProductName,
    int ExpectedQuantity,
    int CountedQuantity,
    int Variance,
    string CountedAt);
