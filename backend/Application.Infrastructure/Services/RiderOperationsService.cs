using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class RiderOperationsService : IRiderOperationsService
{
    /// <summary>
    /// An open shift with stops on the route and zero completed stops becomes attention after this long.
    /// </summary>
    public static readonly TimeSpan OpenShiftIdleThreshold = TimeSpan.FromHours(2);

    private readonly AppDbContext _db;

    public RiderOperationsService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<ServiceResult<RiderOpsSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var roster = await LoadRosterAsync(day, cancellationToken);
        var inProgress = await _db.RouteStops.AsNoTracking()
            .CountAsync(stop => stop.ServiceDate == day && stop.Status == StopStatus.InProgress, cancellationToken);
        var dto = new RiderOpsSummaryDto(
            day,
            roster.Count,
            roster.Count(rider => rider.Status == "available"),
            roster.Count(rider => rider.Status is "onDuty" or "attention"),
            inProgress,
            roster.Count(rider => rider.Status is "attention" or "inactive"));
        return ServiceResult<RiderOpsSummaryDto>.Ok(dto, "Rider operations summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RiderOpsCardDto>>> RidersAsync(string? search, string? status, DateOnly? date, CancellationToken cancellationToken)
    {
        if (!TryStatus(status, out var filter, out var error))
        {
            return ServiceResult<IReadOnlyList<RiderOpsCardDto>>.Fail(400, error!);
        }

        var day = date ?? ReportingWindow.Today();
        var roster = await LoadRosterAsync(day, cancellationToken);
        IEnumerable<RiderFacts> rows = roster;
        if (filter is not null)
        {
            rows = rows.Where(rider => rider.Status == filter);
        }

        var term = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        if (term is not null)
        {
            rows = rows.Where(rider =>
                Contains(rider.User.FullName, term)
                || Contains(rider.User.RiderCode, term)
                || Contains(rider.User.Vehicle?.Name, term)
                || Contains(rider.User.Vehicle?.Plate, term)
                || Contains(rider.User.Route?.Name, term));
        }

        IReadOnlyList<RiderOpsCardDto> cards = rows.Select(ToCard).ToList();
        var message = cards.Count == 0 ? "No riders match." : "Riders loaded.";
        return ServiceResult<IReadOnlyList<RiderOpsCardDto>>.Ok(cards, message);
    }

    public async Task<ServiceResult<RiderOpsCardDto>> RiderAsync(string id, DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var roster = await LoadRosterAsync(day, cancellationToken);
        var rider = roster.FirstOrDefault(item => item.User.Id == id);
        if (rider is null)
        {
            return ServiceResult<RiderOpsCardDto>.Fail(404, "Rider not found.");
        }

        return ServiceResult<RiderOpsCardDto>.Ok(ToCard(rider), "Rider loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RiderActivityDto>>> ActivityAsync(string id, CancellationToken cancellationToken)
    {
        if (await FindRiderAsync(id, cancellationToken) is null)
        {
            return ServiceResult<IReadOnlyList<RiderActivityDto>>.Fail(404, "Rider not found.");
        }

        var rows = await _db.ActivityLogs.AsNoTracking()
            .Where(log => log.UserId == id)
            .OrderByDescending(log => log.OccurredAt)
            .Take(100)
            .Select(log => new
            {
                log.Id,
                log.Title,
                log.Reference,
                log.Amount,
                log.SyncStatus,
                log.Detail,
                log.OccurredAt
            })
            .ToListAsync(cancellationToken);
        IReadOnlyList<RiderActivityDto> activity = rows
            .Select(log => new RiderActivityDto(
                log.Id,
                log.Title,
                log.Reference,
                log.Amount,
                ReportingWindow.Sync(log.SyncStatus),
                log.Detail,
                log.OccurredAt))
            .ToList();
        var message = activity.Count == 0 ? "No activity is stored for this rider." : "Rider activity loaded.";
        return ServiceResult<IReadOnlyList<RiderActivityDto>>.Ok(activity, message);
    }

    public async Task<ServiceResult<IReadOnlyList<RiderAssignmentDto>>> AssignmentsAsync(string id, DateOnly? date, CancellationToken cancellationToken)
    {
        var rider = await FindRiderAsync(id, cancellationToken);
        if (rider is null)
        {
            return ServiceResult<IReadOnlyList<RiderAssignmentDto>>.Fail(404, "Rider not found.");
        }

        if (rider.RouteId is null)
        {
            return ServiceResult<IReadOnlyList<RiderAssignmentDto>>.Ok([], "This rider has no route, so there are no stops.");
        }

        var day = date ?? ReportingWindow.Today();
        var stops = await _db.RouteStops.AsNoTracking()
            .Where(stop => stop.RouteId == rider.RouteId && stop.ServiceDate == day)
            .OrderBy(stop => stop.Sequence)
            .Select(stop => new RiderAssignmentDto(
                stop.Id,
                stop.Sequence,
                stop.CustomerId,
                stop.Customer.BusinessName,
                stop.Customer.Code,
                stop.Status == StopStatus.Completed ? "Completed"
                    : stop.Status == StopStatus.InProgress ? "InProgress"
                    : stop.Status == StopStatus.Missed ? "Missed"
                    : "Pending",
                stop.ScheduledTime,
                stop.DistanceMeters))
            .ToListAsync(cancellationToken);
        IReadOnlyList<RiderAssignmentDto> assignments = stops;
        var message = assignments.Count == 0 ? "No stops are scheduled for this rider on that date." : "Assignments loaded.";
        return ServiceResult<IReadOnlyList<RiderAssignmentDto>>.Ok(assignments, message);
    }

    public async Task<ServiceResult<IReadOnlyList<RiderExceptionDto>>> ExceptionsAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var roster = await LoadRosterAsync(day, cancellationToken);
        var items = new List<RiderExceptionDto>();
        foreach (var rider in roster.Where(item => !item.User.IsActive))
        {
            items.Add(new RiderExceptionDto(
                $"rider-inactive:{rider.User.Id}",
                rider.User.Id,
                rider.User.FullName,
                "warning",
                $"{rider.User.FullName} is inactive",
                "The rider account is marked inactive.",
                rider.User.CreatedAt,
                "Open"));
        }

        foreach (var rider in roster.Where(item => item.User.IsActive && item.Idle))
        {
            items.Add(new RiderExceptionDto(
                $"shift-idle:{rider.User.Id}:{day:yyyy-MM-dd}",
                rider.User.Id,
                rider.User.FullName,
                "warning",
                $"{rider.User.FullName} has an open shift with no completed stops",
                $"The shift has been open for more than {OpenShiftIdleThreshold.TotalHours:0} hours and none of the {rider.StopsTotal} stops are completed.",
                rider.ShiftStartedAt ?? DateTime.UtcNow,
                "Open"));
        }

        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var riderIds = roster.Select(rider => rider.User.Id).ToList();
        if (riderIds.Count > 0)
        {
            var failedSales = await _db.Sales.AsNoTracking()
                .Where(sale => riderIds.Contains(sale.RiderId)
                    && sale.SyncStatus == SyncStatus.Failed
                    && sale.CreatedAt >= start
                    && sale.CreatedAt < end)
                .Select(sale => new { sale.Id, sale.RiderId, sale.ReceiptNumber, sale.CreatedAt, Customer = sale.Customer.BusinessName })
                .ToListAsync(cancellationToken);
            var names = roster.ToDictionary(rider => rider.User.Id, rider => rider.User.FullName);
            foreach (var sale in failedSales)
            {
                items.Add(new RiderExceptionDto(
                    $"sale-sync:{sale.Id}",
                    sale.RiderId,
                    names.GetValueOrDefault(sale.RiderId, ""),
                    "high",
                    "Sale failed to sync",
                    $"{sale.ReceiptNumber} · {sale.Customer}",
                    sale.CreatedAt,
                    "Open"));
            }

            var failedLogs = await _db.ActivityLogs.AsNoTracking()
                .Where(log => riderIds.Contains(log.UserId)
                    && log.SyncStatus == SyncStatus.Failed
                    && log.OccurredAt >= start
                    && log.OccurredAt < end)
                .Select(log => new { log.Id, log.UserId, log.Title, log.Reference, log.OccurredAt })
                .ToListAsync(cancellationToken);
            foreach (var log in failedLogs)
            {
                items.Add(new RiderExceptionDto(
                    $"activity-sync:{log.Id}",
                    log.UserId,
                    names.GetValueOrDefault(log.UserId, ""),
                    "high",
                    "Activity failed to sync",
                    $"{log.Title} · {log.Reference}",
                    log.OccurredAt,
                    "Open"));
            }
        }

        IReadOnlyList<RiderExceptionDto> ordered = items
            .OrderBy(item => item.Severity == "high" ? 0 : 1)
            .ThenByDescending(item => item.CreatedAtUtc)
            .ToList();
        var message = ordered.Count == 0 ? "No rider exceptions on this date." : "Rider exceptions loaded.";
        return ServiceResult<IReadOnlyList<RiderExceptionDto>>.Ok(ordered, message);
    }

    public async Task<ServiceResult<LocationVerificationsDto>> LocationVerificationsAsync(CancellationToken cancellationToken)
    {
        var freshnessSeconds = 180;
        var cutoff = DateTime.UtcNow.AddSeconds(-freshnessSeconds);
        var sessions = await _db.TrackingSessions.AsNoTracking()
            .Where(item => item.Status == TrackingSessionStatus.Active)
            .ToListAsync(cancellationToken);
        if (sessions.Count == 0)
        {
            var empty = new LocationVerificationsDto(
                [],
                "No active tracking sessions. Riders share location after shift start.");
            return ServiceResult<LocationVerificationsDto>.Ok(empty, empty.Message);
        }

        var sessionIds = sessions.Select(item => item.Id).ToList();
        var fixes = await _db.RiderLocationTelemetries.AsNoTracking()
            .Where(item => sessionIds.Contains(item.TrackingSessionId) && !item.Rejected)
            .Select(item => new
            {
                item.TrackingSessionId,
                item.RiderUserId,
                item.DeviceTimestampUtc,
                item.Latitude,
                item.Longitude,
                item.AccuracyMeters
            })
            .ToListAsync(cancellationToken);
        var latest = fixes
            .GroupBy(item => item.TrackingSessionId)
            .Select(group => group.OrderByDescending(item => item.DeviceTimestampUtc).First())
            .ToList();

        var items = latest.Select(fix =>
        {
            var fresh = fix.DeviceTimestampUtc >= cutoff;
            return new LocationVerificationDto(
                fix.TrackingSessionId,
                fix.RiderUserId,
                fix.DeviceTimestampUtc,
                (decimal)fix.Latitude,
                (decimal)fix.Longitude,
                fresh ? "live-tracking-fresh" : "live-tracking-stale");
        }).OrderByDescending(item => item.VerifiedAtUtc).ToList();

        var dto = new LocationVerificationsDto(
            items,
            items.Count == 0
                ? "Active sessions have not reported a GPS fix yet."
                : "Latest rider telemetry from live tracking sessions.");
        return ServiceResult<LocationVerificationsDto>.Ok(dto, dto.Message);
    }

    private async Task<List<RiderFacts>> LoadRosterAsync(DateOnly day, CancellationToken cancellationToken)
    {
        var roleId = await _db.Roles.AsNoTracking()
            .Where(role => role.Name == AppRoles.Rider)
            .Select(role => role.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (roleId is null)
        {
            return [];
        }

        var riders = await _db.Users.AsNoTracking()
            .Include(user => user.Vehicle)
            .Include(user => user.Route)
            .Where(user => _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId))
            .OrderBy(user => user.FullName)
            .ToListAsync(cancellationToken);
        if (riders.Count == 0)
        {
            return [];
        }

        var riderIds = riders.Select(user => user.Id).ToList();
        var routeIds = riders.Where(user => user.RouteId is not null).Select(user => user.RouteId!.Value).Distinct().ToList();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var now = DateTime.UtcNow;

        var shifts = await _db.Shifts.AsNoTracking()
            .Where(shift => shift.Status == "Open" && shift.ServiceDate == day && riderIds.Contains(shift.RiderId))
            .GroupBy(shift => shift.RiderId)
            .Select(group => new { RiderId = group.Key, StartedAt = group.Min(shift => shift.StartedAt) })
            .ToListAsync(cancellationToken);
        var shiftByRider = shifts.ToDictionary(shift => shift.RiderId, shift => shift.StartedAt);

        var stopRows = routeIds.Count == 0
            ? []
            : await _db.RouteStops.AsNoTracking()
                .Where(stop => stop.ServiceDate == day && routeIds.Contains(stop.RouteId))
                .GroupBy(stop => stop.RouteId)
                .Select(group => new
                {
                    RouteId = group.Key,
                    Total = group.Count(),
                    Completed = group.Count(stop => stop.Status == StopStatus.Completed)
                })
                .ToListAsync(cancellationToken);
        var stopsByRoute = stopRows.ToDictionary(row => row.RouteId);

        var saleRows = await _db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed
                && sale.CreatedAt >= start
                && sale.CreatedAt < end
                && riderIds.Contains(sale.RiderId))
            .GroupBy(sale => sale.RiderId)
            .Select(group => new
            {
                RiderId = group.Key,
                Billed = group.Sum(sale => sale.SaleAmount),
                Cash = group.Sum(sale => sale.PaymentChannel == PaymentChannel.Cash ? sale.AmountReceived : 0m)
            })
            .ToListAsync(cancellationToken);
        var salesByRider = saleRows.ToDictionary(row => row.RiderId);

        var collectionRows = await _db.Collections.AsNoTracking()
            .Where(item => item.Channel == PaymentChannel.Cash
                && item.CreatedAt >= start
                && item.CreatedAt < end
                && riderIds.Contains(item.RiderId))
            .GroupBy(item => item.RiderId)
            .Select(group => new { RiderId = group.Key, Cash = group.Sum(item => item.Amount) })
            .ToListAsync(cancellationToken);
        var cashByRider = collectionRows.ToDictionary(row => row.RiderId, row => row.Cash);

        var failedSaleRiders = await _db.Sales.AsNoTracking()
            .Where(sale => sale.SyncStatus == SyncStatus.Failed
                && sale.CreatedAt >= start
                && sale.CreatedAt < end
                && riderIds.Contains(sale.RiderId))
            .Select(sale => sale.RiderId)
            .Distinct()
            .ToListAsync(cancellationToken);
        var failedSales = failedSaleRiders.ToHashSet();

        var failedActivityRiders = await _db.ActivityLogs.AsNoTracking()
            .Where(log => log.SyncStatus == SyncStatus.Failed
                && log.OccurredAt >= start
                && log.OccurredAt < end
                && riderIds.Contains(log.UserId))
            .Select(log => log.UserId)
            .Distinct()
            .ToListAsync(cancellationToken);
        var failedActivity = failedActivityRiders.ToHashSet();

        var lastStamps = await _db.ActivityLogs.AsNoTracking()
            .Where(log => riderIds.Contains(log.UserId))
            .GroupBy(log => log.UserId)
            .Select(group => new { UserId = group.Key, OccurredAt = group.Max(log => log.OccurredAt) })
            .ToListAsync(cancellationToken);
        var titles = new Dictionary<string, (DateTime At, string Title)>();
        if (lastStamps.Count > 0)
        {
            var stampUsers = lastStamps.Select(item => item.UserId).ToList();
            var stampTimes = lastStamps.Select(item => item.OccurredAt).ToList();
            var titleRows = await _db.ActivityLogs.AsNoTracking()
                .Where(log => stampUsers.Contains(log.UserId) && stampTimes.Contains(log.OccurredAt))
                .Select(log => new { log.UserId, log.OccurredAt, log.Title })
                .ToListAsync(cancellationToken);
            foreach (var stamp in lastStamps)
            {
                var title = titleRows.FirstOrDefault(row => row.UserId == stamp.UserId && row.OccurredAt == stamp.OccurredAt);
                if (title is not null)
                {
                    titles[stamp.UserId] = (stamp.OccurredAt, title.Title);
                }
            }
        }

        var facts = new List<RiderFacts>(riders.Count);
        foreach (var rider in riders)
        {
            var onDuty = shiftByRider.TryGetValue(rider.Id, out var startedAt);
            var stopsCompleted = 0;
            var stopsTotal = 0;
            if (rider.RouteId is Guid routeId && stopsByRoute.TryGetValue(routeId, out var stops))
            {
                stopsCompleted = stops.Completed;
                stopsTotal = stops.Total;
            }

            var idle = rider.IsActive
                && onDuty
                && now - startedAt >= OpenShiftIdleThreshold
                && stopsCompleted == 0
                && stopsTotal > 0;
            var failed = failedSales.Contains(rider.Id) || failedActivity.Contains(rider.Id);
            var status = Classify(rider.IsActive, onDuty, idle || failed);
            salesByRider.TryGetValue(rider.Id, out var sale);
            cashByRider.TryGetValue(rider.Id, out var collectionCash);
            titles.TryGetValue(rider.Id, out var last);
            facts.Add(new RiderFacts(
                rider,
                status,
                stopsCompleted,
                stopsTotal,
                sale?.Billed ?? 0,
                (sale?.Cash ?? 0) + collectionCash,
                last.At == default ? null : last.At,
                last.Title,
                onDuty ? startedAt : null,
                idle));
        }

        return facts;
    }

    private async Task<ApplicationUser?> FindRiderAsync(string id, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return null;
        }

        var roleId = await _db.Roles.AsNoTracking()
            .Where(role => role.Name == AppRoles.Rider)
            .Select(role => role.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (roleId is null)
        {
            return null;
        }

        return await _db.Users.AsNoTracking()
            .FirstOrDefaultAsync(
                user => user.Id == id && _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId),
                cancellationToken);
    }

    private static string Classify(bool isActive, bool onDuty, bool attention)
    {
        if (!isActive)
        {
            return "inactive";
        }

        if (!onDuty)
        {
            return "available";
        }

        return attention ? "attention" : "onDuty";
    }

    private static bool TryStatus(string? status, out string? filter, out string? error)
    {
        if (string.IsNullOrWhiteSpace(status) || status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            filter = null;
            error = null;
            return true;
        }

        var token = status.Trim();
        if (token.Equals("available", StringComparison.OrdinalIgnoreCase))
        {
            filter = "available";
            error = null;
            return true;
        }

        if (token.Equals("onDuty", StringComparison.OrdinalIgnoreCase))
        {
            filter = "onDuty";
            error = null;
            return true;
        }

        if (token.Equals("attention", StringComparison.OrdinalIgnoreCase))
        {
            filter = "attention";
            error = null;
            return true;
        }

        if (token.Equals("inactive", StringComparison.OrdinalIgnoreCase))
        {
            filter = "inactive";
            error = null;
            return true;
        }

        filter = null;
        error = "Status must be all, available, onDuty, attention, or inactive.";
        return false;
    }

    private static bool Contains(string? value, string term) =>
        !string.IsNullOrEmpty(value) && value.Contains(term, StringComparison.OrdinalIgnoreCase);

    private static RiderOpsCardDto ToCard(RiderFacts rider) =>
        new(
            rider.User.Id,
            rider.User.FullName,
            rider.User.RiderCode,
            rider.User.Vehicle?.Name,
            rider.User.Vehicle?.Plate,
            rider.User.Route?.Name,
            rider.Status,
            rider.StopsCompleted,
            rider.StopsTotal,
            rider.Billed,
            rider.Cash,
            rider.LastActivityAt,
            rider.LastActivityTitle);

    private sealed record RiderFacts(
        ApplicationUser User,
        string Status,
        int StopsCompleted,
        int StopsTotal,
        decimal Billed,
        decimal Cash,
        DateTime? LastActivityAt,
        string? LastActivityTitle,
        DateTime? ShiftStartedAt,
        bool Idle);
}
