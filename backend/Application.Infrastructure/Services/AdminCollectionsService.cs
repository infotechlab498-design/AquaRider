using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminCollectionsService : IAdminCollectionsService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public AdminCollectionsService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<AdminCollectionsSummaryDto>> SummaryAsync(
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (rangeStart, rangeEnd) = ReportingWindow.UtcBounds(day, day);
        var monthStart = new DateOnly(day.Year, day.Month, 1);
        var (monthUtcStart, _) = ReportingWindow.UtcBounds(monthStart, day);

        var todayRows = await _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd)
            .ToListAsync(cancellationToken);
        var monthly = await _db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= monthUtcStart && item.CreatedAt < rangeEnd)
            .SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var cashToday = todayRows.Where(item => item.Channel == PaymentChannel.Cash).Sum(item => item.Amount);
        var todayTotal = todayRows.Sum(item => item.Amount);
        var customers = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted)
            .Select(item => new { item.Outstanding, item.CreditDays, item.LastPaymentAt })
            .ToListAsync(cancellationToken);
        var receivables = customers.Sum(item => item.Outstanding);
        var onCredit = customers.Count(item => item.Outstanding > 0);
        var todayLocal = DateTime.Today;
        var highRisk = customers.Count(item =>
        {
            if (item.Outstanding <= 0) return false;
            var anchor = item.LastPaymentAt?.Date ?? todayLocal.AddDays(-item.CreditDays - 1);
            var overdue = (todayLocal - anchor).TotalDays - item.CreditDays;
            return overdue >= 7;
        });
        var pending = await _db.Collections.AsNoTracking()
            .CountAsync(item => item.SyncStatus == SyncStatus.Pending, cancellationToken);
        var failed = await _db.Collections.AsNoTracking()
            .CountAsync(item => item.SyncStatus == SyncStatus.Failed, cancellationToken);

        var dto = new AdminCollectionsSummaryDto(
            day,
            todayTotal,
            todayRows.Count,
            monthly,
            receivables,
            onCredit,
            highRisk,
            todayRows.Count,
            pending,
            failed,
            todayTotal == 0 ? 0 : ReportingWindow.Percent(cashToday, todayTotal),
            "Locked V1: Cash collections and pending sync only. Raast/Bank/Wallet tabs, Knox, WhatsApp and thermal are not activated.");
        return ServiceResult<AdminCollectionsSummaryDto>.Ok(dto, "Collections summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminCollectionRowDto>>> ListAsync(
        DateOnly? date,
        string? type,
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
            return ServiceResult<IReadOnlyList<AdminCollectionRowDto>>.Fail(400, typeError!);
        }

        var query = _db.Collections.AsNoTracking()
            .Include(item => item.Customer)
            .AsQueryable();

        if (typeFilter == "PendingSync")
        {
            query = query.Where(item =>
                item.SyncStatus == SyncStatus.Pending || item.SyncStatus == SyncStatus.Failed);
        }
        else
        {
            query = query.Where(item => item.CreatedAt >= rangeStart && item.CreatedAt < rangeEnd);
            if (typeFilter == "Cash")
            {
                query = query.Where(item => item.Channel == PaymentChannel.Cash);
            }
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
                item.ReferenceNumber.Contains(term)
                || item.Customer.BusinessName.Contains(term)
                || item.Customer.Code.Contains(term)
                || item.Customer.Area.Contains(term)
                || item.RiderId.Contains(term));
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
            .Select(user => new { user.Id, user.FullName })
            .ToDictionaryAsync(user => user.Id, cancellationToken);

        IReadOnlyList<AdminCollectionRowDto> data = rows.Select(item =>
        {
            riders.TryGetValue(item.RiderId, out var rider);
            return ToRow(item, rider?.FullName ?? item.RiderId);
        }).ToList();

        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<AdminCollectionRowDto>>.Ok(
            data,
            data.Count == 0 ? "No collections matched the filters." : "Collections loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<AdminCollectionDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var item = await _db.Collections.AsNoTracking()
            .Include(row => row.Customer).ThenInclude(customer => customer.Route)
            .FirstOrDefaultAsync(row => row.Id == id, cancellationToken);
        if (item is null)
        {
            return ServiceResult<AdminCollectionDetailDto>.Fail(404, "Collection was not found.");
        }

        var rider = await _db.Users.AsNoTracking().FirstOrDefaultAsync(user => user.Id == item.RiderId, cancellationToken);
        string? vehicleLabel = null;
        if (rider?.VehicleId is Guid vehicleId)
        {
            var vehicle = await _db.Vehicles.AsNoTracking().FirstOrDefaultAsync(row => row.Id == vehicleId, cancellationToken);
            if (vehicle is not null)
            {
                vehicleLabel = $"{vehicle.Name} · {vehicle.Plate}";
            }
        }

        var dto = new AdminCollectionDetailDto(
            item.Id,
            item.ReferenceNumber,
            item.CreatedAt,
            ReportingWindow.Sync(item.SyncStatus),
            item.CustomerId,
            item.Customer.Code,
            item.Customer.BusinessName,
            $"{item.Customer.Street}, {item.Customer.Area}, {item.Customer.City}",
            item.Customer.PrimaryMobile,
            item.RiderId,
            rider?.FullName ?? item.RiderId,
            rider?.RiderCode,
            vehicleLabel,
            item.Customer.Route?.Name,
            ChannelLabel(item.Channel),
            item.Amount,
            item.WithholdingTax,
            item.OutstandingBefore,
            item.OutstandingAfter,
            item.Notes,
            item.SignerName,
            item.SignerRole,
            item.SignatureImage is { Length: > 0 },
            item.SignatureNote,
            "Collections remain separate from sales. GPS/Knox evidence is not fabricated in Locked V1.");
        return ServiceResult<AdminCollectionDetailDto>.Ok(dto, "Collection detail loaded.");
    }

    public async Task<ServiceResult<ReceiptDto>> RecordAsync(
        AdminRecordCollectionRequest request,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.RiderUserId))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Select an authorized rider for this settlement.");
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

        if (!string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            var key = request.IdempotencyKey.Trim();
            var existing = await _db.Collections.AsNoTracking()
                .FirstOrDefaultAsync(item => item.Notes != null && item.Notes.Contains($"idem:{key}"), cancellationToken);
            if (existing is not null)
            {
                return ServiceResult<ReceiptDto>.Ok(await BuildReceiptAsync(existing.Id, cancellationToken), "Collection already recorded.");
            }
        }

        var rider = await _db.Users.FirstOrDefaultAsync(user => user.Id == request.RiderUserId.Trim(), cancellationToken);
        if (rider is null || !rider.IsActive)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "The selected rider is not available.");
        }

        if (rider.RouteId is null)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "The selected rider must have a route assignment.");
        }

        var customer = await _db.Customers.FirstOrDefaultAsync(
            item => item.Id == request.CustomerId && !item.IsDeleted,
            cancellationToken);
        if (customer is null)
        {
            return ServiceResult<ReceiptDto>.Fail(404, "Customer was not found.");
        }

        if (!customer.Status.Equals("Active", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Only active customers can settle collections.");
        }

        if (customer.RouteId != rider.RouteId)
        {
            return ServiceResult<ReceiptDto>.Fail(403, "This customer is on another route than the selected rider.");
        }

        var tax = request.WithholdingTax;
        if (request.Amount <= 0 || tax < 0 || request.Amount + tax > customer.Outstanding)
        {
            return ServiceResult<ReceiptDto>.Fail(400, "Collection and withholding tax must stay within the outstanding balance.");
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

        var reference = await NextCodeAsync(cancellationToken);
        var noteParts = new List<string>();
        if (!string.IsNullOrWhiteSpace(request.Note))
        {
            noteParts.Add(request.Note.Trim());
        }

        if (!string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            noteParts.Add($"idem:{request.IdempotencyKey.Trim()}");
        }

        var collection = new Collection
        {
            ReferenceNumber = reference,
            CustomerId = customer.Id,
            RiderId = rider.Id,
            Amount = request.Amount,
            WithholdingTax = tax,
            Notes = noteParts.Count == 0 ? null : string.Join(" | ", noteParts),
            Channel = PaymentChannel.Cash,
            OutstandingBefore = before,
            OutstandingAfter = customer.Outstanding,
            SignerName = request.SignerName.Trim(),
            SignerRole = string.IsNullOrWhiteSpace(request.SignerRole) ? customer.ContactRole : request.SignerRole.Trim(),
            SignatureImage = signature.Bytes,
            SignatureNote = string.IsNullOrWhiteSpace(request.SignatureNote) ? null : request.SignatureNote.Trim(),
            SyncStatus = SyncStatus.Synced
        };
        _db.Collections.Add(collection);
        _db.LedgerEntries.Add(new LedgerEntry
        {
            CustomerId = customer.Id,
            Kind = LedgerKind.Payment,
            Description = "Cash collection",
            Amount = -request.Amount,
            BalanceAfter = customer.Outstanding + tax,
            Reference = reference
        });
        if (tax > 0)
        {
            _db.LedgerEntries.Add(new LedgerEntry
            {
                CustomerId = customer.Id,
                Kind = LedgerKind.Payment,
                Description = "Withholding tax",
                Amount = -tax,
                BalanceAfter = customer.Outstanding,
                Reference = reference
            });
        }

        var actor = _current.UserId ?? rider.Id;
        _db.ActivityLogs.Add(new ActivityLog
        {
            UserId = actor,
            Title = $"Collection — {customer.BusinessName}",
            Reference = reference,
            Amount = request.Amount,
            SyncStatus = SyncStatus.Synced,
            Detail = "Recorded by HQ admin on the server."
        });
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = actor,
            Action = "AdminRecordCollection",
            EntityName = "Collection",
            EntityId = collection.Id.ToString()
        });

        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<ReceiptDto>.Created(await BuildReceiptAsync(collection.Id, cancellationToken), "Collection recorded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminReceivableExposureDto>>> ExposureAsync(
        CancellationToken cancellationToken)
    {
        var today = DateTime.Today;
        var rows = await _db.Customers.AsNoTracking()
            .Where(item => !item.IsDeleted && item.Outstanding > 0)
            .OrderByDescending(item => item.Outstanding)
            .Take(20)
            .ToListAsync(cancellationToken);
        IReadOnlyList<AdminReceivableExposureDto> data = rows.Select(item =>
        {
            var anchor = item.LastPaymentAt?.Date ?? today.AddDays(-item.CreditDays - 1);
            var overdue = (int)Math.Floor((today - anchor).TotalDays) - item.CreditDays;
            var days = overdue < 0 ? 0 : overdue;
            var risk = days >= 14 ? $"{days} Days Overdue" : days > 0 ? $"{days} Days Overdue" : "Within terms";
            return new AdminReceivableExposureDto(
                item.Id,
                item.Code,
                item.BusinessName,
                item.Area,
                item.Outstanding,
                days,
                risk);
        }).ToList();
        return ServiceResult<IReadOnlyList<AdminReceivableExposureDto>>.Ok(
            data,
            data.Count == 0 ? "No outstanding receivables." : "High exposure accounts loaded.");
    }

    private async Task<ReceiptDto> BuildReceiptAsync(Guid id, CancellationToken cancellationToken)
    {
        var item = await _db.Collections.AsNoTracking()
            .Include(row => row.Customer)
            .FirstAsync(row => row.Id == id, cancellationToken);
        var rider = await _db.Users.AsNoTracking().FirstOrDefaultAsync(user => user.Id == item.RiderId, cancellationToken);
        var depot = await _db.Depots.AsNoTracking().OrderBy(row => row.Name).FirstOrDefaultAsync(cancellationToken);
        return new ReceiptDto(
            item.Id,
            "Collection",
            item.ReferenceNumber,
            item.CreatedAt,
            rider?.FullName ?? item.RiderId,
            rider?.RiderCode ?? "",
            item.Customer.BusinessName,
            item.Customer.Code,
            Array.Empty<SaleLineDto>(),
            0,
            item.OutstandingBefore,
            item.Amount,
            item.OutstandingAfter,
            ChannelLabel(item.Channel),
            item.SignerName,
            item.SignerRole,
            ReportingWindow.Sync(item.SyncStatus),
            $"{item.Customer.Street}, {item.Customer.Area}, {item.Customer.City}",
            item.Customer.PrimaryMobile,
            depot?.Name ?? "",
            depot?.Address ?? "",
            0,
            item.Customer.BottlesHeld,
            item.SignatureNote,
            item.WithholdingTax);
    }

    private async Task<string> NextCodeAsync(CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstAsync(item => item.Name == "Collection", cancellationToken);
        var value = sequence.NextValue++;
        return $"COL-{DateTime.Today:yyyyMMdd}-{value:0000}";
    }

    private static AdminCollectionRowDto ToRow(Collection item, string riderName) =>
        new(
            item.Id,
            item.ReferenceNumber,
            item.CreatedAt,
            item.CustomerId,
            item.Customer.Code,
            item.Customer.BusinessName,
            item.Customer.Area,
            item.RiderId,
            riderName,
            ChannelLabel(item.Channel),
            item.Channel == PaymentChannel.Cash ? "Cash" : "Other",
            item.Amount,
            item.WithholdingTax,
            item.OutstandingBefore,
            item.OutstandingAfter,
            ReportingWindow.Sync(item.SyncStatus));

    private static bool TryParseType(string? value, out string? filter, out string? error)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            filter = null;
            error = null;
            return true;
        }

        if (value.Equals("Cash", StringComparison.OrdinalIgnoreCase))
        {
            filter = "Cash";
            error = null;
            return true;
        }

        if (value.Equals("PendingSync", StringComparison.OrdinalIgnoreCase))
        {
            filter = "PendingSync";
            error = null;
            return true;
        }

        filter = null;
        error = "Type must be All, Cash, or PendingSync in Locked V1.";
        return false;
    }

    private static string ChannelLabel(PaymentChannel channel) => channel switch
    {
        PaymentChannel.BankTransfer => "Bank Transfer",
        PaymentChannel.Wallet => "Wallet",
        PaymentChannel.Cheque => "Cheque",
        _ => "Cash Spot"
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
            return new PhotoRead(null, "The signature could not be read.");
        }

        if (bytes.Length < 32 || bytes.Length > 2_000_000)
        {
            return new PhotoRead(null, "The signature is too large to store.");
        }

        var png = bytes.Length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
        return png
            ? new PhotoRead(bytes, null)
            : new PhotoRead(null, "The signature must be a PNG.");
    }
}
