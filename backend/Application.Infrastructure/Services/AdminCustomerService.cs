using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminCustomerService : IAdminCustomerService
{
    private readonly AppDbContext _db;
    private readonly IZonesRoutesService _zonesRoutes;

    public AdminCustomerService(AppDbContext db, IZonesRoutesService zonesRoutes)
    {
        _db = db;
        _zonesRoutes = zonesRoutes;
    }

    public async Task<ServiceResult<AdminCustomersSummaryDto>> SummaryAsync(CancellationToken cancellationToken)
    {
        var customers = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .Select(item => new { item.Status, item.Outstanding, item.Latitude, item.Longitude, item.CreatedAt })
            .ToListAsync(cancellationToken);
        var monthStart = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var dto = new AdminCustomersSummaryDto(
            customers.Count,
            customers.Count(item => item.Status.Equals("Active", StringComparison.OrdinalIgnoreCase)),
            customers.Count(item => !item.Status.Equals("Active", StringComparison.OrdinalIgnoreCase)),
            customers.Count(item => item.CreatedAt >= monthStart),
            customers.Sum(item => item.Outstanding),
            customers.Count(item => item.Outstanding > 0),
            customers.Count(item => item.Latitude is null || item.Longitude is null));
        return ServiceResult<AdminCustomersSummaryDto>.Ok(dto, "Customer directory summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminCustomerRowDto>>> ListAsync(
        string? search,
        string? status,
        Guid? routeId,
        Guid? zoneId,
        string? area,
        bool? withOutstanding,
        bool? missingGps,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var query = _db.Customers.AsNoTracking()
            .Include(item => item.Route).ThenInclude(route => route.Zone)
            .Where(item => !item.IsDeleted);

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(item => item.Status == status.Trim());
        }

        if (routeId is not null)
        {
            query = query.Where(item => item.RouteId == routeId);
        }

        if (zoneId is not null)
        {
            query = query.Where(item => item.Route.ZoneId == zoneId);
        }

        if (!string.IsNullOrWhiteSpace(area))
        {
            var term = area.Trim();
            query = query.Where(item => item.Area.Contains(term));
        }

        if (withOutstanding == true)
        {
            query = query.Where(item => item.Outstanding > 0);
        }

        if (missingGps == true)
        {
            query = query.Where(item => item.Latitude == null || item.Longitude == null);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.BusinessName.Contains(term)
                || item.Code.Contains(term)
                || item.PrimaryMobile.Contains(term)
                || item.Area.Contains(term)
                || item.Street.Contains(term));
        }

        var total = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderBy(item => item.BusinessName)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .ToListAsync(cancellationToken);
        IReadOnlyList<AdminCustomerRowDto> data = rows.Select(ToRow).ToList();
        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<AdminCustomerRowDto>>.Ok(
            data,
            data.Count == 0 ? "No customers matched the filters." : "Customers loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<AdminCustomerDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(404, "Customer was not found.");
        }

        return ServiceResult<AdminCustomerDetailDto>.Ok(await ToDetailAsync(customer, cancellationToken), "Customer loaded.");
    }

    public async Task<ServiceResult<AdminCustomerDetailDto>> CreateAsync(
        AdminCustomerWriteRequest request,
        CancellationToken cancellationToken)
    {
        var errors = Validate(request, requireRoute: true);
        if (errors.Count > 0)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Check the customer form.", errors.ToArray());
        }

        if (!Enum.TryParse<BottleOwnership>(request.BottleOwnership, true, out var ownership))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Bottle ownership must be Rented or Own.");
        }

        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Assign a valid route.");
        }

        var maxSort = await _db.Customers
            .Where(item => item.RouteId == request.RouteId && !item.IsDeleted)
            .Select(item => (int?)item.RouteSortOrder)
            .MaxAsync(cancellationToken) ?? 0;

        var openingDebt = request.OpeningDebt ?? 0;
        var openingEmpties = request.OpeningEmpties ?? 0;
        var customer = new Customer
        {
            Code = await NextCodeAsync(cancellationToken),
            BusinessName = request.BusinessName.Trim(),
            PrimaryMobile = request.PrimaryMobile.Trim(),
            AdditionalContact = Clean(request.AdditionalContact),
            Category = request.Category.Trim(),
            Street = request.Street.Trim(),
            Area = request.Area.Trim(),
            City = request.City.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            RouteId = request.RouteId,
            RouteSortOrder = maxSort + 1,
            Status = string.IsNullOrWhiteSpace(request.Status) ? "Active" : request.Status.Trim(),
            BottleOwnership = ownership,
            Outstanding = openingDebt,
            BottlesHeld = openingEmpties,
            Cnic = Clean(request.Cnic),
            ContactName = Clean(request.ContactName),
            ContactRole = Clean(request.ContactRole),
            CreditDays = request.CreditDays is > 0 ? request.CreditDays.Value : 7
        };
        _db.Customers.Add(customer);
        if (openingDebt > 0)
        {
            _db.LedgerEntries.Add(new LedgerEntry
            {
                CustomerId = customer.Id,
                Kind = LedgerKind.Opening,
                Description = "Opening balance",
                Amount = openingDebt,
                BalanceAfter = openingDebt
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
        var stored = await CustomerQuery().FirstAsync(item => item.Id == customer.Id, cancellationToken);
        return ServiceResult<AdminCustomerDetailDto>.Created(await ToDetailAsync(stored, cancellationToken), "Customer created.");
    }

    public async Task<ServiceResult<AdminCustomerDetailDto>> UpdateAsync(
        Guid id,
        AdminCustomerWriteRequest request,
        CancellationToken cancellationToken)
    {
        var errors = Validate(request, requireRoute: true);
        if (errors.Count > 0)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Check the customer form.", errors.ToArray());
        }

        if (!Enum.TryParse<BottleOwnership>(request.BottleOwnership, true, out var ownership))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Bottle ownership must be Rented or Own.");
        }

        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(404, "Customer was not found.");
        }

        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Assign a valid route.");
        }

        var message = "Customer updated.";
        if (customer.RouteId != request.RouteId)
        {
            await MoveRouteAsync(customer, request.RouteId, cancellationToken);
        }

        customer.BusinessName = request.BusinessName.Trim();
        customer.PrimaryMobile = request.PrimaryMobile.Trim();
        customer.AdditionalContact = Clean(request.AdditionalContact);
        customer.Category = request.Category.Trim();
        customer.Street = request.Street.Trim();
        customer.Area = request.Area.Trim();
        customer.City = request.City.Trim();
        customer.Latitude = request.Latitude;
        customer.Longitude = request.Longitude;
        customer.BottleOwnership = ownership;
        customer.Cnic = Clean(request.Cnic);
        customer.ContactName = Clean(request.ContactName);
        customer.ContactRole = Clean(request.ContactRole);
        if (!string.IsNullOrWhiteSpace(request.Status))
        {
            customer.Status = request.Status.Trim();
        }

        if (request.CreditDays is > 0)
        {
            customer.CreditDays = request.CreditDays.Value;
        }

        var hasLedger = await _db.LedgerEntries.AnyAsync(entry => entry.CustomerId == id, cancellationToken);
        if (!hasLedger)
        {
            if (request.OpeningDebt is not null)
            {
                customer.Outstanding = request.OpeningDebt.Value;
                if (request.OpeningDebt.Value > 0)
                {
                    _db.LedgerEntries.Add(new LedgerEntry
                    {
                        CustomerId = customer.Id,
                        Kind = LedgerKind.Opening,
                        Description = "Opening balance",
                        Amount = request.OpeningDebt.Value,
                        BalanceAfter = request.OpeningDebt.Value
                    });
                }
            }

            if (request.OpeningEmpties is not null)
            {
                customer.BottlesHeld = request.OpeningEmpties.Value;
            }
        }
        else if (request.OpeningDebt is not null || request.OpeningEmpties is not null)
        {
            message = "Customer updated. Opening balances were kept because ledger activity already exists.";
        }

        await _db.SaveChangesAsync(cancellationToken);
        var stored = await CustomerQuery().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<AdminCustomerDetailDto>.Ok(await ToDetailAsync(stored, cancellationToken), message);
    }

    public async Task<ServiceResult<AdminCustomerDetailDto>> ChangeRouteAsync(
        Guid id,
        ChangeCustomerRouteRequest request,
        CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(404, "Customer was not found.");
        }

        if (!await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Assign a valid route.");
        }

        if (customer.RouteId != request.RouteId)
        {
            await MoveRouteAsync(customer, request.RouteId, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
        }

        var stored = await CustomerQuery().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<AdminCustomerDetailDto>.Ok(await ToDetailAsync(stored, cancellationToken), "Route assignment updated.");
    }

    public async Task<ServiceResult<AdminCustomerDetailDto>> SetStatusAsync(
        Guid id,
        SetCustomerStatusRequest request,
        CancellationToken cancellationToken)
    {
        var status = request.Status?.Trim() ?? "";
        if (status is not ("Active" or "Inactive" or "On-Hold"))
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(400, "Status must be Active, Inactive, or On-Hold.");
        }

        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<AdminCustomerDetailDto>.Fail(404, "Customer was not found.");
        }

        customer.Status = status;
        await _db.SaveChangesAsync(cancellationToken);
        var stored = await CustomerQuery().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<AdminCustomerDetailDto>.Ok(await ToDetailAsync(stored, cancellationToken), "Customer status updated.");
    }

    public async Task<ServiceResult<LedgerDto>> LedgerAsync(Guid id, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
        if (customer is null)
        {
            return ServiceResult<LedgerDto>.Fail(404, "Customer was not found.");
        }

        var entries = await _db.LedgerEntries.AsNoTracking()
            .Where(entry => entry.CustomerId == id)
            .OrderByDescending(entry => entry.OccurredAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        var rows = entries.Select(entry => new LedgerRowDto(
            entry.Id,
            entry.Description,
            entry.OccurredAt,
            entry.Amount,
            entry.BalanceAfter,
            entry.Kind.ToString(),
            entry.Reference)).ToList();
        var openOrders = await _db.CustomerOrders.CountAsync(
            order => order.CustomerId == id && order.Status == CustomerOrderStatus.Scheduled,
            cancellationToken);
        var dto = new LedgerDto(
            customer.Id,
            customer.BusinessName,
            customer.Code,
            customer.Outstanding,
            customer.CreditDays,
            customer.BottlesIssued,
            customer.BottlesReturned,
            customer.BottlesHeld,
            rows,
            openOrders);
        return ServiceResult<LedgerDto>.Ok(dto, "Ledger loaded.");
    }

    private IQueryable<Customer> CustomerQuery() =>
        _db.Customers.Include(item => item.Route).ThenInclude(route => route.Zone);

    private async Task<AdminCustomerDetailDto> ToDetailAsync(Customer customer, CancellationToken cancellationToken)
    {
        var recent = await _db.LedgerEntries.AsNoTracking()
            .Where(entry => entry.CustomerId == customer.Id)
            .OrderByDescending(entry => entry.OccurredAt)
            .Take(8)
            .ToListAsync(cancellationToken);
        var lifetimeSales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.CustomerId == customer.Id && sale.Status == SaleStatus.Completed)
            .SumAsync(sale => (decimal?)sale.SaleAmount, cancellationToken) ?? 0;
        var lifetimeCollections = await _db.Collections.AsNoTracking()
            .Where(item => item.CustomerId == customer.Id)
            .SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var routes = await _zonesRoutes.ListRoutesAsync(null, null, cancellationToken);
        string? lastPayment = null;
        if (customer.LastPaymentAt is not null && customer.LastPaymentAmount is not null)
        {
            lastPayment = $"{customer.LastPaymentAt.Value.ToLocalTime():dd MMM} (PKR {customer.LastPaymentAmount.Value:0})";
        }

        return new AdminCustomerDetailDto(
            ToRow(customer),
            customer.ContactName,
            customer.ContactRole,
            customer.AdditionalContact,
            customer.Cnic,
            customer.BottleOwnership.ToString(),
            customer.CreditDays,
            lastPayment,
            lifetimeSales,
            lifetimeCollections,
            recent.Select(entry => new LedgerRowDto(
                entry.Id,
                entry.Description,
                entry.OccurredAt,
                entry.Amount,
                entry.BalanceAfter,
                entry.Kind.ToString(),
                entry.Reference)).ToList(),
            routes.Data ?? []);
    }

    private static AdminCustomerRowDto ToRow(Customer customer) =>
        new(
            customer.Id,
            customer.Code,
            customer.BusinessName,
            customer.Category,
            customer.Status,
            customer.PrimaryMobile,
            customer.Area,
            customer.City,
            $"{customer.Street}, {customer.Area}",
            customer.RouteId,
            customer.Route.Name,
            customer.Route.ZoneId,
            customer.Route.Zone?.Name,
            customer.Outstanding,
            customer.BottlesHeld,
            customer.BottlesIssued,
            customer.BottlesReturned,
            customer.Latitude is not null && customer.Longitude is not null,
            customer.Latitude,
            customer.Longitude,
            customer.CreatedAt,
            customer.LastDropAt);

    private async Task MoveRouteAsync(Customer customer, Guid routeId, CancellationToken cancellationToken)
    {
        var maxSort = await _db.Customers
            .Where(item => item.RouteId == routeId && !item.IsDeleted)
            .Select(item => (int?)item.RouteSortOrder)
            .MaxAsync(cancellationToken) ?? 0;
        customer.RouteId = routeId;
        customer.RouteSortOrder = maxSort + 1;
        var today = ReportingWindow.Today();
        var stops = await _db.RouteStops
            .Where(item => item.CustomerId == customer.Id && item.ServiceDate >= today)
            .ToListAsync(cancellationToken);
        foreach (var stop in stops)
        {
            stop.RouteId = routeId;
        }
    }

    private async Task<string> NextCodeAsync(CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstOrDefaultAsync(item => item.Name == "Customer", cancellationToken);
        if (sequence is null)
        {
            sequence = new NumberSequence { Name = "Customer", NextValue = 1000 };
            _db.NumberSequences.Add(sequence);
        }

        var value = sequence.NextValue++;
        return $"CUS-{value:0000}";
    }

    private static List<string> Validate(AdminCustomerWriteRequest request, bool requireRoute)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(request.BusinessName))
        {
            errors.Add("Business name is required.");
        }

        if (string.IsNullOrWhiteSpace(request.PrimaryMobile))
        {
            errors.Add("Primary mobile is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Category))
        {
            errors.Add("Category is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Street))
        {
            errors.Add("Street is required.");
        }

        if (string.IsNullOrWhiteSpace(request.Area))
        {
            errors.Add("Area is required.");
        }

        if (string.IsNullOrWhiteSpace(request.City))
        {
            errors.Add("City is required.");
        }

        if (requireRoute && request.RouteId == Guid.Empty)
        {
            errors.Add("Route is required.");
        }

        return errors;
    }

    private static string? Clean(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
