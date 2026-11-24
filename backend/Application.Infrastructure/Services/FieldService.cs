using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class FieldService : IFieldService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public FieldService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<DashboardDto>> DashboardAsync(CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<DashboardDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var user = access.User!;
        var today = DateOnly.FromDateTime(DateTime.Today);
        await PlaceAssignedOrdersAsync(user, today, cancellationToken);
        var (start, end) = TodayRange();
        var stops = await _db.RouteStops
            .Include(stop => stop.Customer)
            .Where(stop => stop.RouteId == user.RouteId && stop.ServiceDate == today)
            .ToListAsync(cancellationToken);
        var sales = await _db.Sales
            .Where(sale => sale.RiderId == user.Id && sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end)
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections
            .Where(item => item.RiderId == user.Id && item.CreatedAt >= start && item.CreatedAt < end && item.Channel == PaymentChannel.Cash)
            .SumAsync(item => item.Amount, cancellationToken);
        var cashSales = sales.Where(sale => sale.PaymentChannel == PaymentChannel.Cash).Sum(sale => sale.AmountReceived);
        var remaining = stops.Where(stop => stop.Status is StopStatus.Pending or StopStatus.InProgress or StopStatus.Missed).ToList();
        var next = remaining.OrderBy(stop => stop.Sequence).FirstOrDefault();
        var urgent = remaining.Count(stop => stop.Status == StopStatus.Pending && stop.ScheduledTime is not null && stop.ScheduledTime < new TimeOnly(12, 0));
        var shiftOpen = await _db.Shifts.AnyAsync(shift => shift.RiderId == user.Id && shift.Status == "Open", cancellationToken);
        var hour = DateTime.Now.Hour;
        var part = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening";
        var first = user.FullName.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? user.FullName;
        var soldCustomers = sales.Select(sale => sale.CustomerId).ToHashSet();
        var visited = stops.Count(stop => stop.Status == StopStatus.Completed || soldCustomers.Contains(stop.CustomerId));
        var dto = new DashboardDto(
            $"Good {part}, {first}",
            today.ToString("yyyy-MM-dd"),
            await ProfileAsync(user),
            shiftOpen,
            new PerformanceDto(
                sales.Sum(sale => sale.SaleAmount),
                sales.Count,
                cashSales + collections,
                visited,
                stops.Count,
                remaining.Count,
                remaining.Count == 0
                    ? "None open"
                    : urgent == 0
                        ? "Still on today's route"
                        : $"{urgent} due before 12:00"),
            new RouteSummaryDto(
                stops.Count,
                remaining.Count,
                next?.Customer.BusinessName,
                next?.DistanceMeters,
                Math.Round(remaining.Sum(stop => stop.DistanceMeters ?? 0) / 1000m, 1),
                next?.Customer.Latitude,
                next?.Customer.Longitude,
                next == null ? null : $"{next.Customer.Street}, {next.Customer.Area}, {next.Customer.City}"),
            remaining.Count);
        return ServiceResult<DashboardDto>.Ok(dto, "Dashboard loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<StopDto>>> StopsAsync(string? search, string? filter, int page, int pageSize, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        page = page < 1 ? 1 : page;
        pageSize = pageSize is < 1 or > 100 ? 20 : pageSize;
        var today = DateOnly.FromDateTime(DateTime.Today);
        await PlaceAssignedOrdersAsync(access.User!, today, cancellationToken);
        var query = _db.RouteStops
            .Include(stop => stop.Customer)
            .Where(stop => stop.RouteId == access.User!.RouteId && stop.ServiceDate == today);
        var mode = (filter ?? "all").Trim().ToLowerInvariant();
        if (mode == "missed")
        {
            query = query.Where(stop => stop.Status == StopStatus.Missed);
        }
        else if (mode == "drafts")
        {
            var draftCustomers = _db.Sales.Where(sale => sale.Status == SaleStatus.Draft).Select(sale => sale.CustomerId);
            query = query.Where(stop => draftCustomers.Contains(stop.CustomerId));
        }
        else if (mode == "orders")
        {
            var ordered = _db.CustomerOrders.Where(order =>
                order.RiderId == access.User!.Id
                && order.DeliveryDate == today
                && order.ShowOnManifest
                && (order.Status == CustomerOrderStatus.Scheduled || order.Status == CustomerOrderStatus.InProgress))
                .Select(order => order.CustomerId);
            query = query.Where(stop => ordered.Contains(stop.CustomerId));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(stop =>
                stop.Customer.BusinessName.Contains(term) ||
                stop.Customer.Code.Contains(term) ||
                stop.Customer.PrimaryMobile.Contains(term) ||
                stop.Customer.Street.Contains(term) ||
                stop.Customer.Area.Contains(term) ||
                stop.Customer.City.Contains(term));
        }

        var total = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderBy(stop => stop.Sequence)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var stopIds = rows.Select(stop => stop.Id).ToList();
        var receipts = await _db.Sales
            .Where(sale => sale.StopId != null && stopIds.Contains(sale.StopId.Value) && sale.Status == SaleStatus.Completed)
            .Select(sale => new { sale.StopId, sale.Id, sale.ReceiptNumber })
            .ToListAsync(cancellationToken);
        var items = rows.Select(stop =>
        {
            var receipt = receipts.FirstOrDefault(item => item.StopId == stop.Id);
            return ToStop(stop, receipt?.Id, receipt?.ReceiptNumber);
        }).ToList();
        var pages = (int)Math.Ceiling(total / (double)pageSize);
        return ServiceResult<IReadOnlyList<StopDto>>.Ok(
            items,
            "Stops loaded.",
            new PaginationMeta { Page = page, PageSize = pageSize, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<IReadOnlyList<StopDto>>> SequenceTodayStopsAsync(StopSequenceRequest request, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        if (access.User!.RouteId is null)
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(400, "This rider has no assigned route.");
        }

        var ordered = (request.OrderedStopIds ?? []).ToList();
        if (ordered.Count == 0 || ordered.Distinct().Count() != ordered.Count)
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(400, "Provide each stop once.");
        }

        var today = DateOnly.FromDateTime(DateTime.Today);
        var stops = await _db.RouteStops
            .Where(stop => stop.RouteId == access.User.RouteId && stop.ServiceDate == today)
            .OrderBy(stop => stop.Sequence)
            .ToListAsync(cancellationToken);
        if (stops.Count != ordered.Count)
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(400, "Sequence must include every stop for the day exactly once.");
        }

        var completedBefore = stops.Where(stop => stop.Status == StopStatus.Completed).Select(stop => stop.Id).ToList();
        var map = stops.ToDictionary(stop => stop.Id);
        var completedAfter = new List<Guid>();
        for (var index = 0; index < ordered.Count; index++)
        {
            if (!map.TryGetValue(ordered[index], out var stop))
            {
                return ServiceResult<IReadOnlyList<StopDto>>.Fail(400, "Sequence includes a stop that is not on today's route.");
            }

            if (stop.Status == StopStatus.Completed)
            {
                completedAfter.Add(stop.Id);
            }

            stop.Sequence = index + 1;
        }

        if (!completedBefore.SequenceEqual(completedAfter))
        {
            return ServiceResult<IReadOnlyList<StopDto>>.Fail(400, "Completed stops stay in place.");
        }

        await _db.SaveChangesAsync(cancellationToken);
        return await StopsAsync(null, "all", 1, 100, cancellationToken);
    }

    public async Task<ServiceResult<CustomerDetailDto>> CustomerAsync(Guid id, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<CustomerDetailDto>.Fail(denied.StatusCode, denied.Message);
        }

        return ServiceResult<CustomerDetailDto>.Ok(await ToCustomerAsync(customer!, cancellationToken), "Customer loaded.");
    }

    public async Task<ServiceResult<CustomerDetailDto>> CreateCustomerAsync(CustomerWriteRequest request, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<CustomerDetailDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var errors = ValidateCustomer(request);
        if (errors.Count > 0)
        {
            return ServiceResult<CustomerDetailDto>.Fail(400, "Check the customer form.", errors.ToArray());
        }

        if (!Enum.TryParse<BottleOwnership>(request.BottleOwnership, true, out var ownership))
        {
            return ServiceResult<CustomerDetailDto>.Fail(400, "Bottle ownership must be Rented or Own.");
        }

        var routeId = request.RouteId ?? access.User!.RouteId;
        if (routeId is null || !await _db.DeliveryRoutes.AnyAsync(route => route.Id == routeId, cancellationToken))
        {
            return ServiceResult<CustomerDetailDto>.Fail(400, "Assign a valid route.");
        }

        if (access.User!.RouteId != routeId && !_current.IsAdmin)
        {
            return ServiceResult<CustomerDetailDto>.Fail(403, "You can only add customers on your route.");
        }

        var customer = new Customer
        {
            Code = await NextCodeAsync("Customer", "CUS", cancellationToken),
            BusinessName = request.BusinessName.Trim(),
            PrimaryMobile = request.PrimaryMobile.Trim(),
            AdditionalContact = Clean(request.AdditionalContact),
            Category = request.Category.Trim(),
            Street = request.Street.Trim(),
            Area = request.Area.Trim(),
            City = request.City.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            RouteId = routeId.Value,
            BottleOwnership = ownership,
            Outstanding = request.OpeningDebt,
            BottlesHeld = request.OpeningEmpties,
            Cnic = Clean(request.Cnic),
            ContactName = Clean(request.ContactName),
            ContactRole = Clean(request.ContactRole)
        };
        _db.Customers.Add(customer);
        if (request.OpeningDebt > 0)
        {
            _db.LedgerEntries.Add(new LedgerEntry
            {
                CustomerId = customer.Id,
                Kind = LedgerKind.Opening,
                Description = "Opening balance",
                Amount = request.OpeningDebt,
                BalanceAfter = request.OpeningDebt
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
        var stored = await CustomerQuery().FirstAsync(item => item.Id == customer.Id, cancellationToken);
        return ServiceResult<CustomerDetailDto>.Created(await ToCustomerAsync(stored, cancellationToken), "Customer saved.");
    }

    public async Task<ServiceResult<CustomerDetailDto>> UpdateCustomerAsync(Guid id, CustomerWriteRequest request, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<CustomerDetailDto>.Fail(denied.StatusCode, denied.Message);
        }

        var errors = ValidateCustomer(request);
        if (errors.Count > 0)
        {
            return ServiceResult<CustomerDetailDto>.Fail(400, "Check the customer form.", errors.ToArray());
        }

        if (!Enum.TryParse<BottleOwnership>(request.BottleOwnership, true, out var ownership))
        {
            return ServiceResult<CustomerDetailDto>.Fail(400, "Bottle ownership must be Rented or Own.");
        }

        customer!.BusinessName = request.BusinessName.Trim();
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
        var hasLedger = await _db.LedgerEntries.AnyAsync(entry => entry.CustomerId == id, cancellationToken);
        var message = "Customer updated.";
        if (!hasLedger)
        {
            customer.Outstanding = request.OpeningDebt;
            customer.BottlesHeld = request.OpeningEmpties;
            if (request.OpeningDebt > 0)
            {
                _db.LedgerEntries.Add(new LedgerEntry
                {
                    CustomerId = customer.Id,
                    Kind = LedgerKind.Opening,
                    Description = "Opening balance",
                    Amount = request.OpeningDebt,
                    BalanceAfter = request.OpeningDebt
                });
            }
        }
        else
        {
            message = "Customer updated. Opening balances were kept because ledger activity already exists.";
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerDetailDto>.Ok(await ToCustomerAsync(customer, cancellationToken), message);
    }

    public async Task<ServiceResult<SaleContextDto>> SaleContextAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == customerId, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<SaleContextDto>.Fail(denied.StatusCode, denied.Message);
        }

        var access = await RiderAsync(cancellationToken);
        var products = await ProductsForVehicleAsync(access.User!.VehicleId, true, cancellationToken);
        var dto = new SaleContextDto(await ToCustomerAsync(customer!, cancellationToken), products, customer!.BottlesHeld);
        return ServiceResult<SaleContextDto>.Ok(dto, "Sale context loaded.");
    }

    public async Task<ServiceResult<SaleDraftDto>> CreateSaleAsync(CreateSaleRequest request, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == request.CustomerId && !item.IsDeleted, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<SaleDraftDto>.Fail(denied.StatusCode, denied.Message);
        }

        if (request.Lines is null || request.Lines.Count == 0 || request.Lines.All(line => line.Quantity <= 0))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Add at least one item.");
        }

        if (request.StopId is not null && !await _db.RouteStops.AnyAsync(stop => stop.Id == request.StopId && stop.CustomerId == customer!.Id, cancellationToken))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "That stop is not for this customer.");
        }

        var access = await RiderAsync(cancellationToken);
        var productIds = request.Lines.Select(line => line.ProductId).Distinct().ToList();
        var products = await _db.Products.Where(product => productIds.Contains(product.Id) && product.ShowOnSale).ToListAsync(cancellationToken);
        if (products.Count != productIds.Count)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "One or more products are not available.");
        }

        var lines = new List<SaleLine>();
        foreach (var requested in request.Lines.Where(line => line.Quantity > 0))
        {
            var product = products.First(item => item.Id == requested.ProductId);
            var assigned = await _db.PriceListAssignments.AsNoTracking()
                .Where(item => item.CustomerId == customer!.Id && item.PriceList.IsActive)
                .SelectMany(item => item.PriceList.Lines.Where(line => line.ProductId == product.Id))
                .Select(line => (decimal?)line.ListRate)
                .FirstOrDefaultAsync(cancellationToken);
            lines.Add(new SaleLine
            {
                ProductId = product.Id,
                Product = product,
                Quantity = requested.Quantity,
                UnitPrice = assigned ?? product.UnitPrice
            });
        }

        var shop = customer!;
        var held = shop.BottlesHeld;
        var returnableQty = lines.Where(line => line.Product.IsReturnable).Sum(line => line.Quantity);
        var returned = request.EmptyBottlesReturned ?? Math.Min(held, returnableQty);
        if (returned < 0 || returned > held)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Empty bottles returned cannot exceed the bottles this customer holds.");
        }

        var shift = await OpenShiftAsync(access.User!.Id, cancellationToken);
        var sale = new Sale
        {
            ReceiptNumber = $"DFT-{Guid.NewGuid():N}"[..24],
            CustomerId = shop.Id,
            RiderId = access.User.Id,
            ShiftId = shift?.Id,
            StopId = request.StopId,
            SaleAmount = lines.Sum(line => line.Quantity * line.UnitPrice),
            PreviousOutstanding = shop.Outstanding,
            EmptyBottlesReturned = returned,
            Status = SaleStatus.Draft,
            SyncStatus = SyncStatus.Pending,
            Lines = lines
        };
        _db.Sales.Add(sale);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<SaleDraftDto>.Created(ToDraft(sale, shop, returned), "Sale draft saved.");
    }

    public async Task<ServiceResult<ReceiptDto>> CompleteSaleAsync(Guid saleId, CompleteSaleRequest request, CancellationToken cancellationToken)
    {
        if (!TryChannel(request.PaymentMethod, out var channel))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Choose a payment method.");
        }

        if (string.IsNullOrWhiteSpace(request.SignerName))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "A customer signature name is required.");
        }

        var signature = SignatureBytes(request.SignatureImage);
        if (signature.Error is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(400, signature.Error);
        }

        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var sale = await _db.Sales
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.Customer)
            .FirstOrDefaultAsync(item => item.Id == saleId && item.RiderId == access.User!.Id, cancellationToken);
        if (sale is null)
        {
            return ServiceResult<ReceiptDto>.Fail(404, "Sale not found.");
        }

        if (sale.Status != SaleStatus.Draft)
        {
            return ServiceResult<ReceiptDto>.Fail(409, "This sale is already completed.");
        }

        if (sale.Customer.RouteId != access.User!.RouteId)
        {
            return ServiceResult<ReceiptDto>.Fail(403, "This customer is on another route.");
        }

        foreach (var line in sale.Lines)
        {
            var stock = await _db.VehicleStocks.FirstOrDefaultAsync(
                item => item.VehicleId == access.User.VehicleId && item.ProductId == line.ProductId,
                cancellationToken);
            if (stock is null || stock.Quantity < line.Quantity)
            {
                return ServiceResult<ReceiptDto>.Fail(409, $"Not enough van stock for {line.Product.Name}.");
            }
        }

        var due = sale.SaleAmount + sale.Customer.Outstanding;
        var received = request.AmountReceived ?? due;
        if (received < 0 || received > due)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Amount received cannot exceed the amount due.");
        }

        var customer = sale.Customer;
        foreach (var line in sale.Lines)
        {
            var stock = await _db.VehicleStocks.FirstAsync(
                item => item.VehicleId == access.User.VehicleId && item.ProductId == line.ProductId,
                cancellationToken);
            stock.Quantity -= line.Quantity;
            if (line.Product.IsReturnable)
            {
                customer.BottlesIssued += line.Quantity;
            }
        }

        var returned = Math.Min(customer.BottlesHeld, Math.Max(0, sale.EmptyBottlesReturned));
        customer.BottlesReturned += returned;
        customer.BottlesHeld -= returned;

        var previous = customer.Outstanding;
        customer.Outstanding += sale.SaleAmount;
        AddLedger(customer.Id, LedgerKind.Sale, DescribeSale(sale), sale.SaleAmount, customer.Outstanding, sale.ReceiptNumber);
        if (received > 0)
        {
            customer.Outstanding -= received;
            customer.LastPaymentAt = DateTime.UtcNow;
            customer.LastPaymentAmount = received;
            AddLedger(customer.Id, LedgerKind.Payment, $"{channel} payment", -received, customer.Outstanding, sale.ReceiptNumber);
        }

        customer.LastDropAt = DateTime.UtcNow;
        sale.PreviousOutstanding = previous;
        sale.AmountReceived = received;
        sale.PaymentChannel = channel;
        sale.Status = SaleStatus.Completed;
        sale.SignerName = request.SignerName.Trim();
        sale.SignerRole = Clean(request.SignerRole) ?? customer.ContactRole;
        sale.SignedAt = DateTime.UtcNow;
        sale.SignatureImage = signature.Bytes;
        sale.SignatureNote = Clean(request.SignatureNote);
        sale.SyncStatus = SyncStatus.Synced;
        sale.ReceiptNumber = await NextCodeAsync("Receipt", "RCP", cancellationToken);
        if (request.CloseStop)
        {
            var stop = sale.StopId is not null
                ? await _db.RouteStops.FirstOrDefaultAsync(item => item.Id == sale.StopId, cancellationToken)
                : await _db.RouteStops.FirstOrDefaultAsync(
                    item => item.CustomerId == customer.Id && item.ServiceDate == DateOnly.FromDateTime(DateTime.Today),
                    cancellationToken);
            if (stop is not null)
            {
                stop.Status = StopStatus.Completed;
            }

            await DeliverOpenOrdersAsync(customer.Id, access.User!.Id, cancellationToken);
        }

        AddActivity(access.User.Id, $"Sale — {customer.BusinessName}", sale.ReceiptNumber, sale.AmountReceived, SyncStatus.Synced, "Recorded on the server.");
        AddAudit(access.User.Id, "CompleteSale", "Sale", sale.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<ReceiptDto>.Ok(await ReceiptForSaleAsync(sale.Id, cancellationToken), "Sale completed.");
    }

    public async Task<ServiceResult<ReceiptDto>> ReceiptAsync(Guid saleId, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var sale = await _db.Sales.FirstOrDefaultAsync(
            item => item.Id == saleId && item.RiderId == access.User!.Id && item.Status == SaleStatus.Completed,
            cancellationToken);
        if (sale is null)
        {
            return ServiceResult<ReceiptDto>.Fail(404, "Receipt not found.");
        }

        return ServiceResult<ReceiptDto>.Ok(await ReceiptForSaleAsync(sale.Id, cancellationToken), "Receipt loaded.");
    }

    public async Task<ServiceResult<ReceiptDto>> CreateCollectionAsync(CreateCollectionRequest request, CancellationToken cancellationToken)
    {
        if (!TryChannel(request.Channel, out var channel))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Choose a collection channel.");
        }

        if (string.IsNullOrWhiteSpace(request.SignerName))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "A customer signature name is required.");
        }

        var signature = SignatureBytes(request.SignatureImage);
        if (signature.Error is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(400, signature.Error);
        }

        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == request.CustomerId && !item.IsDeleted, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(denied.StatusCode, denied.Message);
        }

        var tax = request.WithholdingTax;
        if (request.Amount <= 0 || tax < 0 || request.Amount + tax > customer!.Outstanding)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Collection and withholding tax must stay within the outstanding balance.");
        }

        var access = await RiderAsync(cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.Today);
        if (await _db.DayLocks.AnyAsync(item => item.BusinessDate == today, cancellationToken))
        {
            return ServiceResult<ReceiptDto>.Fail(409, "This business day is locked. The collection cannot be recorded.");
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var before = customer.Outstanding;
        customer.Outstanding -= request.Amount;
        customer.LastPaymentAt = DateTime.UtcNow;
        customer.LastPaymentAmount = request.Amount;
        if (tax > 0)
        {
            customer.Outstanding -= tax;
        }

        var reference = await NextCodeAsync("Collection", "COL", cancellationToken);
        var collection = new Collection
        {
            ReferenceNumber = reference,
            CustomerId = customer.Id,
            RiderId = access.User!.Id,
            Amount = request.Amount,
            WithholdingTax = tax,
            Notes = Clean(request.Note),
            Channel = channel,
            CashStatus = CashCollectionStatus.CollectedByRider,
            OutstandingBefore = before,
            OutstandingAfter = customer.Outstanding,
            SignerName = request.SignerName.Trim(),
            SignerRole = Clean(request.SignerRole) ?? customer.ContactRole,
            SignatureImage = signature.Bytes,
            SignatureNote = Clean(request.SignatureNote),
            SyncStatus = SyncStatus.Synced
        };
        _db.Collections.Add(collection);
        AddLedger(customer.Id, LedgerKind.Payment, $"{ChannelLabel(channel)} collection", -request.Amount, customer.Outstanding + tax, reference);
        if (tax > 0)
        {
            AddLedger(customer.Id, LedgerKind.Payment, "Withholding tax", -tax, customer.Outstanding, reference);
        }
        AddActivity(access.User.Id, $"Collection — {customer.BusinessName}", reference, request.Amount, SyncStatus.Synced, "Recorded on the server.");
        AddAudit(access.User.Id, "CreateCollection", "Collection", collection.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<ReceiptDto>.Created(await ReceiptForCollectionAsync(collection.Id, cancellationToken), "Collection recorded. It stays Collected by Rider until the warehouse confirms the cash.");
    }

    public async Task<ServiceResult<CashHandoverDto>> SubmitHandoverAsync(DateOnly businessDate, Guid? depotId, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null) return ServiceResult<CashHandoverDto>.Fail(access.Error.StatusCode, access.Error.Message);
        var rider = access.User!;
        var depot = depotId ?? rider.DepotId;
        if (depot is null || !await _db.Depots.AnyAsync(item => item.Id == depot, cancellationToken))
        {
            return ServiceResult<CashHandoverDto>.Fail(400, "Choose the warehouse that will count this cash.");
        }

        var start = businessDate.ToDateTime(TimeOnly.MinValue);
        var end = start.AddDays(1);
        var rows = await _db.Collections
            .Where(item => item.RiderId == rider.Id && item.CreatedAt >= start && item.CreatedAt < end && item.CashStatus == CashCollectionStatus.CollectedByRider && item.HandoverId == null)
            .ToListAsync(cancellationToken);
        if (rows.Count == 0) return ServiceResult<CashHandoverDto>.Fail(400, "There is no unhanded rider collection for that day.");
        var handover = new CashHandover
        {
            ReferenceNumber = await NextCodeAsync("Handover", "HO", cancellationToken),
            RiderId = rider.Id,
            DepotId = depot.Value,
            BusinessDate = businessDate,
            ExpectedAmount = rows.Sum(item => item.Amount),
            Status = CashHandoverStatus.Submitted,
            SubmittedByUserId = rider.Id
        };
        _db.CashHandovers.Add(handover);
        foreach (var row in rows) row.HandoverId = handover.Id;
        AddAudit(rider.Id, "SubmitCashHandover", "CashHandover", handover.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CashHandoverDto>.Created(MapHandover(handover, rows.Count), "Cash handover submitted. The warehouse still has to confirm receipt.");
    }

    private static CashHandoverDto MapHandover(CashHandover handover, int count)
    {
        decimal? difference = handover.ActualAmount is decimal actual ? actual - handover.ExpectedAmount : null;
        return new CashHandoverDto(
            handover.Id,
            handover.ReferenceNumber,
            handover.RiderId,
            handover.DepotId,
            handover.BusinessDate.ToString("yyyy-MM-dd"),
            handover.ExpectedAmount,
            handover.ActualAmount,
            difference,
            handover.Status,
            count,
            handover.SubmittedAt.ToString("yyyy-MM-dd HH:mm"),
            handover.ReceivedAt?.ToString("yyyy-MM-dd HH:mm"));
    }

    public async Task<ServiceResult<OrderDto>> CreateOrderAsync(CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == request.CustomerId && !item.IsDeleted, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<OrderDto>.Fail(denied.StatusCode, denied.Message);
        }

        if (!TryWindow(request.Window, out var window))
        {
            return ServiceResult<OrderDto>.Fail(400, "Choose a delivery window.");
        }

        if (request.Lines is null || request.Lines.All(line => line.Quantity <= 0))
        {
            return ServiceResult<OrderDto>.Fail(400, "Add at least one item.");
        }

        var productIds = request.Lines.Select(line => line.ProductId).Distinct().ToList();
        var products = await _db.Products.Where(product => productIds.Contains(product.Id)).ToDictionaryAsync(product => product.Id, cancellationToken);
        if (products.Count != productIds.Count)
        {
            return ServiceResult<OrderDto>.Fail(400, "One or more products are not available.");
        }

        var access = await RiderAsync(cancellationToken);
        var lines = request.Lines.Where(line => line.Quantity > 0).Select(line => new OrderLine
        {
            ProductId = line.ProductId,
            Quantity = line.Quantity,
            UnitPrice = products[line.ProductId].UnitPrice
        }).ToList();
        var order = new CustomerOrder
        {
            ReferenceNumber = await NextCodeAsync("Order", "ORD", cancellationToken),
            CustomerId = customer!.Id,
            RiderId = access.User!.Id,
            DeliveryDate = request.DeliveryDate ?? DateOnly.FromDateTime(DateTime.Today.AddDays(2)),
            Window = window,
            EstimatedValue = lines.Sum(line => line.Quantity * line.UnitPrice),
            Notes = Clean(request.Note),
            ShowOnManifest = request.ShowOnManifest,
            Origin = OrderOrigin.Rider,
            Lines = lines
        };
        _db.CustomerOrders.Add(order);
        if (request.ShowOnManifest && access.User!.RouteId is Guid routeId)
        {
            await AssignedRouteStop.EnsureAsync(_db, routeId, customer!.Id, order.DeliveryDate, cancellationToken);
        }
        var detail = string.IsNullOrWhiteSpace(order.Notes) ? "Scheduled by the rider." : order.Notes;
        _db.OrderLifecycleEvents.Add(OrderLifecycle.Record(order.Id, OrderLifecycle.OrderCreated, "Order created", detail, access.User!.Id));
        AddActivity(access.User.Id, $"Order — {customer.BusinessName}", order.ReferenceNumber, order.EstimatedValue, SyncStatus.Synced, detail);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<OrderDto>.Created(ToOrder(order), "Order scheduled.");
    }

    public async Task<ServiceResult<object>> LogVisitAsync(Guid customerId, string outcome, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == customerId, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<object>.Fail(denied.StatusCode, denied.Message);
        }

        var normalized = outcome.Trim();
        if (normalized is not ("NoNeed" or "NoResponse"))
        {
            return ServiceResult<object>.Fail(400, "Choose No need or No response.");
        }

        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<object>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var today = DateOnly.FromDateTime(DateTime.Today);
        var stop = await _db.RouteStops.FirstOrDefaultAsync(
            item => item.CustomerId == customerId && item.ServiceDate == today,
            cancellationToken);
        if (normalized == "NoResponse" && stop is not null && stop.Status is StopStatus.Pending or StopStatus.InProgress)
        {
            stop.Status = StopStatus.Missed;
        }

        var label = normalized == "NoNeed" ? "No need" : "No response";
        AddActivity(access.User!.Id, $"Visit — {customer!.BusinessName}", customer.Code, 0, SyncStatus.Synced, $"{label}. No sale recorded.");
        AddAudit(access.User.Id, "LogVisit", "Customer", customer.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { outcome = normalized }, "Visit logged without a sale.");
    }

    public async Task<ServiceResult<LedgerDto>> LedgerAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var customer = await CustomerQuery().FirstOrDefaultAsync(item => item.Id == customerId, cancellationToken);
        var denied = await GuardCustomerAsync(customer, cancellationToken);
        if (denied is not null)
        {
            return ServiceResult<LedgerDto>.Fail(denied.StatusCode, denied.Message);
        }

        var entries = await _db.LedgerEntries
            .Where(entry => entry.CustomerId == customerId)
            .OrderByDescending(entry => entry.OccurredAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        var references = entries.Select(entry => entry.Reference).Where(value => !string.IsNullOrWhiteSpace(value)).Distinct().ToList();
        var sales = await _db.Sales.AsNoTracking()
            .Where(sale => sale.CustomerId == customerId && references.Contains(sale.ReceiptNumber))
            .Select(sale => new { sale.ReceiptNumber, sale.RiderId, sale.PaymentChannel })
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections.AsNoTracking()
            .Where(item => item.CustomerId == customerId && references.Contains(item.ReferenceNumber))
            .Select(item => new { item.ReferenceNumber, item.RiderId, item.Channel })
            .ToListAsync(cancellationToken);
        var riderIds = sales.Select(sale => sale.RiderId).Concat(collections.Select(item => item.RiderId)).Distinct().ToList();
        var riders = riderIds.Count == 0
            ? new Dictionary<string, string>()
            : await _db.Users.AsNoTracking()
                .Where(user => riderIds.Contains(user.Id))
                .ToDictionaryAsync(user => user.Id, user => user.FullName, cancellationToken);
        var (start, end) = TodayRange();
        var todayCollected = await _db.LedgerEntries
            .Where(entry => entry.CustomerId == customerId && entry.Kind == LedgerKind.Payment && entry.OccurredAt >= start && entry.OccurredAt < end)
            .SumAsync(entry => (decimal?)-entry.Amount, cancellationToken) ?? 0;
        var openOrders = await _db.CustomerOrders.CountAsync(
            order => order.CustomerId == customerId && order.Status == CustomerOrderStatus.Scheduled,
            cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.Today);
        var stopSequence = await _db.RouteStops
            .Where(stop => stop.CustomerId == customerId && stop.ServiceDate == today)
            .Select(stop => (int?)stop.Sequence)
            .FirstOrDefaultAsync(cancellationToken);
        var completed = await _db.Sales
            .AsNoTracking()
            .Include(sale => sale.Lines).ThenInclude(line => line.Product)
            .Where(sale => sale.CustomerId == customerId && sale.Status == SaleStatus.Completed)
            .OrderByDescending(sale => sale.SignedAt ?? sale.CreatedAt)
            .Take(8)
            .ToListAsync(cancellationToken);
        var holding = customer!.BottlesHeld;
        var movements = new List<BottleMovementDto>();
        foreach (var sale in completed)
        {
            var given = sale.Lines.Where(line => line.Product.IsReturnable).Sum(line => line.Quantity);
            var returned = Math.Max(0, sale.EmptyBottlesReturned);
            var note = sale.SignatureImage is { Length: > 0 } || !string.IsNullOrWhiteSpace(sale.SignerName)
                ? "Handoff verified"
                : "Regular delivery";
            movements.Add(new BottleMovementDto(sale.SignedAt ?? sale.CreatedAt, given, returned, holding, note));
            holding += returned;
        }

        var rows = entries.Select(entry =>
        {
            string? detail = null;
            var sale = sales.FirstOrDefault(item => item.ReceiptNumber == entry.Reference);
            var collection = collections.FirstOrDefault(item => item.ReferenceNumber == entry.Reference);
            if (entry.Kind == LedgerKind.Payment)
            {
                detail = collection is not null
                    ? ChannelLabel(collection.Channel)
                    : sale?.PaymentChannel is { } channel ? ChannelLabel(channel) : MethodFrom(entry.Description);
            }
            else
            {
                var riderId = sale?.RiderId ?? collection?.RiderId;
                if (riderId is not null && riders.TryGetValue(riderId, out var riderName)) detail = riderName;
            }

            return new LedgerRowDto(entry.Id, entry.Description, entry.OccurredAt, entry.Amount, entry.BalanceAfter, entry.Kind.ToString(), entry.Reference, detail);
        }).ToList();
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
            openOrders,
            todayCollected,
            stopSequence,
            movements);
        return ServiceResult<LedgerDto>.Ok(dto, "Ledger loaded.");
    }

    public async Task<ServiceResult<ShiftDto>> CurrentShiftAsync(CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var shift = await OpenShiftAsync(access.User!.Id, cancellationToken);
        return ServiceResult<ShiftDto>.Ok(await ToShiftAsync(access.User, shift, cancellationToken), "Shift loaded.");
    }

    public async Task<ServiceResult<ShiftDto>> StartShiftAsync(StartShiftRequest request, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        if (await OpenShiftAsync(access.User!.Id, cancellationToken) is not null)
        {
            return ServiceResult<ShiftDto>.Fail(409, "A shift is already open.");
        }

        var photo = MeterPhoto(request.OdometerPhoto, required: false);
        if (photo.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(400, photo.Error);
        }

        var inspection = MeterPhoto(request.InspectionPhoto, required: false);
        if (inspection.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(400, inspection.Error);
        }

        var lastMeter = access.User.Vehicle!.CurrentOdometer;
        var reading = request.OpeningOdometer;
        if (reading is null or <= 0)
        {
            return ServiceResult<ShiftDto>.Fail(400, "Type the kilometres, or take a photo of the odometer.");
        }

        if (lastMeter > 0 && (reading < lastMeter - 5 || reading > lastMeter + 2000))
        {
            return ServiceResult<ShiftDto>.Fail(400, "The reading does not match the last recorded meter.");
        }

        var stocks = await _db.VehicleStocks.Include(stock => stock.Product)
            .Where(stock => stock.VehicleId == access.User.VehicleId && stock.Product.ShowOnShift)
            .ToListAsync(cancellationToken);
        var counts = request.Stock ?? [];
        if (counts.Any(count => count.CountedQuantity < 0))
        {
            return ServiceResult<ShiftDto>.Fail(400, "Counted stock cannot be negative.");
        }

        var shift = new Shift
        {
            RiderId = access.User.Id,
            RouteId = access.User.RouteId!.Value,
            VehicleId = access.User.VehicleId!.Value,
            ServiceDate = DateOnly.FromDateTime(DateTime.Today),
            OpeningOdometer = reading.Value,
            OpeningOdometerPhoto = photo.Bytes,
            OpeningInspectionPhoto = inspection.Bytes,
            Lines = stocks.Select(stock => new ShiftStock
            {
                ProductId = stock.ProductId,
                ExpectedQuantity = stock.DepotExpected,
                CountedQuantity = counts.FirstOrDefault(count => count.ProductId == stock.ProductId)?.CountedQuantity ?? stock.Quantity
            }).ToList()
        };
        foreach (var line in shift.Lines)
        {
            var stock = stocks.First(item => item.ProductId == line.ProductId);
            stock.Quantity = line.CountedQuantity;
        }

        access.User.Vehicle!.CurrentOdometer = shift.OpeningOdometer;
        _db.Shifts.Add(shift);
        AddActivity(access.User.Id, "Shift — Day started", shift.ServiceDate.ToString("yyyy-MM-dd"), 0, SyncStatus.Synced, $"Opening meter {shift.OpeningOdometer} km.");
        AddAudit(access.User.Id, "StartShift", "Shift", shift.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<ShiftDto>.Created(await ToShiftAsync(access.User, shift, cancellationToken), "Day started.");
    }

    public async Task<ServiceResult<ShiftDto>> EndShiftAsync(EndShiftRequest request, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var shift = await _db.Shifts.Include(item => item.Lines).FirstOrDefaultAsync(item => item.RiderId == access.User!.Id && item.Status == "Open", cancellationToken);
        if (shift is null)
        {
            return ServiceResult<ShiftDto>.Fail(404, "There is no open shift to close.");
        }

        var photo = MeterPhoto(request.OdometerPhoto, required: false);
        if (photo.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(400, photo.Error);
        }

        var inspection = MeterPhoto(request.InspectionPhoto, required: false);
        if (inspection.Error is not null)
        {
            return ServiceResult<ShiftDto>.Fail(400, inspection.Error);
        }

        var reading = request.ClosingOdometer;
        if (reading is null or <= 0)
        {
            return ServiceResult<ShiftDto>.Fail(400, "Type the kilometres, or take a photo of the odometer.");
        }

        if (reading < shift.OpeningOdometer || reading > shift.OpeningOdometer + 2000)
        {
            return ServiceResult<ShiftDto>.Fail(400, "The closing reading does not follow the opening meter.");
        }

        if ((request.Stock ?? []).Any(count => count.CountedQuantity < 0))
        {
            return ServiceResult<ShiftDto>.Fail(400, "Counted stock cannot be negative.");
        }

        shift.Status = "Closed";
        shift.EndedAt = DateTime.UtcNow;
        shift.ClosingOdometer = reading;
        shift.ClosingOdometerPhoto = photo.Bytes;
        shift.ClosingInspectionPhoto = inspection.Bytes;
        foreach (var count in request.Stock ?? [])
        {
            var line = shift.Lines.FirstOrDefault(item => item.ProductId == count.ProductId);
            if (line is not null)
            {
                line.ClosingQuantity = count.CountedQuantity;
            }
        }
        access.User!.Vehicle!.CurrentOdometer = reading.Value;
        AddActivity(access.User.Id, "Shift — Day closed", shift.ServiceDate.ToString("yyyy-MM-dd"), 0, SyncStatus.Synced, $"Closing meter {reading.Value} km.");
        AddAudit(access.User.Id, "EndShift", "Shift", shift.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<ShiftDto>.Ok(await ToShiftAsync(access.User, null, cancellationToken), "Day closed.");
    }

    public async Task<ServiceResult<HistoryDto>> HistoryAsync(string? search, DateOnly? date, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<HistoryDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var rider = access.User!;
        var day = date ?? DateOnly.FromDateTime(DateTime.Today);
        var (start, end) = DayRange(day);
        var rows = new List<HistoryItemDto>();

        var sales = await _db.Sales.AsNoTracking().Include(sale => sale.Customer)
            .Where(sale => sale.RiderId == rider.Id && sale.Status == SaleStatus.Completed)
            .Where(sale => (sale.SignedAt ?? sale.CreatedAt) >= start && (sale.SignedAt ?? sale.CreatedAt) < end)
            .ToListAsync(cancellationToken);
        foreach (var sale in sales)
        {
            var when = sale.SignedAt ?? sale.CreatedAt;
            var channel = sale.PaymentChannel?.ToString() ?? "Unpaid";
            rows.Add(new HistoryItemDto(sale.Id, $"Sale — {sale.Customer.BusinessName}", sale.ReceiptNumber, when, sale.AmountReceived, sale.SyncStatus.ToString(), $"{channel} payment. Sale {_money(sale.SaleAmount)}.", sale.Customer.Code));
        }

        var collections = await _db.Collections.AsNoTracking().Include(item => item.Customer)
            .Where(item => item.RiderId == rider.Id && item.CreatedAt >= start && item.CreatedAt < end)
            .ToListAsync(cancellationToken);
        foreach (var collection in collections)
        {
            var note = string.IsNullOrWhiteSpace(collection.Notes) ? $"{collection.Channel} collection." : collection.Notes!;
            rows.Add(new HistoryItemDto(collection.Id, $"Collection — {collection.Customer.BusinessName}", collection.ReferenceNumber, collection.CreatedAt, collection.Amount, collection.SyncStatus.ToString(), note, collection.Customer.Code));
        }

        var orders = await _db.CustomerOrders.AsNoTracking().Include(order => order.Customer)
            .Where(order => order.RiderId == rider.Id && (order.DeliveryDate == day || (order.CreatedAt >= start && order.CreatedAt < end)))
            .ToListAsync(cancellationToken);
        foreach (var order in orders)
        {
            var note = string.IsNullOrWhiteSpace(order.Notes) ? $"{order.Window} window · {order.DeliveryDate:yyyy-MM-dd}." : order.Notes!;
            rows.Add(new HistoryItemDto(order.Id, $"Order — {order.Customer.BusinessName}", order.ReferenceNumber, order.CreatedAt, order.EstimatedValue, order.SyncStatus.ToString(), note, order.Customer.Code));
        }

        var shifts = await _db.Shifts.AsNoTracking()
            .Where(shift => shift.RiderId == rider.Id && ((shift.StartedAt >= start && shift.StartedAt < end) || (shift.EndedAt >= start && shift.EndedAt < end)))
            .ToListAsync(cancellationToken);
        foreach (var shift in shifts)
        {
            if (shift.StartedAt >= start && shift.StartedAt < end)
            {
                rows.Add(new HistoryItemDto(shift.Id, "Shift — Day started", shift.ServiceDate.ToString("yyyy-MM-dd"), shift.StartedAt, null, SyncStatus.Synced.ToString(), $"Opening meter {shift.OpeningOdometer} km.", null));
            }

            if (shift.EndedAt is DateTime ended && ended >= start && ended < end)
            {
                rows.Add(new HistoryItemDto(_pairedId(shift.Id), "Shift — Day closed", shift.ServiceDate.ToString("yyyy-MM-dd"), ended, null, SyncStatus.Synced.ToString(), $"Closing meter {shift.ClosingOdometer ?? 0} km.", null));
            }
        }

        var visits = await _db.ActivityLogs.AsNoTracking()
            .Where(item => item.UserId == rider.Id && item.OccurredAt >= start && item.OccurredAt < end)
            .ToListAsync(cancellationToken);
        foreach (var visit in visits)
        {
            if (visit.Title.StartsWith("Sale") || visit.Title.StartsWith("Collection") || visit.Title.StartsWith("Order") || visit.Title.StartsWith("Shift"))
            {
                continue;
            }

            var code = visit.Reference.StartsWith("CUS-", StringComparison.OrdinalIgnoreCase) ? visit.Reference : null;
            rows.Add(new HistoryItemDto(visit.Id, visit.Title, visit.Reference, visit.OccurredAt, visit.Amount, visit.SyncStatus.ToString(), visit.Detail, code));
        }

        var ownedIds = sales.Select(sale => sale.Id.ToString())
            .Concat(collections.Select(item => item.Id.ToString()))
            .Concat(orders.Select(order => order.Id.ToString()))
            .Concat(shifts.Select(shift => shift.Id.ToString()))
            .ToList();
        var auditQuery = _db.AuditLogs.AsNoTracking()
            .Where(item => item.OccurredAt >= start && item.OccurredAt < end);
        var audits = ownedIds.Count == 0
            ? await auditQuery.Where(item => item.UserId == rider.Id).ToListAsync(cancellationToken)
            : await auditQuery.Where(item => item.UserId == rider.Id || ownedIds.Contains(item.EntityId)).ToListAsync(cancellationToken);
        foreach (var audit in audits)
        {
            rows.Add(new HistoryItemDto(audit.Id, audit.Action, audit.EntityId, audit.OccurredAt, null, SyncStatus.Synced.ToString(), audit.EntityName, null));
        }

        var synced = rows.Count(item => item.SyncStatus == nameof(SyncStatus.Synced));
        var pending = rows.Count(item => item.SyncStatus == nameof(SyncStatus.Pending));
        var failed = rows.Count(item => item.SyncStatus == nameof(SyncStatus.Failed));
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            rows = rows.Where(item =>
                item.Title.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                item.Reference.Contains(term, StringComparison.OrdinalIgnoreCase) ||
                (item.CustomerCode ?? "").Contains(term, StringComparison.OrdinalIgnoreCase) ||
                item.Detail.Contains(term, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        var dto = new HistoryDto(
            synced,
            pending,
            failed,
            rows.OrderByDescending(item => item.OccurredAt).Take(100).ToList(),
            rider.Id,
            rider.FullName,
            rider.RiderCode ?? "");
        return ServiceResult<HistoryDto>.Ok(dto, "History loaded.");
    }

    public async Task<ServiceResult<SettingsDto>> SettingsAsync(CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<SettingsDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        return ServiceResult<SettingsDto>.Ok(await SettingsDtoAsync(access.User!.Id, cancellationToken), "Settings loaded.");
    }

    public async Task<ServiceResult<SettingsDto>> UpdateSettingsAsync(UpdateSettingsRequest request, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<SettingsDto>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var allowedPaper = new[] { "48mm", "58mm", "80mm", "58mm Standard" };
        if (!allowedPaper.Contains(request.PaperSize))
        {
            return ServiceResult<SettingsDto>.Fail(400, "Choose a supported paper size.");
        }

        if (request.PrinterId is not null && !await _db.Printers.AnyAsync(printer => printer.Id == request.PrinterId, cancellationToken))
        {
            return ServiceResult<SettingsDto>.Fail(400, "Printer not found.");
        }

        var settings = await _db.RiderSettings.FirstOrDefaultAsync(item => item.UserId == access.User!.Id, cancellationToken);
        if (settings is null)
        {
            settings = new RiderSettings { UserId = access.User!.Id };
            _db.RiderSettings.Add(settings);
        }

        settings.AutoSync = request.AutoSync;
        settings.ShowOrdersTab = request.ShowOrdersTab;
        settings.Language = string.IsNullOrWhiteSpace(request.Language) ? "English (US)" : request.Language.Trim();
        settings.AutoPrint = request.AutoPrint;
        settings.DeleteOnLogout = request.DeleteOnLogout;
        settings.PaperSize = request.PaperSize;
        settings.PrinterId = request.PrinterId;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<SettingsDto>.Ok(await SettingsDtoAsync(access.User!.Id, cancellationToken), "Settings saved.");
    }

    public async Task<ServiceResult<IReadOnlyList<PrinterDto>>> PrintersAsync(CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<IReadOnlyList<PrinterDto>>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var selected = await _db.RiderSettings.Where(item => item.UserId == access.User!.Id).Select(item => item.PrinterId).FirstOrDefaultAsync(cancellationToken);
        var printers = await _db.Printers.OrderBy(printer => printer.Name).ToListAsync(cancellationToken);
        var items = printers.Select(printer => new PrinterDto(printer.Id, printer.Name, printer.Meta, printer.IsOnline, printer.Id == selected)).ToList();
        return ServiceResult<IReadOnlyList<PrinterDto>>.Ok(items, "Printers loaded.");
    }

    public async Task<ServiceResult<object>> QueuePrintAsync(Guid saleId, CancellationToken cancellationToken)
    {
        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return ServiceResult<object>.Fail(access.Error.StatusCode, access.Error.Message);
        }

        var sale = await _db.Sales.FirstOrDefaultAsync(item => item.Id == saleId && item.RiderId == access.User!.Id && item.Status == SaleStatus.Completed, cancellationToken);
        if (sale is null)
        {
            return ServiceResult<object>.Fail(404, "Receipt not found.");
        }

        var settings = await _db.RiderSettings.FirstOrDefaultAsync(item => item.UserId == access.User!.Id, cancellationToken);
        string? printerName = null;
        if (settings?.PrinterId is not null)
        {
            printerName = await _db.Printers.Where(printer => printer.Id == settings.PrinterId).Select(printer => printer.Name).FirstOrDefaultAsync(cancellationToken);
        }

        _db.PrintJobs.Add(new PrintJob
        {
            SaleId = sale.Id,
            UserId = access.User!.Id,
            PrinterName = printerName,
            Status = "Queued"
        });
        await _db.SaveChangesAsync(cancellationToken);
        var message = printerName is null
            ? "Print job queued. No printer is selected in settings."
            : $"Print job queued for {printerName}.";
        return ServiceResult<object>.Ok(new { printerName }, message);
    }

    private async Task<ReceiptDto> ReceiptForSaleAsync(Guid id, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales.Include(item => item.Lines).ThenInclude(line => line.Product).Include(item => item.Customer)
            .FirstAsync(item => item.Id == id, cancellationToken);
        var rider = await _db.Users.FirstAsync(user => user.Id == sale.RiderId, cancellationToken);
        var depot = await DepotForAsync(rider.DepotId, cancellationToken);
        return new ReceiptDto(
            sale.Id,
            "Sale",
            sale.ReceiptNumber,
            sale.SignedAt ?? sale.CreatedAt,
            rider.FullName,
            rider.RiderCode ?? "",
            sale.Customer.BusinessName,
            sale.Customer.Code,
            sale.Lines.Select(line => new SaleLineDto(line.ProductId, line.Product.Name, line.Quantity, line.UnitPrice, line.Quantity * line.UnitPrice)).ToList(),
            sale.SaleAmount,
            sale.PreviousOutstanding,
            sale.AmountReceived,
            sale.Customer.Outstanding,
            ChannelLabel(sale.PaymentChannel ?? PaymentChannel.Cash),
            sale.SignerName,
            sale.SignerRole,
            sale.SyncStatus.ToString(),
            JoinAddress(sale.Customer.Street, sale.Customer.Area, sale.Customer.City),
            sale.Customer.PrimaryMobile,
            depot?.Name ?? "",
            JoinAddress(depot?.Address, depot?.Gate),
            sale.EmptyBottlesReturned,
            sale.Customer.BottlesHeld,
            sale.SignatureNote);
    }

    private async Task<ReceiptDto> ReceiptForCollectionAsync(Guid id, CancellationToken cancellationToken)
    {
        var collection = await _db.Collections.Include(item => item.Customer).FirstAsync(item => item.Id == id, cancellationToken);
        var rider = await _db.Users.FirstAsync(user => user.Id == collection.RiderId, cancellationToken);
        var depot = await DepotForAsync(rider.DepotId, cancellationToken);
        return new ReceiptDto(
            collection.Id,
            "Collection",
            collection.ReferenceNumber,
            collection.CreatedAt,
            rider.FullName,
            rider.RiderCode ?? "",
            collection.Customer.BusinessName,
            collection.Customer.Code,
            [],
            0,
            collection.OutstandingBefore,
            collection.Amount,
            collection.OutstandingAfter,
            ChannelLabel(collection.Channel),
            collection.SignerName,
            collection.SignerRole,
            collection.SyncStatus.ToString(),
            JoinAddress(collection.Customer.Street, collection.Customer.Area, collection.Customer.City),
            collection.Customer.PrimaryMobile,
            depot?.Name ?? "",
            JoinAddress(depot?.Address, depot?.Gate),
            0,
            collection.Customer.BottlesHeld,
            collection.SignatureNote,
            collection.WithholdingTax);
    }

    public async Task<(string Html, bool Found)> VerifyReceiptPageAsync(string receiptNumber, CancellationToken cancellationToken)
    {
        var number = receiptNumber.Trim();
        var sale = await _db.Sales.FirstOrDefaultAsync(item => item.ReceiptNumber == number && item.Status == SaleStatus.Completed, cancellationToken);
        if (sale is not null)
        {
            return (ReceiptPage(await ReceiptForSaleAsync(sale.Id, cancellationToken)), true);
        }

        var collection = await _db.Collections.FirstOrDefaultAsync(item => item.ReferenceNumber == number, cancellationToken);
        if (collection is not null)
        {
            return (ReceiptPage(await ReceiptForCollectionAsync(collection.Id, cancellationToken)), true);
        }

        var missing = $"""
            <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Receipt not found</title></head>
            <body style="font-family:sans-serif;padding:24px;color:#0B1C30"><h1>Receipt not found</h1><p>No completed receipt matches {System.Net.WebUtility.HtmlEncode(number)}.</p></body></html>
            """;
        return (missing, false);
    }

    private async Task<Depot?> DepotForAsync(Guid? depotId, CancellationToken cancellationToken)
    {
        if (depotId is null) return null;
        return await _db.Depots.FirstOrDefaultAsync(depot => depot.Id == depotId, cancellationToken);
    }

    private static string JoinAddress(params string?[] parts) =>
        string.Join(", ", parts.Where(part => !string.IsNullOrWhiteSpace(part)).Select(part => part!.Trim()));

    private static string ReceiptPage(ReceiptDto receipt)
    {
        string h(string? value) => System.Net.WebUtility.HtmlEncode(value ?? "");
        string money(decimal value) => $"PKR {value:0}";
        var rows = string.Join("", receipt.Lines.Select(line =>
            $"<tr><td>{h(line.Name)}</td><td>{line.Quantity}</td><td>{line.UnitPrice:0}</td><td>{money(line.LineTotal)}</td></tr>"));
        if (rows.Length == 0)
        {
            rows = $"<tr><td>Collection</td><td>1</td><td>{receipt.AmountReceived:0}</td><td>{money(receipt.AmountReceived)}</td></tr>";
        }

        var previousHold = receipt.EmptyBottlesHeld + receipt.EmptyBottlesReturned;
        var signed = string.IsNullOrWhiteSpace(receipt.SignatureNote) ? "Accepted and signed" : h(receipt.SignatureNote);
        var paid = receipt.BalanceAfter == 0 ? "Fully paid" : "Balance remains";
        var when = receipt.IssuedAt.ToLocalTime().ToString("dd MMM yyyy HH:mm");
        var depot = h(receipt.DepotName.Length == 0 ? "AquaRider" : receipt.DepotName);
        return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>"
            + h(receipt.ReceiptNumber)
            + "</title></head><body style=\"font-family:sans-serif;background:#F8F9FF;color:#0B1C30;margin:0;padding:16px\"><main style=\"max-width:420px;margin:auto;background:#fff;border-radius:16px;padding:16px\">"
            + "<p style=\"color:#565E74\">RouteLedger receipt check</p><h1>" + depot + "</h1><p style=\"color:#565E74\">" + h(receipt.DepotAddress) + "</p>"
            + "<p><strong>" + h(receipt.ReceiptNumber) + "</strong><br>" + when + "</p>"
            + "<p>Customer<br><strong>" + h(receipt.CustomerName) + "</strong><br>" + h(receipt.CustomerCode) + " · " + h(receipt.CustomerPhone) + "<br>" + h(receipt.CustomerAddress) + "</p>"
            + "<p>Rider<br>" + h(receipt.RiderName) + " (" + h(receipt.RiderCode) + ")</p>"
            + "<table style=\"width:100%;border-collapse:collapse\"><tr><td>Product</td><td>Qty</td><td>Rate</td><td>Amount</td></tr>" + rows + "</table>"
            + "<p>Sale " + money(receipt.SaleAmount) + "<br>Previous balance " + money(receipt.PreviousOutstanding) + "<br>Received (" + h(receipt.PaymentMethod) + ") " + money(receipt.AmountReceived) + "</p>"
            + "<p style=\"color:#0B7A4B;font-weight:700\">Remaining " + money(receipt.BalanceAfter) + " · " + paid + "</p>"
            + "<p>Empty bottles returned " + receipt.EmptyBottlesReturned + ". Previous hold " + previousHold + ". Store now holds " + receipt.EmptyBottlesHeld + ".</p>"
            + "<p>Receiver " + h(receipt.SignerName) + " (" + h(receipt.SignerRole) + ") · " + signed + "</p></main></body></html>";
    }

    private async Task<ShiftDto> ToShiftAsync(ApplicationUser user, Shift? shift, CancellationToken cancellationToken)
    {
        var stocks = await _db.VehicleStocks.Include(stock => stock.Product)
            .Where(stock => stock.VehicleId == user.VehicleId && stock.Product.ShowOnShift)
            .OrderBy(stock => stock.Product.Name)
            .ToListAsync(cancellationToken);
        var lines = stocks.Select(stock =>
        {
            var counted = shift?.Lines.FirstOrDefault(line => line.ProductId == stock.ProductId)?.CountedQuantity ?? stock.Quantity;
            return new ShiftLineDto(stock.ProductId, stock.Product.Name, stock.DepotExpected, counted, stock.Product.IsReturnable);
        }).ToList();
        var verified = shift?.OpeningOdometerPhoto is { Length: > 0 };
        if (!verified)
        {
            verified = await _db.Shifts.AsNoTracking().AnyAsync(
                item => item.RiderId == user.Id && (item.OpeningOdometerPhoto != null || item.ClosingOdometerPhoto != null),
                cancellationToken);
        }

        return new ShiftDto(
            shift?.Id,
            shift?.Status ?? "Closed",
            DateOnly.FromDateTime(DateTime.Today).ToString("yyyy-MM-dd"),
            shift?.OpeningOdometer ?? user.Vehicle?.CurrentOdometer ?? 0,
            user.Vehicle?.FleetCode ?? "",
            user.Route is null ? "" : $"{user.Route.Name} · Sector {user.Route.Sector}",
            user.Depot is null ? "" : $"{user.Depot.Address} · {user.Depot.Name}",
            verified,
            lines);
    }

    private async Task<SettingsDto> SettingsDtoAsync(string userId, CancellationToken cancellationToken)
    {
        var settings = await _db.RiderSettings.FirstOrDefaultAsync(item => item.UserId == userId, cancellationToken) ?? new RiderSettings { UserId = userId };
        var printer = settings.PrinterId is null
            ? null
            : await _db.Printers.Where(item => item.Id == settings.PrinterId).Select(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        return new SettingsDto(settings.AutoSync, settings.ShowOrdersTab, settings.Language, settings.AutoPrint, settings.DeleteOnLogout, settings.PaperSize, settings.PrinterId, printer);
    }

    private async Task<IReadOnlyList<ProductDto>> ProductsForVehicleAsync(Guid? vehicleId, bool saleOnly, CancellationToken cancellationToken)
    {
        var stocks = await _db.VehicleStocks.Include(stock => stock.Product)
            .Where(stock => stock.VehicleId == vehicleId)
            .ToListAsync(cancellationToken);
        return stocks
            .Where(stock => !saleOnly || stock.Product.ShowOnSale)
            .OrderBy(stock => stock.Product.Name)
            .Select(stock => new ProductDto(stock.ProductId, stock.Product.Name, stock.Product.UnitPrice, stock.Product.UnitLabel, stock.Quantity, stock.DepotExpected, stock.Product.IsReturnable))
            .ToList();
    }

    private async Task<CustomerDetailDto> ToCustomerAsync(Customer customer, CancellationToken cancellationToken)
    {
        var scheduled = await _db.CustomerOrders
            .Include(order => order.Lines).ThenInclude(line => line.Product)
            .Where(order => order.CustomerId == customer.Id && order.Status == CustomerOrderStatus.Scheduled)
            .OrderBy(order => order.DeliveryDate)
            .FirstOrDefaultAsync(cancellationToken);
        var openOrders = await _db.CustomerOrders.CountAsync(
            order => order.CustomerId == customer.Id && order.Status == CustomerOrderStatus.Scheduled,
            cancellationToken);
        var nextLine = scheduled?.Lines.OrderByDescending(line => line.Quantity).FirstOrDefault();
        string? lastPayment = null;
        if (customer.LastPaymentAt is not null && customer.LastPaymentAmount is not null)
        {
            lastPayment = $"{customer.LastPaymentAt.Value.ToLocalTime():dd MMM} (PKR {customer.LastPaymentAmount.Value:0})";
        }

        return new CustomerDetailDto(
            customer.Id,
            customer.Code,
            customer.BusinessName,
            customer.Category,
            customer.Status,
            customer.PrimaryMobile,
            customer.AdditionalContact,
            customer.Street,
            customer.Area,
            customer.City,
            customer.Latitude,
            customer.Longitude,
            customer.Route.Name,
            customer.RouteId,
            customer.Outstanding,
            customer.LastDropAt,
            openOrders,
            customer.BottlesIssued,
            customer.BottlesReturned,
            customer.BottlesHeld,
            customer.BottleOwnership.ToString(),
            customer.Cnic,
            customer.ContactName,
            customer.ContactRole,
            customer.CreditDays,
            lastPayment,
            nextLine?.Product.Name,
            nextLine?.Quantity ?? 0,
            scheduled?.DeliveryDate.ToString("yyyy-MM-dd"));
    }

    private static StopDto ToStop(RouteStop stop, Guid? receiptId, string? invoice)
    {
        var action = stop.Status switch
        {
            StopStatus.Completed => "View Invoice",
            StopStatus.InProgress => "Complete Audit & Bill",
            StopStatus.Missed => "Retry Stop",
            _ => "Start Delivery"
        };
        var time = stop.ScheduledTime?.ToString("hh:mm tt");
        return new StopDto(
            stop.Id,
            stop.CustomerId,
            stop.Sequence,
            stop.Customer.BusinessName,
            stop.Customer.Code,
            $"{stop.Customer.Street}, {stop.Customer.Area}",
            stop.Customer.PrimaryMobile,
            stop.Status.ToString(),
            time,
            stop.Customer.Outstanding,
            stop.Customer.BottlesHeld,
            stop.DistanceMeters,
            action,
            receiptId,
            invoice,
            stop.Customer.Latitude,
            stop.Customer.Longitude);
    }

    private static SaleDraftDto ToDraft(Sale sale, Customer customer, int returned)
    {
        return new SaleDraftDto(
            sale.Id,
            customer.Id,
            sale.SaleAmount,
            customer.Outstanding,
            sale.SaleAmount + customer.Outstanding,
            returned,
            Math.Max(0, customer.BottlesHeld - returned),
            sale.Lines.Select(line => new SaleLineDto(line.ProductId, line.Product.Name, line.Quantity, line.UnitPrice, line.Quantity * line.UnitPrice)).ToList(),
            sale.ReceiptNumber);
    }

    private static OrderDto ToOrder(CustomerOrder order) =>
        new(order.Id, order.ReferenceNumber, order.CustomerId, order.DeliveryDate, order.Window.ToString(), order.EstimatedValue, order.Status.ToString());

    private IQueryable<Customer> CustomerQuery() => _db.Customers.Include(customer => customer.Route).Where(customer => !customer.IsDeleted);

    private async Task<ServiceResult<object>?> GuardCustomerAsync(Customer? customer, CancellationToken cancellationToken)
    {
        if (customer is null)
        {
            return ServiceResult<object>.Fail(404, "Customer not found.");
        }

        var access = await RiderAsync(cancellationToken);
        if (access.Error is not null)
        {
            return access.Error;
        }

        if (_current.IsAdmin || customer.RouteId == access.User!.RouteId)
        {
            return null;
        }

        var today = DateOnly.FromDateTime(DateTime.Today);
        var onDay = await _db.RouteStops.AnyAsync(
            stop => stop.CustomerId == customer.Id && stop.RouteId == access.User.RouteId && stop.ServiceDate == today,
            cancellationToken);
        var assigned = await _db.CustomerOrders.AnyAsync(
            order => order.CustomerId == customer.Id
                && order.RiderId == access.User.Id
                && (order.Status == CustomerOrderStatus.Scheduled || order.Status == CustomerOrderStatus.InProgress),
            cancellationToken);
        if (onDay || assigned)
        {
            return null;
        }

        return ServiceResult<object>.Fail(403, "This customer is on another route.");
    }

    private async Task<(ApplicationUser? User, ServiceResult<object>? Error)> RiderAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return (null, ServiceResult<object>.Fail(401, "Sign in required."));
        }

        var user = await _db.Users
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .FirstOrDefaultAsync(item => item.Id == _current.UserId, cancellationToken);
        if (user is null || !user.IsActive)
        {
            return (null, ServiceResult<object>.Fail(401, "Sign in required."));
        }

        if (user.RouteId is null || user.VehicleId is null)
        {
            return (null, ServiceResult<object>.Fail(403, "This account is not assigned to a route."));
        }

        return (user, null);
    }

    private async Task<AuthUserDto> ProfileAsync(ApplicationUser user)
    {
        var roles = _current.IsAdmin ? AppRoles.Admin : AppRoles.Rider;
        return await Task.FromResult(new AuthUserDto(
            user.Id,
            user.UserName ?? "",
            user.FullName,
            user.RiderCode,
            roles,
            user.Route?.Name,
            user.Vehicle?.Name,
            user.Vehicle?.Plate,
            user.Vehicle?.FleetCode,
            user.Depot?.Gate,
            user.Depot?.Name,
            [roles]));
    }

    private async Task DeliverOpenOrdersAsync(Guid customerId, string riderId, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.Today);
        var openOrders = await _db.CustomerOrders
            .Where(order => order.CustomerId == customerId
                && order.RiderId == riderId
                && order.DeliveryDate == today
                && (order.Status == CustomerOrderStatus.Scheduled || order.Status == CustomerOrderStatus.InProgress))
            .ToListAsync(cancellationToken);
        foreach (var order in openOrders)
        {
            order.Status = CustomerOrderStatus.Delivered;
        }

        await RecurringScheduleService.CompleteLinkedAsync(_db, openOrders.Select(order => order.Id), cancellationToken);
    }

    private async Task PlaceAssignedOrdersAsync(ApplicationUser user, DateOnly day, CancellationToken cancellationToken)
    {
        if (user.RouteId is null)
        {
            return;
        }

        var (start, end) = DayRange(day);
        var orders = await _db.CustomerOrders
            .Where(order => order.RiderId == user.Id
                && order.DeliveryDate == day
                && order.ShowOnManifest
                && (order.Status == CustomerOrderStatus.Scheduled || order.Status == CustomerOrderStatus.InProgress))
            .ToListAsync(cancellationToken);
        var coveredUntil = await _db.Sales.AsNoTracking()
            .Where(sale => sale.RiderId == user.Id && sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end)
            .Select(sale => new { sale.CustomerId, At = sale.SignedAt ?? sale.CreatedAt })
            .ToListAsync(cancellationToken);
        var changed = false;
        var coveredOrders = new List<Guid>();
        foreach (var group in orders.GroupBy(order => order.CustomerId))
        {
            var covered = coveredUntil.Where(sale => sale.CustomerId == group.Key).Select(sale => sale.At).DefaultIfEmpty(DateTime.MinValue).Max();
            var stillOpen = false;
            foreach (var order in group)
            {
                if (order.CreatedAt <= covered)
                {
                    order.Status = CustomerOrderStatus.Delivered;
                    coveredOrders.Add(order.Id);
                    changed = true;
                    continue;
                }

                stillOpen = true;
            }

            if (stillOpen)
            {
                changed |= await AssignedRouteStop.EnsureAsync(_db, user.RouteId.Value, group.Key, day, cancellationToken);
            }
        }

        if (coveredOrders.Count > 0)
        {
            await RecurringScheduleService.CompleteLinkedAsync(_db, coveredOrders, cancellationToken);
        }

        if (changed)
        {
            await _db.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task<Shift?> OpenShiftAsync(string riderId, CancellationToken cancellationToken)
    {
        return await _db.Shifts.Include(shift => shift.Lines)
            .FirstOrDefaultAsync(shift => shift.RiderId == riderId && shift.Status == "Open", cancellationToken);
    }

    private async Task<string> NextCodeAsync(string name, string prefix, CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstAsync(item => item.Name == name, cancellationToken);
        var value = sequence.NextValue++;
        return $"{prefix}-{DateTime.Today:yyyyMMdd}-{value:0000}";
    }

    private void AddLedger(Guid customerId, LedgerKind kind, string description, decimal amount, decimal balance, string? reference)
    {
        _db.LedgerEntries.Add(new LedgerEntry
        {
            CustomerId = customerId,
            Kind = kind,
            Description = description,
            Amount = amount,
            BalanceAfter = balance,
            Reference = reference
        });
    }

    private readonly record struct PhotoRead(byte[]? Bytes, string? Error);

    private static PhotoRead MeterPhoto(string? encoded, bool required = true)
    {
        if (string.IsNullOrWhiteSpace(encoded))
        {
            return required
                ? new PhotoRead(null, "Take a photo of the odometer before confirming the shift.")
                : new PhotoRead(null, null);
        }

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(encoded);
        }
        catch (FormatException)
        {
            return new PhotoRead(null, "The photo could not be read. Take it again.");
        }

        if (bytes.Length < 32 || bytes.Length > 2_000_000)
        {
            return new PhotoRead(null, "Use a clear photo under 2 MB.");
        }

        var jpeg = bytes.Length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
        var png = bytes.Length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
        if (!jpeg && !png)
        {
            return new PhotoRead(null, "The photo must be a JPEG or PNG.");
        }

        return new PhotoRead(bytes, null);
    }

    private static PhotoRead SignatureBytes(string? encoded)
    {
        if (string.IsNullOrWhiteSpace(encoded))
        {
            return new PhotoRead(null, null);
        }

        byte[] bytes;
        try
        {
            bytes = Convert.FromBase64String(encoded);
        }
        catch (FormatException)
        {
            return new PhotoRead(null, "The signature could not be read. Sign again.");
        }

        if (bytes.Length < 32 || bytes.Length > 2_000_000)
        {
            return new PhotoRead(null, "The signature is too large to store.");
        }

        var png = bytes.Length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
        if (!png)
        {
            return new PhotoRead(null, "The signature must be a PNG.");
        }

        return new PhotoRead(bytes, null);
    }

    private void AddActivity(string userId, string title, string reference, decimal amount, SyncStatus status, string detail)
    {
        _db.ActivityLogs.Add(new ActivityLog
        {
            UserId = userId,
            Title = title,
            Reference = reference,
            Amount = amount,
            SyncStatus = status,
            Detail = detail
        });
    }

    private void AddAudit(string userId, string action, string entity, string id)
    {
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = action,
            EntityName = entity,
            EntityId = id
        });
    }

    private static List<string> ValidateCustomer(CustomerWriteRequest request)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(request.BusinessName)) errors.Add("Customer name is required.");
        if (string.IsNullOrWhiteSpace(request.PrimaryMobile)) errors.Add("Primary mobile is required.");
        if (string.IsNullOrWhiteSpace(request.Category)) errors.Add("Category is required.");
        if (string.IsNullOrWhiteSpace(request.Street)) errors.Add("Street is required.");
        if (string.IsNullOrWhiteSpace(request.Area)) errors.Add("Area is required.");
        if (string.IsNullOrWhiteSpace(request.City)) errors.Add("City is required.");
        if (request.OpeningDebt < 0) errors.Add("Opening debt cannot be negative.");
        if (request.OpeningEmpties < 0) errors.Add("Opening empties cannot be negative.");
        return errors;
    }

    private static string DescribeSale(Sale sale)
    {
        var line = sale.Lines.FirstOrDefault();
        return line is null ? "Sale" : $"New Sale ({line.Product.Name} x {line.Quantity})";
    }

    private static string? Clean(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string? MethodFrom(string description)
    {
        var text = description.Trim();
        if (text.Contains("Withholding", StringComparison.OrdinalIgnoreCase)) return "Withholding tax";
        foreach (var suffix in new[] { " collection", " payment" })
        {
            var index = text.IndexOf(suffix, StringComparison.OrdinalIgnoreCase);
            if (index > 0) return text[..index];
        }

        return null;
    }

    private static Guid _pairedId(Guid id)
    {
        var bytes = id.ToByteArray();
        bytes[0] ^= 0xA5;
        return new Guid(bytes);
    }

    private static string _money(decimal amount) => $"PKR {amount:0}";

    private static (DateTime Start, DateTime End) TodayRange() => DayRange(DateOnly.FromDateTime(DateTime.Today));

    private static (DateTime Start, DateTime End) DayRange(DateOnly day)
    {
        var local = DateTime.SpecifyKind(day.ToDateTime(TimeOnly.MinValue), DateTimeKind.Local);
        return (local.ToUniversalTime(), local.AddDays(1).ToUniversalTime());
    }

    private static bool TryChannel(string? value, out PaymentChannel channel)
    {
        var text = (value ?? "").Trim();
        if (text.Equals("Mobile Wallet", StringComparison.OrdinalIgnoreCase) || text.Equals("Wallet", StringComparison.OrdinalIgnoreCase))
        {
            text = "Wallet";
        }

        if (text.Equals("Bank Transfer", StringComparison.OrdinalIgnoreCase))
        {
            text = "BankTransfer";
        }

        return Enum.TryParse(text.Replace(" ", "", StringComparison.Ordinal), true, out channel);
    }

    private static bool TryWindow(string? value, out DeliveryWindow window)
    {
        var text = (value ?? "").Replace("Window", "", StringComparison.OrdinalIgnoreCase).Trim();
        return Enum.TryParse(text, true, out window);
    }

    private static string ChannelLabel(PaymentChannel channel) => channel switch
    {
        PaymentChannel.BankTransfer => "Bank Transfer",
        PaymentChannel.Wallet => "Wallet",
        PaymentChannel.Cheque => "Cheque",
        _ => "Cash"
    };
}
