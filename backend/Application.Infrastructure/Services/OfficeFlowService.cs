using System.Text;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Infrastructure.Services;

public interface IOfficeFlowService
{
    Task<ServiceResult<HqSettingsDto>> SettingsAsync(CancellationToken cancellationToken);
    Task<ServiceResult<HqSettingsDto>> UpdateSettingsAsync(UpdateHqSettingsRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<IReadOnlyList<CashHandoverDto>>> HandoversAsync(string? status, CancellationToken cancellationToken);
    Task<ServiceResult<CashHandoverDto>> ConfirmHandoverAsync(Guid id, ConfirmCashHandoverRequest request, CancellationToken cancellationToken);
    Task<ServiceResult<DocumentFileDto>> InvoicePdfAsync(string number, CancellationToken cancellationToken);
    Task<ServiceResult<DocumentFileDto>> OrderPdfAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<DocumentFileDto>> OrderCsvAsync(Guid id, CancellationToken cancellationToken);
    Task<ServiceResult<DocumentFileDto>> ManifestPdfAsync(Guid routeId, DateOnly date, CancellationToken cancellationToken);
}

public sealed class OfficeFlowService : IOfficeFlowService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public OfficeFlowService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<HqSettingsDto>> SettingsAsync(CancellationToken cancellationToken)
    {
        var profile = await ProfileAsync(cancellationToken);
        return ServiceResult<HqSettingsDto>.Ok(Map(profile), "HQ settings loaded.");
    }

