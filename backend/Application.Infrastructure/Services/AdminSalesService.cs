using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminSalesService : IAdminSalesService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public AdminSalesService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<AdminSalesSummaryDto>> SummaryAsync(DateOnly? date, CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(day, day);
        var previousDay = day.AddDays(-1);
        var (prevStart, prevEnd) = ReportingWindow.UtcBounds(previousDay, previousDay);

        var sales = await CompletedInRange(rangeStart, rangeEnd).ToListAsync(cancellationToken);
        var previous = await CompletedInRange(prevStart, prevEnd)
            .SumAsync(item => (decimal?)item.SaleAmount, cancellationToken) ?? 0;

        var billed = sales.Sum(item => item.SaleAmount);
        var completed = sales.Count;
        var cashSales = sales.Where(IsCashSpot).ToList();
        var creditSales = sales.Where(IsCreditLedger).ToList();
        var cashInward = cashSales.Sum(item => item.AmountReceived);
        var creditFromSales = creditSales.Sum(CreditPortion);
        var average = completed == 0 ? 0 : Math.Round(billed / completed, 2, MidpointRounding.AwayFromZero);
        var pending = await _db.Sales.AsNoTracking()
            .CountAsync(item => item.SyncStatus == SyncStatus.Pending, cancellationToken);
        var failed = await _db.Sales.AsNoTracking()
            .CountAsync(item => item.SyncStatus == SyncStatus.Failed, cancellationToken);
        decimal? changePercent = previous == 0
            ? null
            : ReportingWindow.Percent(billed - previous, previous);

        var dto = new AdminSalesSummaryDto(
            day,
            billed,
            completed,
            previous,
            changePercent,
            cashInward,
            cashSales.Count,
            creditFromSales,
            creditSales.Count,
            completed,
            average,
            pending,
            failed);
        return ServiceResult<AdminSalesSummaryDto>.Ok(dto, "Sales summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminSaleRowDto>>> ListAsync(
        DateOnly? date,
        string? type,
        string? syncStatus,
        string? riderId,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(day, day);
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        if (!TryParseType(type, out var typeFilter, out var typeError))
        {
            return ServiceResult<IReadOnlyList<AdminSaleRowDto>>.Fail(400, typeError!);
        }

        if (!ReportingWindow.TrySyncFilter(syncStatus, out var syncFilter, out var syncError))
        {
            return ServiceResult<IReadOnlyList<AdminSaleRowDto>>.Fail(400, syncError!);
        }

        var query = _db.Sales.AsNoTracking()
            .Include(item => item.Customer)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .AsQueryable();

        if (typeFilter == "PendingSync")
        {
            query = query.Where(item =>
                item.SyncStatus == SyncStatus.Pending || item.SyncStatus == SyncStatus.Failed);
        }
        else
        {
            query = query.Where(item =>
                item.Status == SaleStatus.Completed
                && item.CreatedAt >= rangeStart
                && item.CreatedAt < rangeEnd);
            if (typeFilter == "Cash")
            {
                query = query.Where(item =>
                    item.PaymentChannel == PaymentChannel.Cash
                    && item.AmountReceived >= item.SaleAmount);
            }
            else if (typeFilter == "Credit")
            {
                query = query.Where(item => item.AmountReceived < item.SaleAmount);
            }
        }

        if (syncFilter is not null && typeFilter != "PendingSync")
        {
            query = query.Where(item => item.SyncStatus == syncFilter);
        }

        if (!string.IsNullOrWhiteSpace(riderId))
        {
            var rid = riderId.Trim();
            query = query.Where(item => item.RiderId == rid);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.ReceiptNumber.Contains(term)
                || item.Customer.BusinessName.Contains(term)
                || item.Customer.Code.Contains(term)
                || item.RiderId.Contains(term)
                || item.Id.ToString().Contains(term));
        }

        var total = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderByDescending(item => item.CreatedAt)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .ToListAsync(cancellationToken);

        var riderIds = rows.Select(item => item.RiderId).Distinct().ToList();
        var riders = await _db.Users.AsNoTracking()
            .Where(user => riderIds.Contains(user.Id))
            .Select(user => new { user.Id, user.FullName, user.RiderCode, user.VehicleId })
            .ToListAsync(cancellationToken);
        var vehicleIds = riders.Where(item => item.VehicleId != null).Select(item => item.VehicleId!.Value).Distinct().ToList();
        var vehicles = await _db.Vehicles.AsNoTracking()
            .Where(item => vehicleIds.Contains(item.Id))
            .ToDictionaryAsync(item => item.Id, cancellationToken);

        IReadOnlyList<AdminSaleRowDto> data = rows.Select(sale =>
        {
            var rider = riders.FirstOrDefault(item => item.Id == sale.RiderId);
            string? vehicleLabel = null;
            if (rider?.VehicleId is Guid vid && vehicles.TryGetValue(vid, out var vehicle))
            {
                vehicleLabel = $"{vehicle.Plate} · {vehicle.FleetCode}";
            }

            return ToRow(sale, rider?.FullName ?? sale.RiderId, vehicleLabel);
        }).ToList();

        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<AdminSaleRowDto>>.Ok(
            data,
            data.Count == 0 ? "No sales matched the filters." : "Sales loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<AdminSaleDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales.AsNoTracking()
            .Include(item => item.Customer).ThenInclude(customer => customer.Route)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (sale is null)
        {
            return ServiceResult<AdminSaleDetailDto>.Fail(404, "Sale was not found.");
        }

        var rider = await _db.Users.AsNoTracking()
            .FirstOrDefaultAsync(user => user.Id == sale.RiderId, cancellationToken);
        string? vehicleLabel = null;
        if (rider?.VehicleId is Guid vehicleId)
        {
            var vehicle = await _db.Vehicles.AsNoTracking().FirstOrDefaultAsync(item => item.Id == vehicleId, cancellationToken);
            if (vehicle is not null)
            {
                vehicleLabel = $"{vehicle.Name} · {vehicle.Plate}";
            }
        }

        var depotName = await _db.Depots.AsNoTracking()
            .OrderBy(item => item.Name)
            .Select(item => item.Name)
            .FirstOrDefaultAsync(cancellationToken) ?? "";

        var issued = sale.Lines.Where(line => line.Product.IsReturnable).Sum(line => line.Quantity);
        var previousHeld = sale.Customer.BottlesHeld + sale.EmptyBottlesReturned;
        AdminSaleAssetDto? assets = issued > 0 || sale.EmptyBottlesReturned > 0
            ? new AdminSaleAssetDto(
                "19L returnable bottles",
                previousHeld,
                issued,
                sale.EmptyBottlesReturned,
                previousHeld + issued - sale.EmptyBottlesReturned)
            : null;

        var credit = CreditPortion(sale);
        var dto = new AdminSaleDetailDto(
            sale.Id,
            sale.ReceiptNumber,
            sale.CreatedAt,
            sale.Status == SaleStatus.Completed ? sale.SignedAt ?? sale.CreatedAt : null,
            sale.Status.ToString(),
            ReportingWindow.Sync(sale.SyncStatus),
            sale.CustomerId,
            sale.Customer.Code,
            sale.Customer.BusinessName,
            $"{sale.Customer.Street}, {sale.Customer.Area}, {sale.Customer.City}".Trim(',', ' '),
            sale.Customer.PrimaryMobile,
            sale.Customer.Category,
            sale.RiderId,
            rider?.FullName ?? sale.RiderId,
            rider?.RiderCode,
            vehicleLabel,
            sale.Customer.Route?.Name,
            sale.Lines.Select(line => new AdminSaleLineDetailDto(
                line.ProductId,
                line.Product.Name,
                line.Product.Sku,
                line.Quantity,
                line.Product.UnitLabel,
                line.UnitPrice,
                line.Quantity * line.UnitPrice,
                line.Product.IsReturnable)).ToList(),
            sale.SaleAmount,
            sale.PreviousOutstanding,
            sale.AmountReceived,
            credit,
            Math.Max(0, sale.SaleAmount - Math.Min(sale.AmountReceived, sale.SaleAmount)),
            sale.PaymentChannel?.ToString(),
            TenderClassOf(sale),
            assets,
            sale.SignerName,
            sale.SignerRole,
            sale.SignedAt,
            sale.SignatureImage is { Length: > 0 },
            sale.SignatureNote,
            depotName,
            "Collections remain separate. Bank/Wallet tabs are not activated in Locked V1.");
        return ServiceResult<AdminSaleDetailDto>.Ok(dto, "Sale detail loaded.");
    }

    public async Task<ServiceResult<SaleDraftDto>> CreateDraftAsync(
        AdminCreateSaleDraftRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RiderUserId))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Select an authorized rider for this invoice.");
        }

        var rider = await _db.Users.FirstOrDefaultAsync(user => user.Id == request.RiderUserId.Trim(), cancellationToken);
        if (rider is null || !rider.IsActive)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "The selected rider is not available.");
        }

        if (rider.RouteId is null || rider.VehicleId is null)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "The selected rider must have a route and vehicle assignment.");
        }

        var customer = await _db.Customers.FirstOrDefaultAsync(
            item => item.Id == request.CustomerId && !item.IsDeleted,
            cancellationToken);
        if (customer is null)
        {
            return ServiceResult<SaleDraftDto>.Fail(404, "Customer was not found.");
        }

        if (!customer.Status.Equals("Active", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Only active customers can receive a sale.");
        }

        if (customer.RouteId != rider.RouteId)
        {
            return ServiceResult<SaleDraftDto>.Fail(403, "This customer is on another route than the selected rider.");
        }

        if (request.Lines is null || request.Lines.Count == 0 || request.Lines.All(line => line.Quantity <= 0))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Add at least one item.");
        }

        if (request.StopId is not null
            && !await _db.RouteStops.AnyAsync(
                stop => stop.Id == request.StopId && stop.CustomerId == customer.Id,
                cancellationToken))
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "That stop is not for this customer.");
        }

        var productIds = request.Lines.Select(line => line.ProductId).Distinct().ToList();
        var products = await _db.Products
            .Where(product => productIds.Contains(product.Id) && product.ShowOnSale)
            .ToListAsync(cancellationToken);
        if (products.Count != productIds.Count)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "One or more products are not available.");
        }

        var lines = new List<SaleLine>();
        foreach (var requested in request.Lines.Where(line => line.Quantity > 0))
        {
            var product = products.First(item => item.Id == requested.ProductId);
            lines.Add(new SaleLine
            {
                ProductId = product.Id,
                Product = product,
                Quantity = requested.Quantity,
                UnitPrice = product.UnitPrice
            });
        }

        var returnableQty = lines.Where(line => line.Product.IsReturnable).Sum(line => line.Quantity);
        var returned = request.EmptyBottlesReturned ?? Math.Min(customer.BottlesHeld, returnableQty);
        if (returned < 0 || returned > customer.BottlesHeld)
        {
            return ServiceResult<SaleDraftDto>.Fail(400, "Empty bottles returned cannot exceed the bottles this customer holds.");
        }

        var shift = await _db.Shifts.FirstOrDefaultAsync(
            item => item.RiderId == rider.Id && item.Status == "Open",
            cancellationToken);
        var sale = new Sale
        {
            ReceiptNumber = $"DFT-{Guid.NewGuid():N}"[..24],
            CustomerId = customer.Id,
            RiderId = rider.Id,
            ShiftId = shift?.Id,
            StopId = request.StopId,
            SaleAmount = lines.Sum(line => line.Quantity * line.UnitPrice),
            PreviousOutstanding = customer.Outstanding,
            EmptyBottlesReturned = returned,
            Status = SaleStatus.Draft,
            SyncStatus = SyncStatus.Pending,
            Lines = lines
        };
        _db.Sales.Add(sale);
        if (!string.IsNullOrWhiteSpace(_current.UserId))
        {
            _db.AuditLogs.Add(new AuditLog
            {
                UserId = _current.UserId!,
                Action = "AdminCreateSaleDraft",
                EntityName = "Sale",
                EntityId = sale.Id.ToString()
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
        var dto = new SaleDraftDto(
            sale.Id,
            customer.Id,
            sale.SaleAmount,
            sale.PreviousOutstanding,
            sale.SaleAmount + sale.PreviousOutstanding,
            returned,
            Math.Max(0, customer.BottlesHeld - returned),
            lines.Select(line => new SaleLineDto(
                line.ProductId,
                line.Product.Name,
                line.Quantity,
                line.UnitPrice,
                line.Quantity * line.UnitPrice)).ToList(),
            sale.ReceiptNumber);
        return ServiceResult<SaleDraftDto>.Created(dto, "Sale draft saved.");
    }

    public async Task<ServiceResult<ReceiptDto>> CompleteAsync(
        Guid id,
        AdminCompleteSaleRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryChannel(request.PaymentMethod, out var channel))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Choose a payment method. Locked V1 accepts Cash for spot sales; credit uses AmountReceived.");
        }

        // Locked V1: do not expand Bank/Wallet as posting products from HQ.
        if (channel is PaymentChannel.BankTransfer or PaymentChannel.Wallet or PaymentChannel.Cheque)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Bank, wallet, and cheque posting are not activated in Locked V1. Use Cash with a full or partial amount.");
        }

        if (string.IsNullOrWhiteSpace(request.SignerName))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "A customer signature name is required.");
        }

        var signature = DecodePng(request.SignatureImage);
        if (signature.Error is not null)
        {
            return ServiceResult<ReceiptDto>.Fail(400, signature.Error);
        }

        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var sale = await _db.Sales
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.Customer)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (sale is null)
        {
            return ServiceResult<ReceiptDto>.Fail(404, "Sale not found.");
        }

        if (sale.Status != SaleStatus.Draft)
        {
            return ServiceResult<ReceiptDto>.Fail(409, "This sale is already completed.");
        }

        var rider = await _db.Users.FirstOrDefaultAsync(user => user.Id == sale.RiderId, cancellationToken);
        if (rider is null || rider.VehicleId is null || rider.RouteId is null)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "The sale rider must have an active vehicle and route.");
        }

        if (sale.Customer.RouteId != rider.RouteId)
        {
            return ServiceResult<ReceiptDto>.Fail(403, "This customer is on another route.");
        }

        foreach (var line in sale.Lines)
        {
            var stock = await _db.VehicleStocks.FirstOrDefaultAsync(
                item => item.VehicleId == rider.VehicleId && item.ProductId == line.ProductId,
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
                item => item.VehicleId == rider.VehicleId && item.ProductId == line.ProductId,
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
        _db.LedgerEntries.Add(new LedgerEntry
        {
            CustomerId = customer.Id,
            Kind = LedgerKind.Sale,
            Description = sale.Lines.FirstOrDefault() is { } first
                ? $"New Sale ({first.Product.Name} x {first.Quantity})"
                : "Sale",
            Amount = sale.SaleAmount,
            BalanceAfter = customer.Outstanding,
            Reference = sale.ReceiptNumber
        });
        if (received > 0)
        {
            customer.Outstanding -= received;
            customer.LastPaymentAt = DateTime.UtcNow;
            customer.LastPaymentAmount = received;
            _db.LedgerEntries.Add(new LedgerEntry
            {
                CustomerId = customer.Id,
                Kind = LedgerKind.Payment,
                Description = $"{ChannelLabel(channel)} payment",
                Amount = -received,
                BalanceAfter = customer.Outstanding,
                Reference = sale.ReceiptNumber
            });
        }

        customer.LastDropAt = DateTime.UtcNow;
        sale.PreviousOutstanding = previous;
        sale.AmountReceived = received;
        sale.PaymentChannel = channel;
        sale.Status = SaleStatus.Completed;
        sale.SignerName = request.SignerName.Trim();
        sale.SignerRole = string.IsNullOrWhiteSpace(request.SignerRole) ? customer.ContactRole : request.SignerRole.Trim();
        sale.SignedAt = DateTime.UtcNow;
        sale.SignatureImage = signature.Bytes;
        sale.SignatureNote = string.IsNullOrWhiteSpace(request.SignatureNote) ? null : request.SignatureNote.Trim();
        sale.SyncStatus = SyncStatus.Synced;
        sale.ReceiptNumber = await NextCodeAsync(cancellationToken);
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

            var today = DateOnly.FromDateTime(DateTime.Today);
            var openOrders = await _db.CustomerOrders
                .Where(order => order.CustomerId == customer.Id
                    && order.RiderId == rider.Id
                    && order.DeliveryDate == today
                    && (order.Status == CustomerOrderStatus.Scheduled || order.Status == CustomerOrderStatus.InProgress))
                .ToListAsync(cancellationToken);
            foreach (var order in openOrders)
            {
                order.Status = CustomerOrderStatus.Delivered;
            }

            await RecurringScheduleService.CompleteLinkedAsync(_db, openOrders.Select(order => order.Id), cancellationToken);
        }

        var actor = _current.UserId ?? rider.Id;
        _db.ActivityLogs.Add(new ActivityLog
        {
            UserId = actor,
            Title = $"Sale — {customer.BusinessName}",
            Reference = sale.ReceiptNumber,
            Amount = sale.AmountReceived,
            SyncStatus = SyncStatus.Synced,
            Detail = "Recorded by HQ admin on the server."
        });
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = actor,
            Action = "AdminCompleteSale",
            EntityName = "Sale",
            EntityId = sale.Id.ToString()
        });

        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<ReceiptDto>.Ok(await BuildReceiptAsync(sale.Id, cancellationToken), "Sale completed.");
    }

    public async Task<ServiceResult<ReceiptDto>> ReceiptAsync(Guid id, CancellationToken cancellationToken)
    {
        var exists = await _db.Sales.AsNoTracking().AnyAsync(item => item.Id == id, cancellationToken);
        if (!exists)
        {
            return ServiceResult<ReceiptDto>.Fail(404, "Sale was not found.");
        }

        return ServiceResult<ReceiptDto>.Ok(await BuildReceiptAsync(id, cancellationToken), "Receipt loaded.");
    }

    private IQueryable<Sale> CompletedInRange(DateTime startUtc, DateTime endUtc) =>
        _db.Sales.AsNoTracking().Where(item =>
            item.Status == SaleStatus.Completed
            && item.CreatedAt >= startUtc
            && item.CreatedAt < endUtc);

    private async Task<ReceiptDto> BuildReceiptAsync(Guid saleId, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales.AsNoTracking()
            .Include(item => item.Customer)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .FirstAsync(item => item.Id == saleId, cancellationToken);
        var rider = await _db.Users.AsNoTracking().FirstOrDefaultAsync(user => user.Id == sale.RiderId, cancellationToken);
        var depot = await _db.Depots.AsNoTracking().OrderBy(item => item.Name).FirstOrDefaultAsync(cancellationToken);
        return new ReceiptDto(
            sale.Id,
            "Sale",
            sale.ReceiptNumber,
            sale.SignedAt ?? sale.CreatedAt,
            rider?.FullName ?? sale.RiderId,
            rider?.RiderCode ?? "",
            sale.Customer.BusinessName,
            sale.Customer.Code,
            sale.Lines.Select(line => new SaleLineDto(
                line.ProductId,
                line.Product.Name,
                line.Quantity,
                line.UnitPrice,
                line.Quantity * line.UnitPrice)).ToList(),
            sale.SaleAmount,
            sale.PreviousOutstanding,
            sale.AmountReceived,
            sale.Customer.Outstanding,
            sale.PaymentChannel is null ? "Unpaid" : ChannelLabel(sale.PaymentChannel.Value),
            sale.SignerName,
            sale.SignerRole,
            ReportingWindow.Sync(sale.SyncStatus),
            $"{sale.Customer.Street}, {sale.Customer.Area}, {sale.Customer.City}",
            sale.Customer.PrimaryMobile,
            depot?.Name ?? "",
            depot?.Address ?? "",
            sale.EmptyBottlesReturned,
            sale.Customer.BottlesHeld,
            sale.SignatureNote);
    }

    private async Task<string> NextCodeAsync(CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstAsync(item => item.Name == "Receipt", cancellationToken);
        var value = sequence.NextValue++;
        return $"RCP-{DateTime.Today:yyyyMMdd}-{value:0000}";
    }

    private static AdminSaleRowDto ToRow(Sale sale, string riderName, string? vehicleLabel)
    {
        var first = sale.Lines.FirstOrDefault();
        var items = first is null
            ? "—"
            : sale.Lines.Count == 1
                ? $"{first.Product.Name} × {first.Quantity}"
                : $"{first.Product.Name} × {first.Quantity} (+{sale.Lines.Count - 1})";
        return new AdminSaleRowDto(
            sale.Id,
            sale.ReceiptNumber,
            sale.CreatedAt,
            sale.CustomerId,
            sale.Customer.Code,
            sale.Customer.BusinessName,
            sale.RiderId,
            riderName,
            vehicleLabel,
            items,
            sale.Lines.Sum(line => line.Quantity),
            sale.SaleAmount,
            sale.AmountReceived,
            CreditPortion(sale),
            sale.PaymentChannel is null ? "Unpaid" : ChannelLabel(sale.PaymentChannel.Value),
            TenderClassOf(sale),
            sale.Status.ToString(),
            ReportingWindow.Sync(sale.SyncStatus));
    }

    private static bool IsCashSpot(Sale sale) =>
        sale.PaymentChannel == PaymentChannel.Cash && sale.AmountReceived >= sale.SaleAmount;

    private static bool IsCreditLedger(Sale sale) => sale.AmountReceived < sale.SaleAmount;

    private static decimal CreditPortion(Sale sale) =>
        Math.Max(0, sale.SaleAmount - Math.Min(sale.AmountReceived, sale.SaleAmount));

    private static string TenderClassOf(Sale sale)
    {
        if (sale.Status != SaleStatus.Completed)
        {
            return "Draft";
        }

        if (IsCreditLedger(sale))
        {
            return "Credit";
        }

        if (IsCashSpot(sale))
        {
            return "Cash";
        }

        return "Other";
    }

    private static bool TryParseType(string? value, out string? filter, out string? error)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            filter = null;
            error = null;
            return true;
        }

        var text = value.Trim();
        if (text.Equals("Cash", StringComparison.OrdinalIgnoreCase)
            || text.Equals("Credit", StringComparison.OrdinalIgnoreCase)
            || text.Equals("PendingSync", StringComparison.OrdinalIgnoreCase))
        {
            filter = char.ToUpperInvariant(text[0]) + text[1..];
            if (text.Equals("pendingsync", StringComparison.OrdinalIgnoreCase))
            {
                filter = "PendingSync";
            }
            else if (text.Equals("cash", StringComparison.OrdinalIgnoreCase))
            {
                filter = "Cash";
            }
            else if (text.Equals("credit", StringComparison.OrdinalIgnoreCase))
            {
                filter = "Credit";
            }

            error = null;
            return true;
        }

        filter = null;
        error = "Type must be All, Cash, Credit, or PendingSync.";
        return false;
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

    private static string ChannelLabel(PaymentChannel channel) => channel switch
    {
        PaymentChannel.BankTransfer => "Bank Transfer",
        PaymentChannel.Wallet => "Wallet",
        PaymentChannel.Cheque => "Cheque",
        _ => "Cash"
    };

    private readonly record struct PhotoRead(byte[]? Bytes, string? Error);

    private static PhotoRead DecodePng(string? encoded)
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
}
