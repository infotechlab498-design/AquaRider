using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Data;

public sealed class AppDbContext : IdentityDbContext<ApplicationUser>
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Depot> Depots => Set<Depot>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<Zone> Zones => Set<Zone>();
    public DbSet<DeliveryRoute> DeliveryRoutes => Set<DeliveryRoute>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<CustomerAccount> CustomerAccounts => Set<CustomerAccount>();
    public DbSet<CustomerLinkReview> CustomerLinkReviews => Set<CustomerLinkReview>();
    public DbSet<CashHandover> CashHandovers => Set<CashHandover>();
    public DbSet<PriceListAssignment> PriceListAssignments => Set<PriceListAssignment>();
    public DbSet<WarehouseStock> WarehouseStocks => Set<WarehouseStock>();
    public DbSet<InventoryCountLine> InventoryCountLines => Set<InventoryCountLine>();
    public DbSet<CustomerSavedAddress> CustomerSavedAddresses => Set<CustomerSavedAddress>();
    public DbSet<CustomerServiceRequest> CustomerServiceRequests => Set<CustomerServiceRequest>();
    public DbSet<CustomerNotification> CustomerNotifications => Set<CustomerNotification>();
    public DbSet<AdminRequestNotice> AdminRequestNotices => Set<AdminRequestNotice>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<PriceList> PriceLists => Set<PriceList>();
    public DbSet<PriceListLine> PriceListLines => Set<PriceListLine>();
    public DbSet<VehicleStock> VehicleStocks => Set<VehicleStock>();
    public DbSet<Shift> Shifts => Set<Shift>();
    public DbSet<ShiftStock> ShiftStocks => Set<ShiftStock>();
    public DbSet<RouteStop> RouteStops => Set<RouteStop>();
    public DbSet<Sale> Sales => Set<Sale>();
    public DbSet<SaleLine> SaleLines => Set<SaleLine>();
    public DbSet<Collection> Collections => Set<Collection>();
    public DbSet<CustomerOrder> CustomerOrders => Set<CustomerOrder>();
    public DbSet<OrderLine> OrderLines => Set<OrderLine>();
    public DbSet<OrderLifecycleEvent> OrderLifecycleEvents => Set<OrderLifecycleEvent>();
    public DbSet<LedgerEntry> LedgerEntries => Set<LedgerEntry>();
    public DbSet<ActivityLog> ActivityLogs => Set<ActivityLog>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<RoleProfile> RoleProfiles => Set<RoleProfile>();
    public DbSet<RoleScreenGrant> RoleScreenGrants => Set<RoleScreenGrant>();
    public DbSet<RiderSettings> RiderSettings => Set<RiderSettings>();
    public DbSet<PrinterDevice> Printers => Set<PrinterDevice>();
    public DbSet<PrintJob> PrintJobs => Set<PrintJob>();
    public DbSet<NumberSequence> NumberSequences => Set<NumberSequence>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<PasswordResetRequest> PasswordResetRequests => Set<PasswordResetRequest>();
    public DbSet<BusinessProfile> BusinessProfiles => Set<BusinessProfile>();
    public DbSet<OnboardingStepRecord> OnboardingSteps => Set<OnboardingStepRecord>();
    public DbSet<SettlementSession> SettlementSessions => Set<SettlementSession>();
    public DbSet<CashDeclaration> CashDeclarations => Set<CashDeclaration>();
    public DbSet<PhysicalCashVerification> PhysicalCashVerifications => Set<PhysicalCashVerification>();
    public DbSet<DayLock> DayLocks => Set<DayLock>();
    public DbSet<SettlementAuditEvent> SettlementAuditEvents => Set<SettlementAuditEvent>();
    public DbSet<CommunicationTemplate> CommunicationTemplates => Set<CommunicationTemplate>();
    public DbSet<CommunicationMessage> CommunicationMessages => Set<CommunicationMessage>();
    public DbSet<TrackingSession> TrackingSessions => Set<TrackingSession>();
    public DbSet<RiderLocationTelemetry> RiderLocationTelemetries => Set<RiderLocationTelemetry>();
    public DbSet<RouteComplianceAnomaly> RouteComplianceAnomalies => Set<RouteComplianceAnomaly>();
    public DbSet<RiderAnomalyExplanation> RiderAnomalyExplanations => Set<RiderAnomalyExplanation>();
    public DbSet<RouteComplianceReview> RouteComplianceReviews => Set<RouteComplianceReview>();
    public DbSet<RouteAnomalyStatusEvent> RouteAnomalyStatusEvents => Set<RouteAnomalyStatusEvent>();
    public DbSet<RiderInAppNotification> RiderInAppNotifications => Set<RiderInAppNotification>();
    public DbSet<RecurringSchedule> RecurringSchedules => Set<RecurringSchedule>();
    public DbSet<RecurringScheduleLine> RecurringScheduleLines => Set<RecurringScheduleLine>();
    public DbSet<RecurringScheduleMonthDay> RecurringScheduleMonthDays => Set<RecurringScheduleMonthDay>();
    public DbSet<RecurringScheduleCustomDate> RecurringScheduleCustomDates => Set<RecurringScheduleCustomDate>();
    public DbSet<ScheduleException> ScheduleExceptions => Set<ScheduleException>();
    public DbSet<DeliveryOccurrence> DeliveryOccurrences => Set<DeliveryOccurrence>();
    public DbSet<OccurrenceAssignment> OccurrenceAssignments => Set<OccurrenceAssignment>();
    public DbSet<SchedulePublicationLog> SchedulePublicationLogs => Set<SchedulePublicationLog>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        foreach (var property in builder.Model.GetEntityTypes().SelectMany(type => type.GetProperties()))
        {
            if (property.ClrType == typeof(decimal) || property.ClrType == typeof(decimal?))
            {
                property.SetPrecision(18);
                property.SetScale(2);
            }
        }

        builder.Entity<ApplicationUser>(entity =>
        {
            entity.Property(user => user.FullName).HasMaxLength(120).IsRequired();
            entity.Property(user => user.RiderCode).HasMaxLength(32);
            entity.HasIndex(user => user.RiderCode).IsUnique().HasFilter("[RiderCode] IS NOT NULL");
            entity.HasOne(user => user.Route).WithMany().HasForeignKey(user => user.RouteId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(user => user.Vehicle).WithMany().HasForeignKey(user => user.VehicleId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(user => user.Depot).WithMany().HasForeignKey(user => user.DepotId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(user => user.Zone).WithMany().HasForeignKey(user => user.ZoneId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(user => user.WarehousePerson).WithMany().HasForeignKey(user => user.WarehousePersonUserId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CustomerAccount>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Code).HasMaxLength(32).IsRequired();
            entity.Property(item => item.FirstName).HasMaxLength(60).IsRequired();
            entity.Property(item => item.LastName).HasMaxLength(60).IsRequired();
            entity.Property(item => item.Phone).HasMaxLength(20).IsRequired();
            entity.Property(item => item.Email).HasMaxLength(180).IsRequired();
            entity.Property(item => item.City).HasMaxLength(80).IsRequired();
            entity.Property(item => item.Area).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Street).HasMaxLength(180).IsRequired();
            entity.Property(item => item.HouseNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Landmark).HasMaxLength(160);
            entity.Property(item => item.Instructions).HasMaxLength(300);
            entity.Property(item => item.Latitude).HasPrecision(18, 8);
            entity.Property(item => item.Longitude).HasPrecision(18, 8);
            entity.HasIndex(item => item.UserId).IsUnique();
            entity.HasIndex(item => item.Code).IsUnique();
            entity.HasIndex(item => item.Phone).IsUnique();
            entity.HasIndex(item => item.Email).IsUnique();
            entity.HasOne<ApplicationUser>().WithMany().HasForeignKey(item => item.UserId).OnDelete(DeleteBehavior.Restrict);
            entity.Property(item => item.Status).HasMaxLength(32).IsRequired();
            entity.HasIndex(item => item.DeliveryCustomerId).IsUnique().HasFilter("[DeliveryCustomerId] IS NOT NULL");
            entity.HasOne<Customer>().WithMany().HasForeignKey(item => item.DeliveryCustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CustomerSavedAddress>(entity =>
        {
            entity.Property(item => item.Label).HasMaxLength(40).IsRequired();
            entity.Property(item => item.City).HasMaxLength(80).IsRequired();
            entity.Property(item => item.Area).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Street).HasMaxLength(180).IsRequired();
            entity.Property(item => item.HouseNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Landmark).HasMaxLength(160);
            entity.Property(item => item.Instructions).HasMaxLength(300);
            entity.Property(item => item.Latitude).HasPrecision(18, 8);
            entity.Property(item => item.Longitude).HasPrecision(18, 8);
            entity.HasIndex(item => item.CustomerAccountId);
            entity.HasOne(item => item.Account).WithMany().HasForeignKey(item => item.CustomerAccountId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CustomerServiceRequest>(entity =>
        {
            entity.Property(item => item.Code).HasMaxLength(32).IsRequired();
            entity.Property(item => item.Type).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(40).IsRequired();
            entity.Property(item => item.CurrentSummary).HasMaxLength(500).IsRequired();
            entity.Property(item => item.RequestedSummary).HasMaxLength(500).IsRequired();
            entity.Property(item => item.Reason).HasMaxLength(300).IsRequired();
            entity.Property(item => item.Notes).HasMaxLength(500);
            entity.Property(item => item.Frequency).HasMaxLength(20);
            entity.Property(item => item.MonthDays).HasMaxLength(80);
            entity.Property(item => item.TimeWindow).HasMaxLength(20);
            entity.Property(item => item.AddressLabel).HasMaxLength(40);
            entity.Property(item => item.City).HasMaxLength(80);
            entity.Property(item => item.Area).HasMaxLength(120);
            entity.Property(item => item.Street).HasMaxLength(180);
            entity.Property(item => item.HouseNumber).HasMaxLength(40);
            entity.Property(item => item.Landmark).HasMaxLength(160);
            entity.Property(item => item.Instructions).HasMaxLength(300);
            entity.Property(item => item.AffectedDates).HasMaxLength(1000).IsRequired();
            entity.Property(item => item.AdminComment).HasMaxLength(500);
            entity.Property(item => item.ReviewedBy).HasMaxLength(450);
            entity.HasIndex(item => item.Code).IsUnique();
            entity.HasIndex(item => new { item.CustomerAccountId, item.Status });
            entity.HasOne(item => item.Account).WithMany().HasForeignKey(item => item.CustomerAccountId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CustomerNotification>(entity =>
        {
            entity.Property(item => item.Title).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Body).HasMaxLength(500).IsRequired();
            entity.Property(item => item.Kind).HasMaxLength(40).IsRequired();
            entity.HasIndex(item => new { item.CustomerAccountId, item.CreatedAt });
            entity.HasIndex(item => item.RequestId);
        });

        builder.Entity<AdminRequestNotice>(entity =>
        {
            entity.Property(item => item.Title).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Body).HasMaxLength(300).IsRequired();
            entity.HasIndex(item => item.CreatedAt);
            entity.HasIndex(item => item.RequestId);
        });

        builder.Entity<Depot>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Gate).HasMaxLength(80).IsRequired();
            entity.Property(item => item.Address).HasMaxLength(240).IsRequired();
        });

        builder.Entity<Vehicle>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Plate).HasMaxLength(32).IsRequired();
            entity.Property(item => item.FleetCode).HasMaxLength(32).IsRequired();
            entity.HasIndex(item => item.Plate).IsUnique();
            entity.HasIndex(item => item.FleetCode).IsUnique();
        });

        builder.Entity<Zone>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Sector).HasMaxLength(40).IsRequired();
            entity.Property(item => item.City).HasMaxLength(80).IsRequired();
            entity.HasIndex(item => new { item.Sector, item.City, item.DepotId });
            entity.HasOne(item => item.Depot).WithMany().HasForeignKey(item => item.DepotId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<DeliveryRoute>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Sector).HasMaxLength(40).IsRequired();
            entity.Property(item => item.City).HasMaxLength(80).IsRequired();
            entity.HasOne(item => item.Depot).WithMany().HasForeignKey(item => item.DepotId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.Zone).WithMany().HasForeignKey(item => item.ZoneId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(item => item.ZoneId);
        });

        builder.Entity<Customer>(entity =>
        {
            entity.Property(item => item.Code).HasMaxLength(32).IsRequired();
            entity.Property(item => item.BusinessName).HasMaxLength(160).IsRequired();
            entity.Property(item => item.PrimaryMobile).HasMaxLength(32).IsRequired();
            entity.Property(item => item.AdditionalContact).HasMaxLength(32);
            entity.Property(item => item.Category).HasMaxLength(80).IsRequired();
            entity.Property(item => item.Street).HasMaxLength(240).IsRequired();
            entity.Property(item => item.Area).HasMaxLength(120).IsRequired();
            entity.Property(item => item.City).HasMaxLength(80).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(32).IsRequired();
            entity.Property(item => item.Cnic).HasMaxLength(20);
            entity.Property(item => item.ContactName).HasMaxLength(120);
            entity.Property(item => item.ContactRole).HasMaxLength(80);
            entity.Property(item => item.BottleOwnership).HasConversion<string>().HasMaxLength(24);
            entity.HasIndex(item => item.Code).IsUnique().HasFilter("[IsDeleted] = 0");
            entity.HasIndex(item => item.BusinessName);
            entity.HasIndex(item => item.PrimaryMobile);
            entity.HasIndex(item => new { item.RouteId, item.RouteSortOrder });
            entity.HasOne(item => item.Route).WithMany().HasForeignKey(item => item.RouteId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Product>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Sku).HasMaxLength(40).IsRequired();
            entity.Property(item => item.UnitLabel).HasMaxLength(24).IsRequired();
            entity.HasIndex(item => item.Sku).IsUnique();
        });

        builder.Entity<PriceList>(entity =>
        {
            entity.Property(item => item.Code).HasMaxLength(32).IsRequired();
            entity.Property(item => item.Name).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Description).HasMaxLength(400);
            entity.Property(item => item.Scope).HasMaxLength(16).IsRequired();
            entity.HasIndex(item => item.Code).IsUnique();
            entity.HasOne(item => item.Route).WithMany().HasForeignKey(item => item.RouteId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.Zone).WithMany().HasForeignKey(item => item.ZoneId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<PriceListLine>(entity =>
        {
            entity.HasIndex(item => new { item.PriceListId, item.ProductId }).IsUnique();
            entity.HasOne(item => item.PriceList).WithMany(item => item.Lines).HasForeignKey(item => item.PriceListId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<VehicleStock>(entity =>
        {
            entity.HasIndex(item => new { item.VehicleId, item.ProductId }).IsUnique();
            entity.HasOne(item => item.Vehicle).WithMany().HasForeignKey(item => item.VehicleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Shift>(entity =>
        {
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(16).IsRequired();
            entity.HasIndex(item => new { item.RiderId, item.Status });
        });

        builder.Entity<ShiftStock>(entity =>
        {
            entity.HasOne(item => item.Shift).WithMany(shift => shift.Lines).HasForeignKey(item => item.ShiftId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<RouteStop>(entity =>
        {
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(24);
            entity.HasIndex(item => new { item.CustomerId, item.ServiceDate }).IsUnique();
            entity.HasIndex(item => new { item.RouteId, item.ServiceDate, item.Sequence });
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Sale>(entity =>
        {
            entity.Property(item => item.ReceiptNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.PaymentChannel).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.SyncStatus).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.SignerName).HasMaxLength(120);
            entity.Property(item => item.SignerRole).HasMaxLength(80);
            entity.Property(item => item.SignatureNote).HasMaxLength(200);
            entity.HasIndex(item => item.ReceiptNumber).IsUnique();
            entity.HasIndex(item => new { item.RiderId, item.CreatedAt });
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<SaleLine>(entity =>
        {
            entity.HasOne(item => item.Sale).WithMany(sale => sale.Lines).HasForeignKey(item => item.SaleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<Collection>(entity =>
        {
            entity.Property(item => item.ReferenceNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Channel).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.SyncStatus).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.SignerName).HasMaxLength(120);
            entity.Property(item => item.SignerRole).HasMaxLength(80);
            entity.Property(item => item.SignatureNote).HasMaxLength(200);
            entity.Property(item => item.Notes).HasMaxLength(300);
            entity.Property(item => item.CashStatus).HasMaxLength(32).IsRequired().HasDefaultValue(CashCollectionStatus.CollectedByRider);
            entity.Property(item => item.CashReceivedByUserId).HasMaxLength(450);
            entity.HasIndex(item => item.ReferenceNumber).IsUnique();
            entity.HasIndex(item => item.HandoverId);
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CustomerOrder>(entity =>
        {
            entity.Property(item => item.ReferenceNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Window).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.Notes).HasMaxLength(300);
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.SyncStatus).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.CancelledByUserId).HasMaxLength(450);
            entity.Property(item => item.CancellationReason).HasMaxLength(300);
            entity.Property(item => item.Origin).HasMaxLength(16).IsRequired().HasDefaultValue(OrderOrigin.Hq);
            entity.HasIndex(item => item.ReferenceNumber).IsUnique();
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<OrderLifecycleEvent>(entity =>
        {
            entity.Property(item => item.EventCode).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Title).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Detail).HasMaxLength(500);
            entity.Property(item => item.ActorUserId).HasMaxLength(450);
            entity.HasIndex(item => new { item.OrderId, item.OccurredAtUtc });
            entity.HasOne(item => item.Order).WithMany(order => order.Lifecycle).HasForeignKey(item => item.OrderId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<OrderLine>(entity =>
        {
            entity.HasOne(item => item.Order).WithMany(order => order.Lines).HasForeignKey(item => item.OrderId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<LedgerEntry>(entity =>
        {
            entity.Property(item => item.Kind).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.Description).HasMaxLength(240).IsRequired();
            entity.Property(item => item.Reference).HasMaxLength(40);
            entity.HasIndex(item => new { item.CustomerId, item.OccurredAt });
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<ActivityLog>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Title).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Reference).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Detail).HasMaxLength(240).IsRequired();
            entity.Property(item => item.SyncStatus).HasConversion<string>().HasMaxLength(24);
            entity.HasIndex(item => new { item.UserId, item.OccurredAt });
        });

        builder.Entity<AuditLog>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Action).HasMaxLength(80).IsRequired();
            entity.Property(item => item.EntityName).HasMaxLength(80).IsRequired();
            entity.Property(item => item.EntityId).HasMaxLength(64).IsRequired();
            entity.HasIndex(item => item.OccurredAt);
        });

        builder.Entity<RiderSettings>(entity =>
        {
            entity.HasKey(item => item.UserId);
            entity.Property(item => item.UserId).HasMaxLength(450);
            entity.Property(item => item.Language).HasMaxLength(40).IsRequired();
            entity.Property(item => item.PaperSize).HasMaxLength(24).IsRequired();
        });

        builder.Entity<PrinterDevice>(entity =>
        {
            entity.Property(item => item.Name).HasMaxLength(120).IsRequired();
            entity.Property(item => item.Meta).HasMaxLength(160).IsRequired();
        });

        builder.Entity<PrintJob>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.PrinterName).HasMaxLength(120);
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
        });

        builder.Entity<NumberSequence>(entity =>
        {
            entity.HasKey(item => item.Name);
            entity.Property(item => item.Name).HasMaxLength(40);
        });

        builder.Entity<RefreshToken>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.TokenHash).HasMaxLength(128).IsRequired();
            entity.Property(item => item.ReplacedByHash).HasMaxLength(128);
            entity.Property(item => item.DeviceInformation).HasMaxLength(512);
            entity.Property(item => item.RememberMe).HasDefaultValue(false);
            entity.HasIndex(item => item.TokenHash).IsUnique();
            entity.HasIndex(item => item.UserId);
        });

        builder.Entity<BusinessProfile>(entity =>
        {
            entity.Property(item => item.LegalName).HasMaxLength(200).IsRequired();
            entity.Property(item => item.DisplayName).HasMaxLength(200).IsRequired();
            entity.Property(item => item.TaxNumber).HasMaxLength(64);
            entity.Property(item => item.RegistrationNumber).HasMaxLength(64);
            entity.Property(item => item.Status).HasMaxLength(40).IsRequired();
            entity.Property(item => item.SupportEmail).HasMaxLength(180).IsRequired().HasDefaultValue("");
            entity.Property(item => item.SupportPhone).HasMaxLength(40).IsRequired().HasDefaultValue("");
            entity.Property(item => item.SupportAddress).HasMaxLength(300).IsRequired().HasDefaultValue("");
            entity.Property(item => item.Website).HasMaxLength(180).IsRequired().HasDefaultValue("");
            entity.Property(item => item.ReceiptFooter).HasMaxLength(300).IsRequired().HasDefaultValue("");
        });

        builder.Entity<CustomerLinkReview>(entity =>
        {
            entity.Property(item => item.MatchBasis).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.RequestedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.ReviewedByUserId).HasMaxLength(450);
            entity.Property(item => item.Comment).HasMaxLength(500);
            entity.HasIndex(item => item.CustomerAccountId);
            entity.HasIndex(item => item.DeliveryCustomerId);
            entity.HasOne(item => item.Account).WithMany().HasForeignKey(item => item.CustomerAccountId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<CashHandover>(entity =>
        {
            entity.Property(item => item.ReferenceNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.SubmittedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.ReceivedByUserId).HasMaxLength(450);
            entity.Property(item => item.Note).HasMaxLength(300);
            entity.HasIndex(item => item.ReferenceNumber).IsUnique();
            entity.HasIndex(item => new { item.RiderId, item.BusinessDate });
        });

        builder.Entity<PriceListAssignment>(entity =>
        {
            entity.HasIndex(item => item.CustomerId).IsUnique();
            entity.HasIndex(item => item.PriceListId);
            entity.HasOne(item => item.PriceList).WithMany().HasForeignKey(item => item.PriceListId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<WarehouseStock>(entity =>
        {
            entity.HasIndex(item => new { item.DepotId, item.ProductId }).IsUnique();
            entity.HasOne(item => item.Depot).WithMany().HasForeignKey(item => item.DepotId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<InventoryCountLine>(entity =>
        {
            entity.Property(item => item.CountedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Note).HasMaxLength(300);
            entity.HasIndex(item => new { item.DepotId, item.ProductId });
        });

        builder.Entity<SettlementSession>(entity =>
        {
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(32).IsRequired();
            entity.Property(item => item.RiderAnnotation).HasMaxLength(500);
            entity.Property(item => item.DraftResolutionCategory).HasMaxLength(64);
            entity.Property(item => item.DraftRemarks).HasMaxLength(1000);
            entity.Property(item => item.ResolutionCategory).HasMaxLength(64);
            entity.Property(item => item.ResolutionRemarks).HasMaxLength(1000);
            entity.Property(item => item.ApprovedByUserId).HasMaxLength(450);
            entity.Property(item => item.RowVersion).IsRowVersion();
            entity.HasIndex(item => new { item.BusinessDate, item.RiderId }).IsUnique();
            entity.HasIndex(item => new { item.BusinessDate, item.Status });
            entity.HasMany(item => item.Declarations).WithOne(item => item.Session).HasForeignKey(item => item.SettlementSessionId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Verifications).WithOne(item => item.Session).HasForeignKey(item => item.SettlementSessionId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<CashDeclaration>(entity =>
        {
            entity.Property(item => item.Source).HasMaxLength(32).IsRequired();
            entity.Property(item => item.SubmittedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Note).HasMaxLength(500);
            entity.HasIndex(item => item.SettlementSessionId);
        });

        builder.Entity<PhysicalCashVerification>(entity =>
        {
            entity.Property(item => item.BatchReference).HasMaxLength(40);
            entity.Property(item => item.VerifiedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Notes).HasMaxLength(500);
            entity.HasIndex(item => item.SettlementSessionId);
        });

        builder.Entity<DayLock>(entity =>
        {
            entity.Property(item => item.LockedByUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.AcknowledgementNote).HasMaxLength(500);
            entity.HasIndex(item => item.BusinessDate).IsUnique();
        });

        builder.Entity<SettlementAuditEvent>(entity =>
        {
            entity.Property(item => item.EventCode).HasMaxLength(64).IsRequired();
            entity.Property(item => item.Title).HasMaxLength(200).IsRequired();
            entity.Property(item => item.Detail).HasMaxLength(1000);
            entity.Property(item => item.ActorUserId).HasMaxLength(450);
            entity.Property(item => item.RelatedEntityName).HasMaxLength(80);
            entity.Property(item => item.RelatedEntityId).HasMaxLength(64);
            entity.HasIndex(item => new { item.BusinessDate, item.OccurredAtUtc });
            entity.HasIndex(item => item.SettlementSessionId);
        });

        builder.Entity<OnboardingStepRecord>(entity =>
        {
            entity.ToTable("OnboardingStepRecords");
            entity.Property(item => item.StepCode).HasConversion<string>().HasMaxLength(40);
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(32);
            entity.Property(item => item.ValidationNotes).HasMaxLength(500);
            entity.HasIndex(item => new { item.BusinessProfileId, item.StepCode }).IsUnique();
            entity.HasOne<BusinessProfile>().WithMany().HasForeignKey(item => item.BusinessProfileId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<PasswordResetRequest>(entity =>
        {
            entity.Property(item => item.UserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(24);
            entity.HasIndex(item => item.UserId);
        });

        builder.Entity<CommunicationTemplate>(entity =>
        {
            entity.Property(item => item.TemplateCode).HasMaxLength(32).IsRequired();
            entity.Property(item => item.Name).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Language).HasMaxLength(16).IsRequired();
            entity.Property(item => item.TriggerType).HasMaxLength(64).IsRequired();
            entity.Property(item => item.Content).HasMaxLength(1000).IsRequired();
            entity.Property(item => item.UpdatedByUserId).HasMaxLength(450);
            entity.HasIndex(item => item.TemplateCode).IsUnique();
            entity.HasIndex(item => new { item.TriggerType, item.Language, item.IsActive });
        });

        builder.Entity<CommunicationMessage>(entity =>
        {
            entity.Property(item => item.MessageReference).HasMaxLength(40).IsRequired();
            entity.Property(item => item.DestinationNumber).HasMaxLength(32).IsRequired();
            entity.Property(item => item.TriggerType).HasMaxLength(64).IsRequired();
            entity.Property(item => item.TransactionReference).HasMaxLength(64);
            entity.Property(item => item.RenderedContent).HasMaxLength(1000).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(32).IsRequired();
            entity.Property(item => item.FailureReason).HasMaxLength(500);
            entity.Property(item => item.IdempotencyKey).HasMaxLength(120);
            entity.HasIndex(item => item.MessageReference).IsUnique();
            entity.HasIndex(item => item.IdempotencyKey).IsUnique();
            entity.HasIndex(item => new { item.CreatedAtUtc, item.Id });
            entity.HasIndex(item => item.Status);
            entity.HasOne(item => item.Template).WithMany().HasForeignKey(item => item.TemplateId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<TrackingSession>(entity =>
        {
            entity.Property(item => item.RiderUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.EndReason).HasMaxLength(120);
            entity.HasIndex(item => new { item.RiderUserId, item.Status });
            entity.HasIndex(item => item.ShiftId);
            entity.HasMany(item => item.Locations).WithOne(item => item.TrackingSession)
                .HasForeignKey(item => item.TrackingSessionId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<RiderLocationTelemetry>(entity =>
        {
            entity.Property(item => item.RiderUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.NetworkStatus).HasMaxLength(40);
            entity.Property(item => item.RejectReason).HasMaxLength(160);
            entity.Property(item => item.Latitude).HasPrecision(18, 8);
            entity.Property(item => item.Longitude).HasPrecision(18, 8);
            entity.Property(item => item.AccuracyMeters).HasPrecision(18, 2);
            entity.Property(item => item.SpeedMetersPerSecond).HasPrecision(18, 3);
            entity.Property(item => item.HeadingDegrees).HasPrecision(18, 2);
            entity.HasIndex(item => new { item.RiderUserId, item.DeviceTimestampUtc });
            entity.HasIndex(item => new { item.TrackingSessionId, item.DeviceTimestampUtc });
            entity.HasIndex(item => new { item.TrackingSessionId, item.DeviceTimestampUtc, item.Latitude, item.Longitude })
                .IsUnique()
                .HasFilter("[Rejected] = 0");
        });

        builder.Entity<RouteComplianceAnomaly>(entity =>
        {
            entity.Property(item => item.AnomalyNumber).HasMaxLength(40).IsRequired();
            entity.Property(item => item.RiderUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Category).HasConversion<string>().HasMaxLength(40);
            entity.Property(item => item.Severity).HasConversion<string>().HasMaxLength(24);
            entity.Property(item => item.Status).HasConversion<string>().HasMaxLength(40);
            entity.Property(item => item.ExpectedWaypoint).HasMaxLength(200);
            entity.Property(item => item.EvidenceJson).HasMaxLength(4000).IsRequired();
            entity.Property(item => item.ResolutionNotes).HasMaxLength(1000);
            entity.Property(item => item.LastLatitude).HasPrecision(18, 8);
            entity.Property(item => item.LastLongitude).HasPrecision(18, 8);
            entity.Property(item => item.ActualHeadingDegrees).HasPrecision(18, 2);
            entity.Property(item => item.ExpectedHeadingDegrees).HasPrecision(18, 2);
            entity.HasIndex(item => item.AnomalyNumber).IsUnique();
            entity.HasIndex(item => new { item.Status, item.DetectedAtUtc });
            entity.HasIndex(item => new { item.RiderUserId, item.DetectedAtUtc });
            entity.HasOne(item => item.TrackingSession).WithMany().HasForeignKey(item => item.TrackingSessionId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(item => item.Explanations).WithOne(item => item.Anomaly)
                .HasForeignKey(item => item.AnomalyId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Reviews).WithOne(item => item.Anomaly)
                .HasForeignKey(item => item.AnomalyId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.StatusHistory).WithOne(item => item.Anomaly)
                .HasForeignKey(item => item.AnomalyId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<RiderAnomalyExplanation>(entity =>
        {
            entity.Property(item => item.RiderUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Reason).HasConversion<string>().HasMaxLength(64);
            entity.Property(item => item.ExplanationText).HasMaxLength(1000).IsRequired();
            entity.Property(item => item.SupportingNote).HasMaxLength(1000);
            entity.HasIndex(item => new { item.AnomalyId, item.SubmittedAtUtc });
        });

        builder.Entity<RouteComplianceReview>(entity =>
        {
            entity.Property(item => item.AdminUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Action).HasMaxLength(40).IsRequired();
            entity.Property(item => item.Notes).HasMaxLength(1000);
            entity.HasIndex(item => new { item.AnomalyId, item.OccurredAtUtc });
        });

        builder.Entity<RouteAnomalyStatusEvent>(entity =>
        {
            entity.Property(item => item.FromStatus).HasConversion<string>().HasMaxLength(40);
            entity.Property(item => item.ToStatus).HasConversion<string>().HasMaxLength(40);
            entity.Property(item => item.ActorUserId).HasMaxLength(450);
            entity.Property(item => item.Note).HasMaxLength(500);
            entity.HasIndex(item => new { item.AnomalyId, item.OccurredAtUtc });
        });

        builder.Entity<RoleProfile>(entity =>
        {
            entity.HasKey(item => item.RoleName);
            entity.Property(item => item.RoleName).HasMaxLength(64);
            entity.Property(item => item.Description).HasMaxLength(240).IsRequired();
        });

        builder.Entity<RoleScreenGrant>(entity =>
        {
            entity.Property(item => item.RoleName).HasMaxLength(64).IsRequired();
            entity.Property(item => item.ScreenKey).HasMaxLength(64).IsRequired();
            entity.HasIndex(item => new { item.RoleName, item.ScreenKey }).IsUnique();
        });

        builder.Entity<RecurringSchedule>(entity =>
        {
            entity.Property(item => item.ScheduleCode).HasMaxLength(40).IsRequired();
            entity.Property(item => item.DefaultRiderId).HasMaxLength(450);
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.Frequency).HasMaxLength(24).IsRequired();
            entity.Property(item => item.TimeWindow).HasMaxLength(24).IsRequired();
            entity.Property(item => item.TimeZoneId).HasMaxLength(64).IsRequired();
            entity.Property(item => item.AssignmentMode).HasMaxLength(24).IsRequired();
            entity.Property(item => item.Instructions).HasMaxLength(500);
            entity.Property(item => item.DeliveryCity).HasMaxLength(80);
            entity.Property(item => item.DeliveryArea).HasMaxLength(120);
            entity.Property(item => item.DeliveryStreet).HasMaxLength(240);
            entity.Property(item => item.CreatedBy).HasMaxLength(450).IsRequired();
            entity.HasIndex(item => item.ScheduleCode).IsUnique();
            entity.HasIndex(item => new { item.CustomerId, item.Status });
            entity.HasOne(item => item.Customer).WithMany().HasForeignKey(item => item.CustomerId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(item => item.Depot).WithMany().HasForeignKey(item => item.DepotId).OnDelete(DeleteBehavior.Restrict);
            entity.HasMany(item => item.Lines).WithOne(item => item.Schedule).HasForeignKey(item => item.ScheduleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.MonthDays).WithOne(item => item.Schedule).HasForeignKey(item => item.ScheduleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.CustomDates).WithOne(item => item.Schedule).HasForeignKey(item => item.ScheduleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Exceptions).WithOne(item => item.Schedule).HasForeignKey(item => item.ScheduleId).OnDelete(DeleteBehavior.Cascade);
            entity.HasMany(item => item.Occurrences).WithOne(item => item.Schedule).HasForeignKey(item => item.ScheduleId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<RecurringScheduleLine>(entity =>
        {
            entity.HasIndex(item => new { item.ScheduleId, item.ProductId }).IsUnique();
            entity.HasOne(item => item.Product).WithMany().HasForeignKey(item => item.ProductId).OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<RecurringScheduleMonthDay>(entity =>
        {
            entity.HasIndex(item => new { item.ScheduleId, item.Day }).IsUnique();
        });

        builder.Entity<RecurringScheduleCustomDate>(entity =>
        {
            entity.HasIndex(item => new { item.ScheduleId, item.ServiceDate }).IsUnique();
        });

        builder.Entity<ScheduleException>(entity =>
        {
            entity.Property(item => item.ExceptionType).HasMaxLength(24).IsRequired();
            entity.Property(item => item.Reason).HasMaxLength(300).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.CreatedBy).HasMaxLength(450).IsRequired();
            entity.HasIndex(item => new { item.ScheduleId, item.Status });
        });

        builder.Entity<DeliveryOccurrence>(entity =>
        {
            entity.Property(item => item.AssignedRiderId).HasMaxLength(450);
            entity.Property(item => item.TimeWindow).HasMaxLength(24).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.FailureReason).HasMaxLength(300);
            entity.Property(item => item.AddressSnapshot).HasMaxLength(300);
            entity.HasIndex(item => new { item.ScheduleId, item.ServiceDate }).IsUnique();
            entity.HasIndex(item => new { item.ServiceDate, item.Status });
        });

        builder.Entity<OccurrenceAssignment>(entity =>
        {
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.PreviousRiderId).HasMaxLength(450);
            entity.Property(item => item.AssignedBy).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Reason).HasMaxLength(300).IsRequired();
            entity.HasIndex(item => new { item.OccurrenceId, item.AssignedAt });
            entity.HasOne(item => item.Occurrence).WithMany().HasForeignKey(item => item.OccurrenceId).OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<SchedulePublicationLog>(entity =>
        {
            entity.Property(item => item.RiderId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Status).HasMaxLength(24).IsRequired();
            entity.Property(item => item.FailureReason).HasMaxLength(300);
            entity.HasIndex(item => item.OccurrenceId);
        });

        builder.Entity<RiderInAppNotification>(entity =>
        {
            entity.Property(item => item.RiderUserId).HasMaxLength(450).IsRequired();
            entity.Property(item => item.Title).HasMaxLength(160).IsRequired();
            entity.Property(item => item.Body).HasMaxLength(500).IsRequired();
            entity.Property(item => item.DeepLink).HasMaxLength(80).IsRequired();
            entity.Property(item => item.IdempotencyKey).HasMaxLength(120).IsRequired();
            entity.HasIndex(item => item.IdempotencyKey).IsUnique();
            entity.HasIndex(item => new { item.RiderUserId, item.CreatedAtUtc });
        });
    }
}
