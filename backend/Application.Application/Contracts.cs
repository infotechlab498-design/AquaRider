using System.Text.Json.Serialization;
using RouteLedger.Domain;

namespace RouteLedger.Application;

public sealed class ApiResponse<T>
{
    public bool Success { get; init; }
    public string Message { get; init; } = "";
    public T? Data { get; init; }
    public IReadOnlyList<string>? Errors { get; init; }
    public PaginationMeta? Pagination { get; init; }
}

public sealed class PaginationMeta
{
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int TotalRecords { get; init; }
    public int TotalPages { get; init; }
}

public sealed class ServiceResult<T>
{
    public bool Success { get; init; }
    public int StatusCode { get; init; }
    public string Message { get; init; } = "";
    public T? Data { get; init; }
    public IReadOnlyList<string>? Errors { get; init; }
    public PaginationMeta? Pagination { get; init; }

    public static ServiceResult<T> Ok(T data, string message, PaginationMeta? page = null) =>
        new() { Success = true, StatusCode = 200, Message = message, Data = data, Pagination = page };

    public static ServiceResult<T> Created(T data, string message) =>
        new() { Success = true, StatusCode = 201, Message = message, Data = data };

    public static ServiceResult<T> Fail(int status, string message, params string[] errors) =>
        new()
        {
            Success = false,
            StatusCode = status,
            Message = message,
            Errors = errors.Length == 0 ? null : errors
        };
}

public sealed record AuthUserDto(
    string Id,
    string Username,
    string FullName,
    string? RiderCode,
    string Role,
    string? RouteName,
    string? VehicleName,
    string? VehiclePlate,
    string? FleetCode,
    string? DepotGate,
    string? DepotName,
    IReadOnlyList<string>? Roles = null,
    IReadOnlyList<string>? AllowedScreens = null,
    string? CustomerCode = null);

public sealed record AuthResponseDto(
    string AccessToken,
    string RefreshToken,
    DateTime ExpiresAt,
    AuthUserDto User);

public sealed class LoginRequest
{
    public string? Username { get; set; }
    public string? EmailOrUsername { get; set; }
    public string Password { get; set; } = "";
    public bool RememberMe { get; set; }

    [JsonIgnore]
    public string Identifier =>
        FirstNonEmpty(EmailOrUsername, Username);

    public static string FirstNonEmpty(params string?[] values)
    {
        foreach (var value in values)
        {
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value.Trim();
            }
        }

        return "";
    }
}

public sealed record RefreshRequest(string RefreshToken);
public sealed record LogoutRequest(string? RefreshToken);
public sealed record ForgotPasswordRequest(string Username);
public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);
public sealed record ResetPasswordRequest(string NewPassword);

public sealed class PasswordResetConfirmRequest
{
    public string? Email { get; set; }
    public string? Username { get; set; }
    public string? EmailOrUsername { get; set; }
    public string Token { get; set; } = "";
    public string NewPassword { get; set; } = "";

    [JsonIgnore]
    public string Identifier => LoginRequest.FirstNonEmpty(Email, EmailOrUsername, Username);
}

public sealed class SsoProviderOptions
{
    public bool Enabled { get; set; }
    public string? Authority { get; set; }
    public string? ClientId { get; set; }

    [JsonIgnore]
    public bool IsConfigured =>
        Enabled
        && !string.IsNullOrWhiteSpace(Authority)
        && !string.IsNullOrWhiteSpace(ClientId);
}

public sealed class SsoOptions
{
    public const string SectionName = "Sso";
    public SsoProviderOptions Okta { get; set; } = new();
    public SsoProviderOptions AzureAd { get; set; } = new();
}

public sealed record SsoProviderStatusDto(string Name, bool Enabled);

public sealed record SsoStatusDto(SsoProviderStatusDto Okta, SsoProviderStatusDto AzureAd);

public sealed record DashboardDto(
    string Greeting,
    string ServiceDate,
    AuthUserDto Rider,
    bool ShiftOpen,
    PerformanceDto Performance,
    RouteSummaryDto Route,
    int OpenTodoCount);

public sealed record PerformanceDto(
    decimal BilledSales,
    int SalesCount,
    decimal CashCollected,
    int VisitedCount,
    int TotalStops,
    int PendingDeliveries,
    string PendingNote);

public sealed record RouteSummaryDto(
    int Total,
    int Remaining,
    string? NextStopName,
    int? NextDistanceMeters,
    decimal RemainingDistanceKm,
    decimal? NextLatitude = null,
    decimal? NextLongitude = null,
    string? NextAddress = null);

public sealed record StopDto(
    Guid Id,
    Guid CustomerId,
    int Sequence,
    string CustomerName,
    string CustomerCode,
    string Address,
    string Phone,
    string Status,
    string? ScheduledTime,
    decimal Outstanding,
    int EmptyBottles,
    int? DistanceMeters,
    string ActionLabel,
    Guid? ReceiptSaleId,
    string? InvoiceNumber,
    decimal? Latitude,
    decimal? Longitude);

public sealed record CustomerDetailDto(
    Guid Id,
    string Code,
    string BusinessName,
    string Category,
    string Status,
    string Phone,
    string? AdditionalContact,
    string Street,
    string Area,
    string City,
    decimal? Latitude,
    decimal? Longitude,
    string RouteName,
    Guid RouteId,
    decimal Outstanding,
    DateTime? LastDropAt,
    int OpenOrders,
    int BottlesIssued,
    int BottlesReturned,
    int BottlesHeld,
    string BottleOwnership,
    string? Cnic,
    string? ContactName,
    string? ContactRole,
    int CreditDays,
    string? LastPaymentLabel,
    string? NextOrderProduct = null,
    int NextOrderQuantity = 0,
    string? NextOrderDate = null);

public sealed record CustomerWriteRequest(
    string BusinessName,
    string PrimaryMobile,
    string? AdditionalContact,
    string Category,
    string Street,
    string Area,
    string City,
    decimal? Latitude,
    decimal? Longitude,
    Guid? RouteId,
    string BottleOwnership,
    decimal OpeningDebt,
    int OpeningEmpties,
    string? Cnic,
    string? ContactName,
    string? ContactRole);

public sealed record ProductDto(
    Guid Id,
    string Name,
    decimal UnitPrice,
    string UnitLabel,
    int VanStock,
    int DepotExpected,
    bool IsReturnable);

public sealed record SaleContextDto(
    CustomerDetailDto Customer,
    IReadOnlyList<ProductDto> Products,
    int EmptyBottlesHeld);

public sealed record SaleLineRequest(Guid ProductId, int Quantity);

public sealed record CreateSaleRequest(
    Guid CustomerId,
    Guid? StopId,
    IReadOnlyList<SaleLineRequest> Lines,
    int? EmptyBottlesReturned = null);

public sealed record SaleDraftDto(
    Guid Id,
    Guid CustomerId,
    decimal SaleAmount,
    decimal PreviousOutstanding,
    decimal AmountDue,
    int EmptyBottlesReturned,
    int EmptyBottlesRemaining,
    IReadOnlyList<SaleLineDto> Lines,
    string ReceiptNumber = "");

public sealed record SaleLineDto(Guid ProductId, string Name, int Quantity, decimal UnitPrice, decimal LineTotal);

public sealed record CompleteSaleRequest(
    string PaymentMethod,
    decimal? AmountReceived,
    string SignerName,
    string? SignerRole,
    bool CloseStop = true,
    string? SignatureImage = null,
    string? SignatureNote = null);

public sealed record ReceiptDto(
    Guid Id,
    string Kind,
    string ReceiptNumber,
    DateTime IssuedAt,
    string RiderName,
    string RiderCode,
    string CustomerName,
    string CustomerCode,
    IReadOnlyList<SaleLineDto> Lines,
    decimal SaleAmount,
    decimal PreviousOutstanding,
    decimal AmountReceived,
    decimal BalanceAfter,
    string PaymentMethod,
    string? SignerName,
    string? SignerRole,
    string SyncStatus,
    string CustomerAddress = "",
    string CustomerPhone = "",
    string DepotName = "",
    string DepotAddress = "",
    int EmptyBottlesReturned = 0,
    int EmptyBottlesHeld = 0,
    string? SignatureNote = null,
    decimal WithholdingTax = 0);

public sealed record CreateCollectionRequest(
    Guid CustomerId,
    decimal Amount,
    string Channel,
    string SignerName,
    string? SignerRole,
    string? SignatureImage = null,
    string? SignatureNote = null,
    decimal WithholdingTax = 0,
    string? Note = null);

public sealed record CreateOrderRequest(
    Guid CustomerId,
    DateOnly? DeliveryDate,
    string Window,
    IReadOnlyList<SaleLineRequest> Lines,
    string? Note = null,
    bool ShowOnManifest = true);

public sealed record OrderDto(
    Guid Id,
    string ReferenceNumber,
    Guid CustomerId,
    DateOnly DeliveryDate,
    string Window,
    decimal EstimatedValue,
    string Status);

public sealed record LedgerDto(
    Guid CustomerId,
    string CustomerName,
    string CustomerCode,
    decimal Outstanding,
    int CreditDays,
    int BottlesIssued,
    int BottlesReturned,
    int BottlesHeld,
    IReadOnlyList<LedgerRowDto> Entries,
    int OpenOrders = 0,
    decimal TodayCollected = 0,
    int? StopSequence = null,
    IReadOnlyList<BottleMovementDto>? Movements = null);