    public async Task<ServiceResult<HqSettingsDto>> UpdateSettingsAsync(UpdateHqSettingsRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.LegalName) || string.IsNullOrWhiteSpace(request.DisplayName))
        {
            return ServiceResult<HqSettingsDto>.Fail(400, "Company name is required.");
        }

        var profile = await _db.BusinessProfiles.OrderBy(item => item.CreatedAtUtc).FirstOrDefaultAsync(cancellationToken);
        if (profile is null)
        {
            profile = new BusinessProfile();
            _db.BusinessProfiles.Add(profile);
        }

        profile.LegalName = request.LegalName.Trim();
        profile.DisplayName = request.DisplayName.Trim();
        profile.SupportEmail = (request.SupportEmail ?? "").Trim();
        profile.SupportPhone = (request.SupportPhone ?? "").Trim();
        profile.SupportAddress = (request.SupportAddress ?? "").Trim();
        profile.Website = (request.Website ?? "").Trim();
        profile.ReceiptFooter = (request.ReceiptFooter ?? "").Trim();
        Audit("UpdateHqSettings", profile.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<HqSettingsDto>.Ok(Map(profile), "HQ settings saved.");
    }

    public async Task<ServiceResult<IReadOnlyList<CashHandoverDto>>> HandoversAsync(string? status, CancellationToken cancellationToken)
    {
        var query = _db.CashHandovers.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(item => item.Status == status.Trim());
        }

        var rows = await query.OrderByDescending(item => item.SubmittedAt).Take(100).ToListAsync(cancellationToken);
        var ids = rows.Select(item => item.Id).ToList();
        var counts = await _db.Collections.AsNoTracking().Where(item => item.HandoverId != null && ids.Contains(item.HandoverId.Value))
            .GroupBy(item => item.HandoverId)
            .Select(group => new { group.Key, Count = group.Count() })
            .ToListAsync(cancellationToken);
        IReadOnlyList<CashHandoverDto> mapped = rows.Select(item => MapHandover(item, counts.FirstOrDefault(count => count.Key == item.Id)?.Count ?? 0)).ToList();
        return ServiceResult<IReadOnlyList<CashHandoverDto>>.Ok(mapped, "Cash handovers loaded.");
    }

    public async Task<ServiceResult<CashHandoverDto>> ConfirmHandoverAsync(Guid id, ConfirmCashHandoverRequest request, CancellationToken cancellationToken)
    {
        if (request.ActualAmount < 0) return ServiceResult<CashHandoverDto>.Fail(400, "The counted amount cannot be negative.");
        var handover = await _db.CashHandovers.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (handover is null) return ServiceResult<CashHandoverDto>.Fail(404, "Cash handover not found.");
        if (handover.Status != CashHandoverStatus.Submitted) return ServiceResult<CashHandoverDto>.Fail(409, "This handover is already confirmed.");
        if (string.Equals(handover.RiderId, _current.UserId, StringComparison.Ordinal))
        {
            return ServiceResult<CashHandoverDto>.Fail(403, "A rider cannot confirm their own cash handover.");
        }

        var collections = await _db.Collections.Where(item => item.HandoverId == handover.Id).ToListAsync(cancellationToken);
        handover.ActualAmount = request.ActualAmount;
        handover.Note = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();
        handover.Status = CashHandoverStatus.Received;
        handover.ReceivedByUserId = _current.UserId;
        handover.ReceivedAt = DateTime.UtcNow;
        foreach (var collection in collections)
        {
            collection.CashStatus = CashCollectionStatus.CashReceived;
            collection.CashReceivedAt = handover.ReceivedAt;
            collection.CashReceivedByUserId = _current.UserId;
            collection.CashReceivedDepotId = handover.DepotId;
        }

        Audit("ConfirmCashHandover", handover.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CashHandoverDto>.Ok(MapHandover(handover, collections.Count), "Warehouse cash receipt recorded.");
    }

    public async Task<ServiceResult<DocumentFileDto>> InvoicePdfAsync(string number, CancellationToken cancellationToken)
    {
        var sale = await _db.Sales.AsNoTracking().Include(item => item.Lines).ThenInclude(line => line.Product).Include(item => item.Customer)
            .FirstOrDefaultAsync(item => item.ReceiptNumber == number && item.Status == SaleStatus.Completed, cancellationToken);
        if (sale is null) return ServiceResult<DocumentFileDto>.Fail(404, "Invoice not found.");
        var profile = await ProfileAsync(cancellationToken);
        var lines = new List<string>
        {
            profile?.DisplayName ?? "AQUARIDER",
            profile?.ReceiptFooter ?? "",
            $"Invoice {sale.ReceiptNumber}",
            sale.Customer.BusinessName,
            $"Date {sale.CreatedAt:yyyy-MM-dd}",
            $"Billed {sale.SaleAmount:0}",
            $"Paid {sale.AmountReceived:0}",
            $"Outstanding balance on the customer record {sale.Customer.Outstanding:0}"
        };
        lines.AddRange(sale.Lines.Select(line => $"{line.Product.Name} x {line.Quantity} @ {line.UnitPrice:0}"));
        return ServiceResult<DocumentFileDto>.Ok(File(sale.ReceiptNumber, lines), "Invoice PDF created.");
    }

    public async Task<ServiceResult<DocumentFileDto>> OrderPdfAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await _db.CustomerOrders.AsNoTracking().Include(item => item.Lines).ThenInclude(line => line.Product).Include(item => item.Customer)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (order is null) return ServiceResult<DocumentFileDto>.Fail(404, "Order not found.");
        var lines = new List<string> { $"Order {order.ReferenceNumber}", order.Customer.BusinessName, order.DeliveryDate.ToString("yyyy-MM-dd"), order.Status.ToString() };
        lines.AddRange(order.Lines.Select(line => $"{line.Product.Name} x {line.Quantity}"));
        return ServiceResult<DocumentFileDto>.Ok(File(order.ReferenceNumber, lines), "Order PDF created.");
    }

    public async Task<ServiceResult<DocumentFileDto>> OrderCsvAsync(Guid id, CancellationToken cancellationToken)
    {
        var order = await _db.CustomerOrders.AsNoTracking().Include(item => item.Lines).ThenInclude(line => line.Product).Include(item => item.Customer)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (order is null) return ServiceResult<DocumentFileDto>.Fail(404, "Order not found.");
        var csv = new StringBuilder();
        csv.AppendLine("order,customer,product,quantity,unitPrice");
        foreach (var line in order.Lines)
        {
            csv.AppendLine($"{order.ReferenceNumber},{order.Customer.Code},{line.Product.Name},{line.Quantity},{line.UnitPrice}");
        }

        return ServiceResult<DocumentFileDto>.Ok(new DocumentFileDto($"{order.ReferenceNumber}.csv", "text/csv", Convert.ToBase64String(Encoding.UTF8.GetBytes(csv.ToString()))), "Order CSV created.");
    }

    public async Task<ServiceResult<DocumentFileDto>> ManifestPdfAsync(Guid routeId, DateOnly date, CancellationToken cancellationToken)
    {
        var route = await _db.DeliveryRoutes.AsNoTracking().FirstOrDefaultAsync(item => item.Id == routeId, cancellationToken);
        if (route is null) return ServiceResult<DocumentFileDto>.Fail(404, "Route not found.");
        var stops = await _db.RouteStops.AsNoTracking().Include(item => item.Customer)
            .Where(item => item.RouteId == routeId && item.ServiceDate == date)
            .OrderBy(item => item.Sequence)
            .ToListAsync(cancellationToken);
        var lines = new List<string> { route.Name, date.ToString("yyyy-MM-dd") };
        lines.AddRange(stops.Select(stop => $"{stop.Sequence}. {stop.Customer.Code} {stop.Customer.BusinessName}"));
        if (stops.Count == 0) lines.Add("No stops are stored for this date.");
        return ServiceResult<DocumentFileDto>.Ok(File($"manifest-{date:yyyyMMdd}", lines), "Manifest PDF created.");
    }

    private async Task<BusinessProfile?> ProfileAsync(CancellationToken cancellationToken) =>
        await _db.BusinessProfiles.AsNoTracking().OrderBy(item => item.CreatedAtUtc).FirstOrDefaultAsync(cancellationToken);

    private static HqSettingsDto Map(BusinessProfile? profile) => new(
        profile?.LegalName ?? "",
        profile?.DisplayName ?? "",
        profile?.SupportEmail ?? "",
        profile?.SupportPhone ?? "",
        profile?.SupportAddress ?? "",
        profile?.Website ?? "",
        profile?.ReceiptFooter ?? "");

    private static CashHandoverDto MapHandover(CashHandover handover, int count)
    {
        decimal? difference = handover.ActualAmount is decimal actual ? actual - handover.ExpectedAmount : null;
        return new CashHandoverDto(handover.Id, handover.ReferenceNumber, handover.RiderId, handover.DepotId, handover.BusinessDate.ToString("yyyy-MM-dd"), handover.ExpectedAmount, handover.ActualAmount, difference, handover.Status, count, handover.SubmittedAt.ToString("yyyy-MM-dd HH:mm"), handover.ReceivedAt?.ToString("yyyy-MM-dd HH:mm"));
    }

    private static DocumentFileDto File(string name, IReadOnlyList<string> lines)
    {
        var safe = lines.Where(line => !string.IsNullOrWhiteSpace(line)).Select(line => line.Length > 90 ? line[..90] : line).ToList();
        return new DocumentFileDto($"{name}.pdf", "application/pdf", Convert.ToBase64String(PlainPdf.Create(safe)));
    }

    private void Audit(string action, string id)
    {
        if (string.IsNullOrWhiteSpace(_current.UserId)) return;
        _db.AuditLogs.Add(new AuditLog { UserId = _current.UserId, Action = action, EntityName = "OfficeFlow", EntityId = id });
    }
}

