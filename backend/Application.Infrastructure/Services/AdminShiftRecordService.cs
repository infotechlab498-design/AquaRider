using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminShiftRecordService : IAdminShiftRecordService
{
    private readonly AppDbContext _db;

    public AdminShiftRecordService(AppDbContext db)
    {
        _db = db;
    }

    public async Task<ServiceResult<ShiftDayDto>> DayAsync(DateOnly? date, string? riderId, CancellationToken cancellationToken)
    {
        var day = date ?? DateOnly.FromDateTime(DateTime.Today);
        var roleId = await _db.Roles.AsNoTracking()
            .Where(role => role.Name == AppRoles.Rider)
            .Select(role => role.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (roleId is null)
        {
            return ServiceResult<ShiftDayDto>.Ok(new ShiftDayDto(day.ToString("yyyy-MM-dd"), [], null, []), "No riders are registered.");
        }

        var shifts = await _db.Shifts.AsNoTracking()
            .Include(shift => shift.Lines).ThenInclude(line => line.Product)
            .Where(shift => shift.ServiceDate == day)
            .ToListAsync(cancellationToken);
        var orders = await _db.CustomerOrders.AsNoTracking()
            .Include(order => order.Lines).ThenInclude(line => line.Product)
            .Where(order => order.DeliveryDate == day && order.ShowOnManifest && order.Status != CustomerOrderStatus.Cancelled)
            .ToListAsync(cancellationToken);
        var involved = shifts.Select(shift => shift.RiderId).Concat(orders.Select(order => order.RiderId)).ToHashSet();
        var riders = await _db.Users.AsNoTracking()
            .Include(user => user.Vehicle)
            .Include(user => user.Route)
            .Include(user => user.Depot)
            .Where(user => _db.UserRoles.Any(link => link.UserId == user.Id && link.RoleId == roleId))
            .Where(user => user.IsActive || involved.Contains(user.Id))
            .OrderBy(user => user.FullName)
            .ToListAsync(cancellationToken);

        var rows = riders.Select(rider => ToRow(
            rider,
            shifts.Where(shift => shift.RiderId == rider.Id).OrderByDescending(shift => shift.StartedAt).FirstOrDefault(),
            orders.Where(order => order.RiderId == rider.Id).ToList(),
            includePhotos: false)).ToList();
        var selectedId = string.IsNullOrWhiteSpace(riderId) ? rows.FirstOrDefault()?.RiderId : riderId.Trim();
        ShiftRiderDayDto? selected = null;
        var odometer = new List<OdometerDayDto>();
        if (selectedId is not null)
        {
            var rider = riders.FirstOrDefault(item => item.Id == selectedId);
            if (rider is not null)
            {
                selected = ToRow(
                    rider,
                    shifts.Where(shift => shift.RiderId == rider.Id).OrderByDescending(shift => shift.StartedAt).FirstOrDefault(),
                    orders.Where(order => order.RiderId == rider.Id).ToList(),
                    includePhotos: true);
                var history = await _db.Shifts.AsNoTracking()
                    .Where(shift => shift.RiderId == rider.Id)
                    .OrderByDescending(shift => shift.ServiceDate)
                    .ThenByDescending(shift => shift.StartedAt)
                    .ToListAsync(cancellationToken);
                odometer = history.Select(shift => new OdometerDayDto(
                    shift.ServiceDate.ToString("yyyy-MM-dd"),
                    shift.Status,
                    shift.OpeningOdometer,
                    shift.ClosingOdometer,
                    shift.ClosingOdometer is int closing ? closing - shift.OpeningOdometer : null)).ToList();
            }
        }

        return ServiceResult<ShiftDayDto>.Ok(
            new ShiftDayDto(day.ToString("yyyy-MM-dd"), rows, selected, odometer),
            rows.Count == 0 ? "No riders were returned for this date." : "Shift records loaded.");
    }

    private static ShiftRiderDayDto ToRow(ApplicationUser rider, Shift? shift, List<CustomerOrder> orders, bool includePhotos)
    {
        var loaded = shift?.Lines
            .OrderBy(line => line.Product.Name)
            .Select(line => new LoadedBottleDto(line.Product.Name, line.Product.UnitLabel, line.ExpectedQuantity, line.CountedQuantity, line.ClosingQuantity))
            .ToList() ?? [];
        var toDeliver = orders
            .SelectMany(order => order.Lines)
            .GroupBy(line => line.ProductId)
            .Select(group => new DeliverBottleDto(group.First().Product.Name, group.First().Product.UnitLabel, group.Sum(line => line.Quantity)))
            .OrderBy(line => line.ProductName)
            .ToList();
        var status = shift is null ? "NotStarted" : shift.Status == "Closed" ? "Closed" : "Open";
        return new ShiftRiderDayDto(
            rider.Id,
            rider.FullName,
            rider.RiderCode ?? "",
            rider.Route?.Name ?? "",
            rider.Vehicle?.Name ?? "",
            rider.Vehicle?.Plate ?? "",
            rider.Vehicle?.FleetCode ?? "",
            rider.Depot?.Name ?? "",
            status,
            shift?.StartedAt,
            shift?.EndedAt,
            shift?.OpeningOdometer,
            shift?.ClosingOdometer,
            shift?.OpeningOdometerPhoto is { Length: > 0 },
            shift?.ClosingOdometerPhoto is { Length: > 0 },
            shift?.OpeningInspectionPhoto is { Length: > 0 },
            shift?.ClosingInspectionPhoto is { Length: > 0 },
            includePhotos ? Photo(shift?.OpeningOdometerPhoto) : null,
            includePhotos ? Photo(shift?.ClosingOdometerPhoto) : null,
            includePhotos ? Photo(shift?.OpeningInspectionPhoto) : null,
            includePhotos ? Photo(shift?.ClosingInspectionPhoto) : null,
            loaded.Sum(line => line.Loaded),
            loaded.Sum(line => line.DepotExpected),
            toDeliver.Sum(line => line.Quantity),
            orders.Count,
            loaded,
            toDeliver);
    }

    private static string? Photo(byte[]? bytes) => bytes is { Length: > 0 } ? Convert.ToBase64String(bytes) : null;
}
