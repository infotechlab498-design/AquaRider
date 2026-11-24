using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminReportsService : IAdminReportsService
{
    private static readonly AdminReportCatalogItemDto[] Catalog =
    [
        new("daily-sales", "Daily Sales & Tender Settlement", "Posted sales totals and cash vs credit split by day.", "Financial", "CSV", null),
        new("collections-cash", "Cash Collections Ledger", "Cash collections with rider and remaining balance.", "Financial", "CSV", null),
        new("receivables-aging", "Customer Aging & Receivables", "Outstanding balances with simple aging bands.", "Customer & Asset", "CSV", null),
        new("rider-productivity", "Rider Productivity Snapshot", "Completed stops and cash recovery by rider.", "Operations", "CSV", null),
        new("asset-circulation", "Returnable 19L Asset Audit", "Issued, returned and store float for returnable bottles.", "Customer & Asset", "CSV", null),
        new("fulfillment-sla", "Delivery Fulfillment Snapshot", "Route stop outcomes for the selected period.", "Operations", "CSV", null)
    ];

    private readonly AppDbContext _db;

    public AdminReportsService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<ServiceResult<AdminReportsSummaryDto>> SummaryAsync(
        DateOnly? from,
        DateOnly? to,
        CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<AdminReportsSummaryDto>.Fail(400, error!);
        }

        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var days = end.DayNumber - start.DayNumber + 1;
        var previousEnd = start.AddDays(-1);
        var previousStart = previousEnd.AddDays(-(days - 1));
        var (prevStart, prevEnd) = ReportingWindow.UtcBounds(previousStart, previousEnd);

        var sales = await _db.Sales.AsNoTracking()
            .Where(item => item.Status == SaleStatus.Completed
                && item.CreatedAt >= rangeStart
                && item.CreatedAt < rangeEnd)
            .ToListAsync(cancellationToken);
        var previousSales = await _db.Sales.AsNoTracking()
            .Where(item => item.Status == SaleStatus.Completed
                && item.CreatedAt >= prevStart
                && item.CreatedAt < prevEnd)
            .SumAsync(item => (decimal?)item.SaleAmount, cancellationToken) ?? 0;
        var billed = sales.Sum(item => item.SaleAmount);
        decimal? salesChange = previousSales == 0
            ? null
            : ReportingWindow.Percent(billed - previousSales, previousSales);

        var collections = await _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd)
            .ToListAsync(cancellationToken);
        var received = collections.Sum(item => item.Amount);
        decimal? recovery = billed == 0 ? null : ReportingWindow.Percent(received, billed);

        var debtors = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted && item.Outstanding > 0)
            .Select(item => new { item.Outstanding, item.LastPaymentAt, item.CreditDays })
            .ToListAsync(cancellationToken);
        var floatAmount = debtors.Sum(item => item.Outstanding);
        var today = DateTime.Today;
        double? avgAge = debtors.Count == 0
            ? null
            : debtors.Average(item =>
            {
                var anchor = item.LastPaymentAt?.Date ?? today.AddDays(-item.CreditDays);
                return Math.Max(0, (today - anchor).TotalDays);
            });

        var stops = await _db.RouteStops.AsNoTracking()
            .Where(item => item.ServiceDate >= start && item.ServiceDate <= end)
            .GroupBy(item => item.Status)
            .Select(group => new { Status = group.Key, Count = group.Count() })
            .ToListAsync(cancellationToken);
        var totalStops = stops.Sum(item => item.Count);
        var completed = stops.Where(item => item.Status == StopStatus.Completed).Sum(item => item.Count);
        var missed = stops.Where(item => item.Status == StopStatus.Missed).Sum(item => item.Count);
        var pending = stops.Where(item => item.Status == StopStatus.Pending).Sum(item => item.Count);
        var inProgress = stops.Where(item => item.Status == StopStatus.InProgress).Sum(item => item.Count);

        var riders = await _db.Users.AsNoTracking()
            .Where(user => user.RiderCode != null && user.RiderCode != "")
            .Select(user => new { user.Id, user.FullName, user.IsActive, RouteName = user.Route != null ? user.Route.Name : null })
            .ToListAsync(cancellationToken);
        var activeRiders = riders.Count(item => item.IsActive);
        var openShifts = await _db.Shifts.AsNoTracking()
            .Where(item => item.ServiceDate >= start && item.ServiceDate <= end && item.Status == "Open")
            .Select(item => item.RiderId)
            .Distinct()
            .CountAsync(cancellationToken);

        var salesSeries = BuildSeries(start, end, sales.Select(item => (DateOnly.FromDateTime(item.CreatedAt.ToLocalTime()), item.SaleAmount)));
        var collectionSeries = BuildSeries(start, end, collections.Select(item => (DateOnly.FromDateTime(item.CreatedAt.ToLocalTime()), item.Amount)));

        var fulfillment = new List<AdminFulfillmentSliceDto>
        {
            Slice("Fulfilled", completed, totalStops),
            Slice("Pending", pending, totalStops),
            Slice("In Progress", inProgress, totalStops),
            Slice("Missed", missed, totalStops)
        };

        var leaderboard = await BuildLeaderboardAsync(start, end, rangeStart, rangeEnd, cancellationToken);
        var assets = await BuildAssetsAsync(cancellationToken);

        var dto = new AdminReportsSummaryDto(
            start,
            end,
            billed,
            salesChange,
            received,
            recovery,
            floatAmount,
            debtors.Count,
            avgAge is null ? null : Math.Round((decimal)avgAge.Value, 1, MidpointRounding.AwayFromZero),
            completed,
            totalStops == 0 ? null : ReportingWindow.Percent(completed, totalStops),
            totalStops,
            riders.Count,
            riders.Count == 0 ? null : ReportingWindow.Percent(activeRiders, riders.Count),
            salesSeries,
            collectionSeries,
            fulfillment,
            leaderboard,
            assets,
            "Locked V1 analytics from SQL. PDF/XLSX, auto-export schedules and geofence accuracy are not activated.");
        return ServiceResult<AdminReportsSummaryDto>.Ok(dto, "Reports summary loaded.");
    }

    public Task<ServiceResult<IReadOnlyList<AdminReportCatalogItemDto>>> CatalogAsync(CancellationToken cancellationToken)
    {
        IReadOnlyList<AdminReportCatalogItemDto> items = Catalog;
        return Task.FromResult(ServiceResult<IReadOnlyList<AdminReportCatalogItemDto>>.Ok(items, "Report catalog loaded."));
    }

    public async Task<ServiceResult<AdminReportTableDto>> RunAsync(
        string key,
        DateOnly? from,
        DateOnly? to,
        CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<AdminReportTableDto>.Fail(400, error!);
        }

        var item = Catalog.FirstOrDefault(row => row.Key.Equals(key, StringComparison.OrdinalIgnoreCase));
        if (item is null)
        {
            return ServiceResult<AdminReportTableDto>.Fail(404, "Report template was not found.");
        }

        var table = await BuildTableAsync(item, start, end, cancellationToken);
        return ServiceResult<AdminReportTableDto>.Ok(table, "Report generated.");
    }

    public async Task<ServiceResult<string>> ExportCsvAsync(
        string key,
        DateOnly? from,
        DateOnly? to,
        CancellationToken cancellationToken)
    {
        var run = await RunAsync(key, from, to, cancellationToken);
        if (!run.Success || run.Data is null)
        {
            return ServiceResult<string>.Fail(run.StatusCode, run.Message, run.Errors?.ToArray() ?? []);
        }

        var table = run.Data;
        var builder = new StringBuilder();
        builder.AppendLine(string.Join(',', table.Columns.Select(Csv)));
        foreach (var row in table.Rows)
        {
            builder.AppendLine(string.Join(',', row.Select(Csv)));
        }

        return ServiceResult<string>.Ok(builder.ToString(), "CSV export ready.");
    }

    private async Task<AdminReportTableDto> BuildTableAsync(
        AdminReportCatalogItemDto item,
        DateOnly start,
        DateOnly end,
        CancellationToken cancellationToken)
    {
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        return item.Key switch
        {
            "daily-sales" => await DailySalesAsync(item, rangeStart, rangeEnd, cancellationToken),
            "collections-cash" => await CollectionsCashAsync(item, rangeStart, rangeEnd, cancellationToken),
            "receivables-aging" => await ReceivablesAsync(item, cancellationToken),
            "rider-productivity" => await RiderTableAsync(item, start, end, rangeStart, rangeEnd, cancellationToken),
            "asset-circulation" => await AssetTableAsync(item, cancellationToken),
            "fulfillment-sla" => await FulfillmentTableAsync(item, start, end, cancellationToken),
            _ => new AdminReportTableDto(item.Key, item.Name, item.Category, ["Message"], [["Unsupported"]], DateTime.UtcNow)
        };
    }

    private async Task<AdminReportTableDto> DailySalesAsync(
        AdminReportCatalogItemDto item,
        DateTime rangeStart,
        DateTime rangeEnd,
        CancellationToken cancellationToken)
    {
        var rows = await _db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed
                && sale.CreatedAt >= rangeStart
                && sale.CreatedAt < rangeEnd)
            .OrderByDescending(sale => sale.CreatedAt)
            .Select(sale => new
            {
                sale.ReceiptNumber,
                sale.CreatedAt,
                sale.SaleAmount,
                sale.AmountReceived,
                Channel = sale.PaymentChannel.HasValue ? sale.PaymentChannel.Value.ToString() : "Unpaid",
                sale.Customer.BusinessName,
                sale.Customer.Code
            })
            .ToListAsync(cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Receipt", "CreatedAtUtc", "Customer", "Code", "Gross", "Received", "Channel"],
            rows.Select(row => (IReadOnlyList<string>)
            [
                row.ReceiptNumber,
                row.CreatedAt.ToString("O"),
                row.BusinessName,
                row.Code,
                Money(row.SaleAmount),
                Money(row.AmountReceived),
                row.Channel
            ]).ToList(),
            DateTime.UtcNow);
    }

    private async Task<AdminReportTableDto> CollectionsCashAsync(
        AdminReportCatalogItemDto item,
        DateTime rangeStart,
        DateTime rangeEnd,
        CancellationToken cancellationToken)
    {
        var rows = await _db.Collections.AsNoTracking()
            .Include(row => row.Customer)
            .Where(row => row.CreatedAt >= rangeStart && row.CreatedAt < rangeEnd && row.Channel == PaymentChannel.Cash)
            .OrderByDescending(row => row.CreatedAt)
            .ToListAsync(cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Reference", "CreatedAtUtc", "Customer", "Amount", "WHT", "Before", "After", "Sync"],
            rows.Select(row => (IReadOnlyList<string>)
            [
                row.ReferenceNumber,
                row.CreatedAt.ToString("O"),
                row.Customer.BusinessName,
                Money(row.Amount),
                Money(row.WithholdingTax),
                Money(row.OutstandingBefore),
                Money(row.OutstandingAfter),
                ReportingWindow.Sync(row.SyncStatus)
            ]).ToList(),
            DateTime.UtcNow);
    }

    private async Task<AdminReportTableDto> ReceivablesAsync(
        AdminReportCatalogItemDto item,
        CancellationToken cancellationToken)
    {
        var today = DateTime.Today;
        var rows = await _db.Customers.AsNoTracking()
            .Where(row => !row.IsDeleted && row.Outstanding > 0)
            .OrderByDescending(row => row.Outstanding)
            .ToListAsync(cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Code", "Customer", "Area", "Outstanding", "CreditDays", "DaysOverdue"],
            rows.Select(row =>
            {
                var anchor = row.LastPaymentAt?.Date ?? today.AddDays(-row.CreditDays - 1);
                var overdue = Math.Max(0, (int)Math.Floor((today - anchor).TotalDays) - row.CreditDays);
                return (IReadOnlyList<string>)
                [
                    row.Code,
                    row.BusinessName,
                    row.Area,
                    Money(row.Outstanding),
                    row.CreditDays.ToString(CultureInfo.InvariantCulture),
                    overdue.ToString(CultureInfo.InvariantCulture)
                ];
            }).ToList(),
            DateTime.UtcNow);
    }

    private async Task<AdminReportTableDto> RiderTableAsync(
        AdminReportCatalogItemDto item,
        DateOnly start,
        DateOnly end,
        DateTime rangeStart,
        DateTime rangeEnd,
        CancellationToken cancellationToken)
    {
        var board = await BuildLeaderboardAsync(start, end, rangeStart, rangeEnd, cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Rider", "Route", "Recovery", "Stops", "OnTimePercent"],
            board.Select(row => (IReadOnlyList<string>)
            [
                row.RiderName,
                row.RouteName ?? "",
                Money(row.RecoveryAmount),
                row.StopsCompleted.ToString(CultureInfo.InvariantCulture),
                row.OnTimePercent?.ToString(CultureInfo.InvariantCulture) ?? ""
            ]).ToList(),
            DateTime.UtcNow);
    }

    private async Task<AdminReportTableDto> AssetTableAsync(
        AdminReportCatalogItemDto item,
        CancellationToken cancellationToken)
    {
        var assets = await BuildAssetsAsync(cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Metric", "Value"],
            [
                ["Issued", assets.Issued.ToString(CultureInfo.InvariantCulture)],
                ["Recovered", assets.Recovered.ToString(CultureInfo.InvariantCulture)],
                ["StoreFloat", assets.StoreFloat.ToString(CultureInfo.InvariantCulture)],
                ["Scrap", assets.Scrap.ToString(CultureInfo.InvariantCulture)],
                ["ClearedPercent", assets.ClearedPercent.ToString(CultureInfo.InvariantCulture)]
            ],
            DateTime.UtcNow);
    }

    private async Task<AdminReportTableDto> FulfillmentTableAsync(
        AdminReportCatalogItemDto item,
        DateOnly start,
        DateOnly end,
        CancellationToken cancellationToken)
    {
        var rows = await _db.RouteStops.AsNoTracking()
            .Where(stop => stop.ServiceDate >= start && stop.ServiceDate <= end)
            .GroupBy(stop => stop.Status)
            .Select(group => new { Status = group.Key.ToString(), Count = group.Count() })
            .ToListAsync(cancellationToken);
        return new AdminReportTableDto(
            item.Key,
            item.Name,
            item.Category,
            ["Status", "Count"],
            rows.Select(row => (IReadOnlyList<string>)
            [
                row.Status,
                row.Count.ToString(CultureInfo.InvariantCulture)
            ]).ToList(),
            DateTime.UtcNow);
    }

    private async Task<IReadOnlyList<AdminRiderProductivityDto>> BuildLeaderboardAsync(
        DateOnly start,
        DateOnly end,
        DateTime rangeStart,
        DateTime rangeEnd,
        CancellationToken cancellationToken)
    {
        var riders = await _db.Users.AsNoTracking()
            .Where(user => user.RiderCode != null && user.RiderCode != "")
            .Select(user => new { user.Id, user.FullName, RouteName = user.Route != null ? user.Route.Name : null, user.RouteId })
            .ToListAsync(cancellationToken);
        var recovery = await _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd)
            .GroupBy(item => item.RiderId)
            .Select(group => new { RiderId = group.Key, Amount = group.Sum(item => item.Amount) })
            .ToDictionaryAsync(item => item.RiderId, item => item.Amount, cancellationToken);
        var stops = await _db.RouteStops.AsNoTracking()
            .Where(stop => stop.ServiceDate >= start && stop.ServiceDate <= end)
            .GroupBy(stop => stop.RouteId)
            .Select(group => new
            {
                RouteId = group.Key,
                Completed = group.Count(stop => stop.Status == StopStatus.Completed),
                Total = group.Count()
            })
            .ToDictionaryAsync(item => item.RouteId, cancellationToken);

        return riders
            .Select(rider =>
            {
                recovery.TryGetValue(rider.Id, out var amount);
                var completed = 0;
                decimal? onTime = null;
                if (rider.RouteId is Guid routeId && stops.TryGetValue(routeId, out var stopStats))
                {
                    completed = stopStats.Completed;
                    onTime = stopStats.Total == 0
                        ? null
                        : ReportingWindow.Percent(stopStats.Completed, stopStats.Total);
                }

                return new AdminRiderProductivityDto(
                    rider.Id,
                    rider.FullName,
                    rider.RouteName,
                    amount,
                    completed,
                    onTime);
            })
            .OrderByDescending(item => item.RecoveryAmount)
            .ThenByDescending(item => item.StopsCompleted)
            .Take(10)
            .ToList();
    }

    private async Task<AdminAssetCirculationDto> BuildAssetsAsync(CancellationToken cancellationToken)
    {
        var issued = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .SumAsync(item => (int?)item.BottlesIssued, cancellationToken) ?? 0;
        var recovered = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .SumAsync(item => (int?)item.BottlesReturned, cancellationToken) ?? 0;
        var storeFloat = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .SumAsync(item => (int?)item.BottlesHeld, cancellationToken) ?? 0;
        var cleared = issued == 0 ? 0 : ReportingWindow.Percent(recovered, issued);
        return new AdminAssetCirculationDto(issued, recovered, storeFloat, 0, cleared);
    }

    private static List<AdminReportSeriesPointDto> BuildSeries(
        DateOnly start,
        DateOnly end,
        IEnumerable<(DateOnly Day, decimal Amount)> points)
    {
        var map = points
            .GroupBy(item => item.Day)
            .ToDictionary(group => group.Key, group => group.Sum(item => item.Amount));
        var series = new List<AdminReportSeriesPointDto>();
        for (var day = start; day <= end; day = day.AddDays(1))
        {
            map.TryGetValue(day, out var amount);
            series.Add(new AdminReportSeriesPointDto(day, amount));
        }

        return series;
    }

    private static AdminFulfillmentSliceDto Slice(string label, int count, int total) =>
        new(label, count, total == 0 ? 0 : ReportingWindow.Percent(count, total));

    private static string Money(decimal value) =>
        value.ToString("0.00", CultureInfo.InvariantCulture);

    private static string Csv(string value)
    {
        if (value.Contains('"') || value.Contains(',') || value.Contains('\n'))
        {
            return $"\"{value.Replace("\"", "\"\"")}\"";
        }

        return value;
    }
}