public sealed record LedgerRowDto(
    Guid Id,
    string Description,
    DateTime OccurredAt,
    decimal Amount,
    decimal BalanceAfter,
    string Kind = "Opening",
    string? Reference = null,
    string? Detail = null);

public sealed record BottleMovementDto(
    DateTime OccurredAt,
    int FullGiven,
    int EmptiesReturned,
    int HoldingAfter,
    string Note);

public sealed record ShiftDto(
    Guid? Id,
    string Status,
    string ServiceDate,
    int OpeningOdometer,
    string FleetCode,
    string RouteLabel,
    string DepotLabel,
    bool OdometerVerified,
    IReadOnlyList<ShiftLineDto> Lines);

public sealed record ShiftLineDto(
    Guid ProductId,
    string Name,
    int DepotExpected,
    int CountedQuantity,
    bool Editable);

public sealed record StockCountRequest(Guid ProductId, int CountedQuantity);
public sealed record VisitOutcomeRequest(string Outcome);
public sealed record StartShiftRequest(int? OpeningOdometer, IReadOnlyList<StockCountRequest>? Stock, string? OdometerPhoto = null, string? InspectionPhoto = null);
public sealed record EndShiftRequest(int? ClosingOdometer, string? OdometerPhoto = null, string? InspectionPhoto = null, IReadOnlyList<StockCountRequest>? Stock = null);

public sealed record HistoryDto(
    int Synced,
    int Pending,
    int Failed,
    IReadOnlyList<HistoryItemDto> Items,
    string RiderUserId = "",
    string RiderName = "",
    string RiderCode = "");

public sealed record HistoryItemDto(
    Guid Id,
    string Title,
    string Reference,
    DateTime OccurredAt,
    decimal? Amount,
    string SyncStatus,
    string Detail,
    string? CustomerCode = null);

public sealed record SettingsDto(
    bool AutoSync,
    bool ShowOrdersTab,
    string Language,
    bool AutoPrint,
    bool DeleteOnLogout,
    string PaperSize,
    Guid? PrinterId,
    string? PrinterName);

public sealed record UpdateSettingsRequest(
    bool AutoSync,
    bool ShowOrdersTab,
    string Language,
    bool AutoPrint,
    bool DeleteOnLogout,
    string PaperSize,
    Guid? PrinterId);

public sealed record PrinterDto(Guid Id, string Name, string Meta, bool IsOnline, bool Selected);

public sealed record UserDto(
    string Id,
    string Username,
    string FullName,
    string? RiderCode,
    string? Phone,
    bool IsActive,
    IReadOnlyList<string> Roles,
    Guid? RouteId,
    string? Email = null,
    Guid? VehicleId = null,
    string? VehicleName = null,
    string? VehiclePlate = null,
    Guid? DepotId = null,
    string? DepotName = null,
    string? RouteName = null,
    DateTime? LastLoginAtUtc = null,
    DateTime? CreatedAt = null,
    string PrimaryRole = "",
    Guid? ZoneId = null,
    string? ZoneName = null,
    string? WarehousePersonUserId = null,
    string? WarehousePersonName = null);

public sealed record StaffSummaryDto(
    int TotalStaff,
    int ActiveUsers,
    int InactiveUsers,
    int ActiveRiders,
    int Admins,
    int LoggedInToday);

public sealed record RoleReferenceDto(
    string Role,
    string Title,
    string Description,
    int AssignedCount);

public sealed record RoleAccessScreenDto(string Key, string Group, string Label, string Detail);

public sealed record RoleAccessMemberDto(
    string Id,
    string FullName,
    string? RiderCode,
    string? DepotName = null,
    string? WarehousePersonName = null,
    string? ZoneName = null);

public sealed record RoleAccessRowDto(
    string Role,
    string Title,
    string Description,
    int AssignedCount,
    bool IsSystem,
    IReadOnlyList<string> ScreenKeys,
    IReadOnlyList<RoleAccessMemberDto> Members);

public sealed record RoleAccessMatrixDto(
    IReadOnlyList<RoleAccessScreenDto> Screens,
    IReadOnlyList<RoleAccessRowDto> Roles,
    int AssignedStaff,
    string PolicyNote);

public sealed record SaveRoleAccessRequest(IReadOnlyList<string>? ScreenKeys);

public sealed record CreateRoleAccessRequest(string Name, string? Description);

public sealed record AssignRoleMemberRequest(string UserId);

public sealed record CreateUserRequest(
    string Username,
    string Password,
    string FullName,
    string? Phone,
    string? RiderCode,
    string Role,
    Guid? RouteId,
    Guid? VehicleId,
    Guid? DepotId,
    string? Email = null,
    Guid? ZoneId = null,
    string? WarehousePersonUserId = null);

public sealed record UpdateUserRequest(
    string FullName,
    string? Phone,
    string? RiderCode,
    Guid? RouteId,
    Guid? VehicleId,
    Guid? DepotId);

public sealed record UserStatusRequest(bool IsActive);

public interface ICurrentUser
{
    string? UserId { get; }
    bool IsAdmin { get; }
    bool IsAuthenticated { get; }
}

public sealed record AdminLoginPreviewDto(
    DateOnly OperationalDate,
    decimal TodaysBilledSales,
    decimal? PreviousBilledSales,
    decimal? BilledChangePercent,
    decimal CashReconciled,
    int DropsBalanced,
    int DropsTotal,
    string ScopeNote);

