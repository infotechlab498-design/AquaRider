namespace RouteLedger.Domain;

public static class AppRoles
{
    public const string Rider = "Rider";
    public const string Admin = "Admin";
    public const string Customer = "Customer";

    public static string Primary(IEnumerable<string> roles)
    {
        var list = roles.Where(role => !string.IsNullOrWhiteSpace(role)).Select(role => role.Trim()).ToArray();
        if (list.Any(role => role.Equals(Admin, StringComparison.OrdinalIgnoreCase)))
        {
            return Admin;
        }

        var portal = list.FirstOrDefault(role => !role.Equals(Rider, StringComparison.OrdinalIgnoreCase));
        return portal ?? list.FirstOrDefault() ?? Rider;
    }
}

public static class AdminScreens
{
    public static readonly (string Key, string Group, string Label, string Detail)[] Catalog =
    [
        ("adminDashboard", "Dashboard & Business Intelligence", "View Operations Dashboard", "Open the HQ overview."),
        ("reportsAnalytics", "Dashboard & Business Intelligence", "Reports & Analytics", "Open the saved reports."),
        ("liveTrackboard", "Field Operations & Dispatch Board", "View Live Trackboard", "Open the fleet trackboard."),
        ("dispatchOrders", "Field Operations & Dispatch Board", "Dispatch & Orders", "Create and manage orders."),
        ("recurringSchedules", "Field Operations & Dispatch Board", "Recurring Schedules", "Plan weekly and monthly customer deliveries and publish them to a rider."),
        ("routeManifests", "Field Operations & Dispatch Board", "Route Manifests", "Open the day's route stops."),
        ("zonesRoutes", "Field Operations & Dispatch Board", "Zones & Routes", "Manage zones, routes, and rider assignment."),
        ("fleetCouriers", "Field Operations & Dispatch Board", "Fleet Couriers", "Open rider operations."),
        ("dayCloseRecon", "Reconciliation & Cash Settlement", "Day Close & Recon", "Open day close."),
        ("shiftRecords", "Field Operations & Dispatch Board", "Shift Records", "Open a rider's loaded stock, delivery bottles, and odometer for any date."),
        ("salesManagement", "Reconciliation & Cash Settlement", "Sales", "Open recorded sales."),
        ("collectionsManagement", "Reconciliation & Cash Settlement", "Collections & Recovery", "Open recorded collections."),
        ("customersParties", "Customers & Master Catalog", "Customers & Parties", "Open the customer directory."),
        ("customerAccounts", "Customers & Master Catalog", "Customer Accounts", "Review customer app accounts, requests, pauses, and quantity changes."),
        ("basePricing", "Customers & Master Catalog", "Products & Base Pricing", "Open the catalogue and price lists."),
        ("branchesWarehouses", "Customers & Master Catalog", "Branches & Warehouses", "Open the depot."),
        ("usersStaff", "Team & Access Management", "Roles & Permissions", "Choose which screens a role can open."),
        ("communicationSms", "Team & Access Management", "Communication", "Send messages to a rider inbox."),
        ("securityAudit", "System & Audit Logs", "Audit Log", "Read the audit trail."),
        ("setupChecklist", "System & Audit Logs", "Setup Checklist", "Open the onboarding steps.")
    ];

    public static readonly string[] Keys = Catalog.Select(item => item.Key).ToArray();

