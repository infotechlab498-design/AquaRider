using System.Globalization;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class CommandDashboardService : ICommandDashboardService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public CommandDashboardService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<CommandOverviewDto>> OverviewAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<CommandOverviewDto>.Fail(400, error!);
        }

        var admin = await AdminAsync(cancellationToken);
        if (admin is null)
        {
            return ServiceResult<CommandOverviewDto>.Fail(401, "Sign in required.");
        }

        var profile = await _db.BusinessProfiles.AsNoTracking()
            .OrderBy(item => item.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var depot = await _db.Depots.AsNoTracking()
            .OrderBy(item => item.Name)
            .Select(item => item.Name)
            .FirstOrDefaultAsync(cancellationToken);
        var riders = await CountRidersAsync(cancellationToken);
        var display = DisplayName(profile);
        var hour = DateTime.Now.Hour;
        var part = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening";
        var first = admin.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? admin.FullName;
        var greeting = string.IsNullOrWhiteSpace(first) ? $"Good {part}" : $"Good {part}, {first}";
        var dto = new CommandOverviewDto(
            greeting,
            admin.FullName,
            display,
            depot ?? "",
            new CommandPeriodDto(start, end),
            new CommandReadyFlagsDto(
                profile is not null,
                profile?.Status == "Ready",
                !string.IsNullOrWhiteSpace(depot),
                riders > 0));
        return ServiceResult<CommandOverviewDto>.Ok(dto, "Command overview loaded.");
    }

    public async Task<ServiceResult<CommandKpisDto>> KpisAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<CommandKpisDto>.Fail(400, error!);
        }

        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var sales = CompletedSales(rangeStart, rangeEnd);
        var billed = await sales.SumAsync(sale => (decimal?)sale.SaleAmount, cancellationToken) ?? 0;
        var invoices = await sales.CountAsync(cancellationToken);

        var days = end.DayNumber - start.DayNumber + 1;
        var previousEnd = start.AddDays(-1);
        var previousStart = previousEnd.AddDays(-(days - 1));
        var (previousRangeStart, previousRangeEnd) = ReportingWindow.UtcBounds(previousStart, previousEnd);
        var previousSales = CompletedSales(previousRangeStart, previousRangeEnd);
        var previousInvoices = await previousSales.CountAsync(cancellationToken);
        decimal? previousAmount = null;
        decimal? changeAmount = null;
        decimal? changePercent = null;
        if (previousInvoices > 0)
        {
            previousAmount = await previousSales.SumAsync(sale => (decimal?)sale.SaleAmount, cancellationToken) ?? 0;
            changeAmount = billed - previousAmount.Value;
            changePercent = previousAmount.Value == 0
                ? null
                : ReportingWindow.Percent(changeAmount.Value, previousAmount.Value);
        }

        var collections = _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd);
        var received = await collections.SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var collectionCount = await collections.CountAsync(cancellationToken);
        decimal? recovery = billed > 0 ? ReportingWindow.Percent(received, billed) : null;

        var fleetRegistered = await CountRidersAsync(cancellationToken);
        var fleetOnDuty = await _db.Shifts.AsNoTracking()
            .Where(shift => shift.Status == "Open" && shift.ServiceDate >= start && shift.ServiceDate <= end)
            .Select(shift => shift.RiderId)
            .Distinct()
            .CountAsync(cancellationToken);

        var stops = _db.RouteStops.AsNoTracking()
            .Where(stop => stop.ServiceDate >= start && stop.ServiceDate <= end);
        var deliveriesTotal = await stops.CountAsync(cancellationToken);
        var deliveriesCompleted = await stops.CountAsync(stop => stop.Status == StopStatus.Completed, cancellationToken);

        var scheduled = _db.CustomerOrders.AsNoTracking()
            .Where(order => order.Status == CustomerOrderStatus.Scheduled);
        var pendingOrders = await scheduled.CountAsync(cancellationToken);
        var unassignedOrders = await scheduled.CountAsync(order => order.RiderId.Trim() == "", cancellationToken);

        var customers = _db.Customers.AsNoTracking().Where(customer => !customer.IsDeleted);
        var outstanding = await customers.SumAsync(customer => (decimal?)customer.Outstanding, cancellationToken) ?? 0;
        var accounts = await customers.CountAsync(customer => customer.Outstanding > 0, cancellationToken);

        var dto = new CommandKpisDto(
            new CommandPeriodDto(start, end),
            new CommandSalesKpiDto(billed, invoices, previousAmount, changeAmount, changePercent),
            new CommandCollectionsKpiDto(received, collectionCount, recovery),
            new CommandFleetKpiDto(fleetRegistered, fleetOnDuty),
            new CommandDeliveriesKpiDto(
                deliveriesCompleted,
                deliveriesTotal,
                ReportingWindow.Percent(deliveriesCompleted, deliveriesTotal)),
            new CommandOrdersKpiDto(pendingOrders, unassignedOrders),
            new CommandOutstandingKpiDto(outstanding, accounts));
        return ServiceResult<CommandKpisDto>.Ok(dto, "Command KPIs loaded.");
    }

    public async Task<ServiceResult<OperationalSummaryDto>> OperationalSummaryAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<OperationalSummaryDto>.Fail(400, error!);
        }

        var orders = _db.CustomerOrders.AsNoTracking()
            .Where(order => order.DeliveryDate >= start && order.DeliveryDate <= end);
        var orderTotal = await orders.CountAsync(cancellationToken);
        var unassigned = await orders.CountAsync(order => order.RiderId.Trim() == "", cancellationToken);
        var scheduled = await orders.CountAsync(order => order.Status == CustomerOrderStatus.Scheduled, cancellationToken);
        var delivered = await orders.CountAsync(order => order.Status == CustomerOrderStatus.Delivered, cancellationToken);
        var cancelled = await orders.CountAsync(order => order.Status == CustomerOrderStatus.Cancelled, cancellationToken);

        var stops = _db.RouteStops.AsNoTracking()
            .Where(stop => stop.ServiceDate >= start && stop.ServiceDate <= end);
        var stopTotal = await stops.CountAsync(cancellationToken);
        var completed = await stops.CountAsync(stop => stop.Status == StopStatus.Completed, cancellationToken);
        var pending = await stops.CountAsync(stop => stop.Status == StopStatus.Pending, cancellationToken);
        var missed = await stops.CountAsync(stop => stop.Status == StopStatus.Missed, cancellationToken);
        var inProgress = await stops.CountAsync(stop => stop.Status == StopStatus.InProgress, cancellationToken);

        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var recent = await _db.ActivityLogs.AsNoTracking()
            .Where(log => log.OccurredAt >= rangeStart && log.OccurredAt < rangeEnd)
            .OrderByDescending(log => log.OccurredAt)
            .Take(10)
            .Select(log => new RecentActivityDto(
                log.Id,
                log.Title,
                log.Reference,
                log.Detail,
                log.Amount,
                log.SyncStatus == SyncStatus.Failed ? "Failed" : log.SyncStatus == SyncStatus.Pending ? "Pending" : "Synced",
                log.OccurredAt,
                log.UserId))
            .ToListAsync(cancellationToken);

        var dto = new OperationalSummaryDto(
            new CommandPeriodDto(start, end),
            new OperationalOrdersDto(orderTotal, orderTotal - unassigned, unassigned, scheduled, delivered, cancelled),
            new OperationalStopsDto(stopTotal, completed, pending, missed, inProgress),
            recent);
        return ServiceResult<OperationalSummaryDto>.Ok(dto, "Operational summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AttentionItemDto>>> AttentionItemsAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<IReadOnlyList<AttentionItemDto>>.Fail(400, error!);
        }

        var items = new List<AttentionItemDto>();
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);

        if (end == ReportingWindow.Today())
        {
            var roleId = await RiderRoleIdAsync(cancellationToken);
            if (roleId is not null)
            {
                var active = await _db.Users.AsNoTracking()
                    .Where(user => user.IsActive && _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId))
                    .Select(user => new { user.Id, user.FullName })
                    .ToListAsync(cancellationToken);
                var open = await _db.Shifts.AsNoTracking()
                    .Where(shift => shift.Status == "Open" && shift.ServiceDate == end)
                    .Select(shift => shift.RiderId)
                    .ToListAsync(cancellationToken);
                var openIds = open.ToHashSet();
                var dutyStart = ReportingWindow.UtcBounds(end, end).StartUtc;
                foreach (var rider in active.Where(rider => !openIds.Contains(rider.Id)))
                {
                    items.Add(new AttentionItemDto(
                        $"shift-missing:{rider.Id}:{end:yyyy-MM-dd}",
                        "warning",
                        $"{rider.FullName} has not opened a shift",
                        $"No open shift on {end:yyyy-MM-dd}.",
                        dutyStart,
                        "Open",
                        "View rider",
                        $"/rider-operations/riders/{rider.Id}"));
                }
            }
        }

        var failedSales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.SyncStatus == SyncStatus.Failed && sale.CreatedAt >= rangeStart && sale.CreatedAt < rangeEnd)
            .Select(sale => new { sale.Id, sale.ReceiptNumber, sale.CreatedAt, Customer = sale.Customer.BusinessName })
            .ToListAsync(cancellationToken);
        foreach (var sale in failedSales)
        {
            items.Add(new AttentionItemDto(
                $"sale-sync:{sale.Id}",
                "high",
                "Sale failed to sync",
                $"{sale.ReceiptNumber} · {sale.Customer}",
                sale.CreatedAt,
                "Open",
                "Review sale",
                "/dashboard/activity-ledger?search=" + Uri.EscapeDataString(sale.ReceiptNumber)));
        }

        var failedLogs = await _db.ActivityLogs.AsNoTracking()
            .Where(log => log.SyncStatus == SyncStatus.Failed && log.OccurredAt >= rangeStart && log.OccurredAt < rangeEnd)
            .Select(log => new { log.Id, log.Title, log.Reference, log.OccurredAt })
            .ToListAsync(cancellationToken);
        foreach (var log in failedLogs)
        {
            items.Add(new AttentionItemDto(
                $"activity-sync:{log.Id}",
                "high",
                "Activity failed to sync",
                $"{log.Title} · {log.Reference}",
                log.OccurredAt,
                "Open",
                "Review activity",
                "/dashboard/activity-ledger?search=" + Uri.EscapeDataString(log.Reference)));
        }

        var unassigned = await _db.CustomerOrders.AsNoTracking()
            .Where(order => order.Status == CustomerOrderStatus.Scheduled
                && order.DeliveryDate >= start
                && order.DeliveryDate <= end
                && order.RiderId.Trim() == "")
            .Select(order => new { order.Id, order.ReferenceNumber, order.CreatedAt, order.DeliveryDate, Customer = order.Customer.BusinessName })
            .ToListAsync(cancellationToken);
        foreach (var order in unassigned)
        {
            items.Add(new AttentionItemDto(
                $"order-unassigned:{order.Id}",
                "high",
                "Order has no rider",
                $"{order.ReferenceNumber} · {order.Customer} · {order.DeliveryDate:yyyy-MM-dd}",
                order.CreatedAt,
                "Open",
                "Assign rider",
                "/dashboard/orders"));
        }

        IReadOnlyList<AttentionItemDto> ordered = items
            .OrderBy(item => item.Severity == "high" ? 0 : 1)
            .ThenByDescending(item => item.CreatedAtUtc)
            .ToList();
        var message = ordered.Count == 0 ? "No exceptions in this period." : "Attention items loaded.";
        return ServiceResult<IReadOnlyList<AttentionItemDto>>.Ok(ordered, message);
    }

    public async Task<ServiceResult<SalesSummaryDto>> SalesSummaryAsync(DateOnly? from, DateOnly? to, string? bucket, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<SalesSummaryDto>.Fail(400, error!);
        }

        var requested = string.IsNullOrWhiteSpace(bucket) ? "auto" : bucket.Trim().ToLowerInvariant();
        var sameDay = start == end;
        string applied;
        if (requested is "auto")
        {
            applied = sameDay ? "hour" : "day";
        }
        else if (requested is "hour" or "day")
        {
            applied = requested == "hour" && !sameDay ? "day" : requested;
        }
        else
        {
            return ServiceResult<SalesSummaryDto>.Fail(400, "Bucket must be hour or day.");
        }

        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var hourRows = await CompletedSales(rangeStart, rangeEnd)
            .GroupBy(sale => new { sale.CreatedAt.Year, sale.CreatedAt.Month, sale.CreatedAt.Day, sale.CreatedAt.Hour })
            .Select(group => new
            {
                group.Key.Year,
                group.Key.Month,
                group.Key.Day,
                group.Key.Hour,
                Amount = group.Sum(sale => sale.SaleAmount),
                Count = group.Count()
            })
            .ToListAsync(cancellationToken);

        var useHour = applied == "hour";
        var buckets = hourRows
            .Select(row =>
            {
                var utc = new DateTime(row.Year, row.Month, row.Day, row.Hour, 0, 0, DateTimeKind.Utc);
                var local = utc.ToLocalTime();
                var bucketStart = useHour
                    ? new DateTime(local.Year, local.Month, local.Day, local.Hour, 0, 0)
                    : local.Date;
                return new { bucketStart, row.Amount, row.Count };
            })
            .GroupBy(row => row.bucketStart)
            .Select(group =>
            {
                var local = DateTime.SpecifyKind(group.Key, DateTimeKind.Local);
                var label = useHour
                    ? local.ToString("yyyy-MM-dd HH:00", CultureInfo.InvariantCulture)
                    : local.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                return new SalesBucketDto(
                    label,
                    local.ToUniversalTime(),
                    group.Sum(row => row.Amount),
                    group.Sum(row => row.Count));
            })
            .OrderBy(bucketRow => bucketRow.BucketStartUtc)
            .ToList();

        var dto = new SalesSummaryDto(
            new CommandPeriodDto(start, end),
            requested,
            applied,
            buckets.Sum(bucketRow => bucketRow.Amount),
            buckets.Sum(bucketRow => bucketRow.InvoiceCount),
            buckets);
        return ServiceResult<SalesSummaryDto>.Ok(dto, "Sales summary loaded.");
    }

    public async Task<ServiceResult<CollectionsSummaryDto>> CollectionsSummaryAsync(DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<CollectionsSummaryDto>.Fail(400, error!);
        }

        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var sales = CompletedSales(rangeStart, rangeEnd);
        var fullCreditAmount = await sales.Where(sale => sale.AmountReceived == 0)
            .SumAsync(sale => (decimal?)sale.SaleAmount, cancellationToken) ?? 0;
        var fullCreditCount = await sales.CountAsync(sale => sale.AmountReceived == 0, cancellationToken);

        var partialSales = sales.Where(sale => sale.AmountReceived > 0 && sale.AmountReceived < sale.SaleAmount + sale.PreviousOutstanding);
        var partialSaleAmount = await partialSales.SumAsync(sale => (decimal?)sale.AmountReceived, cancellationToken) ?? 0;
        var partialSaleCount = await partialSales.CountAsync(cancellationToken);

        var fullCashSales = sales.Where(sale =>
            sale.AmountReceived > 0
            && sale.AmountReceived >= sale.SaleAmount + sale.PreviousOutstanding
            && sale.PaymentChannel == PaymentChannel.Cash);
        var cashSaleAmount = await fullCashSales.SumAsync(sale => (decimal?)sale.AmountReceived, cancellationToken) ?? 0;
        var cashSaleCount = await fullCashSales.CountAsync(cancellationToken);

        var excludedSales = sales.Where(sale =>
            sale.AmountReceived > 0
            && sale.AmountReceived >= sale.SaleAmount + sale.PreviousOutstanding
            && sale.PaymentChannel != PaymentChannel.Cash);
        var excludedSaleAmount = await excludedSales.SumAsync(sale => (decimal?)sale.AmountReceived, cancellationToken) ?? 0;

        var collections = _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd);
        var partialCollections = collections.Where(item => item.Amount < item.OutstandingBefore);
        var partialCollectionAmount = await partialCollections.SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var partialCollectionCount = await partialCollections.CountAsync(cancellationToken);

        var cashCollections = collections.Where(item => item.Channel == PaymentChannel.Cash && item.Amount >= item.OutstandingBefore);
        var cashCollectionAmount = await cashCollections.SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var cashCollectionCount = await cashCollections.CountAsync(cancellationToken);

        var excludedCollections = collections.Where(item => item.Channel != PaymentChannel.Cash && item.Amount >= item.OutstandingBefore);
        var excludedCollectionAmount = await excludedCollections.SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;

        var cash = cashSaleAmount + cashCollectionAmount;
        var fullCredit = fullCreditAmount;
        var partial = partialSaleAmount + partialCollectionAmount;
        var total = cash + fullCredit + partial;
        var excluded = excludedSaleAmount + excludedCollectionAmount;
        var categories = new List<CollectionCategoryDto>
        {
            Slice("Cash", cash, cashSaleCount + cashCollectionCount, total),
            Slice("FullCredit", fullCredit, fullCreditCount, total),
            Slice("PartialCash", partial, partialSaleCount + partialCollectionCount, total)
        };
        var summed = categories.Sum(category => category.Amount);
        string? note = summed == total
            ? "Cash, full credit, and partial cash reconcile to the reported total."
            : null;
        if (note is not null && excluded > 0)
        {
            note += " Bank transfer, wallet, and cheque amounts are omitted from the chart.";
        }

        var dto = new CollectionsSummaryDto(new CommandPeriodDto(start, end), total, categories, note, excluded);
        return ServiceResult<CollectionsSummaryDto>.Ok(dto, "Collections summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<ActivityLedgerRowDto>>> ActivityLedgerAsync(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? status,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        if (!ReportingWindow.TryResolve(from, to, out var start, out var end, out var error))
        {
            return ServiceResult<IReadOnlyList<ActivityLedgerRowDto>>.Fail(400, error!);
        }

        if (!ReportingWindow.TrySyncFilter(status, out var statusFilter, out var statusError))
        {
            return ServiceResult<IReadOnlyList<ActivityLedgerRowDto>>.Fail(400, statusError!);
        }

        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(start, end);
        var hasTerm = !string.IsNullOrWhiteSpace(search);
        var term = hasTerm ? search!.Trim() : "";

        var sales =
            from sale in _db.Sales.AsNoTracking()
            join customer in _db.Customers.AsNoTracking() on sale.CustomerId equals customer.Id
            join rider in _db.Users.AsNoTracking() on sale.RiderId equals rider.Id into riderJoin
            from rider in riderJoin.DefaultIfEmpty()
            where sale.Status == SaleStatus.Completed
                && sale.CreatedAt >= rangeStart
                && sale.CreatedAt < rangeEnd
                && (statusFilter == null || sale.SyncStatus == statusFilter)
                && (!hasTerm
                    || sale.ReceiptNumber.Contains(term)
                    || customer.BusinessName.Contains(term)
                    || (rider.FullName ?? "").Contains(term))
            select new
            {
                ReferenceId = sale.ReceiptNumber,
                CustomerName = customer.BusinessName,
                RiderName = rider.FullName ?? "",
                TransactionType = "Sale",
                Amount = sale.SaleAmount,
                TimestampUtc = sale.CreatedAt,
                SyncCode = sale.SyncStatus == SyncStatus.Failed ? 2 : sale.SyncStatus == SyncStatus.Pending ? 0 : 1
            };

        var collections =
            from item in _db.Collections.AsNoTracking()
            join customer in _db.Customers.AsNoTracking() on item.CustomerId equals customer.Id
            join rider in _db.Users.AsNoTracking() on item.RiderId equals rider.Id into riderJoin
            from rider in riderJoin.DefaultIfEmpty()
            where item.CreatedAt >= rangeStart
                && item.CreatedAt < rangeEnd
                && (statusFilter == null || item.SyncStatus == statusFilter)
                && (!hasTerm
                    || item.ReferenceNumber.Contains(term)
                    || customer.BusinessName.Contains(term)
                    || (rider.FullName ?? "").Contains(term))
            select new
            {
                ReferenceId = item.ReferenceNumber,
                CustomerName = customer.BusinessName,
                RiderName = rider.FullName ?? "",
                TransactionType = "Collection",
                Amount = item.Amount,
                TimestampUtc = item.CreatedAt,
                SyncCode = item.SyncStatus == SyncStatus.Failed ? 2 : item.SyncStatus == SyncStatus.Pending ? 0 : 1
            };

        var ledger = sales.Concat(collections);
        var total = await ledger.CountAsync(cancellationToken);
        var pageRows = await ledger
            .OrderByDescending(row => row.TimestampUtc)
            .ThenBy(row => row.ReferenceId)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .ToListAsync(cancellationToken);
        var rows = pageRows
            .Select(row => new ActivityLedgerRowDto(
                row.ReferenceId,
                row.CustomerName,
                row.RiderName,
                row.TransactionType,
                row.Amount,
                row.TimestampUtc,
                row.SyncCode == 2 ? "Failed" : row.SyncCode == 0 ? "Pending" : "Synced"))
            .ToList();
        var pages = total == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        var meta = new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages };
        return ServiceResult<IReadOnlyList<ActivityLedgerRowDto>>.Ok(rows, "Activity ledger loaded.", meta);
    }

    public async Task<ServiceResult<OrderDto>> CreateOrderAsync(AdminCreateOrderRequest request, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<OrderDto>.Fail(401, "Sign in required.");
        }

        if (request.DeliveryDate == default)
        {
            return ServiceResult<OrderDto>.Fail(400, "Delivery date is required.");
        }

        if (string.IsNullOrWhiteSpace(request.RiderId))
        {
            return ServiceResult<OrderDto>.Fail(400, "Choose a rider.");
        }

        if (!TryWindow(request.Window, out var window))
        {
            return ServiceResult<OrderDto>.Fail(400, "Choose a delivery window.");
        }

        if (request.Lines is null || request.Lines.All(line => line.Quantity <= 0))
        {
            return ServiceResult<OrderDto>.Fail(400, "Add at least one item.");
        }

        if (request.Lines.Any(line => line.Quantity < 0))
        {
            return ServiceResult<OrderDto>.Fail(400, "Quantity cannot be negative.");
        }

        var customer = await _db.Customers
            .FirstOrDefaultAsync(item => item.Id == request.CustomerId && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<OrderDto>.Fail(404, "Customer not found.");
        }

        var riderId = request.RiderId.Trim();
        var roleId = await RiderRoleIdAsync(cancellationToken);
        var rider = await _db.Users.FirstOrDefaultAsync(user => user.Id == riderId, cancellationToken);
        if (rider is null)
        {
            return ServiceResult<OrderDto>.Fail(404, "Rider not found.");
        }

        var isRider = roleId is not null && await _db.UserRoles.AnyAsync(
            link => link.UserId == rider.Id && link.RoleId == roleId,
            cancellationToken);
        if (!isRider)
        {
            return ServiceResult<OrderDto>.Fail(400, "Assign an active rider.");
        }

        if (!rider.IsActive)
        {
            return ServiceResult<OrderDto>.Fail(400, "That rider is not active.");
        }

        var productIds = request.Lines.Where(line => line.Quantity > 0).Select(line => line.ProductId).Distinct().ToList();
        var products = await _db.Products.Where(product => productIds.Contains(product.Id))
            .ToDictionaryAsync(product => product.Id, cancellationToken);
        if (products.Count != productIds.Count)
        {
            return ServiceResult<OrderDto>.Fail(400, "One or more products are not available.");
        }

        var sequence = await _db.NumberSequences.FirstOrDefaultAsync(item => item.Name == "Order", cancellationToken);
        if (sequence is null)
        {
            return ServiceResult<OrderDto>.Fail(500, "Order numbers are not configured.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var value = sequence.NextValue++;
        var lines = request.Lines.Where(line => line.Quantity > 0).Select(line => new OrderLine
        {
            ProductId = line.ProductId,
            Quantity = line.Quantity,
            UnitPrice = products[line.ProductId].UnitPrice
        }).ToList();
        var note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        var order = new CustomerOrder
        {
            ReferenceNumber = $"ORD-{DateTime.Today:yyyyMMdd}-{value:0000}",
            CustomerId = customer.Id,
            RiderId = rider.Id,
            DeliveryDate = request.DeliveryDate,
            Window = window,
            EstimatedValue = lines.Sum(line => line.Quantity * line.UnitPrice),
            Notes = note,
            ShowOnManifest = true,
            Origin = OrderOrigin.Hq,
            Status = CustomerOrderStatus.Scheduled,
            SyncStatus = SyncStatus.Synced,
            Lines = lines
        };
        _db.CustomerOrders.Add(order);
        if (rider.RouteId is Guid routeId)
        {
            await AssignedRouteStop.EnsureAsync(_db, routeId, customer.Id, order.DeliveryDate, cancellationToken);
        }
        _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(
            order.Id,
            OrderLifecycle.OrderCreated,
            "Order created",
            note ?? "Scheduled by dispatch.",
            _current.UserId));
        var title = $"Order — {customer.BusinessName}";
        if (title.Length > 160)
        {
            title = title[..160];
        }

        var detail = note ?? "Scheduled by dispatch.";
        if (detail.Length > 240)
        {
            detail = detail[..240];
        }

        _db.ActivityLogs.Add(new ActivityLog
        {
            UserId = rider.Id,
            Title = title,
            Reference = order.ReferenceNumber,
            Amount = order.EstimatedValue,
            SyncStatus = SyncStatus.Synced,
            Detail = detail
        });
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = "CreateOrder",
            EntityName = "CustomerOrder",
            EntityId = order.Id.ToString()
        });
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        var dto = new OrderDto(
            order.Id,
            order.ReferenceNumber,
            order.CustomerId,
            order.DeliveryDate,
            order.Window.ToString(),
            order.EstimatedValue,
            order.Status.ToString());
        return ServiceResult<OrderDto>.Created(dto, "Order scheduled.");
    }

    private IQueryable<Sale> CompletedSales(DateTime startUtc, DateTime endUtc) =>
        _db.Sales.AsNoTracking().Where(sale =>
            sale.Status == SaleStatus.Completed && sale.CreatedAt >= startUtc && sale.CreatedAt < endUtc);

    private async Task<ApplicationUser?> AdminAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return null;
        }

        return await _db.Users.AsNoTracking()
            .FirstOrDefaultAsync(user => user.Id == _current.UserId, cancellationToken);
    }

    private async Task<string?> RiderRoleIdAsync(CancellationToken cancellationToken) =>
        await _db.Roles.AsNoTracking()
            .Where(role => role.Name == AppRoles.Rider)
            .Select(role => role.Id)
            .FirstOrDefaultAsync(cancellationToken);

    private async Task<int> CountRidersAsync(CancellationToken cancellationToken)
    {
        var roleId = await RiderRoleIdAsync(cancellationToken);
        if (roleId is null)
        {
            return 0;
        }

        return await _db.UserRoles.CountAsync(link => link.RoleId == roleId, cancellationToken);
    }

    private static string DisplayName(BusinessProfile? profile)
    {
        if (profile is null)
        {
            return "";
        }

        if (!string.IsNullOrWhiteSpace(profile.DisplayName))
        {
            return profile.DisplayName.Trim();
        }

        return profile.LegalName.Trim();
    }

    private static CollectionCategoryDto Slice(string category, decimal amount, int count, decimal total) =>
        new(category, amount, count, ReportingWindow.Percent(amount, total));

    private static bool TryWindow(string? value, out DeliveryWindow window)
    {
        var text = (value ?? "").Replace("Window", "", StringComparison.OrdinalIgnoreCase).Trim();
        return Enum.TryParse(text, true, out window) && Enum.IsDefined(window);
    }
}