public interface IAuthService
{
    Task<ServiceResult<AuthResponseDto>> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<AuthResponseDto>> RefreshAsync(string refreshToken, CancellationToken cancellationToken);
    Task<ServiceResult<object>> LogoutAsync(string? refreshToken, CancellationToken cancellationToken);
    Task<ServiceResult<object>> ForgotPasswordAsync(string username, CancellationToken cancellationToken);
    Task<ServiceResult<object>> ResetPasswordAsync(PasswordResetConfirmRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<SsoStatusDto>> SsoStatusAsync(CancellationToken cancellationToken);
    Task<ServiceResult<AuthUserDto>> MeAsync(CancellationToken cancellationToken);
    Task<ServiceResult<object>> ChangePasswordAsync(ChangePasswordRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<AdminLoginPreviewDto>> LoginPreviewAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CustomerRegistrationDto>> RegisterCustomerAsync(RegisterCustomerRequest request, CancellationToken cancellationToken);
}

public sealed class RegisterCustomerRequest
{
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
    public string Password { get; set; } = "";
    public string ConfirmPassword { get; set; } = "";
    public bool AcceptedTerms { get; set; }
}

public sealed record CustomerRegistrationDto(string CustomerCode, string FullName, string Email);

public sealed record BusinessProfileDto(
    Guid Id,
    string LegalName,
    string DisplayName,
    string? TaxNumber,
    string? RegistrationNumber,
    string Status);

public sealed record OnboardingStepDto(
    OnboardingStepCode StepCode,
    string Title,
    int Order,
    OnboardingStepStatus Status,
    DateTime? CompletedAtUtc,
    string? ValidationNotes);

public sealed record OnboardingFacilityDto(
    string? DepotName,
    string? Address,
    int ProductCount,
    int CustomerCount,
    int ZoneCount,
    int ActiveRiderCount,
    int VehicleStockCount,
    int SyncedSaleCount);

public sealed record OnboardingSupportDto(
    bool ChatAvailable,
    bool SchedulingAvailable,
    string Note);

public sealed record OnboardingOverviewDto(
    BusinessProfileDto Business,
    int CompletedCount,
    int TotalSteps,
    int ProgressPercent,
    bool Ready,
    OnboardingStepDto? NextStep,
    IReadOnlyList<OnboardingStepDto> Steps,
    OnboardingFacilityDto Facility,
    OnboardingSupportDto Support);

public sealed record OnboardingProgressDto(
    int CompletedCount,
    int TotalSteps,
    int ProgressPercent);

public sealed record OnboardingReadinessDto(
    bool Ready,
    int CompletedCount,
    int TotalSteps,
    IReadOnlyList<OnboardingStepCode> BlockingSteps);

public sealed record OnboardingNextStepDto(
    bool SetupComplete,
    OnboardingStepDto? Step);

public sealed record OnboardingValidationDto(
    OnboardingStepDto Step,
    bool Passed,
    string Notes);

public sealed record OnboardingActivityDto(
    string Title,
    string Detail,
    DateTime OccurredAtUtc,
    string? ActorUserId);

public interface IOnboardingService
{
    Task<ServiceResult<OnboardingOverviewDto>> OverviewAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<OnboardingStepDto>>> StepsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingStepDto>> StepAsync(string stepCode, CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingProgressDto>> ProgressAsync(CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingValidationDto>> ValidateAsync(string stepCode, CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingValidationDto>> CompleteAsync(string stepCode, CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingNextStepDto>> NextStepAsync(CancellationToken cancellationToken);
    Task<ServiceResult<OnboardingReadinessDto>> ReadinessAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<OnboardingActivityDto>>> ActivityAsync(CancellationToken cancellationToken);
}

public interface IUserAdminService
{
    Task<ServiceResult<StaffSummaryDto>> SummaryAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RoleReferenceDto>>> RoleReferenceAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<UserDto>>> ListAsync(
        string? search,
        string? role,
        bool? isActive,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<UserDto>> GetAsync(string id, CancellationToken cancellationToken);
    Task<ServiceResult<UserDto>> CreateAsync(CreateUserRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<UserDto>> UpdateAsync(string id, UpdateUserRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<UserDto>> SetStatusAsync(string id, bool isActive, CancellationToken cancellationToken);
    Task<ServiceResult<object>> ResetPasswordAsync(string id, string newPassword, CancellationToken cancellationToken);
    Task<ServiceResult<RoleAccessMatrixDto>> AccessMatrixAsync(CancellationToken cancellationToken);
    Task<ServiceResult<RoleAccessRowDto>> SaveAccessAsync(string role, SaveRoleAccessRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RoleAccessRowDto>> CreateRoleAsync(CreateRoleAccessRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RoleAccessRowDto>> AssignMemberAsync(string role, string userId, CancellationToken cancellationToken);
    Task<IReadOnlyList<string>> ScreensForRolesAsync(IEnumerable<string> roles, CancellationToken cancellationToken);
}

public interface IFieldService
{
    Task<ServiceResult<DashboardDto>> DashboardAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<StopDto>>> StopsAsync(string? search, string? filter, int page, int pageSize, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<StopDto>>> SequenceTodayStopsAsync(StopSequenceRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerDetailDto>> CustomerAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerDetailDto>> CreateCustomerAsync(CustomerWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerDetailDto>> UpdateCustomerAsync(Guid id, CustomerWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<SaleContextDto>> SaleContextAsync(Guid customerId, CancellationToken cancellationToken);
    Task<ServiceResult<SaleDraftDto>> CreateSaleAsync(CreateSaleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> CompleteSaleAsync(Guid saleId, CompleteSaleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> ReceiptAsync(Guid saleId, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> CreateCollectionAsync(CreateCollectionRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CashHandoverDto>> SubmitHandoverAsync(DateOnly businessDate, Guid? depotId, CancellationToken cancellationToken);
    Task<ServiceResult<OrderDto>> CreateOrderAsync(CreateOrderRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<object>> LogVisitAsync(Guid customerId, string outcome, CancellationToken cancellationToken);
    Task<ServiceResult<LedgerDto>> LedgerAsync(Guid customerId, CancellationToken cancellationToken);
    Task<ServiceResult<ShiftDto>> CurrentShiftAsync(CancellationToken cancellationToken);
    Task<ServiceResult<ShiftDto>> StartShiftAsync(StartShiftRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ShiftDto>> EndShiftAsync(EndShiftRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<HistoryDto>> HistoryAsync(string? search, DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<SettingsDto>> SettingsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<SettingsDto>> UpdateSettingsAsync(UpdateSettingsRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<PrinterDto>>> PrintersAsync(CancellationToken cancellationToken);
    Task<ServiceResult<object>> QueuePrintAsync(Guid saleId, CancellationToken cancellationToken);
    Task<(string Html, bool Found)> VerifyReceiptPageAsync(string receiptNumber, CancellationToken cancellationToken);
}

public sealed record CommandPeriodDto(DateOnly From, DateOnly To);

public sealed record CommandReadyFlagsDto(
    bool BusinessProfilePresent,
    bool BusinessReady,
    bool FacilityPresent,
    bool RidersPresent);

public sealed record CommandOverviewDto(
    string Greeting,
    string AdminFullName,
    string BusinessDisplayName,
    string FacilityDepotName,
    CommandPeriodDto Period,
    CommandReadyFlagsDto Ready);

public sealed record CommandSalesKpiDto(
    decimal TotalBilledSales,
    int InvoiceCount,
    decimal? PreviousPeriodSales,
    decimal? ChangeAmount,
    decimal? ChangePercent);

public sealed record CommandCollectionsKpiDto(
    decimal CollectionsReceived,
    int CollectionCount,
    decimal? RecoveryPercent);

public sealed record CommandFleetKpiDto(int FleetRegistered, int FleetOnDuty);

public sealed record CommandDeliveriesKpiDto(int DeliveriesCompleted, int DeliveriesTotal, decimal Percent);

public sealed record CommandOrdersKpiDto(int PendingOrders, int UnassignedOrders);

public sealed record CommandOutstandingKpiDto(decimal OutstandingDues, int AccountsWithDues);

public sealed record CommandKpisDto(
    CommandPeriodDto Period,
    CommandSalesKpiDto Sales,
    CommandCollectionsKpiDto Collections,
    CommandFleetKpiDto Fleet,
    CommandDeliveriesKpiDto Deliveries,
    CommandOrdersKpiDto Orders,
    CommandOutstandingKpiDto Outstanding);

public sealed record OperationalOrdersDto(
    int Total,
    int Assigned,
    int Unassigned,
    int Scheduled,
    int Delivered,
    int Cancelled);

public sealed record OperationalStopsDto(
    int Total,
    int Completed,
    int Pending,
    int Missed,
    int InProgress);

public sealed record RecentActivityDto(
    Guid Id,
    string Title,
    string Reference,
    string Detail,
    decimal? Amount,
    string SyncStatus,
    DateTime OccurredAtUtc,
    string UserId);

public sealed record OperationalSummaryDto(
    CommandPeriodDto Period,
    OperationalOrdersDto Orders,
    OperationalStopsDto Stops,
    IReadOnlyList<RecentActivityDto> RecentActivity);

public sealed record AttentionItemDto(
    string Id,
    string Severity,
    string Title,
    string Detail,
    DateTime CreatedAtUtc,
    string Status,
    string ActionLabel,
    string ActionRoute);

public sealed record SalesBucketDto(
    string Label,
    DateTime BucketStartUtc,
    decimal Amount,
    int InvoiceCount);

public sealed record SalesSummaryDto(
    CommandPeriodDto Period,
    string RequestedBucket,
    string Bucket,
    decimal Total,
    int InvoiceCount,
    IReadOnlyList<SalesBucketDto> Buckets);

public sealed record CollectionCategoryDto(
    string Category,
    decimal Amount,
    int Count,
    decimal Percent);

public sealed record CollectionsSummaryDto(
    CommandPeriodDto Period,
    decimal Total,
    IReadOnlyList<CollectionCategoryDto> Categories,
    string? ReconciliationNote,
    decimal ExcludedUnsupportedAmount);

public sealed record ActivityLedgerRowDto(
    string ReferenceId,
    string CustomerName,
    string RiderName,
    string TransactionType,
    decimal Amount,
    DateTime TimestampUtc,
    string SyncStatus);

public sealed record AdminCreateOrderRequest(
    Guid CustomerId,
    string RiderId,
    DateOnly DeliveryDate,
    string Window,
    IReadOnlyList<SaleLineRequest>? Lines,
    string? Note = null);

public sealed record RiderOpsSummaryDto(
    DateOnly Date,
    int RidersRegistered,
    int AvailableForAssignment,
    int ActiveAssignments,
    int DeliveriesInProgress,
    int RequiringAttention);

public sealed record RiderOpsCardDto(
    string Id,
    string FullName,
    string? RiderCode,
    string? VehicleName,
    string? Plate,
    string? RouteName,
    string Status,
    int StopsCompleted,
    int StopsTotal,
    decimal BilledSalesToday,
    decimal CashCollectedToday,
    DateTime? LastActivityAt,
    string? LastActivityTitle);

public sealed record RiderActivityDto(
    Guid Id,
    string Title,
    string Reference,
    decimal? Amount,
    string SyncStatus,
    string Detail,
    DateTime OccurredAtUtc);

public sealed record RiderAssignmentDto(
    Guid StopId,
    int Sequence,
    Guid CustomerId,
    string CustomerName,
    string CustomerCode,
    string Status,
    TimeOnly? ScheduledTime,
    int? DistanceMeters);

public sealed record RiderExceptionDto(
    string Id,
    string RiderId,
    string RiderName,
    string Severity,
    string Title,
    string Detail,
    DateTime CreatedAtUtc,
    string Status);

public sealed record LocationVerificationDto(
    Guid Id,
    string RiderId,
    DateTime VerifiedAtUtc,
    decimal? Latitude,
    decimal? Longitude,
    string Source);

public sealed record LocationVerificationsDto(
    IReadOnlyList<LocationVerificationDto> Items,
    string Message);

public interface ICommandDashboardService
{
    Task<ServiceResult<CommandOverviewDto>> OverviewAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<CommandKpisDto>> KpisAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<OperationalSummaryDto>> OperationalSummaryAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AttentionItemDto>>> AttentionItemsAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<SalesSummaryDto>> SalesSummaryAsync(DateOnly? from, DateOnly? to, string? bucket, CancellationToken cancellationToken);
    Task<ServiceResult<CollectionsSummaryDto>> CollectionsSummaryAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<ActivityLedgerRowDto>>> ActivityLedgerAsync(DateOnly? from, DateOnly? to, string? search, string? status, int page, int pageSize, CancellationToken cancellationToken);
    Task<ServiceResult<OrderDto>> CreateOrderAsync(AdminCreateOrderRequest request, CancellationToken cancellationToken);
}

public interface IRiderOperationsService
{
    Task<ServiceResult<RiderOpsSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RiderOpsCardDto>>> RidersAsync(string? search, string? status, DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<RiderOpsCardDto>> RiderAsync(string id, DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RiderActivityDto>>> ActivityAsync(string id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RiderAssignmentDto>>> AssignmentsAsync(string id, DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RiderExceptionDto>>> ExceptionsAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<LocationVerificationsDto>> LocationVerificationsAsync(CancellationToken cancellationToken);
}

public sealed record DispatchOrderRowDto(
    Guid Id,
    string ReferenceNumber,
    string CustomerName,
    string CustomerCode,
    string CustomerPhone,
    string Address,
    DateOnly DeliveryDate,
    string Window,
    string RiderId,
    string? RiderName,
    string? RiderCode,
    decimal EstimatedValue,
    string Status,
    string OrderStatus,
    string SyncStatus,
    DateTime CreatedAtUtc,
    int LineCount,
    string PriorityLabel,
    string Origin = OrderOrigin.Hq);

public sealed record DispatchOrderSummaryDto(
    int Total,
    int PendingAssignment,
    int Assigned,
    int InProgress,
    int Completed,
    int Cancelled,
    decimal CombinedEstimatedValue);

public sealed record DispatchStatusCountsDto(
    int Total,
    int PendingAssignment,
    int Assigned,
    int InProgress,
    int Completed,
    int Cancelled);

public sealed record DispatchCustomerCardDto(
    Guid Id,
    string Name,
    string Code,
    string Phone,
    string Address,
    string Street,
    string Area,
    string City);

public sealed record DispatchRiderCardDto(
    string Id,
    string FullName,
    string? RiderCode,
    bool IsActive);

public sealed record DispatchOrderTotalsDto(
    decimal EstimatedValue,
    decimal LinesSubtotal,
    int LineCount);

public sealed record DispatchOrderDetailDto(
    Guid Id,
    string ReferenceNumber,
    DateOnly DeliveryDate,
    string Window,
    string Status,
    string OrderStatus,
    string SyncStatus,
    string? Notes,
    string PriorityLabel,
    DateTime CreatedAtUtc,
    string RiderId,
    DispatchOrderTotalsDto Totals,
    DispatchCustomerCardDto Customer,
    DispatchRiderCardDto? Rider,
    DateTime? CancelledAtUtc,
    string? CancelledByUserId,
    string? CancellationReason,
    string Origin = OrderOrigin.Hq);

public sealed record DispatchOrderItemDto(
    Guid LineId,
    Guid ProductId,
    string ProductName,
    string Sku,
    int Quantity,
    string UnitLabel,
    decimal UnitPrice,
    decimal Subtotal);

public sealed record OrderLifecycleEventDto(
    Guid Id,
    Guid OrderId,
    string EventCode,
    string Title,
    string? Detail,
    string? ActorUserId,
    DateTime OccurredAtUtc);

public sealed record PickListDto(
    Guid OrderId,
    string ReferenceNumber,
    DateOnly DeliveryDate,
    string Window,
    string OrderStatus,
    decimal EstimatedValue,
    string? Notes,
    DispatchCustomerCardDto Customer,
    IReadOnlyList<DispatchOrderItemDto> Lines,
    decimal LinesTotal);

public sealed record EligibleRiderDto(
    string Id,
    string FullName,
    string? RiderCode,
    string? RouteName,
    bool HasOpenShift);

public sealed record DispatchZoneSummaryDto(
    Guid RouteId,
    string RouteName,
    string Sector,
    string City,
    int OrderCount,
    int StopCount);

public sealed record DispatchShiftProgressDto(
    int CompletedStops,
    int TotalStops,
    bool TargetConfigured,
    int? Target);

public sealed record DispatchOperationalSummaryDto(
    DateOnly Date,
    IReadOnlyList<DispatchZoneSummaryDto> Zones,
    DispatchShiftProgressDto ShiftProgress);

public sealed record AssignRiderRequest(string? RiderId);

public sealed record CancelOrderRequest(string? Reason);

public interface IDispatchOrderService
{
    Task<ServiceResult<IReadOnlyList<DispatchOrderRowDto>>> OrdersAsync(
        int page,
        int pageSize,
        string? search,
        string? status,
        DateOnly? from,
        DateOnly? to,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken);

    Task<ServiceResult<DispatchOrderSummaryDto>> SummaryAsync(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken);

    Task<ServiceResult<DispatchStatusCountsDto>> StatusCountsAsync(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken);

    Task<ServiceResult<DispatchOrderDetailDto>> OrderAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<DispatchOrderItemDto>>> ItemsAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<OrderLifecycleEventDto>>> LifecycleAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<PickListDto>> PickListAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<EligibleRiderDto>>> EligibleRidersAsync(DateOnly? deliveryDate, CancellationToken cancellationToken);
    Task<ServiceResult<DispatchOperationalSummaryDto>> OperationalSummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<DispatchOrderDetailDto>> AssignRiderAsync(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<DispatchOrderDetailDto>> ReassignRiderAsync(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<DispatchOrderDetailDto>> CancelAsync(Guid id, CancelOrderRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<PickListDto>> PreparePickListAsync(Guid id, CancellationToken cancellationToken);
}

public sealed record DayCloseGatewayStatusDto(
    bool Configured,
    string Status,
    DateTime? LastSuccessfulSyncUtc,
    DateTime? LastVerificationUtc,
    int? PendingCount,
    int? FailedCount,
    string Message);

public sealed record DayCloseSummaryDto(
    DateOnly BusinessDate,
    string? WarehouseName,
    DayCloseGatewayStatusDto Gateway,
    int RidersSubmitted,
    int RidersEligible,
    int RidersRemaining,
    decimal? SubmissionPercent,
    decimal ExpectedCash,
    decimal? PreviousDayExpectedCash,
    decimal? ExpectedChangePercent,
    decimal DeclaredCash,
    int DeclarationCount,
    decimal PhysicallyReceived,
    int VerificationBatchCount,
    decimal UnresolvedNetVariance,
    int UnresolvedFlagCount,
    decimal? VarianceThreshold,
    string? SopMessage);

public sealed record SettlementStatusCountsDto(
    int All,
    int NotStarted,
    int AwaitingReview,
    int VarianceDetected,
    int Reconciled,
    int Locked);

public sealed record SettlementSessionRowDto(
    Guid Id,
    DateOnly BusinessDate,
    string RiderId,
    string RiderName,
    string? RiderCode,
    string? RouteName,
    Guid? ShiftId,
    string? ShiftStatus,
    DateTime? ShiftStartedAtUtc,
    DateTime? ShiftEndedAtUtc,
    decimal ExpectedCash,
    decimal? DeclaredCash,
    decimal? PhysicallyReceived,
    decimal? NetVariance,
    string Status,
    string SessionCode);

public sealed record CashLedgerDto(
    decimal ExpectedCash,
    decimal? DeclaredCash,
    decimal? PhysicallyReceived,
    decimal? DeclarationVariance,
    decimal? PhysicalVariance,
    decimal? NetVariance,
    int CashSaleCount,
    int PartialSaleCount,
    int CashCollectionCount,
    int PartialCollectionCount,
    decimal ExcludedUnsupportedAmount);

public sealed record StockReconciliationDto(
    IReadOnlyList<StockAssetCardDto> FullBottles,
    IReadOnlyList<StockAssetCardDto> EmptyReturns,
    string? Note);

public sealed record StockAssetCardDto(
    string ProductName,
    string Sku,
    string Kind,
    int? Loaded,
    int? Sold,
    int? Returned,
    int? Expected,
    int? Declared,
    int? Received,
    int? Discrepancy,
    string? StatusLabel);

public sealed record SettlementAuditEventDto(
    Guid Id,
    string EventCode,
    string Title,
    string? Detail,
    string? ActorUserId,
    string? ActorName,
    DateTime OccurredAtUtc);

public sealed record SettlementSessionDetailDto(
    SettlementSessionRowDto Session,
    CashLedgerDto Ledger,
    string? RiderAnnotation,
    StockReconciliationDto Stock,
    IReadOnlyList<SettlementAuditEventDto> AuditTrail,
    decimal? DraftVerifiedCash,
    string? DraftResolutionCategory,
    string? DraftRemarks,
    string? ResolutionCategory,
    string? ResolutionRemarks,
    bool DayLocked,
    bool CanEdit,
    IReadOnlyList<string> ResolutionCategories);

public sealed record SettlementDraftRequest(
    decimal? CashierVerifiedCash,
    string? ResolutionCategory,
    string? Remarks,
    string? RiderAnnotation);

public sealed record VerifyCashRequest(
    decimal VerifiedAmount,
    string? BatchReference,
    string? Notes);

public sealed record ResolveSettlementRequest(
    decimal? CashierVerifiedCash,
    string? ResolutionCategory,
    string? Remarks);

public sealed record BulkLockRequest(IReadOnlyList<DateOnly>? Dates, string? AcknowledgementNote);

public sealed record DayLockReadinessDto(
    DateOnly BusinessDate,
    bool Ready,
    IReadOnlyList<string> BlockingReasons,
    int SessionCount,
    int ReconciledCount,
    int LockedCount);

public sealed record DayLockResultDto(
    DateOnly BusinessDate,
    bool Locked,
    string Message,
    IReadOnlyList<string>? BlockingReasons);

public interface IDayCloseSettlementService
{
    Task<ServiceResult<DayCloseSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<SettlementStatusCountsDto>> StatusCountsAsync(DateOnly? date, string? search, Guid? routeId, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<SettlementSessionRowDto>>> SessionsAsync(
        DateOnly? date,
        string? status,
        string? search,
        Guid? routeId,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<SettlementSessionDetailDto>> SessionAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CashLedgerDto>> CashLedgerAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<StockReconciliationDto>> StockAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<SettlementAuditEventDto>>> AuditTrailAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<SettlementSessionDetailDto>> SaveDraftAsync(Guid id, SettlementDraftRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<SettlementSessionDetailDto>> VerifyCashAsync(Guid id, VerifyCashRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<SettlementSessionDetailDto>> ResolveAsync(Guid id, ResolveSettlementRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<DayLockReadinessDto>> LockReadinessAsync(DateOnly date, CancellationToken cancellationToken);
    Task<ServiceResult<DayLockResultDto>> LockDayAsync(DateOnly date, string? acknowledgementNote, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<DayLockResultDto>>> BulkLockAsync(BulkLockRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<DayCloseGatewayStatusDto>> GatewayStatusAsync(CancellationToken cancellationToken);
}

public sealed record ProductCategoryDto(string Key, string Label, string Description, int ProductCount, bool Active);

public sealed record ProductBasePriceRowDto(
    Guid Id,
    string Name,
    string Sku,
    string UnitLabel,
    decimal BaseSystemPrice,
    decimal EffectiveBasePrice,
    string PriceStatus,
    bool ShowOnSale,
    bool ShowOnShift,
    bool IsReturnable,
    string CategoryKey);

public sealed record PricingCoverageDto(
    int ActiveProducts,
    int CategoryCount,
    int PricedProducts,
    decimal? CoveragePercent,
    int CustomerAccounts,
    int UnpricedProducts);

public sealed record BasePriceValidationDto(
    Guid ProductId,
    string Name,
    string Sku,
    string UnitLabel,
    decimal BasePrice,
    string PriceStatus,
    string CategoryKey,
    int Quantity,
    decimal Subtotal);

public sealed record CustomerBasePriceLookupDto(
    Guid CustomerId,
    string CustomerCode,
    string BusinessName,
    string Status,
    string PricingModel,
    IReadOnlyList<ProductBasePriceRowDto> Products);

public interface IProductPricingService
{
    Task<ServiceResult<PricingCoverageDto>> CoverageAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<ProductCategoryDto>>> CategoriesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>> CatalogueAsync(
        string? categoryKey,
        string? search,
        string? status,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<ProductBasePriceRowDto>>> UnpricedAsync(CancellationToken cancellationToken);
    Task<ServiceResult<ProductBasePriceRowDto>> BasePriceAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<object>>> PriceHistoryAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<BasePriceValidationDto>> ValidateAsync(Guid productId, int quantity, CancellationToken cancellationToken);
    Task<ServiceResult<CustomerBasePriceLookupDto>> CustomerLookupAsync(Guid customerId, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<PriceListSummaryDto>>> PriceListsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<PriceListDetailDto>> PriceListAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<PriceListDetailDto>> CreatePriceListAsync(CreatePriceListRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<PriceListDetailDto>> UpdatePriceListAsync(Guid id, CreatePriceListRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<PriceListDetailDto>> DuplicatePriceListAsync(Guid id, DuplicatePriceListRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<PriceListDetailDto>> AssignPriceListAsync(Guid id, AssignPriceListRequest request, CancellationToken cancellationToken);
}

public sealed record PriceListLineDto(
    Guid ProductId,
    string Name,
    string Sku,
    string UnitLabel,
    string CategoryKey,
    string PriceStatus,
    decimal BaseSystemPrice,
    decimal ListRate);

public sealed record PriceListSummaryDto(
    Guid Id,
    string Code,
    string Name,
    string Description,
    bool IsDefault,
    bool IsActive,
    DateOnly EffectiveFrom,
    DateOnly? EffectiveTo,
    string Scope,
    Guid? RouteId,
    string? RouteName,
    Guid? ZoneId,
    string? ZoneName,
    int LineCount);

public sealed record PriceListDetailDto(
    Guid Id,
    string Code,
    string Name,
    string Description,
    bool IsDefault,
    bool IsActive,
    DateOnly EffectiveFrom,
    DateOnly? EffectiveTo,
    string Scope,
    Guid? RouteId,
    string? RouteName,
    Guid? ZoneId,
    string? ZoneName,
    int LineCount,
    IReadOnlyList<PriceListLineDto> Lines);

public sealed record PriceListLineRequest(Guid ProductId, decimal ListRate, bool Included = true);

public sealed record CreatePriceListRequest(
    string Code,
    string Name,
    string? Description,
    bool IsDefault,
    bool IsActive,
    DateOnly EffectiveFrom,
    DateOnly? EffectiveTo,
    string Scope,
    Guid? RouteId,
    Guid? ZoneId,
    IReadOnlyList<PriceListLineRequest>? Lines);

public sealed record ZonesRoutesSummaryDto(
    int TotalZones,
    int ActiveZones,
    int ActiveRoutes,
    int AssignedRiders,
    int AssignedStores,
    int CustomersMissingGps,
    string? DepotName);

public sealed record ZoneListItemDto(
    Guid Id,
    string Name,
    string Sector,
    string City,
    Guid DepotId,
    string DepotName,
    bool IsActive,
    int RouteCount,
    int CustomerCount,
    int AssignedRiderCount);

public sealed record ZoneDetailDto(
    Guid Id,
    string Name,
    string Sector,
    string City,
    Guid DepotId,
    string DepotName,
    bool IsActive,
    DateTime CreatedAt,
    int RouteCount,
    int CustomerCount,
    IReadOnlyList<RouteListItemDto> Routes);

public sealed record ZoneWriteRequest(
    string Name,
    string Sector,
    string City,
    Guid? DepotId,
    bool IsActive = true);

public sealed record RouteListItemDto(
    Guid Id,
    string Name,
    string Sector,
    string City,
    Guid ZoneId,
    string ZoneName,
    Guid DepotId,
    string DepotName,
    int CustomerCount,
    int StopCountToday,
    IReadOnlyList<RouteRiderDto> Riders,
    bool HasRider);

public sealed record RouteDetailDto(
    Guid Id,
    string Name,
    string Sector,
    string City,
    Guid ZoneId,
    string ZoneName,
    Guid DepotId,
    string DepotName,
    int CustomerCount,
    int CustomersWithGps,
    int StopCountToday,
    IReadOnlyList<RouteRiderDto> Riders,
    IReadOnlyList<RouteCustomerRowDto> Customers);

public sealed record RouteWriteRequest(
    string Name,
    Guid ZoneId,
    string? Sector,
    string? City,
    Guid? DepotId);

public sealed record RouteRiderDto(
    string UserId,
    string FullName,
    string? RiderCode,
    string? VehiclePlate,
    bool IsActive);

public sealed record AssignRouteRiderRequest(string RiderUserId);

public sealed record RouteCustomerRowDto(
    Guid Id,
    string Code,
    string BusinessName,
    string Status,
    string Phone,
    string Address,
    string Area,
    int RouteSortOrder,
    decimal? Latitude,
    decimal? Longitude,
    decimal Outstanding,
    bool HasGps);

public sealed record AllocateCustomersRequest(IReadOnlyList<Guid> CustomerIds);

public sealed record CustomerSequenceRequest(IReadOnlyList<Guid> OrderedCustomerIds);

public sealed record RouteStopRowDto(
    Guid Id,
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string Address,
    string Phone,
    int Sequence,
    string Status,
    decimal? Latitude,
    decimal? Longitude);

public sealed record StopSequenceRequest(IReadOnlyList<Guid> OrderedStopIds);

public sealed record EnsureStopsRequest(DateOnly? ServiceDate);

public sealed record RouteMapPinDto(
    Guid CustomerId,
    string Label,
    string Code,
    decimal Latitude,
    decimal Longitude,
    int Sequence,
    bool IsStop);

public sealed record RouteMapDto(
    Guid RouteId,
    string RouteName,
    string ZoneName,
    DateOnly ServiceDate,
    IReadOnlyList<RouteMapPinDto> Pins);

public sealed record EligibleRouteRiderDto(
    string UserId,
    string FullName,
    string? RiderCode,
    Guid? CurrentRouteId,
    string? CurrentRouteName,
    string? VehiclePlate,
    bool IsActive);

public sealed record AdminCustomersSummaryDto(
    int TotalCustomers,
    int ActiveCustomers,
    int InactiveCustomers,
    int NewThisMonth,
    decimal TotalOutstanding,
    int WithOutstanding,
    int MissingGps);

public sealed record AdminCustomerRowDto(
    Guid Id,
    string Code,
    string BusinessName,
    string Category,
    string Status,
    string Phone,
    string Area,
    string City,
    string Address,
    Guid RouteId,
    string RouteName,
    Guid? ZoneId,
    string? ZoneName,
    decimal Outstanding,
    int BottlesHeld,
    int BottlesIssued,
    int BottlesReturned,
    bool HasGps,
    decimal? Latitude,
    decimal? Longitude,
    DateTime CreatedAt,
    DateTime? LastDropAt);

public sealed record AdminCustomerDetailDto(
    AdminCustomerRowDto Customer,
    string? ContactName,
    string? ContactRole,
    string? AdditionalContact,
    string? Cnic,
    string BottleOwnership,
    int CreditDays,
    string? LastPaymentLabel,
    decimal LifetimeSales,
    decimal LifetimeCollections,
    IReadOnlyList<LedgerRowDto> RecentLedger,
    IReadOnlyList<RouteListItemDto> AvailableRoutes);

public sealed record AdminCustomerWriteRequest(
    string BusinessName,
    string PrimaryMobile,
    string? AdditionalContact,
    string Category,
    string Street,
    string Area,
    string City,
    decimal? Latitude,
    decimal? Longitude,
    Guid RouteId,
    string BottleOwnership,
    decimal? OpeningDebt,
    int? OpeningEmpties,
    string? Cnic,
    string? ContactName,
    string? ContactRole,
    string? Status,
    int? CreditDays);

public sealed record ChangeCustomerRouteRequest(Guid RouteId);

public sealed record SetCustomerStatusRequest(string Status);

public interface IAdminCustomerService
{
    Task<ServiceResult<AdminCustomersSummaryDto>> SummaryAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminCustomerRowDto>>> ListAsync(
        string? search,
        string? status,
        Guid? routeId,
        Guid? zoneId,
        string? area,
        bool? withOutstanding,
        bool? missingGps,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<AdminCustomerDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<AdminCustomerDetailDto>> CreateAsync(AdminCustomerWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<AdminCustomerDetailDto>> UpdateAsync(Guid id, AdminCustomerWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<AdminCustomerDetailDto>> ChangeRouteAsync(Guid id, ChangeCustomerRouteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<AdminCustomerDetailDto>> SetStatusAsync(Guid id, SetCustomerStatusRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<LedgerDto>> LedgerAsync(Guid id, CancellationToken cancellationToken);
}

public interface IZonesRoutesService
{
    Task<ServiceResult<ZonesRoutesSummaryDto>> SummaryAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<ZoneListItemDto>>> ListZonesAsync(string? search, bool? activeOnly, CancellationToken cancellationToken);
    Task<ServiceResult<ZoneDetailDto>> GetZoneAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<ZoneDetailDto>> CreateZoneAsync(ZoneWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ZoneDetailDto>> UpdateZoneAsync(Guid id, ZoneWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<object>> DeactivateZoneAsync(Guid id, CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<RouteListItemDto>>> ListRoutesAsync(Guid? zoneId, string? search, CancellationToken cancellationToken);
    Task<ServiceResult<RouteDetailDto>> GetRouteAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<RouteDetailDto>> CreateRouteAsync(RouteWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RouteDetailDto>> UpdateRouteAsync(Guid id, RouteWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<object>> DeleteRouteAsync(Guid id, CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<EligibleRouteRiderDto>>> EligibleRidersAsync(string? search, CancellationToken cancellationToken);
    Task<ServiceResult<RouteDetailDto>> AssignRiderAsync(Guid routeId, AssignRouteRiderRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RouteDetailDto>> UnassignRiderAsync(Guid routeId, AssignRouteRiderRequest request, CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> RouteCustomersAsync(Guid routeId, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> AllocateCustomersAsync(Guid routeId, AllocateCustomersRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> SequenceCustomersAsync(Guid routeId, CustomerSequenceRequest request, CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> StopsAsync(Guid routeId, DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> EnsureStopsAsync(Guid routeId, EnsureStopsRequest? request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> SequenceStopsAsync(Guid routeId, StopSequenceRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RouteMapDto>> MapPinsAsync(Guid routeId, DateOnly? date, CancellationToken cancellationToken);
}

// --- W14 Main Warehouse (single Depot) ---

public sealed record DepotDetailDto(
    Guid Id,
    string Name,
    string Gate,
    string Address,
    string Classification,
    string Status,
    string Code);

public sealed record DepotKpiDto(
    int TotalDepots,
    int CentralWarehouses,
    int SatelliteHubs,
    int ActiveWarehouses,
    decimal ActivePercent,
    int AssignedFleet,
    int ActiveVehicles,
    int TodaysDispatchOrders,
    int TodaysDispatchVolume,
    string DispatchUnit,
    int LinkedStores);

public sealed record DepotCapacityDto(
    int OccupiedUnits,
    int ExpectedUnits,
    int AvailableUnits,
    decimal UtilizationPercent,
    string UnitLabel);

public sealed record DepotFleetMemberDto(
    string VehicleId,
    string VehicleName,
    string Plate,
    string FleetCode,
    string? RiderUserId,
    string? RiderName,
    string? RiderCode,
    bool RiderActive,
    int StockUnits);

public sealed record DepotStockLineDto(
    Guid ProductId,
    string ProductName,
    string Sku,
    int QuantityOnVans,
    int DepotExpected,
    bool IsReturnable);

public sealed record DepotOperationsDto(
    DepotDetailDto Depot,
    DepotKpiDto Kpis,
    DepotCapacityDto Capacity,
    IReadOnlyList<DepotFleetMemberDto> Fleet,
    IReadOnlyList<DepotStockLineDto> Stock,
    int TodaysCompletedSales,
    decimal TodaysBilledSales,
    string? ManagerName,
    string ScopeNote);

public sealed record UpdateDepotRequest(string Name, string Gate, string Address);

public interface IDepotOperationsService
{
    Task<ServiceResult<DepotDetailDto>> GetAsync(CancellationToken cancellationToken);
    Task<ServiceResult<DepotOperationsDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<DepotFleetMemberDto>>> FleetAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<DepotStockLineDto>>> StockAsync(CancellationToken cancellationToken);
    Task<ServiceResult<DepotDetailDto>> UpdateAsync(UpdateDepotRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<DepotDetailDto>> CreateAsync(CreateWarehouseRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<InventoryCountDto>> CountStockAsync(InventoryCountRequest request, CancellationToken cancellationToken);
}

// --- W15 Admin Sales ledger ---

public sealed record AdminSalesSummaryDto(
    DateOnly OperationalDate,
    decimal TodaysBilledSales,
    int BilledTransactionCount,
    decimal? PreviousBilledSales,
    decimal? BilledChangePercent,
    decimal CashSalesInward,
    int CashSaleCount,
    decimal CreditReceivablesFromSales,
    int CreditSaleCount,
    int CompletedSales,
    decimal AverageSaleValue,
    int PendingSyncCount,
    int FailedSyncCount);

public sealed record AdminSaleRowDto(
    Guid Id,
    string ReceiptNumber,
    DateTime CreatedAtUtc,
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string RiderId,
    string RiderName,
    string? VehicleLabel,
    string ItemsSummary,
    int ItemCount,
    decimal GrossAmount,
    decimal AmountReceived,
    decimal CreditAmount,
    string TenderLabel,
    string TenderClass,
    string Status,
    string SyncStatus);

public sealed record AdminSaleLineDetailDto(
    Guid ProductId,
    string ProductName,
    string Sku,
    int Quantity,
    string Unit,
    decimal UnitPrice,
    decimal LineTotal,
    bool IsReturnable);

public sealed record AdminSaleAssetDto(
    string AssetType,
    int PreviousHeld,
    int Issued,
    int Returned,
    int ClosingBalance);

public sealed record AdminSaleDetailDto(
    Guid Id,
    string ReceiptNumber,
    DateTime CreatedAtUtc,
    DateTime? PostedAtUtc,
    string Status,
    string SyncStatus,
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string CustomerAddress,
    string CustomerPhone,
    string CustomerCategory,
    string RiderId,
    string RiderName,
    string? RiderCode,
    string? VehicleLabel,
    string? RouteName,
    IReadOnlyList<AdminSaleLineDetailDto> Lines,
    decimal GrossAmount,
    decimal PreviousOutstanding,
    decimal AmountReceived,
    decimal CreditAmount,
    decimal RemainingFromSale,
    string? PaymentChannel,
    string TenderClass,
    AdminSaleAssetDto? ReturnableAssets,
    string? SignerName,
    string? SignerRole,
    DateTime? SignedAtUtc,
    bool HasSignatureImage,
    string? SignatureNote,
    string DepotName,
    string ScopeNote);

public sealed record AdminCreateSaleDraftRequest(
    string RiderUserId,
    Guid CustomerId,
    Guid? StopId,
    IReadOnlyList<SaleLineRequest> Lines,
    int? EmptyBottlesReturned = null);

public sealed record AdminCompleteSaleRequest(
    string PaymentMethod,
    decimal? AmountReceived,
    string SignerName,
    string? SignerRole = null,
    bool CloseStop = true,
    string? SignatureImage = null,
    string? SignatureNote = null);

public sealed record ShiftDayDto(
    string ServiceDate,
    IReadOnlyList<ShiftRiderDayDto> Riders,
    ShiftRiderDayDto? Selected,
    IReadOnlyList<OdometerDayDto> Odometer);

public sealed record ShiftRiderDayDto(
    string RiderId,
    string RiderName,
    string RiderCode,
    string RouteName,
    string VehicleName,
    string Plate,
    string FleetCode,
    string DepotName,
    string Status,
    DateTime? StartedAt,
    DateTime? EndedAt,
    int? OpeningOdometer,
    int? ClosingOdometer,
    bool OpeningPhotoStored,
    bool ClosingPhotoStored,
    bool OpeningInspectionStored,
    bool ClosingInspectionStored,
    string? OpeningOdometerPhoto,
    string? ClosingOdometerPhoto,
    string? OpeningInspectionPhoto,
    string? ClosingInspectionPhoto,
    int LoadedUnits,
    int ExpectedUnits,
    int ToDeliverUnits,
    int OrderCount,
    IReadOnlyList<LoadedBottleDto> Loaded,
    IReadOnlyList<DeliverBottleDto> ToDeliver);

public sealed record LoadedBottleDto(string ProductName, string UnitLabel, int DepotExpected, int Loaded, int? Closing);
public sealed record DeliverBottleDto(string ProductName, string UnitLabel, int Quantity);
public sealed record OdometerDayDto(string ServiceDate, string Status, int OpeningOdometer, int? ClosingOdometer, int? DistanceKm);

public interface IAdminShiftRecordService
{
    Task<ServiceResult<ShiftDayDto>> DayAsync(DateOnly? date, string? riderId, CancellationToken cancellationToken);
}

public interface IAdminSalesService
{
    Task<ServiceResult<AdminSalesSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminSaleRowDto>>> ListAsync(
        DateOnly? date,
        string? type,
        string? syncStatus,
        string? riderId,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<AdminSaleDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<SaleDraftDto>> CreateDraftAsync(AdminCreateSaleDraftRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> CompleteAsync(Guid id, AdminCompleteSaleRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> ReceiptAsync(Guid id, CancellationToken cancellationToken);
}

// --- W16 Admin Collections ---

public sealed record AdminCollectionsSummaryDto(
    DateOnly OperationalDate,
    decimal TodaysCollections,
    int TodaysCollectionCount,
    decimal MonthlyCollections,
    decimal ReceivablesLedger,
    int AccountsOnCredit,
    int HighRiskAgingAccounts,
    int FieldCollectionCount,
    int PendingSyncCount,
    int FailedSyncCount,
    decimal CashSharePercent,
    string ScopeNote);

public sealed record AdminCollectionRowDto(
    Guid Id,
    string ReferenceNumber,
    DateTime CreatedAtUtc,
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string CustomerArea,
    string RiderId,
    string RiderName,
    string ChannelLabel,
    string ChannelClass,
    decimal Amount,
    decimal WithholdingTax,
    decimal OutstandingBefore,
    decimal OutstandingAfter,
    string SyncStatus);

public sealed record AdminCollectionDetailDto(
    Guid Id,
    string ReferenceNumber,
    DateTime CreatedAtUtc,
    string SyncStatus,
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string CustomerAddress,
    string CustomerPhone,
    string RiderId,
    string RiderName,
    string? RiderCode,
    string? VehicleLabel,
    string? RouteName,
    string ChannelLabel,
    decimal Amount,
    decimal WithholdingTax,
    decimal OutstandingBefore,
    decimal OutstandingAfter,
    string? Notes,
    string? SignerName,
    string? SignerRole,
    bool HasSignatureImage,
    string? SignatureNote,
    string ScopeNote);

public sealed record AdminReceivableExposureDto(
    Guid CustomerId,
    string CustomerCode,
    string CustomerName,
    string Area,
    decimal Outstanding,
    int? DaysOverdue,
    string RiskLabel);

public sealed record AdminRecordCollectionRequest(
    string RiderUserId,
    Guid CustomerId,
    decimal Amount,
    string SignerName,
    string? SignerRole = null,
    string? SignatureImage = null,
    string? SignatureNote = null,
    decimal WithholdingTax = 0,
    string? Note = null,
    string? IdempotencyKey = null);

public interface IAdminCollectionsService
{
    Task<ServiceResult<AdminCollectionsSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminCollectionRowDto>>> ListAsync(
        DateOnly? date,
        string? type,
        string? riderId,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<AdminCollectionDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<ReceiptDto>> RecordAsync(AdminRecordCollectionRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminReceivableExposureDto>>> ExposureAsync(CancellationToken cancellationToken);
}

// --- W17 Admin Reports ---

public sealed record AdminReportsSummaryDto(
    DateOnly From,
    DateOnly To,
    decimal TotalRealizedSales,
    decimal? SalesChangePercent,
    decimal CollectionsReceived,
    decimal? RecoveryRatePercent,
    decimal ReceivablesFloat,
    int ReceivableAccounts,
    decimal? AverageReceivableAgeDays,
    int CompletedDrops,
    decimal? FirstAttemptSlaPercent,
    int CustomerVisits,
    int FleetCouriers,
    decimal? ShiftAttendancePercent,
    IReadOnlyList<AdminReportSeriesPointDto> SalesSeries,
    IReadOnlyList<AdminReportSeriesPointDto> CollectionsSeries,
    IReadOnlyList<AdminFulfillmentSliceDto> Fulfillment,
    IReadOnlyList<AdminRiderProductivityDto> RiderLeaderboard,
    AdminAssetCirculationDto AssetCirculation,
    string ScopeNote);

public sealed record AdminReportSeriesPointDto(DateOnly Day, decimal Amount);

public sealed record AdminFulfillmentSliceDto(string Label, int Count, decimal Percent);

public sealed record AdminRiderProductivityDto(
    string RiderId,
    string RiderName,
    string? RouteName,
    decimal RecoveryAmount,
    int StopsCompleted,
    decimal? OnTimePercent);

public sealed record AdminAssetCirculationDto(
    int Issued,
    int Recovered,
    int StoreFloat,
    int Scrap,
    decimal ClearedPercent);

public sealed record AdminReportCatalogItemDto(
    string Key,
    string Name,
    string Description,
    string Category,
    string Formats,
    DateTime? LastGeneratedAtUtc);

public sealed record AdminReportTableDto(
    string Key,
    string Name,
    string Category,
    IReadOnlyList<string> Columns,
    IReadOnlyList<IReadOnlyList<string>> Rows,
    DateTime GeneratedAtUtc);

public interface IAdminReportsService
{
    Task<ServiceResult<AdminReportsSummaryDto>> SummaryAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminReportCatalogItemDto>>> CatalogAsync(CancellationToken cancellationToken);
    Task<ServiceResult<AdminReportTableDto>> RunAsync(string key, DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
    Task<ServiceResult<string>> ExportCsvAsync(string key, DateOnly? from, DateOnly? to, CancellationToken cancellationToken);
}

// --- W19 Security Audit ---

public sealed record AdminAuditSummaryDto(
    DateOnly OperationalDate,
    int TotalEventsToday,
    int UserAndCourierActions,
    int AdministrativeModifications,
    int FinancialJournalOps,
    int AccessAndSecurity,
    int FieldOperations,
    int MasterData,
    string IntegrityNote,
    string ScopeNote);

public sealed record AdminAuditEventRowDto(
    Guid Id,
    DateTime OccurredAtUtc,
    string ActorUserId,
    string ActorName,
    string ActorRole,
    string Action,
    string EntityName,
    string EntityId,
    string Category,
    string Outcome,
    string Description);

public sealed record AdminAuditEventDetailDto(
    Guid Id,
    DateTime OccurredAtUtc,
    string ActorUserId,
    string ActorName,
    string ActorRole,
    string Action,
    string EntityName,
    string EntityId,
    string Category,
    string Outcome,
    string Description,
    string VerificationStatus,
    string? VerificationMessage,
    IReadOnlyList<AdminAuditTimelineItemDto> Timeline,
    string ScopeNote);

public sealed record AdminAuditTimelineItemDto(
    Guid Id,
    DateTime OccurredAtUtc,
    string Action,
    string EntityName,
    string EntityId,
    bool IsCurrent);

public sealed record AdminAuditVerifyResultDto(
    Guid EventId,
    string Status,
    string Message);

public interface IAdminSecurityAuditService
{
    Task<ServiceResult<AdminAuditSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<AdminAuditEventRowDto>>> ListAsync(
        DateOnly? date,
        string? category,
        string? search,
        string? outcome,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<AdminAuditEventDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<AdminAuditVerifyResultDto>> VerifyAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<string>> ExportCsvAsync(
        DateOnly? date,
        string? category,
        string? search,
        CancellationToken cancellationToken);
}

// --- W18 Communication (SMS) ---

public sealed record CommunicationGatewayStatusDto(
    string ProviderName,
    string Status,
    bool IsConfigured,
    string? SenderId,
    int MessagesToday,
    string Message,
    string ScopeNote);

public sealed record CommunicationDashboardSummaryDto(
    DateOnly OperationalDate,
    int MessagesDispatchedToday,
    int DeliveredSuccessfully,
    int PendingOrQueued,
    int FailedOrExceptions,
    CommunicationGatewayStatusDto Gateway,
    string ScopeNote);

public sealed record CommunicationTemplateDto(
    Guid Id,
    string TemplateCode,
    string Name,
    string Language,
    string TriggerType,
    string Content,
    bool IsActive,
    bool IsArchived,
    DateTime UpdatedAtUtc);

public sealed record CommunicationTemplateWriteRequest(
    string Name,
    string Language,
    string TriggerType,
    string Content,
    string? TemplateCode = null);

public sealed record CommunicationMessageRowDto(
    Guid Id,
    string MessageReference,
    string? CustomerName,
    string DestinationNumber,
    string Channel,
    string TriggerType,
    string? TransactionReference,
    DateTime CreatedAtUtc,
    string Status,
    string? FailureReason);

public sealed record CommunicationMessageDetailDto(
    Guid Id,
    string MessageReference,
    Guid? CustomerId,
    string? CustomerName,
    string DestinationNumber,
    string Channel,
    string TriggerType,
    string? TransactionReference,
    Guid? TemplateId,
    string? TemplateName,
    string RenderedContent,
    string Status,
    string? FailureReason,
    string? IdempotencyKey,
    DateTime CreatedAtUtc,
    DateTime? SubmittedAtUtc,
    string ScopeNote);

public sealed record CommunicationEnqueueRequest(
    Guid? CustomerId,
    Guid TemplateId,
    string DestinationNumber,
    string? TransactionReference,
    Dictionary<string, string>? Variables,
    string? IdempotencyKey = null,
    string? RiderUserId = null);

public sealed record CommunicationPreviewRequest(
    Guid TemplateId,
    Dictionary<string, string>? Variables);

public sealed record CommunicationPreviewDto(
    string Language,
    string RenderedContent,
    string DestinationHint);

public sealed record CommunicationTriggerDto(
    string TriggerType,
    string Description,
    Guid? TemplateId,
    string? TemplateName,
    bool Enabled);

public interface IAdminCommunicationsService
{
    Task<ServiceResult<CommunicationDashboardSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationGatewayStatusDto>> GatewayStatusAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationGatewayStatusDto>> TestGatewayAsync(CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<CommunicationTemplateDto>>> ListTemplatesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationTemplateDto>> GetTemplateAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationTemplateDto>> CreateTemplateAsync(CommunicationTemplateWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationTemplateDto>> UpdateTemplateAsync(Guid id, CommunicationTemplateWriteRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationTemplateDto>> SetTemplateActiveAsync(Guid id, bool isActive, CancellationToken cancellationToken);
    Task<ServiceResult<object>> ArchiveTemplateAsync(Guid id, CancellationToken cancellationToken);

    Task<ServiceResult<CommunicationPreviewDto>> PreviewAsync(CommunicationPreviewRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CommunicationTriggerDto>>> ListTriggersAsync(CancellationToken cancellationToken);

    Task<ServiceResult<IReadOnlyList<CommunicationMessageRowDto>>> ListMessagesAsync(
        DateOnly? date,
        string? status,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationMessageDetailDto>> GetMessageAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationMessageDetailDto>> EnqueueAsync(CommunicationEnqueueRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<CommunicationMessageDetailDto>> RetryAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<string>> ExportMessagesCsvAsync(DateOnly? date, string? status, CancellationToken cancellationToken);
}

public sealed class FleetTrackingOptions
{
    public const string SectionName = "FleetTracking";
    public int TransmitIntervalSeconds { get; set; } = 45;
    public int FreshnessSeconds { get; set; } = 180;
    public double CorridorMeters { get; set; } = 150;
    public int StationaryMinutes { get; set; } = 15;
    public int ConsecutiveFixesRequired { get; set; } = 3;
    public double MaxAccuracyMeters { get; set; } = 75;
    public int ExplanationResponseHours { get; set; } = 4;
    public double MovingSpeedMps { get; set; } = 1.5;
}

public sealed record TrackingLocationPointDto(
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    double? SpeedMetersPerSecond,
    double? HeadingDegrees,
    DateTime DeviceTimestampUtc,
    int? BatteryPercent,
    string? NetworkStatus);

public sealed class TrackingLocationBatchRequest
{
    public Guid? SessionId { get; set; }
    public List<TrackingLocationPointDto> Points { get; set; } = [];
}

public sealed record TrackingStopRequest(string? Reason);

public sealed record TrackingSessionDto(
    Guid Id,
    Guid ShiftId,
    Guid? RouteId,
    string Status,
    DateTime StartedAtUtc,
    DateTime? EndedAtUtc,
    string? EndReason);

public sealed record TrackingStatusDto(
    bool TrackingActive,
    TrackingSessionDto? Session,
    DateTime? LastFixAtUtc,
    double? LastLatitude,
    double? LastLongitude,
    double? LastAccuracyMeters,
    double? LastSpeedMps,
    int? LastBatteryPercent,
    string? NetworkStatus,
    bool LastFixStale,
    string LocationSharingLabel);

public sealed record AssignmentStopDto(
    Guid StopId,
    Guid CustomerId,
    string CustomerName,
    int Sequence,
    string Status,
    double? Latitude,
    double? Longitude);

public sealed record ActiveAssignmentDto(
    string RiderUserId,
    string RiderCode,
    string FullName,
    string? DepotName,
    string? VehicleName,
    string? VehiclePlate,
    string? FleetCode,
    Guid? RouteId,
    string? RouteName,
    Guid? ShiftId,
    string? ShiftStatus,
    AssignmentStopDto? NextStop,
    IReadOnlyList<AssignmentStopDto> Stops,
    int CompletedStops,
    int PendingStops,
    int TotalStops);

public sealed record RouteComplianceStateDto(
    string State,
    string Summary,
    Guid? OpenAnomalyId,
    string? OpenAnomalyNumber,
    string? OpenAnomalyCategory,
    DateTime? LastEvaluatedAtUtc);

public sealed record AnomalyExplanationDto(
    Guid Id,
    string Reason,
    string ExplanationText,
    string? SupportingNote,
    DateTime SubmittedAtUtc,
    bool IsCorrection);

public sealed record AnomalyReviewDto(
    Guid Id,
    string AdminUserId,
    string Action,
    string? Notes,
    DateTime OccurredAtUtc);

public sealed record AnomalyStatusEventDto(
    string FromStatus,
    string ToStatus,
    string? ActorUserId,
    string? Note,
    DateTime OccurredAtUtc);

public sealed record RouteAnomalyDto(
    Guid Id,
    string AnomalyNumber,
    string RiderUserId,
    string RiderName,
    string? RiderCode,
    Guid TrackingSessionId,
    Guid? RouteId,
    string? RouteName,
    string Category,
    string Severity,
    string Status,
    DateTime DetectedAtUtc,
    double? LastLatitude,
    double? LastLongitude,
    string? ExpectedWaypoint,
    double? ActualHeadingDegrees,
    double? ExpectedHeadingDegrees,
    string EvidenceJson,
    DateTime? ResponseDueAtUtc,
    DateTime? ResolvedAtUtc,
    string? ResolutionNotes,
    IReadOnlyList<AnomalyExplanationDto> Explanations,
    IReadOnlyList<AnomalyReviewDto> Reviews,
    IReadOnlyList<AnomalyStatusEventDto> StatusHistory);

public sealed class AnomalyExplanationRequest
{
    public AnomalyExplanationReason Reason { get; set; }
    public string ExplanationText { get; set; } = "";
    public string? SupportingNote { get; set; }
    public bool IsCorrection { get; set; }
}

public sealed class AnomalyReviewRequest
{
    public string Action { get; set; } = "";
    public string? Notes { get; set; }
}

public sealed class AnomalyQueryRequest
{
    public string Message { get; set; } = "";
}

public sealed class AnomalyResolveRequest
{
    public string? Notes { get; set; }
    public bool MarkFalsePositive { get; set; }
}

public sealed record RiderNotificationDto(
    Guid Id,
    string Title,
    string Body,
    string DeepLink,
    Guid? AnomalyId,
    bool IsRead,
    DateTime CreatedAtUtc);

public sealed record LiveTrackingOverviewDto(
    int RidersOnDuty,
    int FleetTotal,
    int MovingCount,
    double? AverageSpeedKmh,
    int DeliveringCount,
    int StationaryAlertCount,
    int StaleOrOfflineCount,
    int TransmittingCount,
    double? AverageBatteryPercent,
    int OpenAnomalies);

public sealed record LiveRiderTelemetryPointDto(
    double Latitude,
    double Longitude,
    DateTime DeviceTimestampUtc,
    double? SpeedMetersPerSecond,
    double? HeadingDegrees);

public sealed record LiveRiderCardDto(
    string RiderUserId,
    string FullName,
    string? RiderCode,
    string? VehicleName,
    string? VehiclePlate,
    string? FleetCode,
    string? RouteName,
    Guid? RouteId,
    Guid? SessionId,
    bool TrackingActive,
    string MotionState,
    double? Latitude,
    double? Longitude,
    DateTime? LastFixAtUtc,
    bool LastFixStale,
    double? SpeedKmh,
    double? AccuracyMeters,
    int? BatteryPercent,
    string? NetworkStatus,
    string? NextWaypoint,
    int CompletedStops,
    int TotalStops,
    decimal TodaySales,
    decimal CashInHand,
    int EmptyReturns,
    int OpenAnomalies,
    int PendingExplanations);

public sealed record LiveRiderDetailDto(
    LiveRiderCardDto Card,
    IReadOnlyList<LiveRiderTelemetryPointDto> Trail,
    IReadOnlyList<AssignmentStopDto> Stops,
    IReadOnlyList<RouteAnomalyDto> RecentAnomalies);

public interface ILiveTrackingService
{
    Task<ServiceResult<TrackingSessionDto>> StartAsync(CancellationToken cancellationToken);
    Task<ServiceResult<TrackingSessionDto>> StopAsync(TrackingStopRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<object>> IngestLocationsAsync(TrackingLocationBatchRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<TrackingStatusDto>> StatusAsync(CancellationToken cancellationToken);
    Task<ServiceResult<ActiveAssignmentDto>> ActiveAssignmentAsync(string? riderUserId, CancellationToken cancellationToken);
    Task<ServiceResult<RouteComplianceStateDto>> CurrentComplianceAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteAnomalyDto>>> RiderAnomaliesAsync(CancellationToken cancellationToken);
    Task<ServiceResult<RouteAnomalyDto>> SubmitExplanationAsync(Guid anomalyId, AnomalyExplanationRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RiderNotificationDto>>> RiderNotificationsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<object>> MarkNotificationReadAsync(Guid id, CancellationToken cancellationToken);

    Task<ServiceResult<LiveTrackingOverviewDto>> OverviewAsync(CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<LiveRiderCardDto>>> LiveRidersAsync(CancellationToken cancellationToken);
    Task<ServiceResult<LiveRiderDetailDto>> LiveRiderAsync(string riderUserId, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<RouteAnomalyDto>>> AdminAnomaliesAsync(string? status, string? riderUserId, CancellationToken cancellationToken);
    Task<ServiceResult<RouteAnomalyDto>> AdminAnomalyAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<RouteAnomalyDto>> ReviewAsync(Guid id, AnomalyReviewRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RouteAnomalyDto>> QueryRiderAsync(Guid id, AnomalyQueryRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<RouteAnomalyDto>> ResolveAsync(Guid id, AnomalyResolveRequest request, CancellationToken cancellationToken);
}
