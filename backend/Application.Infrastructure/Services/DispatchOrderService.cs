using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class DispatchOrderService : IDispatchOrderService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public DispatchOrderService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<IReadOnlyList<DispatchOrderRowDto>>> OrdersAsync(
        int page,
        int pageSize,
        string? search,
        string? status,
        DateOnly? from,
        DateOnly? to,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken)
    {
        if (!TryWindow(from, to, out var window, out var dateError))
        {
            return ServiceResult<IReadOnlyList<DispatchOrderRowDto>>.Fail(400, dateError!);
        }

        if (!TryStatus(status, out var canonical, out var statusError))
        {
            return ServiceResult<IReadOnlyList<DispatchOrderRowDto>>.Fail(400, statusError!);
        }

        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var filtered = WhereStatus(Filtered(window, search, riderId, unassignedOnly), canonical);
        var total = await filtered.CountAsync(cancellationToken);
        var rows = await filtered
            .OrderByDescending(order => order.DeliveryDate)
            .ThenByDescending(order => order.CreatedAt)
            .ThenBy(order => order.ReferenceNumber)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .Select(order => new OrderPageRow(
                order.Id,
                order.ReferenceNumber,
                order.Customer.BusinessName,
                order.Customer.Code,
                order.Customer.PrimaryMobile,
                order.Customer.Street,
                order.Customer.Area,
                order.Customer.City,
                order.DeliveryDate,
                order.Window,
                order.RiderId,
                order.EstimatedValue,
                order.Status,
                order.SyncStatus,
                order.CreatedAt,
                order.Lines.Count(),
                order.Origin))
            .ToListAsync(cancellationToken);

        var riderIds = rows
            .Select(row => row.RiderId)
            .Where(id => !string.IsNullOrWhiteSpace(id))
            .Distinct()
            .ToList();
        var riders = riderIds.Count == 0
            ? new Dictionary<string, RiderName>()
            : await _db.Users.AsNoTracking()
                .Where(user => riderIds.Contains(user.Id))
                .Select(user => new RiderName(user.Id, user.FullName, user.RiderCode))
                .ToDictionaryAsync(user => user.Id, cancellationToken);

        IReadOnlyList<DispatchOrderRowDto> data = rows.Select(row =>
        {
            riders.TryGetValue(row.RiderId, out var rider);
            var unassigned = string.IsNullOrWhiteSpace(row.RiderId);
            return new DispatchOrderRowDto(
                row.Id,
                row.ReferenceNumber,
                row.CustomerName,
                row.CustomerCode,
                row.CustomerPhone,
                Address(row.Street, row.Area, row.City),
                row.DeliveryDate,
                row.Window.ToString(),
                row.RiderId,
                unassigned ? null : rider?.FullName,
                unassigned ? null : rider?.RiderCode,
                row.EstimatedValue,
                Bucket(row.Status, row.RiderId),
                row.Status.ToString(),
                ReportingWindow.Sync(row.SyncStatus),
                row.CreatedAt,
                row.LineCount,
                "",
                row.Origin);
        }).ToList();

        var pages = total == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        var meta = new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages };
        var message = total == 0 ? "No orders match." : "Orders loaded.";
        return ServiceResult<IReadOnlyList<DispatchOrderRowDto>>.Ok(data, message, meta);
    }

    public async Task<ServiceResult<DispatchOrderSummaryDto>> SummaryAsync(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken)
    {
        if (!TryWindow(from, to, out var window, out var error))
        {
            return ServiceResult<DispatchOrderSummaryDto>.Fail(400, error!);
        }

        var summary = await MeasureAsync(Filtered(window, search, riderId, unassignedOnly), cancellationToken);
        return ServiceResult<DispatchOrderSummaryDto>.Ok(summary, "Order summary loaded.");
    }

    public async Task<ServiceResult<DispatchStatusCountsDto>> StatusCountsAsync(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? riderId,
        bool unassignedOnly,
        CancellationToken cancellationToken)
    {
        if (!TryWindow(from, to, out var window, out var error))
        {
            return ServiceResult<DispatchStatusCountsDto>.Fail(400, error!);
        }

        var summary = await MeasureAsync(Filtered(window, search, riderId, unassignedOnly), cancellationToken);
        var counts = new DispatchStatusCountsDto(
            summary.Total,
            summary.PendingAssignment,
            summary.Assigned,
            summary.InProgress,
            summary.Completed,
            summary.Cancelled);
        return ServiceResult<DispatchStatusCountsDto>.Ok(counts, "Status counts loaded.");
    }

    public async Task<ServiceResult<DispatchOrderDetailDto>> OrderAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await TrackedOrder(id, includeProducts: false).AsNoTracking().FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(404, "Order not found.");
        }

        return ServiceResult<DispatchOrderDetailDto>.Ok(await ToDetailAsync(order, cancellationToken), "Order loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<DispatchOrderItemDto>>> ItemsAsync(Guid id, CancellationToken cancellationToken)
    {
        if (!await OrderExistsAsync(id, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<DispatchOrderItemDto>>.Fail(404, "Order not found.");
        }

        var lines = await LoadItemsAsync(id, cancellationToken);
        var message = lines.Count == 0 ? "This order has no lines." : "Order lines loaded.";
        return ServiceResult<IReadOnlyList<DispatchOrderItemDto>>.Ok(lines, message);
    }

    public async Task<ServiceResult<IReadOnlyList<OrderLifecycleEventDto>>> LifecycleAsync(Guid id, CancellationToken cancellationToken)
    {
        if (!await OrderExistsAsync(id, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<OrderLifecycleEventDto>>.Fail(404, "Order not found.");
        }

        var events = await _db.OrderLifecycleEvents.AsNoTracking()
            .Where(item => item.OrderId == id)
            .OrderBy(item => item.OccurredAtUtc)
            .ThenBy(item => item.Id)
            .Select(item => new OrderLifecycleEventDto(
                item.Id,
                item.OrderId,
                item.EventCode,
                item.Title,
                item.Detail,
                item.ActorUserId,
                item.OccurredAtUtc))
            .ToListAsync(cancellationToken);
        IReadOnlyList<OrderLifecycleEventDto> data = events;
        var message = data.Count == 0 ? "No lifecycle events are stored for this order." : "Lifecycle loaded.";
        return ServiceResult<IReadOnlyList<OrderLifecycleEventDto>>.Ok(data, message);
    }

    public async Task<ServiceResult<PickListDto>> PickListAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await TrackedOrder(id, includeProducts: true).AsNoTracking().FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return ServiceResult<PickListDto>.Fail(404, "Order not found.");
        }

        if (order.Lines.Count == 0)
        {
            return ServiceResult<PickListDto>.Fail(400, "This order has no lines to pick.");
        }

        return ServiceResult<PickListDto>.Ok(ToPickList(order), "Pick list loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<EligibleRiderDto>>> EligibleRidersAsync(DateOnly? deliveryDate, CancellationToken cancellationToken)
    {
        var day = deliveryDate ?? ReportingWindow.Today();
        var roleId = await RiderRoleIdAsync(cancellationToken);
        if (roleId is null)
        {
            return ServiceResult<IReadOnlyList<EligibleRiderDto>>.Ok([], "No active riders.");
        }

        var open = await _db.Shifts.AsNoTracking()
            .Where(shift => shift.Status == "Open" && shift.ServiceDate == day)
            .Select(shift => shift.RiderId)
            .ToListAsync(cancellationToken);
        var openIds = open.ToHashSet();
        var users = await _db.Users.AsNoTracking()
            .Include(user => user.Route)
            .Where(user => user.IsActive && _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId))
            .OrderBy(user => user.FullName)
            .ThenBy(user => user.Id)
            .ToListAsync(cancellationToken);
        IReadOnlyList<EligibleRiderDto> riders = users
            .Select(user => new EligibleRiderDto(
                user.Id,
                user.FullName,
                user.RiderCode,
                user.Route?.Name,
                openIds.Contains(user.Id)))
            .ToList();
        var message = riders.Count == 0
            ? "No active riders."
            : "Active riders loaded. An open shift is noted when one is stored; location is not tracked.";
        return ServiceResult<IReadOnlyList<EligibleRiderDto>>.Ok(riders, message);
    }

    public async Task<ServiceResult<DispatchOperationalSummaryDto>> OperationalSummaryAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var routes = await _db.DeliveryRoutes.AsNoTracking()
            .OrderBy(route => route.Name)
            .Select(route => new { route.Id, route.Name, route.Sector, route.City })
            .ToListAsync(cancellationToken);
        var orderCounts = await _db.CustomerOrders.AsNoTracking()
            .Where(order => order.DeliveryDate == day)
            .GroupBy(order => order.Customer.RouteId)
            .Select(group => new { RouteId = group.Key, Count = group.Count() })
            .ToListAsync(cancellationToken);
        var stopCounts = await _db.RouteStops.AsNoTracking()
            .Where(stop => stop.ServiceDate == day)
            .GroupBy(stop => stop.RouteId)
            .Select(group => new { RouteId = group.Key, Count = group.Count() })
            .ToListAsync(cancellationToken);
        var ordersByRoute = orderCounts.ToDictionary(row => row.RouteId, row => row.Count);
        var stopsByRoute = stopCounts.ToDictionary(row => row.RouteId, row => row.Count);
        IReadOnlyList<DispatchZoneSummaryDto> zones = routes
            .Select(route => new DispatchZoneSummaryDto(
                route.Id,
                route.Name,
                route.Sector,
                route.City,
                ordersByRoute.GetValueOrDefault(route.Id),
                stopsByRoute.GetValueOrDefault(route.Id)))
            .ToList();
        var dayStops = _db.RouteStops.AsNoTracking().Where(stop => stop.ServiceDate == day);
        var totalStops = await dayStops.CountAsync(cancellationToken);
        var completedStops = await dayStops.CountAsync(stop => stop.Status == StopStatus.Completed, cancellationToken);
        var dto = new DispatchOperationalSummaryDto(
            day,
            zones,
            new DispatchShiftProgressDto(completedStops, totalStops, false, null));
        return ServiceResult<DispatchOperationalSummaryDto>.Ok(dto, "Operational summary loaded. No shift target is configured.");
    }

    public Task<ServiceResult<DispatchOrderDetailDto>> AssignRiderAsync(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken) =>
        ChangeRiderAsync(id, request, reassign: false, cancellationToken);

    public Task<ServiceResult<DispatchOrderDetailDto>> ReassignRiderAsync(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken) =>
        ChangeRiderAsync(id, request, reassign: true, cancellationToken);

    public async Task<ServiceResult<DispatchOrderDetailDto>> CancelAsync(Guid id, CancelOrderRequest? request, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(401, "Sign in required.");
        }

        var reason = string.IsNullOrWhiteSpace(request?.Reason) ? null : request.Reason.Trim();
        if (reason is not null && reason.Length > 300)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(400, "Cancellation reason is too long.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var order = await TrackedOrder(id, includeProducts: false).FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(404, "Order not found.");
        }

        if (order.Status == CustomerOrderStatus.Delivered)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(409, "A delivered order cannot be cancelled.");
        }

        if (order.Status == CustomerOrderStatus.Cancelled)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(409, "This order is already cancelled.");
        }

        if (order.Status is not (CustomerOrderStatus.Scheduled or CustomerOrderStatus.InProgress))
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(409, "This order cannot be cancelled.");
        }

        order.Status = CustomerOrderStatus.Cancelled;
        order.CancelledAtUtc = DateTime.UtcNow;
        order.CancelledByUserId = _current.UserId;
        order.CancellationReason = reason;
        _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(
            order.Id,
            OrderLifecycle.Cancelled,
            "Order cancelled",
            reason ?? "Cancelled by dispatch.",
            _current.UserId));
        AddAudit("CancelOrder", order.Id);
        await _db.SaveChangesAsync(cancellationToken);
        var detail = await ToDetailAsync(order, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<DispatchOrderDetailDto>.Ok(detail, "Order cancelled.");
    }

    public async Task<ServiceResult<PickListDto>> PreparePickListAsync(Guid id, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<PickListDto>.Fail(401, "Sign in required.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var order = await TrackedOrder(id, includeProducts: true).FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return ServiceResult<PickListDto>.Fail(404, "Order not found.");
        }

        if (order.Lines.Count == 0)
        {
            return ServiceResult<PickListDto>.Fail(400, "This order has no lines to pick.");
        }

        _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(
            order.Id,
            OrderLifecycle.PickListPrepared,
            "Pick list prepared",
            $"Prepared {order.Lines.Count} line(s).",
            _current.UserId));
        AddAudit("PreparePickList", order.Id);
        await _db.SaveChangesAsync(cancellationToken);
        var pickList = ToPickList(order);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<PickListDto>.Ok(pickList, "Pick list prepared.");
    }

    private async Task<ServiceResult<DispatchOrderDetailDto>> ChangeRiderAsync(
        Guid id,
        AssignRiderRequest? request,
        bool reassign,
        CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(401, "Sign in required.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var order = await TrackedOrder(id, includeProducts: false).FirstOrDefaultAsync(cancellationToken);
        if (order is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(404, "Order not found.");
        }

        if (!reassign)
        {
            if (order.Status != CustomerOrderStatus.Scheduled || !string.IsNullOrWhiteSpace(order.RiderId))
            {
                var conflict = order.Status == CustomerOrderStatus.Scheduled
                    ? "This order already has a rider."
                    : "Only a scheduled order without a rider can be assigned.";
                return ServiceResult<DispatchOrderDetailDto>.Fail(409, conflict);
            }
        }
        else
        {
            if (order.Status is not (CustomerOrderStatus.Scheduled or CustomerOrderStatus.InProgress))
            {
                return ServiceResult<DispatchOrderDetailDto>.Fail(409, "This order cannot be reassigned.");
            }

            if (string.IsNullOrWhiteSpace(order.RiderId))
            {
                return ServiceResult<DispatchOrderDetailDto>.Fail(409, "Assign a rider before reassigning.");
            }

            if (!string.IsNullOrWhiteSpace(request?.RiderId)
                && string.Equals(request.RiderId.Trim(), order.RiderId, StringComparison.Ordinal))
            {
                return ServiceResult<DispatchOrderDetailDto>.Fail(400, "Choose a different rider.");
            }
        }

        var rider = await RequireRiderAsync(request?.RiderId, cancellationToken);
        if (rider.User is null)
        {
            return ServiceResult<DispatchOrderDetailDto>.Fail(rider.Status, rider.Message!);
        }

        var previousId = (order.RiderId ?? "").Trim();
        var previousName = "";
        if (reassign && previousId.Length > 0)
        {
            previousName = await _db.Users.AsNoTracking()
                .Where(user => user.Id == previousId)
                .Select(user => user.FullName)
                .FirstOrDefaultAsync(cancellationToken) ?? "";
        }

        order.RiderId = rider.User.Id;
        if (order.ShowOnManifest && rider.User.RouteId is Guid routeId)
        {
            await AssignedRouteStop.EnsureAsync(_db, routeId, order.CustomerId, order.DeliveryDate, cancellationToken);
        }
        if (reassign)
        {
            var previousLabel = string.IsNullOrWhiteSpace(previousName)
                ? previousId
                : $"{previousName} ({previousId})";
            var nextLabel = $"{rider.User.FullName} ({rider.User.Id})";
            _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(
                order.Id,
                OrderLifecycle.RiderReassigned,
                "Rider reassigned",
                $"Previous rider {previousLabel}; new rider {nextLabel}.",
                _current.UserId));
            AddAudit("ReassignRider", order.Id);
        }
        else
        {
            _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(
                order.Id,
                OrderLifecycle.RiderAssigned,
                "Rider assigned",
                $"Assigned rider {rider.User.FullName} ({rider.User.Id}).",
                _current.UserId));
            AddAudit("AssignRider", order.Id);
        }

        await _db.SaveChangesAsync(cancellationToken);
        var detail = await ToDetailAsync(order, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        var message = reassign ? "Rider reassigned." : "Rider assigned.";
        return ServiceResult<DispatchOrderDetailDto>.Ok(detail, message);
    }

    private IQueryable<CustomerOrder> TrackedOrder(Guid id, bool includeProducts)
    {
        IQueryable<CustomerOrder> query = _db.CustomerOrders
            .Include(order => order.Customer)
            .Include(order => order.Lines);
        if (includeProducts)
        {
            query = _db.CustomerOrders
                .Include(order => order.Customer)
                .Include(order => order.Lines)
                .ThenInclude(line => line.Product);
        }

        return query.Where(order => order.Id == id);
    }

    private async Task<bool> OrderExistsAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.CustomerOrders.AsNoTracking().AnyAsync(order => order.Id == id, cancellationToken);

    private async Task<IReadOnlyList<DispatchOrderItemDto>> LoadItemsAsync(Guid id, CancellationToken cancellationToken)
    {
        var lines = await _db.OrderLines.AsNoTracking()
            .Where(line => line.OrderId == id)
            .Select(line => new DispatchOrderItemDto(
                line.Id,
                line.ProductId,
                line.Product.Name,
                line.Product.Sku,
                line.Quantity,
                line.Product.UnitLabel,
                line.UnitPrice,
                line.Quantity * line.UnitPrice))
            .ToListAsync(cancellationToken);
        return lines
            .OrderBy(line => line.ProductName)
            .ThenBy(line => line.LineId)
            .ToList();
    }

    private async Task<DispatchOrderDetailDto> ToDetailAsync(CustomerOrder order, CancellationToken cancellationToken)
    {
        var linesSubtotal = order.Lines.Sum(line => line.Quantity * line.UnitPrice);
        return new DispatchOrderDetailDto(
            order.Id,
            order.ReferenceNumber,
            order.DeliveryDate,
            order.Window.ToString(),
            Bucket(order.Status, order.RiderId),
            order.Status.ToString(),
            ReportingWindow.Sync(order.SyncStatus),
            order.Notes,
            "",
            order.CreatedAt,
            order.RiderId,
            new DispatchOrderTotalsDto(order.EstimatedValue, linesSubtotal, order.Lines.Count),
            ToCustomer(order.Customer),
            await RiderCardAsync(order.RiderId, cancellationToken),
            order.CancelledAtUtc,
            order.CancelledByUserId,
            order.CancellationReason,
            order.Origin);
    }

    private static PickListDto ToPickList(CustomerOrder order)
    {
        var lines = order.Lines
            .OrderBy(line => line.Product.Name)
            .ThenBy(line => line.Id)
            .Select(line => new DispatchOrderItemDto(
                line.Id,
                line.ProductId,
                line.Product.Name,
                line.Product.Sku,
                line.Quantity,
                line.Product.UnitLabel,
                line.UnitPrice,
                line.Quantity * line.UnitPrice))
            .ToList();
        return new PickListDto(
            order.Id,
            order.ReferenceNumber,
            order.DeliveryDate,
            order.Window.ToString(),
            order.Status.ToString(),
            order.EstimatedValue,
            order.Notes,
            ToCustomer(order.Customer),
            lines,
            lines.Sum(line => line.Subtotal));
    }

    private async Task<DispatchRiderCardDto?> RiderCardAsync(string riderId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(riderId))
        {
            return null;
        }

        return await _db.Users.AsNoTracking()
            .Where(user => user.Id == riderId)
            .Select(user => new DispatchRiderCardDto(user.Id, user.FullName, user.RiderCode, user.IsActive))
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<DispatchOrderSummaryDto> MeasureAsync(IQueryable<CustomerOrder> orders, CancellationToken cancellationToken)
    {
        var total = await orders.CountAsync(cancellationToken);
        var pending = await orders.CountAsync(
            order => order.Status == CustomerOrderStatus.Scheduled && order.RiderId.Trim() == "",
            cancellationToken);
        var assigned = await orders.CountAsync(
            order => order.Status == CustomerOrderStatus.Scheduled && order.RiderId.Trim() != "",
            cancellationToken);
        var inProgress = await orders.CountAsync(order => order.Status == CustomerOrderStatus.InProgress, cancellationToken);
        var completed = await orders.CountAsync(order => order.Status == CustomerOrderStatus.Delivered, cancellationToken);
        var cancelled = await orders.CountAsync(order => order.Status == CustomerOrderStatus.Cancelled, cancellationToken);
        var value = await orders.SumAsync(order => (decimal?)order.EstimatedValue, cancellationToken) ?? 0;
        return new DispatchOrderSummaryDto(total, pending, assigned, inProgress, completed, cancelled, value);
    }

    private IQueryable<CustomerOrder> Filtered(DateWindow window, string? search, string? riderId, bool unassignedOnly)
    {
        var query = _db.CustomerOrders.AsNoTracking();
        if (window.From is DateOnly start && window.To is DateOnly end)
        {
            var (createdStart, createdEnd) = ReportingWindow.UtcBounds(start, end);
            query = query.Where(order =>
                (order.DeliveryDate >= start && order.DeliveryDate <= end)
                || (order.Origin == OrderOrigin.Rider && order.CreatedAt >= createdStart && order.CreatedAt < createdEnd));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(order =>
                order.ReferenceNumber.Contains(term)
                || order.Customer.BusinessName.Contains(term)
                || order.Customer.Code.Contains(term)
                || order.Customer.PrimaryMobile.Contains(term)
                || _db.Users.Any(user => user.Id == order.RiderId && (user.FullName.Contains(term) || (user.RiderCode != null && user.RiderCode.Contains(term)))));
        }

        if (!string.IsNullOrWhiteSpace(riderId))
        {
            var id = riderId.Trim();
            query = query.Where(order => order.RiderId == id);
        }

        if (unassignedOnly)
        {
            query = query.Where(order => order.RiderId.Trim() == "");
        }

        return query;
    }

    private static IQueryable<CustomerOrder> WhereStatus(IQueryable<CustomerOrder> query, string? canonical) =>
        canonical switch
        {
            "pendingAssignment" => query.Where(order => order.Status == CustomerOrderStatus.Scheduled && order.RiderId.Trim() == ""),
            "assigned" => query.Where(order => order.Status == CustomerOrderStatus.Scheduled && order.RiderId.Trim() != ""),
            "inProgress" => query.Where(order => order.Status == CustomerOrderStatus.InProgress),
            "completed" => query.Where(order => order.Status == CustomerOrderStatus.Delivered),
            "cancelled" => query.Where(order => order.Status == CustomerOrderStatus.Cancelled),
            _ => query
        };

    private async Task<(ApplicationUser? User, int Status, string? Message)> RequireRiderAsync(string? riderId, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(riderId))
        {
            return (null, 400, "Choose a rider.");
        }

        var id = riderId.Trim();
        var roleId = await RiderRoleIdAsync(cancellationToken);
        var user = await _db.Users.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (user is null || roleId is null || !await _db.UserRoles.AnyAsync(
                link => link.UserId == user.Id && link.RoleId == roleId,
                cancellationToken))
        {
            return (null, 404, "Rider not found.");
        }

        if (!user.IsActive)
        {
            return (null, 400, "That rider is not active.");
        }

        return (user, 200, null);
    }

    private async Task<string?> RiderRoleIdAsync(CancellationToken cancellationToken) =>
        await _db.Roles.AsNoTracking()
            .Where(role => role.Name == AppRoles.Rider)
            .Select(role => role.Id)
            .FirstOrDefaultAsync(cancellationToken);

    private void AddAudit(string action, Guid orderId)
    {
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? "",
            Action = action,
            EntityName = "CustomerOrder",
            EntityId = orderId.ToString()
        });
    }

    private static DispatchCustomerCardDto ToCustomer(Customer customer) =>
        new(
            customer.Id,
            customer.BusinessName,
            customer.Code,
            customer.PrimaryMobile,
            Address(customer.Street, customer.Area, customer.City),
            customer.Street,
            customer.Area,
            customer.City);

    private static string Address(string street, string area, string city) =>
        string.Join(", ", new[] { street, area, city }.Where(part => !string.IsNullOrWhiteSpace(part)));

    private static string Bucket(CustomerOrderStatus status, string riderId) =>
        status switch
        {
            CustomerOrderStatus.Cancelled => "cancelled",
            CustomerOrderStatus.Delivered => "completed",
            CustomerOrderStatus.InProgress => "inProgress",
            CustomerOrderStatus.Scheduled when string.IsNullOrWhiteSpace(riderId) => "pendingAssignment",
            CustomerOrderStatus.Scheduled => "assigned",
            _ => status.ToString()
        };

    private static bool TryStatus(string? status, out string? canonical, out string? error)
    {
        if (string.IsNullOrWhiteSpace(status))
        {
            canonical = null;
            error = null;
            return true;
        }

        var match = status.Trim().ToLowerInvariant() switch
        {
            "all" => "all",
            "pendingassignment" => "pendingAssignment",
            "assigned" => "assigned",
            "inprogress" => "inProgress",
            "completed" => "completed",
            "cancelled" => "cancelled",
            _ => null
        };
        if (match is null)
        {
            canonical = null;
            error = "Status must be all, pendingAssignment, assigned, inProgress, completed, or cancelled.";
            return false;
        }

        canonical = match == "all" ? null : match;
        error = null;
        return true;
    }

    private static bool TryWindow(DateOnly? from, DateOnly? to, out DateWindow window, out string? error)
    {
        if (from is null && to is null)
        {
            window = new DateWindow(null, null);
            error = null;
            return true;
        }

        var start = from ?? to!.Value;
        var end = to ?? from!.Value;
        if (end < start)
        {
            window = default;
            error = "The end date is before the start date.";
            return false;
        }

        window = new DateWindow(start, end);
        error = null;
        return true;
    }

    private readonly record struct DateWindow(DateOnly? From, DateOnly? To);

    private sealed record OrderPageRow(
        Guid Id,
        string ReferenceNumber,
        string CustomerName,
        string CustomerCode,
        string CustomerPhone,
        string Street,
        string Area,
        string City,
        DateOnly DeliveryDate,
        DeliveryWindow Window,
        string RiderId,
        decimal EstimatedValue,
        CustomerOrderStatus Status,
        SyncStatus SyncStatus,
        DateTime CreatedAt,
        int LineCount,
        string Origin);

    private sealed record RiderName(string Id, string FullName, string? RiderCode);
}
