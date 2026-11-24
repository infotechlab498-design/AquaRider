using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminSecurityAuditService : IAdminSecurityAuditService
{
    private readonly AppDbContext _db;

    public AdminSecurityAuditService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<ServiceResult<AdminAuditSummaryDto>> SummaryAsync(
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var rows = await _db.AuditLogs.AsNoTracking()
            .Where(item => item.OccurredAt >= start && item.OccurredAt < end)
            .Select(item => new { item.Action, item.EntityName })
            .ToListAsync(cancellationToken);

        var total = rows.Count;
        var access = rows.Count(item => IsAccess(item.Action, item.EntityName));
        var financial = rows.Count(item => IsFinancial(item.Action, item.EntityName));
        var field = rows.Count(item => IsField(item.Action, item.EntityName));
        var master = rows.Count(item => IsMaster(item.Action, item.EntityName));
        var admin = rows.Count(item => IsAdmin(item.Action, item.EntityName));
        var userCourier = total - access; // approximate operational share

        var dto = new AdminAuditSummaryDto(
            day,
            total,
            userCourier,
            admin,
            financial,
            access,
            field,
            master,
            "Integrity hashing is not stored on AuditLog rows. Verify returns VerificationUnavailable.",
            "Locked V1: read-only AuditLogs. No fabricated IP, device, Knox, or Merkle proofs.");
        return ServiceResult<AdminAuditSummaryDto>.Ok(dto, "Audit summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminAuditEventRowDto>>> ListAsync(
        DateOnly? date,
        string? category,
        string? search,
        string? outcome,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        if (!TryParseCategory(category, out var catFilter, out var catError))
        {
            return ServiceResult<IReadOnlyList<AdminAuditEventRowDto>>.Fail(400, catError!);
        }

        var query = _db.AuditLogs.AsNoTracking()
            .Where(item => item.OccurredAt >= start && item.OccurredAt < end);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.Action.Contains(term)
                || item.EntityName.Contains(term)
                || item.EntityId.Contains(term)
                || item.UserId.Contains(term)
                || item.Id.ToString().Contains(term));
        }

        var material = await query
            .OrderByDescending(item => item.OccurredAt)
            .ThenByDescending(item => item.Id)
            .ToListAsync(cancellationToken);

        if (catFilter is not null)
        {
            material = material.Where(item => Categorize(item.Action, item.EntityName) == catFilter).ToList();
        }

        // Outcome filter: AuditLog has no outcome column — treat all as Success.
        if (!string.IsNullOrWhiteSpace(outcome)
            && !outcome.Equals("all", StringComparison.OrdinalIgnoreCase)
            && !outcome.Equals("Success", StringComparison.OrdinalIgnoreCase))
        {
            material = [];
        }

        var total = material.Count;
        var pageRows = material.Skip((pageIndex - 1) * size).Take(size).ToList();
        var userIds = pageRows.Select(item => item.UserId).Distinct().ToList();
        var users = await _db.Users.AsNoTracking()
            .Where(user => userIds.Contains(user.Id))
            .Select(user => new { user.Id, user.FullName, user.RiderCode })
            .ToDictionaryAsync(user => user.Id, cancellationToken);

        IReadOnlyList<AdminAuditEventRowDto> data = pageRows.Select(item =>
        {
            users.TryGetValue(item.UserId, out var user);
            var role = string.IsNullOrWhiteSpace(user?.RiderCode) ? "Admin" : "Rider";
            var categoryLabel = Categorize(item.Action, item.EntityName);
            return new AdminAuditEventRowDto(
                item.Id,
                item.OccurredAt,
                item.UserId,
                user?.FullName ?? item.UserId,
                role,
                item.Action,
                item.EntityName,
                item.EntityId,
                categoryLabel,
                "Success",
                $"{item.Action} on {item.EntityName}");
        }).ToList();

        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<AdminAuditEventRowDto>>.Ok(
            data,
            data.Count == 0 ? "No audit events matched the filters." : "Audit events loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<AdminAuditEventDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var item = await _db.AuditLogs.AsNoTracking().FirstOrDefaultAsync(row => row.Id == id, cancellationToken);
        if (item is null)
        {
            return ServiceResult<AdminAuditEventDetailDto>.Fail(404, "Audit event was not found.");
        }

        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(row => row.Id == item.UserId, cancellationToken);
        var role = string.IsNullOrWhiteSpace(user?.RiderCode) ? "Admin" : "Rider";
        var category = Categorize(item.Action, item.EntityName);

        var related = await _db.AuditLogs.AsNoTracking()
            .Where(row => row.EntityName == item.EntityName && row.EntityId == item.EntityId)
            .OrderBy(row => row.OccurredAt)
            .Take(20)
            .ToListAsync(cancellationToken);

        var timeline = related.Select(row => new AdminAuditTimelineItemDto(
            row.Id,
            row.OccurredAt,
            row.Action,
            row.EntityName,
            row.EntityId,
            row.Id == item.Id)).ToList();

        var dto = new AdminAuditEventDetailDto(
            item.Id,
            item.OccurredAt,
            item.UserId,
            user?.FullName ?? item.UserId,
            role,
            item.Action,
            item.EntityName,
            item.EntityId,
            category,
            "Success",
            $"{item.Action} on {item.EntityName}",
            "VerificationUnavailable",
            "AuditLog rows do not store cryptographic hashes in Locked V1.",
            timeline,
            "Before/after field diffs and client IP/device telemetry are not recorded on AuditLog. Only persisted columns are shown.");
        return ServiceResult<AdminAuditEventDetailDto>.Ok(dto, "Audit event loaded.");
    }

    public async Task<ServiceResult<AdminAuditVerifyResultDto>> VerifyAsync(Guid id, CancellationToken cancellationToken)
    {
        var exists = await _db.AuditLogs.AsNoTracking().AnyAsync(item => item.Id == id, cancellationToken);
        if (!exists)
        {
            return ServiceResult<AdminAuditVerifyResultDto>.Fail(404, "Audit event was not found.");
        }

        var dto = new AdminAuditVerifyResultDto(
            id,
            "VerificationUnavailable",
            "Locked V1 AuditLog has no stored event hash. Verification cannot run without fabricating integrity data.");
        return ServiceResult<AdminAuditVerifyResultDto>.Ok(dto, "Verification unavailable.");
    }

    public async Task<ServiceResult<string>> ExportCsvAsync(
        DateOnly? date,
        string? category,
        string? search,
        CancellationToken cancellationToken)
    {
        var list = await ListAsync(date, category, search, null, 1, 100, cancellationToken);
        if (!list.Success || list.Data is null)
        {
            return ServiceResult<string>.Fail(list.StatusCode, list.Message, list.Errors?.ToArray() ?? []);
        }

        var builder = new StringBuilder();
        builder.AppendLine("OccurredAtUtc,Actor,Role,Action,EntityName,EntityId,Category,Outcome");
        foreach (var row in list.Data)
        {
            builder.AppendLine(string.Join(',',
                Csv(row.OccurredAtUtc.ToString("O", CultureInfo.InvariantCulture)),
                Csv(row.ActorName),
                Csv(row.ActorRole),
                Csv(row.Action),
                Csv(row.EntityName),
                Csv(row.EntityId),
                Csv(row.Category),
                Csv(row.Outcome)));
        }

        return ServiceResult<string>.Ok(builder.ToString(), "Audit CSV export ready.");
    }

    private static string Categorize(string action, string entity) =>
        IsAccess(action, entity) ? "AccessSecurity"
        : IsFinancial(action, entity) ? "FinancialJournal"
        : IsField(action, entity) ? "FieldOperations"
        : IsMaster(action, entity) ? "MasterData"
        : IsAdmin(action, entity) ? "Administrative"
        : "All";

    private static bool IsAccess(string action, string entity) =>
        entity.Equals("User", StringComparison.OrdinalIgnoreCase)
        && (action.Contains("Login", StringComparison.OrdinalIgnoreCase)
            || action.Contains("Logout", StringComparison.OrdinalIgnoreCase)
            || action.Contains("Password", StringComparison.OrdinalIgnoreCase));

    private static bool IsFinancial(string action, string entity) =>
        entity is "Sale" or "Collection" or "Settlement"
        || action.Contains("Sale", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Collection", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Settlement", StringComparison.OrdinalIgnoreCase);

    private static bool IsField(string action, string entity) =>
        entity is "CustomerOrder" or "Shift" or "Customer"
        || action.Contains("Shift", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Visit", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Assign", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Dispatch", StringComparison.OrdinalIgnoreCase)
        || action.Contains("PickList", StringComparison.OrdinalIgnoreCase);

    private static bool IsMaster(string action, string entity) =>
        entity is "Depot" or "Zone" or "DeliveryRoute" or "Product"
        || action.Contains("Depot", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Zone", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Route", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Price", StringComparison.OrdinalIgnoreCase);

    private static bool IsAdmin(string action, string entity) =>
        action.Contains("CreateUser", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Onboarding", StringComparison.OrdinalIgnoreCase)
        || action.Contains("Admin", StringComparison.OrdinalIgnoreCase)
        || entity.Equals("OnboardingStep", StringComparison.OrdinalIgnoreCase)
        || entity.Equals("BusinessProfile", StringComparison.OrdinalIgnoreCase);

    private static bool TryParseCategory(string? value, out string? filter, out string? error)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            filter = null;
            error = null;
            return true;
        }

        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["FinancialJournal"] = "FinancialJournal",
            ["Financial"] = "FinancialJournal",
            ["FieldOperations"] = "FieldOperations",
            ["Field"] = "FieldOperations",
            ["AccessSecurity"] = "AccessSecurity",
            ["Access"] = "AccessSecurity",
            ["MasterData"] = "MasterData",
            ["Master"] = "MasterData",
            ["Administrative"] = "Administrative"
        };
        if (map.TryGetValue(value.Trim(), out var parsed))
        {
            filter = parsed;
            error = null;
            return true;
        }

        filter = null;
        error = "Category must be All, FinancialJournal, FieldOperations, AccessSecurity, or MasterData.";
        return false;
    }

    private static string Csv(string value)
    {
        if (value.Contains('"') || value.Contains(',') || value.Contains('\n'))
        {
            return $"\"{value.Replace("\"", "\"\"")}\"";
        }

        return value;
    }
}
