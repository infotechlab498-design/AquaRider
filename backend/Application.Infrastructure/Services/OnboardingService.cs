using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class OnboardingService : IOnboardingService
{
    private static readonly OnboardingStepCode[] StepOrder = Enum.GetValues<OnboardingStepCode>();

    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _users;
    private readonly ICurrentUser _current;

    public OnboardingService(AppDbContext db, UserManager<ApplicationUser> users, ICurrentUser current)
    {
        _db = db;
        _users = users;
        _current = current;
    }

    public async Task<ServiceResult<OnboardingOverviewDto>> OverviewAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        var steps = MapSteps(snapshot);
        var next = steps.FirstOrDefault(step => step.Status != OnboardingStepStatus.Completed);
        var completed = steps.Count(step => step.Status == OnboardingStepStatus.Completed);
        return ServiceResult<OnboardingOverviewDto>.Ok(new OnboardingOverviewDto(
            MapProfile(snapshot.Profile),
            completed,
            StepOrder.Length,
            Percent(completed),
            completed == StepOrder.Length,
            next,
            steps,
            snapshot.Facility,
            Support()), "Onboarding overview loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<OnboardingStepDto>>> StepsAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<OnboardingStepDto>>.Ok(MapSteps(snapshot), "Onboarding steps loaded.");
    }

    public async Task<ServiceResult<OnboardingStepDto>> StepAsync(string stepCode, CancellationToken cancellationToken)
    {
        if (!TryParse(stepCode, out var code))
        {
            return ServiceResult<OnboardingStepDto>.Fail(404, "That onboarding step does not exist.");
        }

        var snapshot = await RecomputeAsync(cancellationToken);
        return ServiceResult<OnboardingStepDto>.Ok(MapStep(snapshot, code), "Onboarding step loaded.");
    }

    public async Task<ServiceResult<OnboardingProgressDto>> ProgressAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        var completed = snapshot.Records.Count(record => record.Status == OnboardingStepStatus.Completed);
        return ServiceResult<OnboardingProgressDto>.Ok(
            new OnboardingProgressDto(completed, StepOrder.Length, Percent(completed)),
            "Onboarding progress loaded.");
    }

    public async Task<ServiceResult<OnboardingValidationDto>> ValidateAsync(string stepCode, CancellationToken cancellationToken)
    {
        if (!TryParse(stepCode, out var code))
        {
            return ServiceResult<OnboardingValidationDto>.Fail(404, "That onboarding step does not exist.");
        }

        var snapshot = await RecomputeAsync(cancellationToken);
        var step = MapStep(snapshot, code);
        var passed = step.Status == OnboardingStepStatus.Completed;
        return ServiceResult<OnboardingValidationDto>.Ok(
            new OnboardingValidationDto(step, passed, step.ValidationNotes ?? ""),
            passed ? "The step checks out." : "The step is not complete yet.");
    }

    public async Task<ServiceResult<OnboardingValidationDto>> CompleteAsync(string stepCode, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<OnboardingValidationDto>.Fail(401, "Sign in required.");
        }

        if (!TryParse(stepCode, out var code))
        {
            return ServiceResult<OnboardingValidationDto>.Fail(404, "That onboarding step does not exist.");
        }

        var snapshot = await RecomputeAsync(cancellationToken);
        var record = snapshot.Records.Single(item => item.StepCode == code);
        if (record.Status != OnboardingStepStatus.Completed)
        {
            return ServiceResult<OnboardingValidationDto>.Fail(400, record.ValidationNotes ?? "The step is not complete yet.");
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = "OnboardingComplete",
            EntityName = "OnboardingStep",
            EntityId = code.ToString()
        });
        await _db.SaveChangesAsync(cancellationToken);
        var step = MapStep(snapshot, code);
        return ServiceResult<OnboardingValidationDto>.Ok(
            new OnboardingValidationDto(step, true, step.ValidationNotes ?? ""),
            "Step completed.");
    }

    public async Task<ServiceResult<OnboardingNextStepDto>> NextStepAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        var steps = MapSteps(snapshot);
        var next = steps.FirstOrDefault(step => step.Status != OnboardingStepStatus.Completed);
        var done = next is null;
        return ServiceResult<OnboardingNextStepDto>.Ok(
            new OnboardingNextStepDto(done, next),
            done ? "Setup is complete." : "Next onboarding step loaded.");
    }

    public async Task<ServiceResult<OnboardingReadinessDto>> ReadinessAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        var blocking = snapshot.Records
            .Where(record => record.Status != OnboardingStepStatus.Completed)
            .Select(record => record.StepCode)
            .ToArray();
        var completed = StepOrder.Length - blocking.Length;
        return ServiceResult<OnboardingReadinessDto>.Ok(
            new OnboardingReadinessDto(blocking.Length == 0, completed, StepOrder.Length, blocking),
            blocking.Length == 0 ? "The business is ready." : "Setup is still in progress.");
    }

    public async Task<ServiceResult<IReadOnlyList<OnboardingActivityDto>>> ActivityAsync(CancellationToken cancellationToken)
    {
        var snapshot = await RecomputeAsync(cancellationToken);
        var audits = await _db.AuditLogs
            .Where(log => log.EntityName == "OnboardingStep" || log.EntityName == "BusinessProfile")
            .OrderByDescending(log => log.OccurredAt)
            .Take(30)
            .ToListAsync(cancellationToken);

        IReadOnlyList<OnboardingActivityDto> activity = audits.Count == 0
            ? snapshot.Records
                .Where(record => record.CompletedAtUtc is not null)
                .OrderByDescending(record => record.CompletedAtUtc)
                .Select(record => new OnboardingActivityDto(
                    "StepSatisfied",
                    Title(record.StepCode),
                    record.CompletedAtUtc!.Value,
                    null))
                .ToArray()
            : audits.Select(log => new OnboardingActivityDto(
                log.Action,
                log.EntityId,
                log.OccurredAt,
                log.UserId)).ToArray();

        return ServiceResult<IReadOnlyList<OnboardingActivityDto>>.Ok(activity, "Onboarding activity loaded.");
    }

    private async Task<Snapshot> RecomputeAsync(CancellationToken cancellationToken)
    {
        var profile = await EnsureProfileAsync(cancellationToken);
        var records = await _db.OnboardingSteps
            .Where(step => step.BusinessProfileId == profile.Id)
            .ToListAsync(cancellationToken);

        foreach (var code in StepOrder)
        {
            if (records.All(step => step.StepCode != code))
            {
                var created = new OnboardingStepRecord
                {
                    BusinessProfileId = profile.Id,
                    StepCode = code,
                    Status = OnboardingStepStatus.NotStarted
                };
                _db.OnboardingSteps.Add(created);
                records.Add(created);
            }
        }

        var evaluation = await EvaluateAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var record in records)
        {
            var result = evaluation[record.StepCode];
            var wasComplete = record.Status == OnboardingStepStatus.Completed && record.CompletedAtUtc is not null;
            record.Status = result.Status;
            record.ValidationNotes = result.Notes;
            if (result.Status == OnboardingStepStatus.Completed)
            {
                record.CompletedAtUtc ??= now;
            }
            else if (wasComplete || record.CompletedAtUtc is not null)
            {
                record.CompletedAtUtc = null;
            }
        }

        var completed = records.Count(record => record.Status == OnboardingStepStatus.Completed);
        profile.Status = completed == StepOrder.Length ? "Ready" : "SetupInProgress";
        await _db.SaveChangesAsync(cancellationToken);
        return new Snapshot(profile, records, evaluation.Facility);
    }

    private async Task<BusinessProfile> EnsureProfileAsync(CancellationToken cancellationToken)
    {
        var profile = await _db.BusinessProfiles.OrderBy(item => item.CreatedAtUtc).FirstOrDefaultAsync(cancellationToken);
        if (profile is not null)
        {
            return profile;
        }

        var depot = await _db.Depots.OrderBy(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        var name = string.IsNullOrWhiteSpace(depot?.Name) ? "RouteLedger" : depot!.Name.Trim();
        profile = new BusinessProfile
        {
            LegalName = name,
            DisplayName = name,
            Status = "SetupInProgress"
        };
        _db.BusinessProfiles.Add(profile);
        await _db.SaveChangesAsync(cancellationToken);
        return profile;
    }

    private async Task<Evaluation> EvaluateAsync(CancellationToken cancellationToken)
    {
        var depots = await _db.Depots
            .Select(depot => new { depot.Name, depot.Address })
            .ToListAsync(cancellationToken);
        var plant = depots.Any(depot => !string.IsNullOrWhiteSpace(depot.Name) && !string.IsNullOrWhiteSpace(depot.Address));
        var plantPartial = depots.Count > 0 && !plant;

        var products = await _db.Products.CountAsync(cancellationToken);
        var sellable = await _db.Products.CountAsync(product => product.ShowOnSale, cancellationToken);
        var customers = await _db.Customers.CountAsync(customer => !customer.IsDeleted, cancellationToken);
        var deletedCustomers = await _db.Customers.CountAsync(customer => customer.IsDeleted, cancellationToken);
        var zones = await _db.DeliveryRoutes.CountAsync(cancellationToken);
        var stocks = await _db.VehicleStocks.CountAsync(cancellationToken);
        var sales = await _db.Sales.CountAsync(cancellationToken);
        var syncedSales = await _db.Sales.CountAsync(
            sale => sale.Status == SaleStatus.Completed && sale.SyncStatus == SyncStatus.Synced,
            cancellationToken);
        var riders = await _users.GetUsersInRoleAsync(AppRoles.Rider);
        var activeRiders = riders.Count(user => user.IsActive);

        var primary = await _db.Depots.OrderBy(depot => depot.Name).FirstOrDefaultAsync(cancellationToken);
        var facility = new OnboardingFacilityDto(
            primary?.Name,
            primary?.Address,
            sellable,
            customers,
            zones,
            activeRiders,
            stocks,
            syncedSales);

        var results = new Dictionary<OnboardingStepCode, StepResult>
        {
            [OnboardingStepCode.PlantDetails] = new(
                plant ? OnboardingStepStatus.Completed : plantPartial ? OnboardingStepStatus.InProgress : OnboardingStepStatus.NotStarted,
                plant ? "A depot with a name and address is on file." : "Add a depot with a name and address."),
            [OnboardingStepCode.ItemsAndOpenings] = new(
                sellable > 0 ? OnboardingStepStatus.Completed : products > 0 ? OnboardingStepStatus.InProgress : OnboardingStepStatus.NotStarted,
                sellable > 0 ? "A sellable product is on file." : "Add a product that is shown on sale."),
            [OnboardingStepCode.Customers] = new(
                customers > 0 ? OnboardingStepStatus.Completed : deletedCustomers > 0 ? OnboardingStepStatus.InProgress : OnboardingStepStatus.NotStarted,
                customers > 0 ? "An active customer is on file." : "Add a customer."),
            [OnboardingStepCode.Zones] = new(
                zones > 0 ? OnboardingStepStatus.Completed : OnboardingStepStatus.NotStarted,
                zones > 0 ? "A delivery zone is on file." : "Add a delivery route."),
            [OnboardingStepCode.RiderAndLoad] = RiderStep(activeRiders, stocks),
            [OnboardingStepCode.FirstSyncedSale] = new(
                syncedSales > 0 ? OnboardingStepStatus.Completed : sales > 0 ? OnboardingStepStatus.InProgress : OnboardingStepStatus.NotStarted,
                syncedSales > 0 ? "A completed, synced sale is on file." : "Record a completed sale that has synced.")
        };

        return new Evaluation(results, facility);
    }

    private static StepResult RiderStep(int activeRiders, int stocks)
    {
        if (activeRiders > 0 && stocks > 0)
        {
            return new StepResult(OnboardingStepStatus.Completed, "An active rider and vehicle stock are on file.");
        }

        if (activeRiders > 0)
        {
            return new StepResult(OnboardingStepStatus.InProgress, "Add vehicle stock for the rider load.");
        }

        if (stocks > 0)
        {
            return new StepResult(OnboardingStepStatus.InProgress, "Add an active user in the Rider role.");
        }

        return new StepResult(OnboardingStepStatus.NotStarted, "Add an active rider and vehicle stock.");
    }

    private static List<OnboardingStepDto> MapSteps(Snapshot snapshot) =>
        StepOrder.Select(code => MapStep(snapshot, code)).ToList();

    private static OnboardingStepDto MapStep(Snapshot snapshot, OnboardingStepCode code)
    {
        var record = snapshot.Records.Single(item => item.StepCode == code);
        return new OnboardingStepDto(
            code,
            Title(code),
            Array.IndexOf(StepOrder, code) + 1,
            record.Status,
            record.CompletedAtUtc,
            record.ValidationNotes);
    }

    private static BusinessProfileDto MapProfile(BusinessProfile profile) =>
        new(profile.Id, profile.LegalName, profile.DisplayName, profile.TaxNumber, profile.RegistrationNumber, profile.Status);

    private static OnboardingSupportDto Support() =>
        new(false, false, "Support chat and scheduling are not configured.");

    private static int Percent(int completed) =>
        StepOrder.Length == 0 ? 0 : completed * 100 / StepOrder.Length;

    private static bool TryParse(string? value, out OnboardingStepCode code) =>
        Enum.TryParse(value, ignoreCase: true, out code) && Enum.IsDefined(code);

    private static string Title(OnboardingStepCode code) => code switch
    {
        OnboardingStepCode.PlantDetails => "Plant Details",
        OnboardingStepCode.ItemsAndOpenings => "Items & Openings",
        OnboardingStepCode.Customers => "Customers",
        OnboardingStepCode.Zones => "Zones",
        OnboardingStepCode.RiderAndLoad => "Rider & Load",
        OnboardingStepCode.FirstSyncedSale => "First Synced Sale",
        _ => code.ToString()
    };

    private sealed record StepResult(OnboardingStepStatus Status, string Notes);

    private sealed class Evaluation
    {
        public Evaluation(Dictionary<OnboardingStepCode, StepResult> steps, OnboardingFacilityDto facility)
        {
            Steps = steps;
            Facility = facility;
        }

        public Dictionary<OnboardingStepCode, StepResult> Steps { get; }
        public OnboardingFacilityDto Facility { get; }

        public StepResult this[OnboardingStepCode code] => Steps[code];
    }

    private sealed record Snapshot(
        BusinessProfile Profile,
        List<OnboardingStepRecord> Records,
        OnboardingFacilityDto Facility);
}