    public static string? ForPath(string path)
    {
        var value = path.ToLowerInvariant();
        // The rider home is GET /api/dashboard. HQ screens live under /api/dashboard/.
        if (value.StartsWith("/api/dashboard/")) return "adminDashboard";
        if (value.StartsWith("/api/admin/reports")) return "reportsAnalytics";
        if (value.StartsWith("/api/admin/live-tracking") || value.StartsWith("/api/admin/route-anomalies")) return "liveTrackboard";
        if (value.StartsWith("/api/admin/recurring-schedules") || value.StartsWith("/api/admin/delivery-occurrences")) return "recurringSchedules";
        if (value.StartsWith("/api/dispatch")) return "dispatchOrders";
        if (value.StartsWith("/api/routes") || value.StartsWith("/api/zones")) return "zonesRoutes";
        if (value.StartsWith("/api/rider-operations")) return "fleetCouriers";
        if (value.StartsWith("/api/settlements")) return "dayCloseRecon";
        if (value.StartsWith("/api/admin/shifts")) return "shiftRecords";
        if (value.StartsWith("/api/admin/sales")) return "salesManagement";
        if (value.StartsWith("/api/admin/collections") || value.StartsWith("/api/admin/receivables")) return "collectionsManagement";
        if (value.StartsWith("/api/admin/customer-accounts") || value.StartsWith("/api/admin/customer-requests")) return "customerAccounts";
        if (value.StartsWith("/api/admin/customers")) return "customersParties";
        if (value.StartsWith("/api/products") || value.Contains("/base-price-lookup")) return "basePricing";
        if (value.StartsWith("/api/depot")) return "branchesWarehouses";
        if (value.StartsWith("/api/users")) return "usersStaff";
        if (value.StartsWith("/api/admin/communication")) return "communicationSms";
        if (value.StartsWith("/api/admin/audit")) return "securityAudit";
        if (value.StartsWith("/api/onboarding")) return "setupChecklist";
        return null;
    }
}

public sealed class RoleProfile
{
    public string RoleName { get; set; } = "";
    public string Description { get; set; } = "";
    public bool IsSystem { get; set; }
}

public sealed class RoleScreenGrant
{
    public int Id { get; set; }
    public string RoleName { get; set; } = "";
    public string ScreenKey { get; set; } = "";
}

public enum StopStatus
{
    Pending,
    InProgress,
    Completed,
    Missed
}

public enum SaleStatus
{
    Draft,
    Completed
}

public enum SyncStatus
{
    Pending,
    Synced,
    Failed
}

public enum PaymentChannel
{
    Cash,
    BankTransfer,
    Wallet,
    Cheque
}

public enum DeliveryWindow
{
    Morning,
    Afternoon,
    Evening
}

public static class OrderOrigin
{
    public const string Hq = "Hq";
    public const string Rider = "Rider";
}

public enum CustomerOrderStatus
{
    Scheduled,
    Cancelled,
    Delivered,
    InProgress
}

public enum LedgerKind
{
    Opening,
    Sale,
    Payment
}

public enum BottleOwnership
{
    Rented,
    Own
}

public enum ResetRequestStatus
{
    Pending,
    Completed
}

public abstract class Entity
{
    public Guid Id { get; set; } = Guid.NewGuid();
}

public sealed class Depot : Entity
{
    public string Name { get; set; } = "";
    public string Gate { get; set; } = "";
    public string Address { get; set; } = "";
}

public sealed class Vehicle : Entity
{
    public string Name { get; set; } = "";
    public string Plate { get; set; } = "";
    public string FleetCode { get; set; } = "";
    public int CurrentOdometer { get; set; }
}

