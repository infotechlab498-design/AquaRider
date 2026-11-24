using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class ZonesRoutesService : IZonesRoutesService
{
    private readonly AppDbContext _db;
    private readonly UserManager<ApplicationUser> _users;

    public ZonesRoutesService(AppDbContext db, UserManager<ApplicationUser> users)
    {
        _db = db;
        _users = users;
    }

    public async Task<ServiceResult<ZonesRoutesSummaryDto>> SummaryAsync(CancellationToken cancellationToken)
    {
        var zones = await _db.Zones.AsNoTracking().ToListAsync(cancellationToken);
        var routes = await _db.DeliveryRoutes.AsNoTracking().Select(item => item.Id).ToListAsync(cancellationToken);
        var customers = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .Select(item => new { item.Latitude, item.Longitude })
            .ToListAsync(cancellationToken);
        var assignedRiders = await _db.Users.AsNoTracking()
            .CountAsync(item => item.RiderCode != null && item.RouteId != null && item.IsActive, cancellationToken);
        var depotName = await _db.Depots.AsNoTracking().OrderBy(item => item.Name).Select(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        var dto = new ZonesRoutesSummaryDto(
            zones.Count,
            zones.Count(item => item.IsActive),
            routes.Count,
            assignedRiders,
            customers.Count,
            customers.Count(item => item.Latitude is null || item.Longitude is null),
            depotName);
        return ServiceResult<ZonesRoutesSummaryDto>.Ok(dto, "Zones and routes summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<ZoneListItemDto>>> ListZonesAsync(
        string? search,
        bool? activeOnly,
        CancellationToken cancellationToken)
    {
        var query = _db.Zones.AsNoTracking().Include(item => item.Depot).AsQueryable();
        if (activeOnly == true)
        {
            query = query.Where(item => item.IsActive);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.Name.Contains(term)
                || item.Sector.Contains(term)
                || item.City.Contains(term));
        }

        var zones = await query.OrderBy(item => item.Name).ToListAsync(cancellationToken);
        var routeCounts = await _db.DeliveryRoutes.AsNoTracking()
            .GroupBy(item => item.ZoneId)
            .Select(group => new { ZoneId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.ZoneId, item => item.Count, cancellationToken);
        var customerCounts = await (
            from customer in _db.Customers.AsNoTracking()
            where !customer.IsDeleted
            join route in _db.DeliveryRoutes.AsNoTracking() on customer.RouteId equals route.Id
            group customer by route.ZoneId into grouped
            select new { ZoneId = grouped.Key, Count = grouped.Count() })
            .ToDictionaryAsync(item => item.ZoneId, item => item.Count, cancellationToken);
        var riderCounts = await (
            from user in _db.Users.AsNoTracking()
            where user.RiderCode != null && user.RouteId != null && user.IsActive
            join route in _db.DeliveryRoutes.AsNoTracking() on user.RouteId equals route.Id
            group user by route.ZoneId into grouped
            select new { ZoneId = grouped.Key, Count = grouped.Count() })
            .ToDictionaryAsync(item => item.ZoneId, item => item.Count, cancellationToken);

        IReadOnlyList<ZoneListItemDto> rows = zones.Select(zone => new ZoneListItemDto(
            zone.Id,
            zone.Name,
            zone.Sector,
            zone.City,
            zone.DepotId,
            zone.Depot.Name,
            zone.IsActive,
            routeCounts.GetValueOrDefault(zone.Id),
            customerCounts.GetValueOrDefault(zone.Id),
            riderCounts.GetValueOrDefault(zone.Id))).ToList();
        return ServiceResult<IReadOnlyList<ZoneListItemDto>>.Ok(
            rows,
            rows.Count == 0 ? "No delivery zones were returned." : "Delivery zones loaded.");
    }

    public async Task<ServiceResult<ZoneDetailDto>> GetZoneAsync(Guid id, CancellationToken cancellationToken)
    {
        var zone = await _db.Zones.AsNoTracking().Include(item => item.Depot).FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (zone is null)
        {
            return ServiceResult<ZoneDetailDto>.Fail(404, "Zone was not found.");
        }

        return ServiceResult<ZoneDetailDto>.Ok(await ToZoneDetailAsync(zone, cancellationToken), "Zone loaded.");
    }

    public async Task<ServiceResult<ZoneDetailDto>> CreateZoneAsync(ZoneWriteRequest request, CancellationToken cancellationToken)
    {
        var errors = ValidateZone(request);
        if (errors.Count > 0)
        {
            return ServiceResult<ZoneDetailDto>.Fail(400, "Check the zone form.", errors.ToArray());
        }

        var depotId = await ResolveDepotIdAsync(request.DepotId, cancellationToken);
        if (depotId is null)
        {
            return ServiceResult<ZoneDetailDto>.Fail(400, "Assign a valid depot.");
        }

        var zone = new Zone
        {
            Name = request.Name.Trim(),
            Sector = request.Sector.Trim(),
            City = request.City.Trim(),
            DepotId = depotId.Value,
            IsActive = request.IsActive
        };
        _db.Zones.Add(zone);
        await _db.SaveChangesAsync(cancellationToken);
        var stored = await _db.Zones.AsNoTracking().Include(item => item.Depot).FirstAsync(item => item.Id == zone.Id, cancellationToken);
        return ServiceResult<ZoneDetailDto>.Created(await ToZoneDetailAsync(stored, cancellationToken), "Zone created.");
    }

    public async Task<ServiceResult<ZoneDetailDto>> UpdateZoneAsync(Guid id, ZoneWriteRequest request, CancellationToken cancellationToken)
    {
        var errors = ValidateZone(request);
        if (errors.Count > 0)
        {
            return ServiceResult<ZoneDetailDto>.Fail(400, "Check the zone form.", errors.ToArray());
        }

        var zone = await _db.Zones.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (zone is null)
        {
            return ServiceResult<ZoneDetailDto>.Fail(404, "Zone was not found.");
        }

        var depotId = await ResolveDepotIdAsync(request.DepotId ?? zone.DepotId, cancellationToken);
        if (depotId is null)
        {
            return ServiceResult<ZoneDetailDto>.Fail(400, "Assign a valid depot.");
        }

        zone.Name = request.Name.Trim();
        zone.Sector = request.Sector.Trim();
        zone.City = request.City.Trim();
        zone.DepotId = depotId.Value;
        zone.IsActive = request.IsActive;

        var routes = await _db.DeliveryRoutes.Where(item => item.ZoneId == id).ToListAsync(cancellationToken);
        foreach (var route in routes)
        {
            route.Sector = zone.Sector;
            route.City = zone.City;
            route.DepotId = zone.DepotId;
        }

        await _db.SaveChangesAsync(cancellationToken);
        var stored = await _db.Zones.AsNoTracking().Include(item => item.Depot).FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<ZoneDetailDto>.Ok(await ToZoneDetailAsync(stored, cancellationToken), "Zone updated.");
    }

    public async Task<ServiceResult<object>> DeactivateZoneAsync(Guid id, CancellationToken cancellationToken)
    {
        var zone = await _db.Zones.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (zone is null)
        {
            return ServiceResult<object>.Fail(404, "Zone was not found.");
        }

        var routeCount = await _db.DeliveryRoutes.CountAsync(item => item.ZoneId == id, cancellationToken);
        if (routeCount > 0 && zone.IsActive)
        {
            zone.IsActive = false;
            await _db.SaveChangesAsync(cancellationToken);
            return ServiceResult<object>.Ok(new { id, isActive = false }, "Zone deactivated. Existing routes were kept.");
        }

        if (routeCount > 0)
        {
            return ServiceResult<object>.Fail(400, "Remove or move routes before deleting this zone.");
        }

        _db.Zones.Remove(zone);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { id, deleted = true }, "Zone deleted.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteListItemDto>>> ListRoutesAsync(
        Guid? zoneId,
        string? search,
        CancellationToken cancellationToken)
    {
        var query = _db.DeliveryRoutes.AsNoTracking()
            .Include(item => item.Zone)
            .Include(item => item.Depot)
            .AsQueryable();
        if (zoneId is not null)
        {
            query = query.Where(item => item.ZoneId == zoneId);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.Name.Contains(term)
                || item.Sector.Contains(term)
                || item.City.Contains(term)
                || item.Zone.Name.Contains(term));
        }

        var routes = await query.OrderBy(item => item.Name).ToListAsync(cancellationToken);
        IReadOnlyList<RouteListItemDto> rows = await ToRouteListAsync(routes, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteListItemDto>>.Ok(
            rows,
            rows.Count == 0 ? "No routes were returned." : "Routes loaded.");
    }

    public async Task<ServiceResult<RouteDetailDto>> GetRouteAsync(Guid id, CancellationToken cancellationToken)
    {
        var route = await RouteQuery().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (route is null)
        {
            return ServiceResult<RouteDetailDto>.Fail(404, "Route was not found.");
        }

        return ServiceResult<RouteDetailDto>.Ok(await ToRouteDetailAsync(route, cancellationToken), "Route loaded.");
    }

    public async Task<ServiceResult<RouteDetailDto>> CreateRouteAsync(RouteWriteRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Route name is required.");
        }

        var zone = await _db.Zones.FirstOrDefaultAsync(item => item.Id == request.ZoneId, cancellationToken);
        if (zone is null)
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Assign a valid zone.");
        }

        if (!zone.IsActive)
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Cannot add a route to an inactive zone.");
        }

        var depotId = request.DepotId ?? zone.DepotId;
        if (!await _db.Depots.AnyAsync(item => item.Id == depotId, cancellationToken))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Assign a valid depot.");
        }

        var route = new DeliveryRoute
        {
            Name = request.Name.Trim(),
            ZoneId = zone.Id,
            Sector = string.IsNullOrWhiteSpace(request.Sector) ? zone.Sector : request.Sector.Trim(),
            City = string.IsNullOrWhiteSpace(request.City) ? zone.City : request.City.Trim(),
            DepotId = depotId
        };
        _db.DeliveryRoutes.Add(route);
        await _db.SaveChangesAsync(cancellationToken);
        var stored = await RouteQuery().FirstAsync(item => item.Id == route.Id, cancellationToken);
        return ServiceResult<RouteDetailDto>.Created(await ToRouteDetailAsync(stored, cancellationToken), "Route created.");
    }

    public async Task<ServiceResult<RouteDetailDto>> UpdateRouteAsync(Guid id, RouteWriteRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Route name is required.");
        }

        var route = await _db.DeliveryRoutes.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (route is null)
        {
            return ServiceResult<RouteDetailDto>.Fail(404, "Route was not found.");
        }

        var zone = await _db.Zones.FirstOrDefaultAsync(item => item.Id == request.ZoneId, cancellationToken);
        if (zone is null)
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Assign a valid zone.");
        }

        var depotId = request.DepotId ?? zone.DepotId;
        if (!await _db.Depots.AnyAsync(item => item.Id == depotId, cancellationToken))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Assign a valid depot.");
        }

        route.Name = request.Name.Trim();
        route.ZoneId = zone.Id;
        route.Sector = string.IsNullOrWhiteSpace(request.Sector) ? zone.Sector : request.Sector.Trim();
        route.City = string.IsNullOrWhiteSpace(request.City) ? zone.City : request.City.Trim();
        route.DepotId = depotId;
        await _db.SaveChangesAsync(cancellationToken);
        var stored = await RouteQuery().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<RouteDetailDto>.Ok(await ToRouteDetailAsync(stored, cancellationToken), "Route updated.");
    }

    public async Task<ServiceResult<object>> DeleteRouteAsync(Guid id, CancellationToken cancellationToken)
    {
        var route = await _db.DeliveryRoutes.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (route is null)
        {
            return ServiceResult<object>.Fail(404, "Route was not found.");
        }

        var customers = await _db.Customers.CountAsync(item => item.RouteId == id && !item.IsDeleted, cancellationToken);
        if (customers > 0)
        {
            return ServiceResult<object>.Fail(400, "Reassign customers before deleting this route.");
        }

        var stops = await _db.RouteStops.CountAsync(item => item.RouteId == id, cancellationToken);
        if (stops > 0)
        {
            return ServiceResult<object>.Fail(400, "Clear day stops before deleting this route.");
        }

        var riders = await _db.Users.Where(item => item.RouteId == id).ToListAsync(cancellationToken);
        foreach (var rider in riders)
        {
            rider.RouteId = null;
        }

        _db.DeliveryRoutes.Remove(route);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { id, deleted = true }, "Route deleted.");
    }

    public async Task<ServiceResult<IReadOnlyList<EligibleRouteRiderDto>>> EligibleRidersAsync(
        string? search,
        CancellationToken cancellationToken)
    {
        var riders = await _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Where(item => item.RiderCode != null)
            .OrderBy(item => item.FullName)
            .ToListAsync(cancellationToken);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            riders = riders.Where(item =>
                item.FullName.Contains(term, StringComparison.OrdinalIgnoreCase)
                || (item.RiderCode?.Contains(term, StringComparison.OrdinalIgnoreCase) ?? false)).ToList();
        }

        IReadOnlyList<EligibleRouteRiderDto> rows = riders.Select(item => new EligibleRouteRiderDto(
            item.Id,
            item.FullName,
            item.RiderCode,
            item.RouteId,
            item.Route?.Name,
            item.Vehicle?.Plate,
            item.IsActive)).ToList();
        return ServiceResult<IReadOnlyList<EligibleRouteRiderDto>>.Ok(rows, "Eligible riders loaded.");
    }

    public async Task<ServiceResult<RouteDetailDto>> AssignRiderAsync(
        Guid routeId,
        AssignRouteRiderRequest request,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<RouteDetailDto>.Fail(404, "Route was not found.");
        }

        if (string.IsNullOrWhiteSpace(request.RiderUserId))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Rider is required.");
        }

        var rider = await _users.FindByIdAsync(request.RiderUserId.Trim());
        if (rider is null || string.IsNullOrWhiteSpace(rider.RiderCode))
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Assign a valid rider account.");
        }

        rider.RouteId = routeId;
        await _users.UpdateAsync(rider);
        var stored = await RouteQuery().FirstAsync(item => item.Id == routeId, cancellationToken);
        return ServiceResult<RouteDetailDto>.Ok(await ToRouteDetailAsync(stored, cancellationToken), "Rider assigned to route.");
    }

    public async Task<ServiceResult<RouteDetailDto>> UnassignRiderAsync(
        Guid routeId,
        AssignRouteRiderRequest request,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<RouteDetailDto>.Fail(404, "Route was not found.");
        }

        var rider = await _users.FindByIdAsync(request.RiderUserId.Trim());
        if (rider is null || rider.RouteId != routeId)
        {
            return ServiceResult<RouteDetailDto>.Fail(400, "Rider is not assigned to this route.");
        }

        rider.RouteId = null;
        await _users.UpdateAsync(rider);
        var stored = await RouteQuery().FirstAsync(item => item.Id == routeId, cancellationToken);
        return ServiceResult<RouteDetailDto>.Ok(await ToRouteDetailAsync(stored, cancellationToken), "Rider unassigned from route.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> RouteCustomersAsync(
        Guid routeId,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(404, "Route was not found.");
        }

        var rows = await LoadCustomersAsync(routeId, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Ok(rows, "Route customers loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> AllocateCustomersAsync(
        Guid routeId,
        AllocateCustomersRequest request,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(404, "Route was not found.");
        }

        var ids = (request.CustomerIds ?? []).Distinct().ToList();
        if (ids.Count == 0)
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(400, "Select at least one customer.");
        }

        var customers = await _db.Customers.Where(item => ids.Contains(item.Id) && !item.IsDeleted).ToListAsync(cancellationToken);
        if (customers.Count != ids.Count)
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(400, "One or more customers were not found.");
        }

        var maxSort = await _db.Customers
            .Where(item => item.RouteId == routeId && !item.IsDeleted)
            .Select(item => (int?)item.RouteSortOrder)
            .MaxAsync(cancellationToken) ?? 0;
        var today = ReportingWindow.Today();
        foreach (var customer in customers.OrderBy(item => item.RouteSortOrder).ThenBy(item => item.BusinessName))
        {
            if (customer.RouteId == routeId)
            {
                continue;
            }

            var linked = await _db.CustomerAccounts.AnyAsync(item => item.DeliveryCustomerId == customer.Id, cancellationToken);
            if (!linked)
            {
                return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(409, $"{customer.Code} needs an approved customer account link before a future route allocation.");
            }

            customer.RouteId = routeId;
            customer.RouteSortOrder = ++maxSort;
            var stops = await _db.RouteStops
                .Where(item => item.CustomerId == customer.Id && item.ServiceDate >= today)
                .ToListAsync(cancellationToken);
            foreach (var stop in stops)
            {
                stop.RouteId = routeId;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        var rows = await LoadCustomersAsync(routeId, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Ok(rows, "Customers allocated to route.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteCustomerRowDto>>> SequenceCustomersAsync(
        Guid routeId,
        CustomerSequenceRequest request,
        CancellationToken cancellationToken)
    {
        var ordered = (request.OrderedCustomerIds ?? []).ToList();
        if (ordered.Count == 0)
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(400, "Provide the customer sequence.");
        }

        var customers = await _db.Customers
            .Where(item => item.RouteId == routeId && !item.IsDeleted)
            .ToListAsync(cancellationToken);
        if (customers.Count != ordered.Count || ordered.Distinct().Count() != ordered.Count)
        {
            return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(400, "Sequence must include every customer on the route exactly once.");
        }

        var map = customers.ToDictionary(item => item.Id);
        for (var index = 0; index < ordered.Count; index++)
        {
            if (!map.TryGetValue(ordered[index], out var customer))
            {
                return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Fail(400, "Sequence includes a customer that is not on this route.");
            }

            customer.RouteSortOrder = index + 1;
        }

        await _db.SaveChangesAsync(cancellationToken);
        var rows = await LoadCustomersAsync(routeId, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteCustomerRowDto>>.Ok(rows, "Customer sequence updated.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> StopsAsync(
        Guid routeId,
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(404, "Route was not found.");
        }

        var serviceDate = date ?? ReportingWindow.Today();
        var rows = await LoadStopsAsync(routeId, serviceDate, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Ok(
            rows,
            rows.Count == 0 ? "No stops for this service date." : "Route stops loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> EnsureStopsAsync(
        Guid routeId,
        EnsureStopsRequest? request,
        CancellationToken cancellationToken)
    {
        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == routeId, cancellationToken))
        {
            return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(404, "Route was not found.");
        }

        var serviceDate = request?.ServiceDate ?? ReportingWindow.Today();
        var customers = await _db.Customers
            .Where(item => item.RouteId == routeId && !item.IsDeleted && item.Status == "Active")
            .OrderBy(item => item.RouteSortOrder)
            .ThenBy(item => item.BusinessName)
            .ToListAsync(cancellationToken);
        var existing = await _db.RouteStops
            .Where(item => item.RouteId == routeId && item.ServiceDate == serviceDate)
            .ToListAsync(cancellationToken);
        var byCustomer = existing.ToDictionary(item => item.CustomerId);
        var nextSequence = existing.Count == 0 ? 0 : existing.Max(item => item.Sequence);
        foreach (var customer in customers)
        {
            if (byCustomer.ContainsKey(customer.Id))
            {
                continue;
            }

            nextSequence++;
            _db.RouteStops.Add(new RouteStop
            {
                CustomerId = customer.Id,
                RouteId = routeId,
                ServiceDate = serviceDate,
                Sequence = customer.RouteSortOrder > 0 ? customer.RouteSortOrder : nextSequence,
                Status = StopStatus.Pending
            });
        }

        await _db.SaveChangesAsync(cancellationToken);

        // Normalize sequences to dense 1..n by master sort when we just created gaps.
        var all = await _db.RouteStops
            .Include(item => item.Customer)
            .Where(item => item.RouteId == routeId && item.ServiceDate == serviceDate)
            .OrderBy(item => item.Customer.RouteSortOrder)
            .ThenBy(item => item.Sequence)
            .ToListAsync(cancellationToken);
        for (var index = 0; index < all.Count; index++)
        {
            all[index].Sequence = index + 1;
        }

        await _db.SaveChangesAsync(cancellationToken);
        var rows = await LoadStopsAsync(routeId, serviceDate, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Ok(rows, "Day stops ensured from route customers.");
    }

    public async Task<ServiceResult<IReadOnlyList<RouteStopRowDto>>> SequenceStopsAsync(
        Guid routeId,
        StopSequenceRequest request,
        CancellationToken cancellationToken)
    {
        var ordered = (request.OrderedStopIds ?? []).ToList();
        if (ordered.Count == 0)
        {
            return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(400, "Provide the stop sequence.");
        }

        var serviceDates = await _db.RouteStops
            .Where(item => item.RouteId == routeId && ordered.Contains(item.Id))
            .Select(item => item.ServiceDate)
            .Distinct()
            .ToListAsync(cancellationToken);
        if (serviceDates.Count != 1)
        {
            return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(400, "Stops must belong to one service date on this route.");
        }

        var serviceDate = serviceDates[0];
        var stops = await _db.RouteStops
            .Where(item => item.RouteId == routeId && item.ServiceDate == serviceDate)
            .ToListAsync(cancellationToken);
        if (stops.Count != ordered.Count || ordered.Distinct().Count() != ordered.Count)
        {
            return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(400, "Sequence must include every stop for the day exactly once.");
        }

        var map = stops.ToDictionary(item => item.Id);
        for (var index = 0; index < ordered.Count; index++)
        {
            if (!map.TryGetValue(ordered[index], out var stop))
            {
                return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Fail(400, "Sequence includes a stop that is not on this route.");
            }

            stop.Sequence = index + 1;
            if (stop.Customer is null)
            {
                // Customer nav not loaded; update sort via separate query below.
            }
        }

        await _db.SaveChangesAsync(cancellationToken);

        // Mirror day order into master RouteSortOrder for the same customers.
        var customerIds = ordered.Select(id => map[id].CustomerId).ToList();
        var customers = await _db.Customers.Where(item => customerIds.Contains(item.Id)).ToListAsync(cancellationToken);
        var customerMap = customers.ToDictionary(item => item.Id);
        for (var index = 0; index < customerIds.Count; index++)
        {
            if (customerMap.TryGetValue(customerIds[index], out var customer) && customer.RouteId == routeId)
            {
                customer.RouteSortOrder = index + 1;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        var rows = await LoadStopsAsync(routeId, serviceDate, cancellationToken);
        return ServiceResult<IReadOnlyList<RouteStopRowDto>>.Ok(rows, "Stop sequence updated.");
    }

    public async Task<ServiceResult<RouteMapDto>> MapPinsAsync(
        Guid routeId,
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var route = await RouteQuery().FirstOrDefaultAsync(item => item.Id == routeId, cancellationToken);
        if (route is null)
        {
            return ServiceResult<RouteMapDto>.Fail(404, "Route was not found.");
        }

        var serviceDate = date ?? ReportingWindow.Today();
        var stops = await _db.RouteStops.AsNoTracking()
            .Include(item => item.Customer)
            .Where(item => item.RouteId == routeId && item.ServiceDate == serviceDate)
            .OrderBy(item => item.Sequence)
            .ToListAsync(cancellationToken);
        var pins = new List<RouteMapPinDto>();
        if (stops.Count > 0)
        {
            foreach (var stop in stops)
            {
                if (stop.Customer.Latitude is null || stop.Customer.Longitude is null)
                {
                    continue;
                }

                pins.Add(new RouteMapPinDto(
                    stop.CustomerId,
                    stop.Customer.BusinessName,
                    stop.Customer.Code,
                    stop.Customer.Latitude.Value,
                    stop.Customer.Longitude.Value,
                    stop.Sequence,
                    true));
            }
        }
        else
        {
            var customers = await _db.Customers.AsNoTracking()
                .Where(item => item.RouteId == routeId && !item.IsDeleted && item.Latitude != null && item.Longitude != null)
                .OrderBy(item => item.RouteSortOrder)
                .ThenBy(item => item.BusinessName)
                .ToListAsync(cancellationToken);
            foreach (var customer in customers)
            {
                pins.Add(new RouteMapPinDto(
                    customer.Id,
                    customer.BusinessName,
                    customer.Code,
                    customer.Latitude!.Value,
                    customer.Longitude!.Value,
                    customer.RouteSortOrder,
                    false));
            }
        }

        var dto = new RouteMapDto(route.Id, route.Name, route.Zone.Name, serviceDate, pins);
        return ServiceResult<RouteMapDto>.Ok(
            dto,
            pins.Count == 0 ? "No GPS pins are available for this route." : "Static map pins loaded.");
    }

    private IQueryable<DeliveryRoute> RouteQuery() =>
        _db.DeliveryRoutes.AsNoTracking().Include(item => item.Zone).Include(item => item.Depot);

    private async Task<ZoneDetailDto> ToZoneDetailAsync(Zone zone, CancellationToken cancellationToken)
    {
        var routes = await _db.DeliveryRoutes.AsNoTracking()
            .Include(item => item.Zone)
            .Include(item => item.Depot)
            .Where(item => item.ZoneId == zone.Id)
            .OrderBy(item => item.Name)
            .ToListAsync(cancellationToken);
        var routeRows = await ToRouteListAsync(routes, cancellationToken);
        var customerCount = routeRows.Sum(item => item.CustomerCount);
        return new ZoneDetailDto(
            zone.Id,
            zone.Name,
            zone.Sector,
            zone.City,
            zone.DepotId,
            zone.Depot.Name,
            zone.IsActive,
            zone.CreatedAt,
            routeRows.Count,
            customerCount,
            routeRows);
    }

    private async Task<IReadOnlyList<RouteListItemDto>> ToRouteListAsync(
        IReadOnlyList<DeliveryRoute> routes,
        CancellationToken cancellationToken)
    {
        if (routes.Count == 0)
        {
            return [];
        }

        var ids = routes.Select(item => item.Id).ToList();
        var today = ReportingWindow.Today();
        var customerCounts = await _db.Customers.AsNoTracking()
            .Where(item => ids.Contains(item.RouteId) && !item.IsDeleted)
            .GroupBy(item => item.RouteId)
            .Select(group => new { RouteId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.RouteId, item => item.Count, cancellationToken);
        var stopCounts = await _db.RouteStops.AsNoTracking()
            .Where(item => ids.Contains(item.RouteId) && item.ServiceDate == today)
            .GroupBy(item => item.RouteId)
            .Select(group => new { RouteId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.RouteId, item => item.Count, cancellationToken);
        var riders = await _db.Users.AsNoTracking()
            .Include(item => item.Vehicle)
            .Where(item => item.RouteId != null && ids.Contains(item.RouteId.Value) && item.RiderCode != null)
            .ToListAsync(cancellationToken);
        var ridersByRoute = riders.GroupBy(item => item.RouteId!.Value)
            .ToDictionary(group => group.Key, group => group.Select(ToRider).ToList());

        return routes.Select(route =>
        {
            var assigned = ridersByRoute.GetValueOrDefault(route.Id) ?? [];
            return new RouteListItemDto(
                route.Id,
                route.Name,
                route.Sector,
                route.City,
                route.ZoneId,
                route.Zone.Name,
                route.DepotId,
                route.Depot.Name,
                customerCounts.GetValueOrDefault(route.Id),
                stopCounts.GetValueOrDefault(route.Id),
                assigned,
                assigned.Count > 0);
        }).ToList();
    }

    private async Task<RouteDetailDto> ToRouteDetailAsync(DeliveryRoute route, CancellationToken cancellationToken)
    {
        var list = await ToRouteListAsync([route], cancellationToken);
        var summary = list[0];
        var customers = await LoadCustomersAsync(route.Id, cancellationToken);
        return new RouteDetailDto(
            route.Id,
            route.Name,
            route.Sector,
            route.City,
            route.ZoneId,
            route.Zone.Name,
            route.DepotId,
            route.Depot.Name,
            summary.CustomerCount,
            customers.Count(item => item.HasGps),
            summary.StopCountToday,
            summary.Riders,
            customers);
    }

    private async Task<IReadOnlyList<RouteCustomerRowDto>> LoadCustomersAsync(Guid routeId, CancellationToken cancellationToken)
    {
        var customers = await _db.Customers.AsNoTracking()
            .Where(item => item.RouteId == routeId && !item.IsDeleted)
            .OrderBy(item => item.RouteSortOrder)
            .ThenBy(item => item.BusinessName)
            .ToListAsync(cancellationToken);
        return customers.Select(item => new RouteCustomerRowDto(
            item.Id,
            item.Code,
            item.BusinessName,
            item.Status,
            item.PrimaryMobile,
            $"{item.Street}, {item.Area}",
            item.Area,
            item.RouteSortOrder,
            item.Latitude,
            item.Longitude,
            item.Outstanding,
            item.Latitude is not null && item.Longitude is not null)).ToList();
    }

    private async Task<IReadOnlyList<RouteStopRowDto>> LoadStopsAsync(
        Guid routeId,
        DateOnly serviceDate,
        CancellationToken cancellationToken)
    {
        var stops = await _db.RouteStops.AsNoTracking()
            .Include(item => item.Customer)
            .Where(item => item.RouteId == routeId && item.ServiceDate == serviceDate)
            .OrderBy(item => item.Sequence)
            .ToListAsync(cancellationToken);
        return stops.Select(item => new RouteStopRowDto(
            item.Id,
            item.CustomerId,
            item.Customer.Code,
            item.Customer.BusinessName,
            $"{item.Customer.Street}, {item.Customer.Area}",
            item.Customer.PrimaryMobile,
            item.Sequence,
            item.Status.ToString(),
            item.Customer.Latitude,
            item.Customer.Longitude)).ToList();
    }

    private static RouteRiderDto ToRider(ApplicationUser user) =>
        new(user.Id, user.FullName, user.RiderCode, user.Vehicle?.Plate, user.IsActive);

    private async Task<Guid?> ResolveDepotIdAsync(Guid? requested, CancellationToken cancellationToken)
    {
        if (requested is not null)
        {
            return await _db.Depots.AnyAsync(item => item.Id == requested, cancellationToken) ? requested : null;
        }

        return await _db.Depots.OrderBy(item => item.Name).Select(item => (Guid?)item.Id).FirstOrDefaultAsync(cancellationToken);
    }

    private static List<string> ValidateZone(ZoneWriteRequest request)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            errors.Add("Zone name is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Sector))
        {
            errors.Add("Sector is required.");
        }

        if (string.IsNullOrWhiteSpace(request.City))
        {
            errors.Add("City is required.");
        }

        return errors;
    }
}
