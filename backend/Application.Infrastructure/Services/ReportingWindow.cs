using RouteLedger.Domain;

namespace RouteLedger.Infrastructure.Services;

/// <summary>
/// Command and rider reports use the server's local calendar.
/// Default day is <see cref="DateOnly.FromDateTime(DateTime)"/> of <see cref="DateTime.Today"/>,
/// the same clock as the rider field dashboard. A date becomes the half-open UTC interval
/// from that local midnight to the next local midnight.
/// </summary>
internal static class ReportingWindow
{
    public static DateOnly Today() => DateOnly.FromDateTime(DateTime.Today);

    public static bool TryResolve(DateOnly? from, DateOnly? to, out DateOnly start, out DateOnly end, out string? error)
    {
        if (from is null && to is null)
        {
            start = end = Today();
            error = null;
            return true;
        }

        start = from ?? to!.Value;
        end = to ?? from!.Value;
        if (end < start)
        {
            error = "The end date is before the start date.";
            return false;
        }

        error = null;
        return true;
    }

    public static (DateTime StartUtc, DateTime EndUtcExclusive) UtcBounds(DateOnly from, DateOnly to)
    {
        var startLocal = DateTime.SpecifyKind(from.ToDateTime(TimeOnly.MinValue), DateTimeKind.Local);
        var endLocal = DateTime.SpecifyKind(to.AddDays(1).ToDateTime(TimeOnly.MinValue), DateTimeKind.Local);
        return (startLocal.ToUniversalTime(), endLocal.ToUniversalTime());
    }

    public static (int Page, int PageSize) NormalizePage(int page, int pageSize)
    {
        var size = pageSize < 1 ? 20 : Math.Min(pageSize, 100);
        var index = page < 1 ? 1 : page;
        return (index, size);
    }

    public static decimal Percent(decimal part, decimal whole) =>
        whole == 0 ? 0 : Math.Round(part / whole * 100m, 2, MidpointRounding.AwayFromZero);

    public static string Sync(SyncStatus status) => status switch
    {
        SyncStatus.Failed => "Failed",
        SyncStatus.Pending => "Pending",
        _ => "Synced"
    };

    public static bool TrySyncFilter(string? value, out SyncStatus? status, out string? error)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            status = null;
            error = null;
            return true;
        }

        if (Enum.TryParse<SyncStatus>(value.Trim(), true, out var parsed) && Enum.IsDefined(parsed))
        {
            status = parsed;
            error = null;
            return true;
        }

        status = null;
        error = "Status must be Pending, Synced, or Failed.";
        return false;
    }
}