/// <summary>Delivery sector / cluster that owns one or more <see cref="DeliveryRoute"/> rows.</summary>
public sealed class Zone : Entity
{
    public string Name { get; set; } = "";
    public string Sector { get; set; } = "";
    public string City { get; set; } = "";
    public Guid DepotId { get; set; }
    public Depot Depot { get; set; } = null!;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class DeliveryRoute : Entity
{
    public string Name { get; set; } = "";
    public string Sector { get; set; } = "";
    public string City { get; set; } = "";
    public Guid ZoneId { get; set; }
    public Zone Zone { get; set; } = null!;
    public Guid DepotId { get; set; }
    public Depot Depot { get; set; } = null!;
}

public sealed class Customer : Entity
{
    public string Code { get; set; } = "";
    public string BusinessName { get; set; } = "";
    public string PrimaryMobile { get; set; } = "";
    public string? AdditionalContact { get; set; }
    public string Category { get; set; } = "";
    public string Street { get; set; } = "";
    public string Area { get; set; } = "";
    public string City { get; set; } = "";
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public Guid RouteId { get; set; }
    public DeliveryRoute Route { get; set; } = null!;
    /// <summary>Master stop order within the assigned route (1-based).</summary>
    public int RouteSortOrder { get; set; }
    public string Status { get; set; } = "Active";
    public decimal Outstanding { get; set; }
    public int BottlesIssued { get; set; }
    public int BottlesReturned { get; set; }
    public int BottlesHeld { get; set; }
    public BottleOwnership BottleOwnership { get; set; } = BottleOwnership.Rented;
    public string? Cnic { get; set; }
    public string? ContactName { get; set; }
    public string? ContactRole { get; set; }
    public DateTime? LastDropAt { get; set; }
    public DateTime? LastPaymentAt { get; set; }
    public decimal? LastPaymentAmount { get; set; }
    public int CreditDays { get; set; } = 7;
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class Product : Entity
{
    public string Name { get; set; } = "";
    public string Sku { get; set; } = "";
    public decimal UnitPrice { get; set; }
    public string UnitLabel { get; set; } = "";
    public bool IsReturnable { get; set; }
    public bool ShowOnSale { get; set; } = true;
    public bool ShowOnShift { get; set; } = true;
}

/// <summary>A named rate card. Product.UnitPrice stays the base system price.</summary>
public sealed class PriceList : Entity
{
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public bool IsDefault { get; set; }
    public bool IsActive { get; set; } = true;
    public DateOnly EffectiveFrom { get; set; }
    public DateOnly? EffectiveTo { get; set; }
    public string Scope { get; set; } = "all";
    public Guid? RouteId { get; set; }
    public DeliveryRoute? Route { get; set; }
    public Guid? ZoneId { get; set; }
    public Zone? Zone { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<PriceListLine> Lines { get; set; } = [];
}

public sealed class PriceListLine : Entity
{
    public Guid PriceListId { get; set; }
    public PriceList PriceList { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public decimal ListRate { get; set; }
    public decimal BaseSystemPrice { get; set; }
}

public sealed class VehicleStock : Entity
{
    public Guid VehicleId { get; set; }
    public Vehicle Vehicle { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int Quantity { get; set; }
    public int DepotExpected { get; set; }
}

public sealed class Shift : Entity
{
    public string RiderId { get; set; } = "";
    public Guid RouteId { get; set; }
    public Guid VehicleId { get; set; }
    public DateOnly ServiceDate { get; set; }
    public int OpeningOdometer { get; set; }
    public int? ClosingOdometer { get; set; }
    public byte[]? OpeningOdometerPhoto { get; set; }
    public byte[]? ClosingOdometerPhoto { get; set; }
    public byte[]? OpeningInspectionPhoto { get; set; }
    public byte[]? ClosingInspectionPhoto { get; set; }
    public string Status { get; set; } = "Open";
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? EndedAt { get; set; }
    public List<ShiftStock> Lines { get; set; } = [];
}

public sealed class ShiftStock : Entity
{
    public Guid ShiftId { get; set; }
    public Shift Shift { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int ExpectedQuantity { get; set; }
    public int CountedQuantity { get; set; }
    public int? ClosingQuantity { get; set; }
}

public sealed class RouteStop : Entity
{
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public Guid RouteId { get; set; }
    public DateOnly ServiceDate { get; set; }
    public int Sequence { get; set; }
    public TimeOnly? ScheduledTime { get; set; }
    public StopStatus Status { get; set; } = StopStatus.Pending;
    public int? DistanceMeters { get; set; }
}

public sealed class Sale : Entity
{
    public string ReceiptNumber { get; set; } = "";
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public string RiderId { get; set; } = "";
    public Guid? ShiftId { get; set; }
    public Guid? StopId { get; set; }
    public decimal SaleAmount { get; set; }
    public decimal PreviousOutstanding { get; set; }
    public int EmptyBottlesReturned { get; set; }
    public decimal AmountReceived { get; set; }
    public PaymentChannel? PaymentChannel { get; set; }
    public SaleStatus Status { get; set; } = SaleStatus.Draft;
    public string? SignerName { get; set; }
    public string? SignerRole { get; set; }
    public DateTime? SignedAt { get; set; }
    public byte[]? SignatureImage { get; set; }
    public string? SignatureNote { get; set; }
    public SyncStatus SyncStatus { get; set; } = SyncStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<SaleLine> Lines { get; set; } = [];
}

public sealed class SaleLine : Entity
{
    public Guid SaleId { get; set; }
    public Sale Sale { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}

public sealed class Collection : Entity
{
    public string ReferenceNumber { get; set; } = "";
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public string RiderId { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal WithholdingTax { get; set; }
    public string? Notes { get; set; }
    public PaymentChannel Channel { get; set; }
    public string CashStatus { get; set; } = CashCollectionStatus.CollectedByRider;
    public Guid? HandoverId { get; set; }
    public DateTime? CashReceivedAt { get; set; }
    public string? CashReceivedByUserId { get; set; }
    public Guid? CashReceivedDepotId { get; set; }
    public decimal OutstandingBefore { get; set; }
    public decimal OutstandingAfter { get; set; }
    public string? SignerName { get; set; }
    public string? SignerRole { get; set; }
    public byte[]? SignatureImage { get; set; }
    public string? SignatureNote { get; set; }
    public SyncStatus SyncStatus { get; set; } = SyncStatus.Synced;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public sealed class CustomerOrder : Entity
{
    public string ReferenceNumber { get; set; } = "";
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public string RiderId { get; set; } = "";
    public DateOnly DeliveryDate { get; set; }
    public DeliveryWindow Window { get; set; }
    public decimal EstimatedValue { get; set; }
    public string? Notes { get; set; }
    public bool ShowOnManifest { get; set; } = true;
    public CustomerOrderStatus Status { get; set; } = CustomerOrderStatus.Scheduled;
    public SyncStatus SyncStatus { get; set; } = SyncStatus.Synced;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CancelledAtUtc { get; set; }
    public string? CancelledByUserId { get; set; }
    public string? CancellationReason { get; set; }
    public string Origin { get; set; } = OrderOrigin.Hq;
    public List<OrderLine> Lines { get; set; } = [];
    public List<OrderLifecycleEvent> Lifecycle { get; set; } = [];
}

public sealed class OrderLine : Entity
{
    public Guid OrderId { get; set; }
    public CustomerOrder Order { get; set; } = null!;
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}

public sealed class OrderLifecycleEvent : Entity
{
    public Guid OrderId { get; set; }
    public CustomerOrder Order { get; set; } = null!;
    public string EventCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Detail { get; set; }
    public string? ActorUserId { get; set; }
    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class LedgerEntry : Entity
{
    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = null!;
    public LedgerKind Kind { get; set; }
    public string Description { get; set; } = "";
    public decimal Amount { get; set; }
    public decimal BalanceAfter { get; set; }
    public string? Reference { get; set; }
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}

public sealed class ActivityLog : Entity
{
    public string UserId { get; set; } = "";
    public string Title { get; set; } = "";
    public string Reference { get; set; } = "";
    public decimal? Amount { get; set; }
    public SyncStatus SyncStatus { get; set; }
    public string Detail { get; set; } = "";
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}

public sealed class AuditLog : Entity
{
    public string UserId { get; set; } = "";
    public string Action { get; set; } = "";
    public string EntityName { get; set; } = "";
    public string EntityId { get; set; } = "";
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}

public sealed class RiderSettings
{
    public string UserId { get; set; } = "";
    public bool AutoSync { get; set; } = true;
    public bool ShowOrdersTab { get; set; } = true;
    public string Language { get; set; } = "English (US)";
    public bool AutoPrint { get; set; }
    public bool DeleteOnLogout { get; set; }
    public string PaperSize { get; set; } = "58mm";
    public Guid? PrinterId { get; set; }
}

public sealed class PrinterDevice : Entity
{
    public string Name { get; set; } = "";
    public string Meta { get; set; } = "";
    public bool IsOnline { get; set; }
}

public sealed class PrintJob : Entity
{
    public Guid? SaleId { get; set; }
    public Guid? CollectionId { get; set; }
    public string UserId { get; set; } = "";
    public string? PrinterName { get; set; }
    public string Status { get; set; } = "Queued";
    public DateTime RequestedAt { get; set; } = DateTime.UtcNow;
}

public sealed class NumberSequence
{
    public string Name { get; set; } = "";
    public int NextValue { get; set; } = 1;
}

public sealed class RefreshToken : Entity
{
    public string UserId { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAt { get; set; }
    public string? ReplacedByHash { get; set; }
    public bool RememberMe { get; set; }
    public string? DeviceInformation { get; set; }
}

public enum OnboardingStepCode
{
    PlantDetails,
    ItemsAndOpenings,
    Customers,
    Zones,
    RiderAndLoad,
    FirstSyncedSale
}

public enum OnboardingStepStatus
{
    NotStarted,
    InProgress,
    PendingVerification,
    Completed,
    Blocked
}

public sealed class BusinessProfile : Entity
{
    public string LegalName { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string? TaxNumber { get; set; }
    public string? RegistrationNumber { get; set; }
    public string Status { get; set; } = "SetupInProgress";
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    /// <summary>When null, any non-zero net variance requires remarks on approve.</summary>
    public decimal? SettlementVarianceThreshold { get; set; }
    public string SupportEmail { get; set; } = "";
    public string SupportPhone { get; set; } = "";
    public string SupportAddress { get; set; } = "";
    public string Website { get; set; } = "";
    public string ReceiptFooter { get; set; } = "";
}

public static class SettlementStatuses
{
    public const string NotStarted = "notStarted";
    public const string AwaitingReview = "awaitingReview";
    public const string VarianceDetected = "varianceDetected";
    public const string Reconciled = "reconciled";
    public const string Locked = "locked";
}

public static class SettlementEventCodes
{
    public const string DayStarted = "DayStarted";
    public const string RiderSubmission = "RiderSubmission";
    public const string PhysicalVaultCount = "PhysicalVaultCount";
    public const string StockReturnVerification = "StockReturnVerification";
    public const string VarianceDetected = "VarianceDetected";
    public const string ManagerReviewStarted = "ManagerReviewStarted";
    public const string ManagerDecisionSaved = "ManagerDecisionSaved";
    public const string SettlementApproved = "SettlementApproved";
    public const string DayLocked = "DayLocked";
}

public static class SettlementResolutionCategories
{
    public const string CashShortageRiderAccountable = "cashShortageRiderAccountable";
    public const string CashOverageRecorded = "cashOverageRecorded";
    public const string CountingErrorCorrected = "countingErrorCorrected";
    public const string PendingSyncResolved = "pendingSyncResolved";
    public const string StockDiscrepancyNoted = "stockDiscrepancyNoted";
    public const string Other = "other";

    public static readonly HashSet<string> All = new(StringComparer.Ordinal)
    {
        CashShortageRiderAccountable,
        CashOverageRecorded,
        CountingErrorCorrected,
        PendingSyncResolved,
        StockDiscrepancyNoted,
        Other
    };
}

public sealed class SettlementSession : Entity
{
    public DateOnly BusinessDate { get; set; }
    public string RiderId { get; set; } = "";
    public Guid? ShiftId { get; set; }
    public Guid? RouteId { get; set; }
    public string Status { get; set; } = SettlementStatuses.NotStarted;
    public string? RiderAnnotation { get; set; }
    public decimal? DraftVerifiedCash { get; set; }
    public string? DraftResolutionCategory { get; set; }
    public string? DraftRemarks { get; set; }
    public string? ResolutionCategory { get; set; }
    public string? ResolutionRemarks { get; set; }
    public string? ApprovedByUserId { get; set; }
    public DateTime? ApprovedAtUtc { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public List<CashDeclaration> Declarations { get; set; } = [];
    public List<PhysicalCashVerification> Verifications { get; set; } = [];
}

public sealed class CashDeclaration : Entity
{
    public Guid SettlementSessionId { get; set; }
    public SettlementSession Session { get; set; } = null!;
    public decimal DeclaredAmount { get; set; }
    public string Source { get; set; } = "AdminAssist";
    public DateTime SubmittedAtUtc { get; set; } = DateTime.UtcNow;
    public string SubmittedByUserId { get; set; } = "";
    public string? Note { get; set; }
}

public sealed class PhysicalCashVerification : Entity
{
    public Guid SettlementSessionId { get; set; }
    public SettlementSession Session { get; set; } = null!;
    public decimal VerifiedAmount { get; set; }
    public string? BatchReference { get; set; }
    public DateTime VerifiedAtUtc { get; set; } = DateTime.UtcNow;
    public string VerifiedByUserId { get; set; } = "";
    public string? Notes { get; set; }
}

public sealed class DayLock : Entity
{
    public DateOnly BusinessDate { get; set; }
    public Guid? DepotId { get; set; }
    public DateTime LockedAtUtc { get; set; } = DateTime.UtcNow;
    public string LockedByUserId { get; set; } = "";
    public string? AcknowledgementNote { get; set; }
}

public sealed class SettlementAuditEvent : Entity
{
    public DateOnly BusinessDate { get; set; }
    public Guid? SettlementSessionId { get; set; }
    public string EventCode { get; set; } = "";
    public string Title { get; set; } = "";
    public string? Detail { get; set; }
    public string? ActorUserId { get; set; }
    public DateTime OccurredAtUtc { get; set; } = DateTime.UtcNow;
    public string? RelatedEntityName { get; set; }
    public string? RelatedEntityId { get; set; }
}

public sealed class OnboardingStepRecord : Entity
{
    public Guid BusinessProfileId { get; set; }
    public OnboardingStepCode StepCode { get; set; }
    public OnboardingStepStatus Status { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public string? ValidationNotes { get; set; }
}

public sealed class PasswordResetRequest : Entity
{
    public string UserId { get; set; } = "";
    public DateTime RequestedAt { get; set; } = DateTime.UtcNow;
    public ResetRequestStatus Status { get; set; } = ResetRequestStatus.Pending;
}

/// <summary>Locked V1 transactional SMS template (English/Urdu).</summary>
public sealed class CommunicationTemplate : Entity
{
    public string TemplateCode { get; set; } = "";
    public string Name { get; set; } = "";
    public string Language { get; set; } = "en";
    public string TriggerType { get; set; } = "";
    public string Content { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public bool IsArchived { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public string? UpdatedByUserId { get; set; }
}

/// <summary>Outbound transactional SMS record. Delivered is never set without a real provider callback.</summary>
public sealed class CommunicationMessage : Entity
{
    public string MessageReference { get; set; } = "";
    public Guid? CustomerId { get; set; }
    public Customer? Customer { get; set; }
    public Guid? TemplateId { get; set; }
    public CommunicationTemplate? Template { get; set; }
    public string TriggerType { get; set; } = "";
    public string DestinationNumber { get; set; } = "";
    public string RenderedContent { get; set; } = "";
    public string Status { get; set; } = "Queued";
    public string? FailureReason { get; set; }
    public string? TransactionReference { get; set; }
    public string? IdempotencyKey { get; set; }
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? SubmittedAtUtc { get; set; }
}
