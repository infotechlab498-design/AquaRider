using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class AdminCommunicationsService : IAdminCommunicationsService
{
    private static readonly HashSet<string> AllowedVariables = new(StringComparer.OrdinalIgnoreCase)
    {
        "customer_name", "order_id", "receipt_no", "amount", "remaining_balance", "rider_name", "delivery_status"
    };

    private static readonly (string Type, string Description)[] Triggers =
    [
        ("OrderConfirmed", "Order confirmation SMS"),
        ("OrderDispatched", "Dispatch notification"),
        ("DeliveryCompleted", "Delivery / sale receipt notification"),
        ("PaymentCollected", "Payment collection confirmation"),
        ("BalanceRecoveryReminder", "Outstanding balance reminder")
    ];

    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public AdminCommunicationsService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<CommunicationDashboardSummaryDto>> SummaryAsync(
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        await EnsureDefaultTemplatesAsync(cancellationToken);
        var day = date ?? ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var rows = await _db.CommunicationMessages.AsNoTracking()
            .Where(item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end)
            .Select(item => item.Status)
            .ToListAsync(cancellationToken);
        var gateway = await GatewayStatusCoreAsync(rows.Count, cancellationToken);
        var dto = new CommunicationDashboardSummaryDto(
            day,
            rows.Count,
            rows.Count(status => status.Equals("Delivered", StringComparison.OrdinalIgnoreCase)),
            rows.Count(status => status is "Queued" or "NotConfigured" or "Submitted"),
            rows.Count(status => status is "Failed" or "Suppressed"),
            gateway,
            "Locked V1: transactional SMS only. WhatsApp and fabricated delivery receipts are disabled.");
        return ServiceResult<CommunicationDashboardSummaryDto>.Ok(dto, "Communication summary loaded.");
    }

    public async Task<ServiceResult<CommunicationGatewayStatusDto>> GatewayStatusAsync(CancellationToken cancellationToken)
    {
        var status = await GatewayStatusCoreAsync(null, cancellationToken);
        return ServiceResult<CommunicationGatewayStatusDto>.Ok(status, "Gateway status loaded.");
    }

    public async Task<ServiceResult<CommunicationGatewayStatusDto>> TestGatewayAsync(CancellationToken cancellationToken)
    {
        var status = await GatewayStatusCoreAsync(null, cancellationToken);
        if (!string.IsNullOrWhiteSpace(_current.UserId))
        {
            _db.AuditLogs.Add(new AuditLog
            {
                UserId = _current.UserId!,
                Action = "TestSmsGateway",
                EntityName = "CommunicationGateway",
                EntityId = "default"
            });
            await _db.SaveChangesAsync(cancellationToken);
        }

        return ServiceResult<CommunicationGatewayStatusDto>.Ok(status, status.Message);
    }

    public async Task<ServiceResult<IReadOnlyList<CommunicationTemplateDto>>> ListTemplatesAsync(
        CancellationToken cancellationToken)
    {
        await EnsureDefaultTemplatesAsync(cancellationToken);
        var rows = await _db.CommunicationTemplates.AsNoTracking()
            .Where(item => !item.IsArchived)
            .OrderBy(item => item.TemplateCode)
            .ToListAsync(cancellationToken);
        IReadOnlyList<CommunicationTemplateDto> data = rows.Select(ToTemplate).ToList();
        return ServiceResult<IReadOnlyList<CommunicationTemplateDto>>.Ok(data, "Templates loaded.");
    }

    public async Task<ServiceResult<CommunicationTemplateDto>> GetTemplateAsync(Guid id, CancellationToken cancellationToken)
    {
        var item = await _db.CommunicationTemplates.AsNoTracking()
            .FirstOrDefaultAsync(row => row.Id == id && !row.IsArchived, cancellationToken);
        return item is null
            ? ServiceResult<CommunicationTemplateDto>.Fail(404, "Template was not found.")
            : ServiceResult<CommunicationTemplateDto>.Ok(ToTemplate(item), "Template loaded.");
    }

    public async Task<ServiceResult<CommunicationTemplateDto>> CreateTemplateAsync(
        CommunicationTemplateWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryValidateTemplate(request, out var error))
        {
            return ServiceResult<CommunicationTemplateDto>.Fail(400, error!);
        }

        var code = string.IsNullOrWhiteSpace(request.TemplateCode)
            ? $"T-{Guid.NewGuid():N}"[..10].ToUpperInvariant()
            : request.TemplateCode.Trim();
        if (await _db.CommunicationTemplates.AnyAsync(item => item.TemplateCode == code, cancellationToken))
        {
            return ServiceResult<CommunicationTemplateDto>.Fail(409, "Template code already exists.");
        }

        var entity = new CommunicationTemplate
        {
            TemplateCode = code,
            Name = request.Name.Trim(),
            Language = NormalizeLanguage(request.Language),
            TriggerType = request.TriggerType.Trim(),
            Content = request.Content.Trim(),
            IsActive = true,
            UpdatedByUserId = _current.UserId
        };
        _db.CommunicationTemplates.Add(entity);
        AddAudit("CreateSmsTemplate", "CommunicationTemplate", entity.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CommunicationTemplateDto>.Created(ToTemplate(entity), "Template created.");
    }

    public async Task<ServiceResult<CommunicationTemplateDto>> UpdateTemplateAsync(
        Guid id,
        CommunicationTemplateWriteRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryValidateTemplate(request, out var error))
        {
            return ServiceResult<CommunicationTemplateDto>.Fail(400, error!);
        }

        var entity = await _db.CommunicationTemplates.FirstOrDefaultAsync(item => item.Id == id && !item.IsArchived, cancellationToken);
        if (entity is null)
        {
            return ServiceResult<CommunicationTemplateDto>.Fail(404, "Template was not found.");
        }

        entity.Name = request.Name.Trim();
        entity.Language = NormalizeLanguage(request.Language);
        entity.TriggerType = request.TriggerType.Trim();
        entity.Content = request.Content.Trim();
        entity.UpdatedAtUtc = DateTime.UtcNow;
        entity.UpdatedByUserId = _current.UserId;
        AddAudit("UpdateSmsTemplate", "CommunicationTemplate", entity.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CommunicationTemplateDto>.Ok(ToTemplate(entity), "Template updated.");
    }

    public async Task<ServiceResult<CommunicationTemplateDto>> SetTemplateActiveAsync(
        Guid id,
        bool isActive,
        CancellationToken cancellationToken)
    {
        var entity = await _db.CommunicationTemplates.FirstOrDefaultAsync(item => item.Id == id && !item.IsArchived, cancellationToken);
        if (entity is null)
        {
            return ServiceResult<CommunicationTemplateDto>.Fail(404, "Template was not found.");
        }

        entity.IsActive = isActive;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        entity.UpdatedByUserId = _current.UserId;
        AddAudit(isActive ? "ActivateSmsTemplate" : "DeactivateSmsTemplate", "CommunicationTemplate", entity.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CommunicationTemplateDto>.Ok(ToTemplate(entity), isActive ? "Template activated." : "Template deactivated.");
    }

    public async Task<ServiceResult<object>> ArchiveTemplateAsync(Guid id, CancellationToken cancellationToken)
    {
        var entity = await _db.CommunicationTemplates.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (entity is null)
        {
            return ServiceResult<object>.Fail(404, "Template was not found.");
        }

        entity.IsArchived = true;
        entity.IsActive = false;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        entity.UpdatedByUserId = _current.UserId;
        AddAudit("ArchiveSmsTemplate", "CommunicationTemplate", entity.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { entity.Id }, "Template archived.");
    }

    public async Task<ServiceResult<CommunicationPreviewDto>> PreviewAsync(
        CommunicationPreviewRequest request,
        CancellationToken cancellationToken)
    {
        var template = await _db.CommunicationTemplates.AsNoTracking()
            .FirstOrDefaultAsync(item => item.Id == request.TemplateId && !item.IsArchived, cancellationToken);
        if (template is null)
        {
            return ServiceResult<CommunicationPreviewDto>.Fail(404, "Template was not found.");
        }

        var rendered = Render(template.Content, request.Variables);
        return ServiceResult<CommunicationPreviewDto>.Ok(
            new CommunicationPreviewDto(template.Language, rendered, "Preview only — not submitted."),
            "Preview rendered.");
    }

    public async Task<ServiceResult<IReadOnlyList<CommunicationTriggerDto>>> ListTriggersAsync(
        CancellationToken cancellationToken)
    {
        await EnsureDefaultTemplatesAsync(cancellationToken);
        var templates = await _db.CommunicationTemplates.AsNoTracking()
            .Where(item => !item.IsArchived)
            .ToListAsync(cancellationToken);
        IReadOnlyList<CommunicationTriggerDto> data = Triggers.Select(trigger =>
        {
            var match = templates.FirstOrDefault(item =>
                item.TriggerType.Equals(trigger.Type, StringComparison.OrdinalIgnoreCase) && item.IsActive);
            return new CommunicationTriggerDto(
                trigger.Type,
                trigger.Description,
                match?.Id,
                match?.Name,
                match is not null);
        }).ToList();
        return ServiceResult<IReadOnlyList<CommunicationTriggerDto>>.Ok(data, "Triggers loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<CommunicationMessageRowDto>>> ListMessagesAsync(
        DateOnly? date,
        string? status,
        string? search,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var day = date ?? ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var query = _db.CommunicationMessages.AsNoTracking()
            .Include(item => item.Customer)
            .Where(item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end);

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            var st = status.Trim();
            query = query.Where(item => item.Status == st);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.MessageReference.Contains(term)
                || item.DestinationNumber.Contains(term)
                || (item.TransactionReference != null && item.TransactionReference.Contains(term))
                || (item.Customer != null && item.Customer.BusinessName.Contains(term)));
        }

        var total = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderByDescending(item => item.CreatedAtUtc)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .ToListAsync(cancellationToken);
        IReadOnlyList<CommunicationMessageRowDto> data = rows.Select(ToMessageRow).ToList();
        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<CommunicationMessageRowDto>>.Ok(
            data,
            data.Count == 0 ? "No messages matched the filters." : "Messages loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<CommunicationMessageDetailDto>> GetMessageAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        var item = await _db.CommunicationMessages.AsNoTracking()
            .Include(row => row.Customer)
            .Include(row => row.Template)
            .FirstOrDefaultAsync(row => row.Id == id, cancellationToken);
        return item is null
            ? ServiceResult<CommunicationMessageDetailDto>.Fail(404, "Message was not found.")
            : ServiceResult<CommunicationMessageDetailDto>.Ok(ToMessageDetail(item), "Message loaded.");
    }

    public async Task<ServiceResult<CommunicationMessageDetailDto>> EnqueueAsync(
        CommunicationEnqueueRequest request,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(request.IdempotencyKey))
        {
            var key = request.IdempotencyKey.Trim();
            var existing = await _db.CommunicationMessages
                .Include(item => item.Customer)
                .Include(item => item.Template)
                .FirstOrDefaultAsync(item => item.IdempotencyKey == key, cancellationToken);
            if (existing is not null)
            {
                return ServiceResult<CommunicationMessageDetailDto>.Ok(ToMessageDetail(existing), "Message already enqueued.");
            }
        }

        var template = await _db.CommunicationTemplates
            .FirstOrDefaultAsync(item => item.Id == request.TemplateId && !item.IsArchived && item.IsActive, cancellationToken);
        if (template is null)
        {
            return ServiceResult<CommunicationMessageDetailDto>.Fail(400, "Active template was not found.");
        }

        ApplicationUser? rider = null;
        if (!string.IsNullOrWhiteSpace(request.RiderUserId))
        {
            var riderId = request.RiderUserId.Trim();
            rider = await _db.Users.FirstOrDefaultAsync(
                item => item.Id == riderId && item.RiderCode != null && item.IsActive,
                cancellationToken);
            if (rider is null)
            {
                return ServiceResult<CommunicationMessageDetailDto>.Fail(404, "Rider was not found.");
            }
        }

        var destination = (request.DestinationNumber ?? "").Trim();
        if (rider is not null && string.IsNullOrWhiteSpace(destination))
        {
            destination = (rider.PhoneNumber ?? "").Trim();
        }

        if (rider is null && !IsValidPkMobile(destination))
        {
            return ServiceResult<CommunicationMessageDetailDto>.Fail(400, "Enter a valid Pakistan mobile number.");
        }

        if (string.IsNullOrWhiteSpace(destination))
        {
            destination = "in-app";
        }

        Customer? customer = null;
        if (request.CustomerId is Guid customerId)
        {
            customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == customerId && !item.IsDeleted, cancellationToken);
            if (customer is null)
            {
                return ServiceResult<CommunicationMessageDetailDto>.Fail(404, "Customer was not found.");
            }
        }

        var variables = request.Variables ?? new Dictionary<string, string>();
        if (customer is not null && !variables.ContainsKey("customer_name"))
        {
            variables["customer_name"] = customer.BusinessName;
        }

        var rendered = Render(template.Content, variables);
        var gateway = await GatewayStatusCoreAsync(null, cancellationToken);
        var inApp = rider is not null;
        var status = gateway.IsConfigured ? "Queued" : inApp ? "InApp" : "NotConfigured";
        var reason = gateway.IsConfigured || inApp ? null : "SMS gateway is not configured.";

        var message = new CommunicationMessage
        {
            MessageReference = $"MSG-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid():N}"[..28],
            CustomerId = customer?.Id,
            TemplateId = template.Id,
            TriggerType = template.TriggerType,
            DestinationNumber = destination,
            RenderedContent = rendered,
            Status = status,
            FailureReason = reason,
            TransactionReference = string.IsNullOrWhiteSpace(request.TransactionReference)
                ? null
                : request.TransactionReference.Trim(),
            IdempotencyKey = string.IsNullOrWhiteSpace(request.IdempotencyKey) ? null : request.IdempotencyKey.Trim()
        };
        _db.CommunicationMessages.Add(message);
        if (rider is not null)
        {
            _db.RiderInAppNotifications.Add(new RiderInAppNotification
            {
                RiderUserId = rider.Id,
                Title = template.Name,
                Body = rendered,
                DeepLink = $"message:{message.Id:N}",
                IdempotencyKey = $"comm:{message.Id:N}"
            });
        }
        AddAudit("EnqueueSmsMessage", "CommunicationMessage", message.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        message.Customer = customer;
        message.Template = template;
        return ServiceResult<CommunicationMessageDetailDto>.Created(ToMessageDetail(message), "Message recorded.");
    }

    public async Task<ServiceResult<CommunicationMessageDetailDto>> RetryAsync(Guid id, CancellationToken cancellationToken)
    {
        var item = await _db.CommunicationMessages
            .Include(row => row.Customer)
            .Include(row => row.Template)
            .FirstOrDefaultAsync(row => row.Id == id, cancellationToken);
        if (item is null)
        {
            return ServiceResult<CommunicationMessageDetailDto>.Fail(404, "Message was not found.");
        }

        if (item.Status.Equals("Delivered", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<CommunicationMessageDetailDto>.Fail(409, "Delivered messages cannot be retried.");
        }

        var gateway = await GatewayStatusCoreAsync(null, cancellationToken);
        if (!gateway.IsConfigured)
        {
            item.Status = "NotConfigured";
            item.FailureReason = "SMS gateway is not configured.";
            AddAudit("RetrySmsMessage", "CommunicationMessage", item.Id.ToString());
            await _db.SaveChangesAsync(cancellationToken);
            return ServiceResult<CommunicationMessageDetailDto>.Ok(ToMessageDetail(item), "Retry recorded; gateway still not configured.");
        }

        item.Status = "Queued";
        item.FailureReason = null;
        item.SubmittedAtUtc = null;
        AddAudit("RetrySmsMessage", "CommunicationMessage", item.Id.ToString());
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CommunicationMessageDetailDto>.Ok(ToMessageDetail(item), "Message re-queued.");
    }

    public async Task<ServiceResult<string>> ExportMessagesCsvAsync(
        DateOnly? date,
        string? status,
        CancellationToken cancellationToken)
    {
        var list = await ListMessagesAsync(date, status, null, 1, 100, cancellationToken);
        if (!list.Success || list.Data is null)
        {
            return ServiceResult<string>.Fail(list.StatusCode, list.Message, list.Errors?.ToArray() ?? []);
        }

        var builder = new StringBuilder();
        builder.AppendLine("MessageReference,Customer,Destination,Channel,Trigger,Transaction,CreatedAtUtc,Status,FailureReason");
        foreach (var row in list.Data)
        {
            builder.AppendLine(string.Join(',',
                Csv(row.MessageReference),
                Csv(row.CustomerName ?? ""),
                Csv(MaskPhone(row.DestinationNumber)),
                Csv(row.Channel),
                Csv(row.TriggerType),
                Csv(row.TransactionReference ?? ""),
                Csv(row.CreatedAtUtc.ToString("O", CultureInfo.InvariantCulture)),
                Csv(row.Status),
                Csv(row.FailureReason ?? "")));
        }

        return ServiceResult<string>.Ok(builder.ToString(), "Messages CSV export ready.");
    }

    private async Task<CommunicationGatewayStatusDto> GatewayStatusCoreAsync(int? messagesToday, CancellationToken cancellationToken)
    {
        if (messagesToday is null)
        {
            var (start, end) = ReportingWindow.UtcBounds(ReportingWindow.Today(), ReportingWindow.Today());
            messagesToday = await _db.CommunicationMessages.AsNoTracking()
                .CountAsync(item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end, cancellationToken);
        }
        return new CommunicationGatewayStatusDto(
            "Not configured",
            "NotConfigured",
            false,
            null,
            messagesToday.Value,
            "No SMS provider credentials are configured. Messages are recorded as NotConfigured until a gateway is approved and connected.",
            "Locked V1: secrets are never returned to Flutter. WhatsApp gateway is out of scope.");
    }

    private async Task EnsureDefaultTemplatesAsync(CancellationToken cancellationToken)
    {
        if (await _db.CommunicationTemplates.AnyAsync(cancellationToken))
        {
            return;
        }

        _db.CommunicationTemplates.AddRange(
            new CommunicationTemplate
            {
                TemplateCode = "T-01",
                Name = "Sale Delivery Slip",
                Language = "en",
                TriggerType = "DeliveryCompleted",
                Content = "Dear {customer_name}, your delivery receipt {receipt_no} totaling {amount} is confirmed. Thank you."
            },
            new CommunicationTemplate
            {
                TemplateCode = "T-02",
                Name = "Payment Collection",
                Language = "en",
                TriggerType = "PaymentCollected",
                Content = "Dear {customer_name}, we received {amount}. Remaining balance {remaining_balance}."
            },
            new CommunicationTemplate
            {
                TemplateCode = "T-03",
                Name = "Dispatch Schedule",
                Language = "en",
                TriggerType = "OrderDispatched",
                Content = "Dear {customer_name}, order {order_id} is on the way with rider {rider_name}."
            },
            new CommunicationTemplate
            {
                TemplateCode = "T-04",
                Name = "Overdue Reminder",
                Language = "ur",
                TriggerType = "BalanceRecoveryReminder",
                Content = "محترم {customer_name}، آپ کا بقایا {remaining_balance} ہے۔ براہ کرم جلد ادا کریں۔"
            });
        await _db.SaveChangesAsync(cancellationToken);
    }

    private void AddAudit(string action, string entity, string id)
    {
        if (string.IsNullOrWhiteSpace(_current.UserId))
        {
            return;
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId!,
            Action = action,
            EntityName = entity,
            EntityId = id
        });
    }

    private static CommunicationTemplateDto ToTemplate(CommunicationTemplate item) =>
        new(item.Id, item.TemplateCode, item.Name, item.Language, item.TriggerType, item.Content, item.IsActive, item.IsArchived, item.UpdatedAtUtc);

    private static CommunicationMessageRowDto ToMessageRow(CommunicationMessage item) =>
        new(
            item.Id,
            item.MessageReference,
            item.Customer?.BusinessName,
            MaskPhone(item.DestinationNumber),
            ChannelOf(item),
            item.TriggerType,
            item.TransactionReference,
            item.CreatedAtUtc,
            item.Status,
            item.FailureReason);

    private static CommunicationMessageDetailDto ToMessageDetail(CommunicationMessage item) =>
        new(
            item.Id,
            item.MessageReference,
            item.CustomerId,
            item.Customer?.BusinessName,
            MaskPhone(item.DestinationNumber),
            ChannelOf(item),
            item.TriggerType,
            item.TransactionReference,
            item.TemplateId,
            item.Template?.Name,
            item.RenderedContent,
            item.Status,
            item.FailureReason,
            item.IdempotencyKey,
            item.CreatedAtUtc,
            item.SubmittedAtUtc,
            "Delivery is never marked Delivered without a real provider callback.");

    private static string ChannelOf(CommunicationMessage item) =>
        item.Status.Equals("InApp", StringComparison.OrdinalIgnoreCase) ? "In-app" : "SMS";

    private static bool TryValidateTemplate(CommunicationTemplateWriteRequest request, out string? error)
    {
        if (string.IsNullOrWhiteSpace(request.Name)
            || string.IsNullOrWhiteSpace(request.TriggerType)
            || string.IsNullOrWhiteSpace(request.Content))
        {
            error = "Name, trigger type and content are required.";
            return false;
        }

        if (!Triggers.Any(item => item.Type.Equals(request.TriggerType.Trim(), StringComparison.OrdinalIgnoreCase)))
        {
            error = "Trigger type is not supported.";
            return false;
        }

        var language = NormalizeLanguage(request.Language);
        if (language is not ("en" or "ur"))
        {
            error = "Language must be en or ur.";
            return false;
        }

        foreach (Match match in Regex.Matches(request.Content, @"\{([a-zA-Z0-9_]+)\}"))
        {
            var key = match.Groups[1].Value;
            if (!AllowedVariables.Contains(key))
            {
                error = $"Placeholder {{{key}}} is not an approved variable.";
                return false;
            }
        }

        error = null;
        return true;
    }

    private static string Render(string content, Dictionary<string, string>? variables)
    {
        var text = content;
        if (variables is null)
        {
            return text;
        }

        foreach (var pair in variables)
        {
            if (!AllowedVariables.Contains(pair.Key))
            {
                continue;
            }

            text = text.Replace("{" + pair.Key + "}", pair.Value ?? "", StringComparison.OrdinalIgnoreCase);
        }

        return text;
    }

    private static string NormalizeLanguage(string? language)
    {
        var value = (language ?? "en").Trim().ToLowerInvariant();
        if (value is "urdu" or "ur")
        {
            return "ur";
        }

        return "en";
    }

    private static bool IsValidPkMobile(string value)
    {
        var digits = Regex.Replace(value, @"[^\d+]", "");
        return Regex.IsMatch(digits, @"^(\+92|0)?3\d{9}$");
    }

    private static string MaskPhone(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length < 4)
        {
            return "****";
        }

        return $"{value[..Math.Min(4, value.Length)]}****{value[^2..]}";
    }

    private static string Csv(string value)
    {
        if (value.Contains('"') || value.Contains(',') || value.Contains('\n'))
        {
            return $"\"{value.Replace("\"", "\"\"")}\"";
        }

        return value;
    }
}
