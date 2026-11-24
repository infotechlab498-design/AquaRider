using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class DepotOperationsService : IDepotOperationsService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public DepotOperationsService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<DepotDetailDto>> GetAsync(CancellationToken cancellationToken)
    {
        var depot = await MainDepotAsync(cancellationToken);
        if (depot is null)
        {
            return ServiceResult<DepotDetailDto>.Fail(404, "No main warehouse is registered.");
        }

        return ServiceResult<DepotDetailDto>.Ok(ToDetail(depot), "Main warehouse loaded.");
    }

    public async Task<ServiceResult<DepotOperationsDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var depot = await MainDepotAsync(cancellationToken);
        if (depot is null)
        {
            return ServiceResult<DepotOperationsDto>.Fail(404, "No main warehouse is registered.");
        }

        var day = date ?? ReportingWindow.Today();
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(day, day);
        var fleet = await BuildFleetAsync(depot.Id, cancellationToken);
        var stock = await BuildStockAsync(cancellationToken);
        var occupied = stock.Sum(item => item.QuantityOnVans);
        var expected = stock.Sum(item => item.DepotExpected);
        var capacityMax = Math.Max(expected, occupied);
        var available = Math.Max(0, capacityMax - occupied);
        var utilization = capacityMax == 0
            ? 0
            : Math.Min(100m, ReportingWindow.Percent(occupied, capacityMax));

        var activeVehicles = fleet.Count(item => item.RiderActive && !string.IsNullOrWhiteSpace(item.RiderUserId));
        var dispatchOrders = await _db.CustomerOrders.AsNoTracking()
            .CountAsync(item => item.DeliveryDate == day && item.Status != CustomerOrderStatus.Cancelled, cancellationToken);
        var dispatchVolume = await _db.SaleLines.AsNoTracking()
            .Where(line => line.Sale.Status == SaleStatus.Completed
                && line.Sale.CreatedAt >= rangeStart
                && line.Sale.CreatedAt < rangeEnd)
            .SumAsync(line => (int?)line.Quantity, cancellationToken) ?? 0;
        var linkedStores = await _db.Customers.AsNoTracking()
            .CountAsync(item => !item.IsDeleted, cancellationToken);
        var completedSales = await _db.Sales.AsNoTracking()
            .CountAsync(item => item.Status == SaleStatus.Completed
                && item.CreatedAt >= rangeStart
                && item.CreatedAt < rangeEnd, cancellationToken);
        var billed = await _db.Sales.AsNoTracking()
            .Where(item => item.Status == SaleStatus.Completed
                && item.CreatedAt >= rangeStart
                && item.CreatedAt < rangeEnd)
            .SumAsync(item => (decimal?)item.SaleAmount, cancellationToken) ?? 0;
        var manager = fleet
            .Where(item => item.RiderActive && !string.IsNullOrWhiteSpace(item.RiderName))
            .Select(item => item.RiderName)
            .FirstOrDefault();

        var kpis = new DepotKpiDto(
            TotalDepots: 1,
            CentralWarehouses: 1,
            SatelliteHubs: 0,
            ActiveWarehouses: 1,
            ActivePercent: 100m,
            AssignedFleet: fleet.Count,
            ActiveVehicles: activeVehicles,
            TodaysDispatchOrders: dispatchOrders,
            TodaysDispatchVolume: dispatchVolume,
            DispatchUnit: "units",
            LinkedStores: linkedStores);

        var capacity = new DepotCapacityDto(
            OccupiedUnits: occupied,
            ExpectedUnits: expected,
            AvailableUnits: available,
            UtilizationPercent: utilization,
            UnitLabel: "units on assigned vans");

        var dto = new DepotOperationsDto(
            ToDetail(depot),
            kpis,
            capacity,
            fleet,
            stock,
            completedSales,
            billed,
            manager,
            "Locked V1: single Main Warehouse. Multi-depot network is not available.");
        return ServiceResult<DepotOperationsDto>.Ok(dto, "Main warehouse operations loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<DepotFleetMemberDto>>> FleetAsync(CancellationToken cancellationToken)
    {
        var depot = await MainDepotAsync(cancellationToken);
        if (depot is null)
        {
            return ServiceResult<IReadOnlyList<DepotFleetMemberDto>>.Fail(404, "No main warehouse is registered.");
        }

        IReadOnlyList<DepotFleetMemberDto> fleet = await BuildFleetAsync(depot.Id, cancellationToken);
        return ServiceResult<IReadOnlyList<DepotFleetMemberDto>>.Ok(
            fleet,
            fleet.Count == 0 ? "No vehicles are assigned." : "Depot fleet loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<DepotStockLineDto>>> StockAsync(CancellationToken cancellationToken)
    {
        if (await MainDepotAsync(cancellationToken) is null)
        {
            return ServiceResult<IReadOnlyList<DepotStockLineDto>>.Fail(404, "No main warehouse is registered.");
        }

        IReadOnlyList<DepotStockLineDto> stock = await BuildStockAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<DepotStockLineDto>>.Ok(
            stock,
            stock.Count == 0 ? "No van stock rows were found." : "Depot stock rollup loaded.");
    }

    public async Task<ServiceResult<DepotDetailDto>> UpdateAsync(UpdateDepotRequest request, CancellationToken cancellationToken)
    {
        var name = (request.Name ?? "").Trim();
        var gate = (request.Gate ?? "").Trim();
        var address = (request.Address ?? "").Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            return ServiceResult<DepotDetailDto>.Fail(400, "Warehouse name is required.");
        }

        if (string.IsNullOrWhiteSpace(address))
        {
            return ServiceResult<DepotDetailDto>.Fail(400, "Warehouse address is required.");
        }

        var depot = await _db.Depots.OrderBy(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        if (depot is null)
        {
            return ServiceResult<DepotDetailDto>.Fail(404, "No main warehouse is registered.");
        }

        depot.Name = name;
        depot.Gate = gate;
        depot.Address = address;
        if (!string.IsNullOrWhiteSpace(_current.UserId))
        {
            _db.AuditLogs.Add(new AuditLog
            {
                UserId = _current.UserId!,
                Action = "UpdateDepot",
                EntityName = "Depot",
                EntityId = depot.Id.ToString()
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<DepotDetailDto>.Ok(ToDetail(depot), "Main warehouse updated.");
    }

    public async Task<ServiceResult<DepotDetailDto>> CreateAsync(CreateWarehouseRequest request, CancellationToken cancellationToken)
    {
        var name = (request.Name ?? "").Trim();
        var address = (request.Address ?? "").Trim();
        if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(address))
        {
            return ServiceResult<DepotDetailDto>.Fail(400, "Warehouse name and address are required.");
        }

        var depot = new Depot { Name = name, Gate = (request.Gate ?? "").Trim(), Address = address };
        _db.Depots.Add(depot);
        if (!string.IsNullOrWhiteSpace(_current.UserId))
        {
            _db.AuditLogs.Add(new AuditLog { UserId = _current.UserId!, Action = "CreateDepot", EntityName = "Depot", EntityId = depot.Id.ToString() });
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<DepotDetailDto>.Created(ToDetail(depot), "Warehouse saved.");
    }

    public async Task<ServiceResult<InventoryCountDto>> CountStockAsync(InventoryCountRequest request, CancellationToken cancellationToken)
    {
        if (request.CountedQuantity < 0) return ServiceResult<InventoryCountDto>.Fail(400, "Counted quantity cannot be negative.");
        var depot = await _db.Depots.FirstOrDefaultAsync(item => item.Id == request.DepotId, cancellationToken);
        var product = await _db.Products.FirstOrDefaultAsync(item => item.Id == request.ProductId, cancellationToken);
        if (depot is null || product is null) return ServiceResult<InventoryCountDto>.Fail(404, "Warehouse or product was not found.");
        var stock = await _db.WarehouseStocks.FirstOrDefaultAsync(item => item.DepotId == depot.Id && item.ProductId == product.Id, cancellationToken);
        var expected = stock?.Quantity ?? 0;
        if (stock is null)
        {
            stock = new WarehouseStock { DepotId = depot.Id, ProductId = product.Id, Quantity = request.CountedQuantity };
            _db.WarehouseStocks.Add(stock);
        }
        else
        {
            stock.Quantity = request.CountedQuantity;
        }

        var count = new InventoryCountLine
        {
            DepotId = depot.Id,
            ProductId = product.Id,
            ExpectedQuantity = expected,
            CountedQuantity = request.CountedQuantity,
            Variance = request.CountedQuantity - expected,
            CountedByUserId = _current.UserId ?? "",
            Note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim()
        };
        _db.InventoryCountLines.Add(count);
        if (!string.IsNullOrWhiteSpace(_current.UserId))
        {
            _db.AuditLogs.Add(new AuditLog { UserId = _current.UserId!, Action = "InventoryCount", EntityName = "WarehouseStock", EntityId = count.Id.ToString() });
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<InventoryCountDto>.Ok(
            new InventoryCountDto(count.Id, depot.Id, product.Id, product.Name, expected, count.CountedQuantity, count.Variance, count.CountedAt.ToString("yyyy-MM-dd HH:mm")),
            "Warehouse count saved.");
    }

    private async Task<Depot?> MainDepotAsync(CancellationToken cancellationToken) =>
        await _db.Depots.AsNoTracking().OrderBy(item => item.Name).FirstOrDefaultAsync(cancellationToken);

    private async Task<List<DepotFleetMemberDto>> BuildFleetAsync(Guid depotId, CancellationToken cancellationToken)
    {
        var vehicles = await _db.Vehicles.AsNoTracking().OrderBy(item => item.Name).ToListAsync(cancellationToken);
        var riders = await _db.Users.AsNoTracking()
            .Where(user => user.VehicleId != null)
            .Select(user => new
            {
                user.Id,
                user.FullName,
                user.RiderCode,
                user.IsActive,
                user.VehicleId,
                user.DepotId
            })
            .ToListAsync(cancellationToken);
        var stockByVehicle = await _db.VehicleStocks.AsNoTracking()
            .GroupBy(item => item.VehicleId)
            .Select(group => new { VehicleId = group.Key, Qty = group.Sum(item => item.Quantity) })
            .ToDictionaryAsync(item => item.VehicleId, item => item.Qty, cancellationToken);

        return vehicles.Select(vehicle =>
        {
            var rider = riders.FirstOrDefault(item => item.VehicleId == vehicle.Id
                && (item.DepotId == null || item.DepotId == depotId));
            stockByVehicle.TryGetValue(vehicle.Id, out var units);
            return new DepotFleetMemberDto(
                vehicle.Id.ToString(),
                vehicle.Name,
                vehicle.Plate,
                vehicle.FleetCode,
                rider?.Id,
                rider?.FullName,
                rider?.RiderCode,
                rider?.IsActive ?? false,
                units);
        }).ToList();
    }

    private async Task<List<DepotStockLineDto>> BuildStockAsync(CancellationToken cancellationToken)
    {
        var rows = await _db.VehicleStocks.AsNoTracking()
            .Include(item => item.Product)
            .ToListAsync(cancellationToken);
        return rows
            .GroupBy(item => item.ProductId)
            .Select(group =>
            {
                var product = group.First().Product;
                return new DepotStockLineDto(
                    product.Id,
                    product.Name,
                    product.Sku,
                    group.Sum(item => item.Quantity),
                    group.Sum(item => item.DepotExpected),
                    product.IsReturnable);
            })
            .OrderBy(item => item.ProductName)
            .ToList();
    }

    private static DepotDetailDto ToDetail(Depot depot) =>
        new(
            depot.Id,
            depot.Name,
            depot.Gate,
            depot.Address,
            "PRIMARY DEPOT",
            "Active",
            $"WH-{depot.Id.ToString("N")[..8].ToUpperInvariant()}");
}