static class PlainPdf
{
    public static byte[] Create(IReadOnlyList<string> lines)
    {
        var text = new StringBuilder();
        text.AppendLine("BT /F1 11 Tf 40 800 Td");
        foreach (var line in lines.Take(42))
        {
            text.Append('(').Append(line.Replace("\\", " ").Replace("(", " ").Replace(")", " ")).AppendLine(") Tj");
            text.AppendLine("0 -16 Td");
        }

        text.Append("ET");
        var stream = text.ToString();
        var objects = new[]
        {
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Count 1 /Kids [3 0 R] >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
            $"<< /Length {Encoding.ASCII.GetByteCount(stream)} >>\nstream\n{stream}\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
        };
        var builder = new StringBuilder();
        builder.Append("%PDF-1.4\n");
        var offsets = new List<int>();
        for (var index = 0; index < objects.Length; index++)
        {
            offsets.Add(Encoding.ASCII.GetByteCount(builder.ToString()));
            builder.Append($"{index + 1} 0 obj\n{objects[index]}\nendobj\n");
        }

        var xref = Encoding.ASCII.GetByteCount(builder.ToString());
        builder.Append($"xref\n0 {objects.Length + 1}\n0000000000 65535 f \n");
        foreach (var offset in offsets) builder.Append(offset.ToString("D10")).Append(" 00000 n \n");
        builder.Append($"trailer << /Size {objects.Length + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF");
        return Encoding.ASCII.GetBytes(builder.ToString());
    }
}
