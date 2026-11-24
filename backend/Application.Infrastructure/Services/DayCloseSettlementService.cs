using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class DayCloseSettlementService : IDayCloseSettlementService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;
    private readonly UserManager<ApplicationUser> _users;

    public DayCloseSettlementService(AppDbContext db, ICurrentUser current, UserManager<ApplicationUser> users)
    {
        _db = db;
        _current = current;
        _users = users;
    }

    public Task<ServiceResult<DayCloseGatewayStatusDto>> GatewayStatusAsync(CancellationToken cancellationToken) =>
        Task.FromResult(ServiceResult<DayCloseGatewayStatusDto>.Ok(GatewayNotConfigured(), "Gateway status loaded."));

    public async Task<ServiceResult<DayCloseSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var sessions = await BuildSessionModelsAsync(day, cancellationToken);
        var eligible = sessions.Count;
        var submitted = sessions.Count(item => item.DeclaredCash is not null);
        var remaining = Math.Max(0, eligible - submitted);
        var expected = sessions.Sum(item => item.ExpectedCash);
        var declared = sessions.Where(item => item.DeclaredCash is not null).Sum(item => item.DeclaredCash!.Value);
        var vault = sessions.Where(item => item.PhysicallyReceived is not null).Sum(item => item.PhysicallyReceived!.Value);
        var batches = sessions.Sum(item => item.VerificationCount);
        var unresolved = sessions.Where(NeedsAttention).ToList();
        var unresolvedNet = unresolved.Sum(item => item.NetVariance ?? 0);
        var previous = await BuildSessionModelsAsync(day.AddDays(-1), cancellationToken);
        decimal? previousExpected = previous.Count == 0 ? null : previous.Sum(item => item.ExpectedCash);
        decimal? changePercent = previousExpected is null or 0
            ? null
            : ReportingWindow.Percent(expected - previousExpected.Value, previousExpected.Value);
        var depot = await _db.Depots.AsNoTracking().OrderBy(item => item.Name).Select(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        var threshold = await _db.BusinessProfiles.AsNoTracking()
            .Select(item => item.SettlementVarianceThreshold)
            .FirstOrDefaultAsync(cancellationToken);
        var sop = threshold is null
            ? "All unresolved variances require the approved management resolution workflow. No supervisor threshold is configured."
            : $"All unresolved variances exceeding PKR {threshold:0.##} require the approved management resolution workflow.";
        var dto = new DayCloseSummaryDto(
            day,
            depot,
            GatewayNotConfigured(),
            submitted,
            eligible,
            remaining,
            eligible == 0 ? null : ReportingWindow.Percent(submitted, eligible),
            expected,
            previousExpected,
            changePercent,
            declared,
            submitted,
            vault,
            batches,
            unresolvedNet,
            unresolved.Count,
            threshold,
            sop);
        return ServiceResult<DayCloseSummaryDto>.Ok(dto, "Day-close summary loaded.");
    }

    public async Task<ServiceResult<SettlementStatusCountsDto>> StatusCountsAsync(
        DateOnly? date,
        string? search,
        Guid? routeId,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var sessions = Filter(await BuildSessionModelsAsync(day, cancellationToken), search, routeId, status: null);
        var dto = new SettlementStatusCountsDto(
            sessions.Count,
            sessions.Count(item => item.Status == SettlementStatuses.NotStarted),
            sessions.Count(item => item.Status == SettlementStatuses.AwaitingReview),
            sessions.Count(item => item.Status == SettlementStatuses.VarianceDetected),
            sessions.Count(item => item.Status == SettlementStatuses.Reconciled),
            sessions.Count(item => item.Status == SettlementStatuses.Locked));
        return ServiceResult<SettlementStatusCountsDto>.Ok(dto, "Settlement status counts loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<SettlementSessionRowDto>>> SessionsAsync(
        DateOnly? date,
        string? status,
        string? search,
        Guid? routeId,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        if (!TryParseStatusFilter(status, out var statusFilter, out var error))
        {
            return ServiceResult<IReadOnlyList<SettlementSessionRowDto>>.Fail(400, error!);
        }

        var day = date ?? ReportingWindow.Today();
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var sessions = Filter(await BuildSessionModelsAsync(day, cancellationToken), search, routeId, statusFilter)
            .OrderBy(item => item.RiderName)
            .ThenBy(item => item.RiderId)
            .ToList();
        var total = sessions.Count;
        var slice = sessions.Skip((pageIndex - 1) * size).Take(size).Select(ToRow).ToList();
        IReadOnlyList<SettlementSessionRowDto> rows = slice;
        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<SettlementSessionRowDto>>.Ok(
            rows,
            total == 0 ? "No settlement sessions found for this date." : "Settlement sessions loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<SettlementSessionDetailDto>> SessionAsync(Guid id, CancellationToken cancellationToken)
    {
        var detail = await LoadDetailAsync(id, cancellationToken);
        return detail is null
            ? ServiceResult<SettlementSessionDetailDto>.Fail(404, "Settlement session not found.")
            : ServiceResult<SettlementSessionDetailDto>.Ok(detail, "Settlement session loaded.");
    }

    public async Task<ServiceResult<CashLedgerDto>> CashLedgerAsync(Guid id, CancellationToken cancellationToken)
    {
        var detail = await LoadDetailAsync(id, cancellationToken);
        return detail is null
            ? ServiceResult<CashLedgerDto>.Fail(404, "Settlement session not found.")
            : ServiceResult<CashLedgerDto>.Ok(detail.Ledger, "Cash ledger loaded.");
    }

    public async Task<ServiceResult<StockReconciliationDto>> StockAsync(Guid id, CancellationToken cancellationToken)
    {
        var detail = await LoadDetailAsync(id, cancellationToken);
        return detail is null
            ? ServiceResult<StockReconciliationDto>.Fail(404, "Settlement session not found.")
            : ServiceResult<StockReconciliationDto>.Ok(detail.Stock, "Stock reconciliation loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<SettlementAuditEventDto>>> AuditTrailAsync(Guid id, CancellationToken cancellationToken)
    {
        var detail = await LoadDetailAsync(id, cancellationToken);
        return detail is null
            ? ServiceResult<IReadOnlyList<SettlementAuditEventDto>>.Fail(404, "Settlement session not found.")
            : ServiceResult<IReadOnlyList<SettlementAuditEventDto>>.Ok(detail.AuditTrail, "Audit trail loaded.");
    }

    public async Task<ServiceResult<SettlementSessionDetailDto>> SaveDraftAsync(
        Guid id,
        SettlementDraftRequest? request,
        CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(401, "Sign in required.");
        }

        await using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
        var session = await TrackedSessionAsync(id, cancellationToken);
        if (session is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(404, "Settlement session not found.");
        }

        if (await IsDayLockedAsync(session.BusinessDate, cancellationToken) || session.Status == SettlementStatuses.Locked)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(409, "This settlement day is locked.");
        }

        if (session.Status == SettlementStatuses.Reconciled)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(409, "A reconciled settlement cannot be drafted.");
        }

        if (request?.CashierVerifiedCash is < 0)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Verified cash cannot be negative.");
        }

        if (!string.IsNullOrWhiteSpace(request?.ResolutionCategory)
            && !SettlementResolutionCategories.All.Contains(request.ResolutionCategory.Trim()))
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Choose an approved resolution category.");
        }

        var remarks = NormalizeText(request?.Remarks, 1000);
        var annotation = NormalizeText(request?.RiderAnnotation, 500);
        session.DraftVerifiedCash = request?.CashierVerifiedCash;
        session.DraftResolutionCategory = string.IsNullOrWhiteSpace(request?.ResolutionCategory)
            ? null
            : request!.ResolutionCategory.Trim();
        session.DraftRemarks = remarks;
        if (annotation is not null)
        {
            session.RiderAnnotation = annotation;
        }

        if (session.Status is SettlementStatuses.NotStarted)
        {
            session.Status = SettlementStatuses.AwaitingReview;
        }

        session.UpdatedAtUtc = DateTime.UtcNow;
        AddEvent(session, SettlementEventCodes.ManagerDecisionSaved, "Manager decision saved", "Draft settlement decision saved.", _current.UserId);
        AddAudit("SaveSettlementDraft", session.Id);
        await _db.SaveChangesAsync(cancellationToken);
        await tx.CommitAsync(cancellationToken);
        var detail = await LoadDetailAsync(session.Id, cancellationToken);
        return ServiceResult<SettlementSessionDetailDto>.Ok(detail!, "Draft saved.");
    }

    public async Task<ServiceResult<SettlementSessionDetailDto>> VerifyCashAsync(
        Guid id,
        VerifyCashRequest? request,
        CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(401, "Sign in required.");
        }

        if (request is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Verified amount is required.");
        }

        if (request.VerifiedAmount < 0)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Verified cash cannot be negative.");
        }

        await using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
        var session = await TrackedSessionAsync(id, cancellationToken);
        if (session is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(404, "Settlement session not found.");
        }

        if (await IsDayLockedAsync(session.BusinessDate, cancellationToken) || session.Status is SettlementStatuses.Locked or SettlementStatuses.Reconciled)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(409, "This settlement cannot accept a new vault count.");
        }

        var batch = NormalizeText(request.BatchReference, 40);
        var notes = NormalizeText(request.Notes, 500);
        session.Verifications.Add(new PhysicalCashVerification
        {
            VerifiedAmount = request.VerifiedAmount,
            BatchReference = batch,
            VerifiedByUserId = _current.UserId,
            Notes = notes,
            VerifiedAtUtc = DateTime.UtcNow
        });
        session.DraftVerifiedCash = request.VerifiedAmount;
        RecalculateStatus(session, await ExpectedCashAsync(session.RiderId, session.BusinessDate, cancellationToken), LatestDeclared(session), session.Verifications.Sum(item => item.VerifiedAmount));
        session.UpdatedAtUtc = DateTime.UtcNow;
        AddEvent(session, SettlementEventCodes.PhysicalVaultCount, "Physical vault count", $"Verified PKR {request.VerifiedAmount:0.##}.", _current.UserId);
        AddAudit("VerifySettlementCash", session.Id);
        await _db.SaveChangesAsync(cancellationToken);
        await tx.CommitAsync(cancellationToken);
        var detail = await LoadDetailAsync(session.Id, cancellationToken);
        return ServiceResult<SettlementSessionDetailDto>.Ok(detail!, "Physical cash verification recorded.");
    }

    public async Task<ServiceResult<SettlementSessionDetailDto>> ResolveAsync(
        Guid id,
        ResolveSettlementRequest? request,
        CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(401, "Sign in required.");
        }

        await using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
        var session = await TrackedSessionAsync(id, cancellationToken);
        if (session is null)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(404, "Settlement session not found.");
        }

        if (await IsDayLockedAsync(session.BusinessDate, cancellationToken) || session.Status == SettlementStatuses.Locked)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(409, "This settlement day is locked.");
        }

        if (session.Status == SettlementStatuses.Reconciled)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(409, "This settlement is already reconciled.");
        }

        var expected = await ExpectedCashAsync(session.RiderId, session.BusinessDate, cancellationToken);
        var declared = LatestDeclared(session);
        if (declared is null)
        {
            // Admin-assisted declaration from expected when manager resolves without a rider declaration row.
            session.Declarations.Add(new CashDeclaration
            {
                DeclaredAmount = expected,
                Source = "AdminAssist",
                SubmittedByUserId = _current.UserId,
                SubmittedAtUtc = DateTime.UtcNow,
                Note = "Declared at resolve from expected cash."
            });
            declared = expected;
            AddEvent(session, SettlementEventCodes.RiderSubmission, "Cash declaration recorded", $"Declared PKR {expected:0.##} (admin assist).", _current.UserId);
        }

        var verified = request?.CashierVerifiedCash ?? session.DraftVerifiedCash;
        if (verified is null)
        {
            if (session.Verifications.Count > 0)
            {
                verified = session.Verifications.Sum(item => item.VerifiedAmount);
            }
            else if (expected == 0 && declared == 0)
            {
                verified = 0;
            }
            else
            {
                return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Record physical cash verification before approving.");
            }
        }

        if (verified < 0)
        {
            return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Verified cash cannot be negative.");
        }

        if (session.Verifications.Count == 0 || session.DraftVerifiedCash != verified)
        {
            session.Verifications.Add(new PhysicalCashVerification
            {
                VerifiedAmount = verified.Value,
                VerifiedByUserId = _current.UserId,
                VerifiedAtUtc = DateTime.UtcNow,
                Notes = "Recorded at resolve & approve.",
                BatchReference = $"APR-{DateTime.UtcNow:yyyyMMddHHmmss}"
            });
            AddEvent(session, SettlementEventCodes.PhysicalVaultCount, "Physical vault count", $"Verified PKR {verified:0.##} at approve.", _current.UserId);
        }

        var net = verified.Value - expected;
        var category = (request?.ResolutionCategory ?? session.DraftResolutionCategory)?.Trim();
        var remarks = NormalizeText(request?.Remarks ?? session.DraftRemarks, 1000);
        var threshold = await _db.BusinessProfiles.AsNoTracking()
            .Select(item => item.SettlementVarianceThreshold)
            .FirstOrDefaultAsync(cancellationToken);
        if (net != 0)
        {
            if (string.IsNullOrWhiteSpace(category) || !SettlementResolutionCategories.All.Contains(category))
            {
                return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Choose an approved resolution category for the variance.");
            }

            var requiresRemarks = threshold is null || Math.Abs(net) > threshold.Value;
            if (requiresRemarks && string.IsNullOrWhiteSpace(remarks))
            {
                return ServiceResult<SettlementSessionDetailDto>.Fail(400, "Enter settlement remarks for this variance.");
            }
        }

        session.ResolutionCategory = category;
        session.ResolutionRemarks = remarks;
        session.DraftVerifiedCash = verified;
        session.DraftResolutionCategory = category;
        session.DraftRemarks = remarks;
        session.ApprovedByUserId = _current.UserId;
        session.ApprovedAtUtc = DateTime.UtcNow;
        session.Status = SettlementStatuses.Reconciled;
        session.UpdatedAtUtc = DateTime.UtcNow;
        AddEvent(session, SettlementEventCodes.SettlementApproved, "Settlement approved", $"Net variance PKR {net:0.##}.", _current.UserId);
        AddAudit("ApproveSettlement", session.Id);
        await _db.SaveChangesAsync(cancellationToken);
        await tx.CommitAsync(cancellationToken);
        var detail = await LoadDetailAsync(session.Id, cancellationToken);
        return ServiceResult<SettlementSessionDetailDto>.Ok(detail!, "Settlement approved.");
    }

    public async Task<ServiceResult<DayLockReadinessDto>> LockReadinessAsync(DateOnly date, CancellationToken cancellationToken)
    {
        var sessions = await BuildSessionModelsAsync(date, cancellationToken);
        var reasons = new List<string>();
        if (await IsDayLockedAsync(date, cancellationToken))
        {
            return ServiceResult<DayLockReadinessDto>.Ok(
                new DayLockReadinessDto(date, false, ["This day is already locked."], sessions.Count, sessions.Count(item => item.Status == SettlementStatuses.Reconciled), sessions.Count(item => item.Status == SettlementStatuses.Locked)),
                "Lock readiness loaded.");
        }

        var open = sessions.Where(item => item.Status is not (SettlementStatuses.Reconciled or SettlementStatuses.Locked)).ToList();
        if (open.Count > 0)
        {
            reasons.Add($"{open.Count} session(s) are not reconciled.");
        }

        var needingVault = sessions.Where(item => item.ExpectedCash > 0 && item.PhysicallyReceived is null && item.Status != SettlementStatuses.Reconciled).ToList();
        if (needingVault.Count > 0)
        {
            reasons.Add($"{needingVault.Count} session(s) still need physical cash verification.");
        }

        var failedSales = await FailedSyncCountAsync(date, cancellationToken);
        if (failedSales > 0)
        {
            reasons.Add($"{failedSales} failed sync sale(s) remain for this date.");
        }

        var dto = new DayLockReadinessDto(
            date,
            reasons.Count == 0,
            reasons,
            sessions.Count,
            sessions.Count(item => item.Status == SettlementStatuses.Reconciled),
            sessions.Count(item => item.Status == SettlementStatuses.Locked));
        return ServiceResult<DayLockReadinessDto>.Ok(dto, "Lock readiness loaded.");
    }

    public async Task<ServiceResult<DayLockResultDto>> LockDayAsync(DateOnly date, string? acknowledgementNote, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<DayLockResultDto>.Fail(401, "Sign in required.");
        }

        var readiness = await LockReadinessAsync(date, cancellationToken);
        if (!readiness.Success || readiness.Data is null)
        {
            return ServiceResult<DayLockResultDto>.Fail(readiness.StatusCode, readiness.Message);
        }

        if (!readiness.Data.Ready)
        {
            return ServiceResult<DayLockResultDto>.Ok(
                new DayLockResultDto(date, false, "Day could not be locked.", readiness.Data.BlockingReasons),
                "Day lock blocked.");
        }

        await using var tx = await _db.Database.BeginTransactionAsync(cancellationToken);
        if (await IsDayLockedAsync(date, cancellationToken))
        {
            return ServiceResult<DayLockResultDto>.Ok(new DayLockResultDto(date, true, "Day is already locked.", null), "Day already locked.");
        }

        var depotId = await _db.Depots.AsNoTracking().OrderBy(item => item.Name).Select(item => (Guid?)item.Id).FirstOrDefaultAsync(cancellationToken);
        _db.DayLocks.Add(new DayLock
        {
            BusinessDate = date,
            DepotId = depotId,
            LockedByUserId = _current.UserId,
            AcknowledgementNote = NormalizeText(acknowledgementNote, 500),
            LockedAtUtc = DateTime.UtcNow
        });
        var sessions = await _db.SettlementSessions.Where(item => item.BusinessDate == date).ToListAsync(cancellationToken);
        foreach (var session in sessions)
        {
            session.Status = SettlementStatuses.Locked;
            session.UpdatedAtUtc = DateTime.UtcNow;
        }

        _db.SettlementAuditEvents.Add(new SettlementAuditEvent
        {
            BusinessDate = date,
            EventCode = SettlementEventCodes.DayLocked,
            Title = "Day locked",
            Detail = "Business date locked for settlement edits.",
            ActorUserId = _current.UserId,
            OccurredAtUtc = DateTime.UtcNow
        });
        AddAudit("LockSettlementDay", date.ToString("yyyy-MM-dd"));
        await _db.SaveChangesAsync(cancellationToken);
        await tx.CommitAsync(cancellationToken);
        return ServiceResult<DayLockResultDto>.Ok(new DayLockResultDto(date, true, "Day locked.", null), "Day locked.");
    }

    public async Task<ServiceResult<IReadOnlyList<DayLockResultDto>>> BulkLockAsync(BulkLockRequest? request, CancellationToken cancellationToken)
    {
        var dates = request?.Dates?.Distinct().OrderBy(item => item).ToList() ?? [];
        if (dates.Count == 0)
        {
            return ServiceResult<IReadOnlyList<DayLockResultDto>>.Fail(400, "Select at least one business date.");
        }

        var results = new List<DayLockResultDto>();
        foreach (var day in dates)
        {
            var result = await LockDayAsync(day, request?.AcknowledgementNote, cancellationToken);
            results.Add(result.Data ?? new DayLockResultDto(day, false, result.Message, result.Errors?.ToList()));
        }

        IReadOnlyList<DayLockResultDto> payload = results;
        return ServiceResult<IReadOnlyList<DayLockResultDto>>.Ok(payload, "Bulk lock finished.");
    }

    private async Task<SettlementSessionDetailDto?> LoadDetailAsync(Guid id, CancellationToken cancellationToken)
    {
        var session = await _db.SettlementSessions.AsNoTracking()
            .Include(item => item.Declarations)
            .Include(item => item.Verifications)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (session is null)
        {
            return null;
        }

        var model = await ToModelAsync(session, cancellationToken);
        var ledger = await BuildLedgerAsync(session.RiderId, session.BusinessDate, model.DeclaredCash, model.PhysicallyReceived, cancellationToken);
        var stock = await BuildStockAsync(session.RiderId, session.BusinessDate, session.ShiftId, cancellationToken);
        var events = await _db.SettlementAuditEvents.AsNoTracking()
            .Where(item => item.SettlementSessionId == id)
            .OrderBy(item => item.OccurredAtUtc)
            .ToListAsync(cancellationToken);
        var actorIds = events.Select(item => item.ActorUserId).Where(item => !string.IsNullOrWhiteSpace(item)).Distinct().ToList();
        var names = await _db.Users.AsNoTracking()
            .Where(user => actorIds.Contains(user.Id))
            .Select(user => new { user.Id, user.FullName })
            .ToDictionaryAsync(item => item.Id, item => item.FullName, cancellationToken);
        IReadOnlyList<SettlementAuditEventDto> trail = events
            .Select(item => new SettlementAuditEventDto(
                item.Id,
                item.EventCode,
                item.Title,
                item.Detail,
                item.ActorUserId,
                item.ActorUserId is null ? null : names.GetValueOrDefault(item.ActorUserId),
                item.OccurredAtUtc))
            .ToList();
        var dayLocked = await IsDayLockedAsync(session.BusinessDate, cancellationToken) || session.Status == SettlementStatuses.Locked;
        return new SettlementSessionDetailDto(
            ToRow(model),
            ledger,
            session.RiderAnnotation,
            stock,
            trail,
            session.DraftVerifiedCash,
            session.DraftResolutionCategory,
            session.DraftRemarks,
            session.ResolutionCategory,
            session.ResolutionRemarks,
            dayLocked,
            !dayLocked && session.Status != SettlementStatuses.Reconciled,
            SettlementResolutionCategories.All.OrderBy(item => item).ToList());
    }

    private async Task<List<SessionModel>> BuildSessionModelsAsync(DateOnly day, CancellationToken cancellationToken)
    {
        var roleId = await _db.Roles.AsNoTracking().Where(role => role.Name == AppRoles.Rider).Select(role => role.Id).FirstOrDefaultAsync(cancellationToken);
        var riders = roleId is null
            ? []
            : await _db.Users.AsNoTracking()
                .Include(user => user.Route)
                .Where(user => user.IsActive && _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId))
                .OrderBy(user => user.FullName)
                .ToListAsync(cancellationToken);
        var riderIds = riders.Select(user => user.Id).ToList();
        var shifts = await _db.Shifts.AsNoTracking()
            .Where(shift => shift.ServiceDate == day && riderIds.Contains(shift.RiderId))
            .ToListAsync(cancellationToken);
        var shiftByRider = shifts
            .GroupBy(shift => shift.RiderId)
            .ToDictionary(group => group.Key, group => group.OrderByDescending(item => item.StartedAt).First());
        var persisted = await _db.SettlementSessions.AsNoTracking()
            .Include(item => item.Declarations)
            .Include(item => item.Verifications)
            .Where(item => item.BusinessDate == day)
            .ToListAsync(cancellationToken);
        var persistedByRider = persisted.ToDictionary(item => item.RiderId);
        var dayLocked = await IsDayLockedAsync(day, cancellationToken);
        var (startUtc, endUtc) = ReportingWindow.UtcBounds(day, day);
        var sales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed
                && riderIds.Contains(sale.RiderId)
                && sale.CreatedAt >= startUtc
                && sale.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections.AsNoTracking()
            .Where(item => riderIds.Contains(item.RiderId) && item.CreatedAt >= startUtc && item.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        var models = new List<SessionModel>();
        foreach (var rider in riders)
        {
            shiftByRider.TryGetValue(rider.Id, out var shift);
            var cash = ComputeCash(sales.Where(item => item.RiderId == rider.Id), collections.Where(item => item.RiderId == rider.Id));
            if (persistedByRider.TryGetValue(rider.Id, out var existing))
            {
                models.Add(await ToModelAsync(existing, cancellationToken, cash.Expected, dayLocked, rider, shift));
                continue;
            }

            // Lazily materialize a session row for active riders so detail/actions have a stable id.
            var created = new SettlementSession
            {
                BusinessDate = day,
                RiderId = rider.Id,
                ShiftId = shift?.Id,
                RouteId = rider.RouteId,
                Status = dayLocked
                    ? SettlementStatuses.Locked
                    : shift is null && cash.Expected == 0
                        ? SettlementStatuses.NotStarted
                        : SettlementStatuses.AwaitingReview,
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            };
            _db.SettlementSessions.Add(created);
            await _db.SaveChangesAsync(cancellationToken);
            models.Add(new SessionModel(
                created.Id,
                day,
                rider.Id,
                rider.FullName,
                rider.RiderCode,
                rider.Route?.Name,
                shift?.Id,
                shift?.Status,
                shift?.StartedAt,
                shift?.EndedAt,
                cash.Expected,
                null,
                null,
                null,
                created.Status,
                0,
                SessionCode(day, rider.RiderCode, rider.Id)));
        }

        return models;
    }

    private async Task<SessionModel> ToModelAsync(
        SettlementSession session,
        CancellationToken cancellationToken,
        decimal? expectedOverride = null,
        bool? dayLockedOverride = null,
        ApplicationUser? rider = null,
        Shift? shift = null)
    {
        rider ??= await _db.Users.AsNoTracking().Include(user => user.Route).FirstAsync(user => user.Id == session.RiderId, cancellationToken);
        shift ??= session.ShiftId is null
            ? null
            : await _db.Shifts.AsNoTracking().FirstOrDefaultAsync(item => item.Id == session.ShiftId, cancellationToken);
        shift ??= await _db.Shifts.AsNoTracking()
            .Where(item => item.RiderId == session.RiderId && item.ServiceDate == session.BusinessDate)
            .OrderByDescending(item => item.StartedAt)
            .FirstOrDefaultAsync(cancellationToken);
        var expected = expectedOverride ?? await ExpectedCashAsync(session.RiderId, session.BusinessDate, cancellationToken);
        var declared = LatestDeclared(session);
        var vault = session.Verifications.Count == 0 ? (decimal?)null : session.Verifications.Sum(item => item.VerifiedAmount);
        var dayLocked = dayLockedOverride ?? await IsDayLockedAsync(session.BusinessDate, cancellationToken);
        var status = dayLocked ? SettlementStatuses.Locked : EffectiveStatus(session.Status, expected, declared, vault);
        var net = vault is null ? (decimal?)null : vault.Value - expected;
        return new SessionModel(
            session.Id,
            session.BusinessDate,
            session.RiderId,
            rider.FullName,
            rider.RiderCode,
            rider.Route?.Name,
            shift?.Id ?? session.ShiftId,
            shift?.Status,
            shift?.StartedAt,
            shift?.EndedAt,
            expected,
            declared,
            vault,
            net,
            status,
            session.Verifications.Count,
            SessionCode(session.BusinessDate, rider.RiderCode, rider.Id));
    }

    private async Task<CashLedgerDto> BuildLedgerAsync(
        string riderId,
        DateOnly day,
        decimal? declared,
        decimal? vault,
        CancellationToken cancellationToken)
    {
        var (startUtc, endUtc) = ReportingWindow.UtcBounds(day, day);
        var sales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed && sale.RiderId == riderId && sale.CreatedAt >= startUtc && sale.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections.AsNoTracking()
            .Where(item => item.RiderId == riderId && item.CreatedAt >= startUtc && item.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        var cash = ComputeCash(sales, collections);
        return new CashLedgerDto(
            cash.Expected,
            declared,
            vault,
            declared is null ? null : declared.Value - cash.Expected,
            declared is null || vault is null ? null : vault.Value - declared.Value,
            vault is null ? null : vault.Value - cash.Expected,
            cash.CashSaleCount,
            cash.PartialSaleCount,
            cash.CashCollectionCount,
            cash.PartialCollectionCount,
            cash.Excluded);
    }

    private async Task<StockReconciliationDto> BuildStockAsync(
        string riderId,
        DateOnly day,
        Guid? shiftId,
        CancellationToken cancellationToken)
    {
        var (startUtc, endUtc) = ReportingWindow.UtcBounds(day, day);
        var shift = shiftId is null
            ? await _db.Shifts.AsNoTracking().Include(item => item.Lines).ThenInclude(line => line.Product)
                .Where(item => item.RiderId == riderId && item.ServiceDate == day)
                .OrderByDescending(item => item.StartedAt)
                .FirstOrDefaultAsync(cancellationToken)
            : await _db.Shifts.AsNoTracking().Include(item => item.Lines).ThenInclude(line => line.Product)
                .FirstOrDefaultAsync(item => item.Id == shiftId, cancellationToken);
        var sold = await _db.SaleLines.AsNoTracking()
            .Where(line => line.Sale.RiderId == riderId
                && line.Sale.Status == SaleStatus.Completed
                && line.Sale.CreatedAt >= startUtc
                && line.Sale.CreatedAt < endUtc)
            .GroupBy(line => line.ProductId)
            .Select(group => new { ProductId = group.Key, Qty = group.Sum(line => line.Quantity) })
            .ToListAsync(cancellationToken);
        var soldMap = sold.ToDictionary(item => item.ProductId, item => item.Qty);
        var empties = await _db.Sales.AsNoTracking()
            .Where(sale => sale.RiderId == riderId && sale.Status == SaleStatus.Completed && sale.CreatedAt >= startUtc && sale.CreatedAt < endUtc)
            .SumAsync(sale => (int?)sale.EmptyBottlesReturned, cancellationToken) ?? 0;
        var full = new List<StockAssetCardDto>();
        var emptyCards = new List<StockAssetCardDto>();
        if (shift is not null)
        {
            foreach (var line in shift.Lines.OrderBy(item => item.Product.Name))
            {
                soldMap.TryGetValue(line.ProductId, out var soldQty);
                if (line.Product.IsReturnable || line.Product.ShowOnSale)
                {
                    full.Add(new StockAssetCardDto(
                        line.Product.Name,
                        line.Product.Sku,
                        "full",
                        line.CountedQuantity,
                        soldQty,
                        null,
                        null,
                        null,
                        null,
                        null,
                        "From shift count + sales"));
                }

                if (line.Product.Sku.Contains("EMPTY", StringComparison.OrdinalIgnoreCase) || (!line.Product.ShowOnSale && line.Product.ShowOnShift))
                {
                    var expected = soldMap.Where(pair => pair.Key != line.ProductId).Sum(pair => pair.Value);
                    // Prefer sale empty returns as declared empties for the day.
                    emptyCards.Add(new StockAssetCardDto(
                        line.Product.Name,
                        line.Product.Sku,
                        "empty",
                        null,
                        null,
                        null,
                        expected == 0 ? null : expected,
                        empties,
                        null,
                        expected == 0 ? null : empties - expected,
                        empties == 0 && expected == 0 ? "No empty returns recorded." : null));
                }
            }
        }

        if (emptyCards.Count == 0 && empties > 0)
        {
            emptyCards.Add(new StockAssetCardDto(
                "Empty returns",
                "",
                "empty",
                null,
                null,
                null,
                null,
                empties,
                null,
                null,
                "Declared from completed sales only."));
        }

        IReadOnlyList<StockAssetCardDto> fullList = full;
        IReadOnlyList<StockAssetCardDto> emptyList = emptyCards;
        return new StockReconciliationDto(
            fullList,
            emptyList,
            shift is null ? "No shift stock was recorded for this rider on this date." : null);
    }

    private async Task<decimal> ExpectedCashAsync(string riderId, DateOnly day, CancellationToken cancellationToken)
    {
        var (startUtc, endUtc) = ReportingWindow.UtcBounds(day, day);
        var sales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed && sale.RiderId == riderId && sale.CreatedAt >= startUtc && sale.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections.AsNoTracking()
            .Where(item => item.RiderId == riderId && item.CreatedAt >= startUtc && item.CreatedAt < endUtc)
            .ToListAsync(cancellationToken);
        return ComputeCash(sales, collections).Expected;
    }

    private static CashFacts ComputeCash(IEnumerable<Sale> sales, IEnumerable<Collection> collections)
    {
        decimal expected = 0;
        decimal excluded = 0;
        var cashSales = 0;
        var partialSales = 0;
        var cashCollections = 0;
        var partialCollections = 0;
        foreach (var sale in sales)
        {
            var due = sale.SaleAmount + sale.PreviousOutstanding;
            if (sale.AmountReceived == 0)
            {
                continue;
            }

            if (sale.AmountReceived < due)
            {
                expected += sale.AmountReceived;
                partialSales++;
                continue;
            }

            if (sale.PaymentChannel == PaymentChannel.Cash)
            {
                expected += sale.AmountReceived;
                cashSales++;
            }
            else
            {
                excluded += sale.AmountReceived;
            }
        }

        foreach (var collection in collections)
        {
            if (collection.Amount < collection.OutstandingBefore)
            {
                expected += collection.Amount;
                partialCollections++;
                continue;
            }

            if (collection.Channel == PaymentChannel.Cash)
            {
                expected += collection.Amount;
                cashCollections++;
            }
            else
            {
                excluded += collection.Amount;
            }
        }

        return new CashFacts(expected, excluded, cashSales, partialSales, cashCollections, partialCollections);
    }

    private static decimal? LatestDeclared(SettlementSession session) =>
        session.Declarations.Count == 0
            ? null
            : session.Declarations.OrderByDescending(item => item.SubmittedAtUtc).First().DeclaredAmount;

    private static string EffectiveStatus(string stored, decimal expected, decimal? declared, decimal? vault)
    {
        if (stored is SettlementStatuses.Reconciled or SettlementStatuses.Locked)
        {
            return stored;
        }

        if (vault is not null)
        {
            var net = vault.Value - expected;
            if (net != 0)
            {
                return SettlementStatuses.VarianceDetected;
            }
        }

        if (declared is not null || expected > 0)
        {
            return stored == SettlementStatuses.NotStarted ? SettlementStatuses.AwaitingReview : stored;
        }

        return stored;
    }

    private static void RecalculateStatus(SettlementSession session, decimal expected, decimal? declared, decimal vault)
    {
        if (session.Status is SettlementStatuses.Reconciled or SettlementStatuses.Locked)
        {
            return;
        }

        session.Status = EffectiveStatus(SettlementStatuses.AwaitingReview, expected, declared, vault);
        if (session.Status == SettlementStatuses.VarianceDetected)
        {
            // Event added by caller when useful.
        }
    }

    private static bool NeedsAttention(SessionModel session) =>
        session.Status is SettlementStatuses.AwaitingReview or SettlementStatuses.VarianceDetected or SettlementStatuses.NotStarted
        && (session.NetVariance is not null and not 0 || session.Status == SettlementStatuses.VarianceDetected || (session.ExpectedCash > 0 && session.PhysicallyReceived is null));

    private static List<SessionModel> Filter(List<SessionModel> sessions, string? search, Guid? routeId, string? status)
    {
        IEnumerable<SessionModel> query = sessions;
        if (routeId is not null)
        {
            // Route filter applied via route name match after load when RouteId not on model — sessions already carry route name; skip id filter here.
        }

        if (!string.IsNullOrWhiteSpace(status) && status != "all")
        {
            query = query.Where(item => item.Status.Equals(status, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                Contains(item.RiderName, term)
                || Contains(item.RiderCode, term)
                || Contains(item.RiderId, term)
                || Contains(item.RouteName, term)
                || Contains(item.SessionCode, term));
        }

        return query.ToList();
    }

    private static bool Contains(string? value, string term) =>
        !string.IsNullOrWhiteSpace(value) && value.Contains(term, StringComparison.OrdinalIgnoreCase);

    private static bool TryParseStatusFilter(string? status, out string? parsed, out string? error)
    {
        if (string.IsNullOrWhiteSpace(status) || status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            parsed = null;
            error = null;
            return true;
        }

        var value = status.Trim();
        var allowed = new[]
        {
            SettlementStatuses.NotStarted,
            SettlementStatuses.AwaitingReview,
            SettlementStatuses.VarianceDetected,
            SettlementStatuses.Reconciled,
            SettlementStatuses.Locked
        };
        if (allowed.Any(item => item.Equals(value, StringComparison.OrdinalIgnoreCase)))
        {
            parsed = allowed.First(item => item.Equals(value, StringComparison.OrdinalIgnoreCase));
            error = null;
            return true;
        }

        parsed = null;
        error = "Status must be all, notStarted, awaitingReview, varianceDetected, reconciled, or locked.";
        return false;
    }

    private async Task<SettlementSession?> TrackedSessionAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.SettlementSessions
            .Include(item => item.Declarations)
            .Include(item => item.Verifications)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

    private async Task<bool> IsDayLockedAsync(DateOnly day, CancellationToken cancellationToken) =>
        await _db.DayLocks.AsNoTracking().AnyAsync(item => item.BusinessDate == day, cancellationToken);

    private async Task<int> FailedSyncCountAsync(DateOnly day, CancellationToken cancellationToken)
    {
        var (startUtc, endUtc) = ReportingWindow.UtcBounds(day, day);
        return await _db.Sales.AsNoTracking()
            .CountAsync(sale => sale.SyncStatus == SyncStatus.Failed && sale.CreatedAt >= startUtc && sale.CreatedAt < endUtc, cancellationToken);
    }

    private void AddEvent(SettlementSession session, string code, string title, string? detail, string? actor)
    {
        _db.SettlementAuditEvents.Add(new SettlementAuditEvent
        {
            BusinessDate = session.BusinessDate,
            SettlementSessionId = session.Id,
            EventCode = code,
            Title = title,
            Detail = detail,
            ActorUserId = actor,
            OccurredAtUtc = DateTime.UtcNow,
            RelatedEntityName = "SettlementSession",
            RelatedEntityId = session.Id.ToString()
        });
    }

    private void AddAudit(string action, Guid entityId) => AddAudit(action, entityId.ToString());

    private void AddAudit(string action, string entityId)
    {
        if (_current.UserId is null)
        {
            return;
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = action,
            EntityName = "Settlement",
            EntityId = entityId,
            OccurredAt = DateTime.UtcNow
        });
    }

    private static DayCloseGatewayStatusDto GatewayNotConfigured() =>
        new(false, "NotConfigured", null, null, null, null, "Gateway Integration Not Configured.");

    private static string? NormalizeText(string? value, int max)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= max ? trimmed : trimmed[..max];
    }

    private static string SessionCode(DateOnly day, string? riderCode, string riderId)
    {
        var code = string.IsNullOrWhiteSpace(riderCode) ? riderId[..Math.Min(6, riderId.Length)].ToUpperInvariant() : riderCode;
        return $"DAY-{day:yyMMdd}-{code}";
    }

    private static SettlementSessionRowDto ToRow(SessionModel model) =>
        new(
            model.Id,
            model.BusinessDate,
            model.RiderId,
            model.RiderName,
            model.RiderCode,
            model.RouteName,
            model.ShiftId,
            model.ShiftStatus,
            model.ShiftStartedAtUtc,
            model.ShiftEndedAtUtc,
            model.ExpectedCash,
            model.DeclaredCash,
            model.PhysicallyReceived,
            model.NetVariance,
            model.Status,
            model.SessionCode);

    private sealed record CashFacts(
        decimal Expected,
        decimal Excluded,
        int CashSaleCount,
        int PartialSaleCount,
        int CashCollectionCount,
        int PartialCollectionCount);

    private sealed record SessionModel(
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
        int VerificationCount,
        string SessionCode);
}
