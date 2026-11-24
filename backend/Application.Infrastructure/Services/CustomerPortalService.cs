using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class CustomerPortalService : ICustomerPortalService
{
    private const string PaymentNote = "Online payment is not enabled. Billed and paid follow completed invoices and recorded cash. Outstanding is the stored balance and changes when a rider or the office records cash. This screen cannot mark a payment as received.";

    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;
    private readonly IRecurringScheduleService _schedules;

    public CustomerPortalService(AppDbContext db, ICurrentUser current, IRecurringScheduleService schedules)
    {
        _db = db;
        _current = current;
        _schedules = schedules;
    }

    public async Task<ServiceResult<CustomerHomeDto>> HomeAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerHomeDto>.Fail(404, "Customer account not found.");
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        var plans = customer is null ? [] : await PlansAsync(customer.Id, cancellationToken);
        var visits = customer is null ? [] : await VisitsAsync(customer, null, cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.Today).ToString("yyyy-MM-dd");
        var upcomingAll = visits.Where(item =>
            (item.Status is "Scheduled" or "Assigned" or "Out for Delivery")
            && string.CompareOrdinal(item.Date, today) >= 0).ToList();
        var upcoming = upcomingAll.Take(3).ToList();
        var money = await MoneyAsync(customer, cancellationToken);
        var unread = await _db.CustomerNotifications.CountAsync(item => item.CustomerAccountId == account.Id && item.ReadAt == null, cancellationToken);
        var pending = await _db.CustomerServiceRequests.CountAsync(item => item.CustomerAccountId == account.Id && (item.Status == CustomerRequestStatus.Pending || item.Status == CustomerRequestStatus.UnderReview || item.Status == CustomerRequestStatus.MoreInformationRequired), cancellationToken);
        var total = customer is null ? 0 : await _db.DeliveryOccurrences.CountAsync(item => item.CustomerId == customer.Id, cancellationToken);
        var active = plans.FirstOrDefault(item => item.Status == ScheduleStatus.Active) ?? plans.FirstOrDefault();
        var home = new CustomerHomeDto(
            account.FirstName,
            $"{account.FirstName} {account.LastName}".Trim(),
            account.Code,
            account.Status,
            customer is not null,
            customer is null
                ? "The office has not placed this account on a delivery route yet."
                : plans.Count == 0
                    ? "This account is linked, and no delivery schedule is active yet."
                    : "Requests do not change this schedule until the office approves them.",
            active,
            new CustomerCountsDto(
                visits.Count(item => item.Status is "Scheduled" or "Assigned" or "Out for Delivery"),
                visits.Count(item => item.Status == "Delivered"),
                upcomingAll.Count,
                visits.Count(item => item.Status is "Skipped" or "Cancelled" or "Missed"),
                total),
            money,
            upcoming,
            unread,
            plans.Count(item => item.Status == ScheduleStatus.Active),
            customer?.City ?? account.City,
            pending);
        return ServiceResult<CustomerHomeDto>.Ok(home, "Customer home loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerPlanDto>>> SchedulesAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<IReadOnlyList<CustomerPlanDto>>.Fail(404, "Customer account not found.");
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        if (customer is null) return ServiceResult<IReadOnlyList<CustomerPlanDto>>.Ok([], "No delivery route is linked.");
        return ServiceResult<IReadOnlyList<CustomerPlanDto>>.Ok(await PlansAsync(customer.Id, cancellationToken), "Schedules loaded.");
    }

    public async Task<ServiceResult<CustomerCalendarDto>> CalendarAsync(Guid scheduleId, int year, int month, CancellationToken cancellationToken)
    {
        if (month is < 1 or > 12 || year < 2024) return ServiceResult<CustomerCalendarDto>.Fail(400, "Choose a valid month.");
        var owned = await OwnedScheduleAsync(scheduleId, false, cancellationToken);
        if (owned.Error is not null) return ServiceResult<CustomerCalendarDto>.Fail(owned.Error.Value.Status, owned.Error.Value.Message);
        var schedule = owned.Schedule!;
        var customer = schedule.Customer;
        var start = new DateOnly(year, month, 1);
        var end = start.AddMonths(1).AddDays(-1);
        var pauses = OpenPauseDates(schedule);
        var days = new List<CustomerCalendarDayDto>();
        for (var date = start; date <= end; date = date.AddDays(1))
        {
            var items = schedule.Occurrences.Where(item => item.ServiceDate == date)
                .Select(item => Visit(item, customer, schedule, pauses))
                .ToList();
            var status = pauses.Contains(date) ? "Paused" : items.FirstOrDefault()?.Status ?? "";
            days.Add(new CustomerCalendarDayDto(date.ToString("yyyy-MM-dd"), status, items.Count, items));
        }

        return ServiceResult<CustomerCalendarDto>.Ok(new CustomerCalendarDto(year, month, days), "Calendar loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerVisitDto>>> HistoryAsync(Guid? scheduleId, string? status, DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<IReadOnlyList<CustomerVisitDto>>.Fail(404, "Customer account not found.");
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        if (customer is null) return ServiceResult<IReadOnlyList<CustomerVisitDto>>.Ok([], "No delivery route is linked.");
        var visits = await VisitsAsync(customer, scheduleId, cancellationToken);
        if (from is DateOnly start) visits = visits.Where(item => string.CompareOrdinal(item.Date, start.ToString("yyyy-MM-dd")) >= 0).ToList();
        if (to is DateOnly finish) visits = visits.Where(item => string.CompareOrdinal(item.Date, finish.ToString("yyyy-MM-dd")) <= 0).ToList();
        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            visits = visits.Where(item => item.Status.Equals(status.Trim(), StringComparison.OrdinalIgnoreCase)).ToList();
        }

        return ServiceResult<IReadOnlyList<CustomerVisitDto>>.Ok(visits.Take(200).ToList(), "Delivery history loaded.");
    }

    public async Task<ServiceResult<CustomerPaymentsDto>> PaymentsAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerPaymentsDto>.Fail(404, "Customer account not found.");
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        return ServiceResult<CustomerPaymentsDto>.Ok(await BuildPaymentsAsync(customer, cancellationToken), customer is null ? "No delivery route is linked." : "Payments loaded.");
    }

    public async Task<ServiceResult<CustomerInvoiceDetailDto>> InvoiceAsync(string number, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(number)) return ServiceResult<CustomerInvoiceDetailDto>.Fail(400, "Choose an invoice.");
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerInvoiceDetailDto>.Fail(404, "Customer account not found.");
        if (account.DeliveryCustomerId is not Guid customerId) return ServiceResult<CustomerInvoiceDetailDto>.Fail(404, "No delivery route is linked.");
        var sale = await _db.Sales.AsNoTracking()
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .FirstOrDefaultAsync(item => item.CustomerId == customerId && item.ReceiptNumber == number.Trim() && item.Status == SaleStatus.Completed, cancellationToken);
        if (sale is null) return ServiceResult<CustomerInvoiceDetailDto>.Fail(404, "Invoice not found.");
        var customer = await _db.Customers.AsNoTracking().FirstAsync(item => item.Id == customerId, cancellationToken);
        var remaining = sale.SaleAmount > sale.AmountReceived ? sale.SaleAmount - sale.AmountReceived : 0;
        var lines = sale.Lines.Select(line => new CustomerInvoiceLineDto(line.Product?.Name ?? "Product", line.Quantity, line.UnitPrice, line.Quantity * line.UnitPrice)).ToList();
        var payments = sale.AmountReceived <= 0
            ? new List<CustomerPaymentRowDto>()
            : new List<CustomerPaymentRowDto> { new(sale.ReceiptNumber, sale.CreatedAt.ToString("yyyy-MM-dd"), sale.AmountReceived, ChannelName(sale.PaymentChannel), InvoiceState(sale.SaleAmount, sale.AmountReceived, false), sale.ReceiptNumber) };
        var detail = new CustomerInvoiceDetailDto(
            sale.ReceiptNumber,
            sale.CreatedAt.ToString("yyyy-MM-dd"),
            sale.SaleAmount,
            sale.AmountReceived,
            remaining,
            InvoiceState(sale.SaleAmount, sale.AmountReceived, InvoiceOverdue(customer, sale.CreatedAt, remaining)),
            lines,
            payments,
            "A PDF copy of this invoice can be downloaded.");
        return ServiceResult<CustomerInvoiceDetailDto>.Ok(detail, "Invoice loaded.");
    }

    private async Task<CustomerPaymentsDto> BuildPaymentsAsync(Customer? customer, CancellationToken cancellationToken)
    {
        var money = await MoneyAsync(customer, cancellationToken);
        if (customer is null) return new CustomerPaymentsDto(money, [], []);
        var sales = await _db.Sales.AsNoTracking()
            .Where(item => item.CustomerId == customer.Id && item.Status == SaleStatus.Completed)
            .OrderByDescending(item => item.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        var collections = await _db.Collections.AsNoTracking()
            .Where(item => item.CustomerId == customer.Id)
            .OrderByDescending(item => item.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        var payments = sales.Where(item => item.AmountReceived > 0)
            .Select(item => new CustomerPaymentRowDto(item.ReceiptNumber, item.CreatedAt.ToString("yyyy-MM-dd"), item.AmountReceived, ChannelName(item.PaymentChannel), PaymentState(item.SaleAmount, item.AmountReceived), item.ReceiptNumber))
            .Concat(collections.Select(item => new CustomerPaymentRowDto(item.ReferenceNumber, item.CreatedAt.ToString("yyyy-MM-dd"), item.Amount, ChannelName(item.Channel), item.CashStatus == CashCollectionStatus.CashReceived ? "Cash Received" : "Collected by Rider", null)))
            .OrderByDescending(item => item.Date)
            .ToList();
        var invoices = sales
            .Select(item =>
            {
                var remaining = item.SaleAmount > item.AmountReceived ? item.SaleAmount - item.AmountReceived : 0;
                return new CustomerInvoiceRowDto(item.ReceiptNumber, item.CreatedAt.ToString("yyyy-MM-dd"), item.SaleAmount, item.AmountReceived, remaining, InvoiceState(item.SaleAmount, item.AmountReceived, InvoiceOverdue(customer, item.CreatedAt, remaining)));
            })
            .ToList();
        return new CustomerPaymentsDto(money, payments, invoices);
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerRequestDto>>> RequestsAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<IReadOnlyList<CustomerRequestDto>>.Fail(404, "Customer account not found.");
        var rows = await RequestQuery().Where(item => item.CustomerAccountId == account.Id).OrderByDescending(item => item.CreatedAt).ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<CustomerRequestDto>>.Ok(rows.Select(MapRequest).ToList(), "Requests loaded.");
    }

    public async Task<ServiceResult<CustomerRequestDto>> RequestAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Customer account not found.");
        var row = await RequestQuery().FirstOrDefaultAsync(item => item.Id == id && item.CustomerAccountId == account.Id, cancellationToken);
        if (row is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Request not found.");
        return ServiceResult<CustomerRequestDto>.Ok(MapRequest(row), "Request loaded.");
    }

    public async Task<ServiceResult<CustomerRequestDto>> SubmitAsync(SubmitCustomerRequest request, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Customer account not found.");
        if (account.Status.Equals("Suspended", StringComparison.OrdinalIgnoreCase)) return ServiceResult<CustomerRequestDto>.Fail(403, "This customer account is suspended.");
        if (string.IsNullOrWhiteSpace(request.Reason)) return ServiceResult<CustomerRequestDto>.Fail(400, "A reason is required.");
        var type = NormalizeType(request.Type);
        if (type is null) return ServiceResult<CustomerRequestDto>.Fail(400, "Choose a request type.");
        if (account.DeliveryCustomerId is null) return ServiceResult<CustomerRequestDto>.Fail(409, "The office has not placed this account on a delivery route yet.");
        if (request.ScheduleId is not Guid scheduleId) return ServiceResult<CustomerRequestDto>.Fail(400, "Choose a schedule.");
        var owned = await OwnedScheduleAsync(scheduleId, false, cancellationToken);
        if (owned.Error is not null) return ServiceResult<CustomerRequestDto>.Fail(owned.Error.Value.Status, owned.Error.Value.Message);
        var schedule = owned.Schedule!;
        var open = new[] { CustomerRequestStatus.Pending, CustomerRequestStatus.UnderReview, CustomerRequestStatus.MoreInformationRequired };
        if (await _db.CustomerServiceRequests.AnyAsync(item => item.CustomerAccountId == account.Id && item.ScheduleId == schedule.Id && item.Type == type && open.Contains(item.Status), cancellationToken))
        {
            return ServiceResult<CustomerRequestDto>.Fail(409, "A request of this type is already waiting for review.");
        }

        var row = new CustomerServiceRequest
        {
            Code = await NextCodeAsync(cancellationToken),
            CustomerAccountId = account.Id,
            DeliveryCustomerId = account.DeliveryCustomerId,
            ScheduleId = schedule.Id,
            Type = type,
            Status = CustomerRequestStatus.Pending,
            Reason = Trim(request.Reason, 300) ?? "",
            Notes = Trim(request.Notes, 500),
            CurrentSummary = CurrentSummary(schedule)
        };
        var problem = FillRequest(row, request, schedule);
        if (problem is not null) return ServiceResult<CustomerRequestDto>.Fail(400, problem);
        _db.CustomerServiceRequests.Add(row);
        AddAudit("SubmitCustomerRequest", row.Id.ToString(), "CustomerServiceRequest");
        AddNotification(account.Id, "Request received", $"{row.Code} is waiting for office review. The schedule is unchanged.", type, row.Id);
        AddNotice(row.Id, "New customer request", $"{row.Code} {type} is waiting for review.");
        await _db.SaveChangesAsync(cancellationToken);
        var saved = await RequestQuery().FirstAsync(item => item.Id == row.Id, cancellationToken);
        return ServiceResult<CustomerRequestDto>.Created(MapRequest(saved), "Request submitted. The schedule is unchanged until the office approves it.");
    }

    public async Task<ServiceResult<CustomerRequestPreviewDto>> PreviewAsync(SubmitCustomerRequest request, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerRequestPreviewDto>.Fail(404, "Customer account not found.");
        if (request.ScheduleId is not Guid scheduleId) return ServiceResult<CustomerRequestPreviewDto>.Fail(400, "Choose a schedule.");
        var owned = await OwnedScheduleAsync(scheduleId, false, cancellationToken);
        if (owned.Error is not null) return ServiceResult<CustomerRequestPreviewDto>.Fail(owned.Error.Value.Status, owned.Error.Value.Message);
        var schedule = owned.Schedule!;
        var type = NormalizeType(request.Type);
        if (type is null) return ServiceResult<CustomerRequestPreviewDto>.Fail(400, "Choose a request type.");
        var row = new CustomerServiceRequest { Type = type, Reason = request.Reason };
        var problem = FillRequest(row, request, schedule);
        if (problem is not null) return ServiceResult<CustomerRequestPreviewDto>.Fail(400, problem);
        var counts = ImpactCounts(schedule, row);
        return ServiceResult<CustomerRequestPreviewDto>.Ok(new CustomerRequestPreviewDto(
            row.RequestedSummary,
            row.AffectedDates,
            counts.Scheduled,
            counts.Published,
            counts.Completed,
            "Dispatched visits stay assigned. Approval does not recall them.",
            "Inventory availability is not calculated on this request.",
            "Issued invoices stay as recorded. This request does not change a completed sale."), "Preview loaded.");
    }

    public async Task<ServiceResult<CustomerRequestDto>> CancelAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Customer account not found.");
        var row = await _db.CustomerServiceRequests.FirstOrDefaultAsync(item => item.Id == id && item.CustomerAccountId == account.Id, cancellationToken);
        if (row is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Request not found.");
        if (row.Status is not (CustomerRequestStatus.Pending or CustomerRequestStatus.UnderReview or CustomerRequestStatus.MoreInformationRequired))
        {
            return ServiceResult<CustomerRequestDto>.Fail(409, "Only a request that is still waiting can be cancelled.");
        }

        row.Status = CustomerRequestStatus.Cancelled;
        row.ReviewedAt = DateTime.UtcNow;
        AddAudit("CancelCustomerRequest", row.Id.ToString(), "CustomerServiceRequest");
        AddNotification(account.Id, "Request cancelled", $"{row.Code} was cancelled. The schedule is unchanged.", row.Type, row.Id);
        AddNotice(row.Id, "Customer request cancelled", $"{row.Code} was cancelled by the customer.");
        await _db.SaveChangesAsync(cancellationToken);
        var saved = await RequestQuery().FirstAsync(item => item.Id == row.Id, cancellationToken);
        return ServiceResult<CustomerRequestDto>.Ok(MapRequest(saved), "Request cancelled. The schedule is unchanged.");
    }

    public async Task<ServiceResult<CustomerRequestDto>> ReplyAsync(Guid id, string notes, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Customer account not found.");
        var text = Trim(notes, 500);
        if (string.IsNullOrWhiteSpace(text)) return ServiceResult<CustomerRequestDto>.Fail(400, "A reply is required.");
        var row = await _db.CustomerServiceRequests.FirstOrDefaultAsync(item => item.Id == id && item.CustomerAccountId == account.Id, cancellationToken);
        if (row is null) return ServiceResult<CustomerRequestDto>.Fail(404, "Request not found.");
        if (row.Status != CustomerRequestStatus.MoreInformationRequired) return ServiceResult<CustomerRequestDto>.Fail(409, "The office has not asked for more information on this request.");
        row.Notes = text;
        row.Status = CustomerRequestStatus.Pending;
        AddAudit("ReplyCustomerRequest", row.Id.ToString(), "CustomerServiceRequest");
        AddNotification(account.Id, "Reply sent", $"{row.Code} is waiting for office review again.", row.Type, row.Id);
        AddNotice(row.Id, "Customer replied", $"{row.Code} has a reply and is waiting for review.");
        await _db.SaveChangesAsync(cancellationToken);
        var saved = await RequestQuery().FirstAsync(item => item.Id == row.Id, cancellationToken);
        return ServiceResult<CustomerRequestDto>.Ok(MapRequest(saved), "Reply sent. The schedule is unchanged.");
    }

    public async Task<ServiceResult<CustomerProfileDto>> ProfileAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerProfileDto>.Fail(404, "Customer account not found.");
        await EnsureHomeAddressAsync(account, cancellationToken);
        return ServiceResult<CustomerProfileDto>.Ok(await ProfileOfAsync(account, cancellationToken), "Profile loaded.");
    }

    public async Task<ServiceResult<CustomerProfileDto>> UpdateProfileAsync(UpdateCustomerProfileRequest request, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerProfileDto>.Fail(404, "Customer account not found.");
        var first = Trim(request.FirstName, 80);
        var last = Trim(request.LastName, 80);
        if (string.IsNullOrWhiteSpace(first) || string.IsNullOrWhiteSpace(last)) return ServiceResult<CustomerProfileDto>.Fail(400, "First name and last name are required.");
        var phone = NormalizePhone(request.Phone);
        if (phone is null) return ServiceResult<CustomerProfileDto>.Fail(400, "Enter a valid phone number.");
        var taken = await _db.CustomerAccounts.AnyAsync(item => item.Id != account.Id && item.Phone == phone, cancellationToken);
        if (taken) return ServiceResult<CustomerProfileDto>.Fail(409, "That phone number is already used.");
        account.FirstName = first;
        account.LastName = last;
        account.Phone = phone;
        var user = await _db.Users.FirstOrDefaultAsync(item => item.Id == account.UserId, cancellationToken);
        if (user is not null)
        {
            user.FullName = $"{first} {last}".Trim();
            user.PhoneNumber = phone;
        }

        AddAudit("UpdateCustomerProfile", account.Id.ToString(), "CustomerAccount");
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerProfileDto>.Ok(await ProfileOfAsync(account, cancellationToken), "Profile updated. The email, customer ID, and account status are unchanged.");
    }

    public async Task<ServiceResult<CustomerAddressDto>> SaveAddressAsync(Guid? id, SaveCustomerAddressRequest request, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Customer account not found.");
        var problem = AddressProblem(request);
        if (problem is not null) return ServiceResult<CustomerAddressDto>.Fail(400, problem);
        CustomerSavedAddress row;
        if (id is Guid addressId)
        {
            var existing = await _db.CustomerSavedAddresses.FirstOrDefaultAsync(item => item.Id == addressId && item.CustomerAccountId == account.Id, cancellationToken);
            if (existing is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Address not found.");
            row = existing;
        }
        else
        {
            var any = await _db.CustomerSavedAddresses.AnyAsync(item => item.CustomerAccountId == account.Id, cancellationToken);
            row = new CustomerSavedAddress { CustomerAccountId = account.Id, IsDefault = !any };
            _db.CustomerSavedAddresses.Add(row);
        }

        CopyAddress(row, request);
        AddAudit(id is null ? "AddCustomerAddress" : "EditCustomerAddress", row.Id.ToString(), "CustomerSavedAddress");
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerAddressDto>.Ok(MapAddress(row), id is null ? "Address saved." : "Address updated. Active schedules keep their current address.");
    }

    public async Task<ServiceResult<CustomerAddressDto>> DefaultAddressAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Customer account not found.");
        var rows = await _db.CustomerSavedAddresses.Where(item => item.CustomerAccountId == account.Id).ToListAsync(cancellationToken);
        var chosen = rows.FirstOrDefault(item => item.Id == id && item.IsActive);
        if (chosen is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Address not found.");
        foreach (var row in rows) row.IsDefault = row.Id == id;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerAddressDto>.Ok(MapAddress(chosen), "Default address updated. Active schedules keep their current address.");
    }

    public async Task<ServiceResult<CustomerAddressDto>> DeactivateAddressAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Customer account not found.");
        var rows = await _db.CustomerSavedAddresses.Where(item => item.CustomerAccountId == account.Id).ToListAsync(cancellationToken);
        var chosen = rows.FirstOrDefault(item => item.Id == id);
        if (chosen is null) return ServiceResult<CustomerAddressDto>.Fail(404, "Address not found.");
        if (rows.Count(item => item.IsActive && item.Id != id) == 0) return ServiceResult<CustomerAddressDto>.Fail(409, "Keep at least one active address.");
        chosen.IsActive = false;
        chosen.IsDefault = false;
        if (rows.All(item => !item.IsDefault))
        {
            var replacement = rows.First(item => item.IsActive);
            replacement.IsDefault = true;
        }

        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerAddressDto>.Ok(MapAddress(chosen), "Address deactivated. Delivery history is unchanged.");
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerNotificationDto>>> NotificationsAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<IReadOnlyList<CustomerNotificationDto>>.Fail(404, "Customer account not found.");
        var rows = await _db.CustomerNotifications.AsNoTracking()
            .Where(item => item.CustomerAccountId == account.Id)
            .OrderByDescending(item => item.CreatedAt)
            .Take(50)
            .ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<CustomerNotificationDto>>.Ok(rows.Select(item => new CustomerNotificationDto(item.Id, item.Title, item.Body, item.Kind, item.ReadAt != null, item.CreatedAt.ToString("yyyy-MM-dd HH:mm"), item.RequestId)).ToList(), "Notifications loaded.");
    }

    public async Task<ServiceResult<object>> ReadNotificationAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<object>.Fail(404, "Customer account not found.");
        var row = await _db.CustomerNotifications.FirstOrDefaultAsync(item => item.Id == id && item.CustomerAccountId == account.Id, cancellationToken);
        if (row is null) return ServiceResult<object>.Fail(404, "Notification not found.");
        row.ReadAt ??= DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Notification marked read.");
    }

    public async Task<ServiceResult<object>> ReadAllNotificationsAsync(CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return ServiceResult<object>.Fail(404, "Customer account not found.");
        var rows = await _db.CustomerNotifications.Where(item => item.CustomerAccountId == account.Id && item.ReadAt == null).ToListAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var row in rows) row.ReadAt = now;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Notifications marked read.");
    }

    public async Task<ServiceResult<CustomerOpsOverviewDto>> OverviewAsync(CancellationToken cancellationToken)
    {
        var total = await _db.CustomerAccounts.CountAsync(cancellationToken);
        var active = await _db.CustomerAccounts.CountAsync(item => item.Status == "Active", cancellationToken);
        var linked = await _db.CustomerAccounts.AsNoTracking().Where(item => item.DeliveryCustomerId != null).Select(item => item.DeliveryCustomerId!.Value).ToListAsync(cancellationToken);
        var withSchedules = linked.Count == 0 ? 0 : await _db.RecurringSchedules.Where(item => linked.Contains(item.CustomerId) && item.Status == ScheduleStatus.Active).Select(item => item.CustomerId).Distinct().CountAsync(cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.Today);
        var upcomingCount = await _db.DeliveryOccurrences.CountAsync(item => item.ServiceDate >= today && (item.Status == OccurrenceStatus.Scheduled || item.Status == OccurrenceStatus.Published), cancellationToken);
        var completed = await _db.DeliveryOccurrences.CountAsync(item => item.Status == OccurrenceStatus.Completed, cancellationToken);
        var withBalance = linked.Count == 0 ? 0 : await _db.Customers.CountAsync(item => linked.Contains(item.Id) && item.Outstanding > 0, cancellationToken);
        var pending = await _db.CustomerServiceRequests.CountAsync(item => item.Status == CustomerRequestStatus.Pending || item.Status == CustomerRequestStatus.UnderReview || item.Status == CustomerRequestStatus.MoreInformationRequired, cancellationToken);
        var registrations = new List<CustomerMonthCountDto>();
        var deliveries = new List<CustomerMonthCountDto>();
        for (var offset = 5; offset >= 0; offset--)
        {
            var month = new DateOnly(today.Year, today.Month, 1).AddMonths(-offset);
            var end = month.AddMonths(1).AddDays(-1);
            var startTime = month.ToDateTime(TimeOnly.MinValue);
            var endTime = end.ToDateTime(TimeOnly.MaxValue);
            registrations.Add(new CustomerMonthCountDto(month.ToString("yyyy-MM"), await _db.CustomerAccounts.CountAsync(item => item.CreatedAt >= startTime && item.CreatedAt <= endTime, cancellationToken)));
            deliveries.Add(new CustomerMonthCountDto(month.ToString("yyyy-MM"), await _db.DeliveryOccurrences.CountAsync(item => item.ServiceDate >= month && item.ServiceDate <= end, cancellationToken)));
        }

        var next = await _db.DeliveryOccurrences.AsNoTracking()
            .Include(item => item.Schedule).ThenInclude(item => item.Customer)
            .Where(item => item.ServiceDate >= today && (item.Status == OccurrenceStatus.Scheduled || item.Status == OccurrenceStatus.Published))
            .OrderBy(item => item.ServiceDate)
            .Take(8)
            .ToListAsync(cancellationToken);
        var rows = next.Select(item => new CustomerOpsRowDto(
            item.ServiceDate.ToString("yyyy-MM-dd"),
            item.Schedule.Customer.BusinessName,
            item.Schedule.ScheduleCode,
            item.Quantity,
            item.Status,
            string.IsNullOrWhiteSpace(item.AddressSnapshot) ? AddressOf(item.Schedule.Customer) : item.AddressSnapshot)).ToList();
        return ServiceResult<CustomerOpsOverviewDto>.Ok(new CustomerOpsOverviewDto(total, active, withSchedules, upcomingCount, completed, withBalance, pending, registrations, deliveries, rows), "Customer overview loaded.");
    }

    public async Task<ServiceResult<CustomerAccountBoardDto>> AccountBoardAsync(string? search, string? status, CancellationToken cancellationToken)
    {
        var accounts = await _db.CustomerAccounts.AsNoTracking().OrderByDescending(item => item.CreatedAt).ToListAsync(cancellationToken);
        var links = accounts.Where(item => item.DeliveryCustomerId != null).Select(item => item.DeliveryCustomerId!.Value).Distinct().ToList();
        var customers = await _db.Customers.AsNoTracking().Where(item => links.Contains(item.Id)).ToListAsync(cancellationToken);
        var scheduleCounts = await _db.RecurringSchedules.AsNoTracking()
            .Where(item => links.Contains(item.CustomerId) && item.Status == ScheduleStatus.Active)
            .GroupBy(item => item.CustomerId)
            .Select(item => new { item.Key, Count = item.Count() })
            .ToListAsync(cancellationToken);
        var pendingRows = await _db.CustomerServiceRequests.AsNoTracking()
            .Where(item => item.Status == CustomerRequestStatus.Pending || item.Status == CustomerRequestStatus.UnderReview || item.Status == CustomerRequestStatus.MoreInformationRequired)
            .GroupBy(item => item.CustomerAccountId)
            .Select(item => new { item.Key, Count = item.Count() })
            .ToListAsync(cancellationToken);
        var rows = accounts.Select(account =>
        {
            var customer = customers.FirstOrDefault(item => item.Id == account.DeliveryCustomerId);
            return MapAccount(account, customer, scheduleCounts.FirstOrDefault(item => item.Key == account.DeliveryCustomerId)?.Count ?? 0, pendingRows.FirstOrDefault(item => item.Key == account.Id)?.Count ?? 0);
        }).ToList();
        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            rows = rows.Where(item => item.Status.Equals(status.Trim(), StringComparison.OrdinalIgnoreCase)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            rows = rows.Where(item =>
                item.Name.Contains(term, StringComparison.OrdinalIgnoreCase)
                || item.Code.Contains(term, StringComparison.OrdinalIgnoreCase)
                || item.Phone.Contains(term, StringComparison.OrdinalIgnoreCase)
                || item.Email.Contains(term, StringComparison.OrdinalIgnoreCase)
                || item.City.Contains(term, StringComparison.OrdinalIgnoreCase)
                || (item.DeliveryCustomerName ?? "").Contains(term, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        var board = new CustomerAccountBoardDto(
            rows.Count,
            rows.Count(item => item.Status == "Active"),
            rows.Count(item => item.Status != "Active"),
            rows.Count(item => item.ActiveSchedules > 0),
            rows.Count(item => item.Outstanding > 0),
            rows.Sum(item => item.PendingRequests),
            rows);
        return ServiceResult<CustomerAccountBoardDto>.Ok(board, "Customer accounts loaded.");
    }

    public async Task<ServiceResult<CustomerAccountDetailDto>> AccountAsync(Guid id, CancellationToken cancellationToken)
    {
        var account = await _db.CustomerAccounts.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (account is null) return ServiceResult<CustomerAccountDetailDto>.Fail(404, "Customer account not found.");
        return ServiceResult<CustomerAccountDetailDto>.Ok(await DetailAsync(account, cancellationToken), "Customer account loaded.");
    }

    public async Task<ServiceResult<CustomerAccountDetailDto>> LinkAsync(Guid id, Guid? deliveryCustomerId, CancellationToken cancellationToken)
    {
        var account = await _db.CustomerAccounts.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (account is null) return ServiceResult<CustomerAccountDetailDto>.Fail(404, "Customer account not found.");
        string action;
        if (deliveryCustomerId is null)
        {
            action = account.DeliveryCustomerId is null ? "Link unchanged." : "Route customer unlinked.";
            account.DeliveryCustomerId = null;
        }
        else
        {
            return ServiceResult<CustomerAccountDetailDto>.Fail(409, "Approve a pending link review. A route customer is linked only after that approval.");
        }

        AddAudit("LinkCustomerAccount", account.Id.ToString(), "CustomerAccount");
        AddNotification(account.Id, "Account updated", action, "Account");
        await _db.SaveChangesAsync(cancellationToken);
        var fresh = await _db.CustomerAccounts.AsNoTracking().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<CustomerAccountDetailDto>.Ok(await DetailAsync(fresh, cancellationToken), action);
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerAccountRowDto>>> UnlinkedAsync(CancellationToken cancellationToken)
    {
        var board = await AccountBoardAsync(null, null, cancellationToken);
        if (!board.Success || board.Data is null) return ServiceResult<IReadOnlyList<CustomerAccountRowDto>>.Fail(board.StatusCode, board.Message);
        IReadOnlyList<CustomerAccountRowDto> rows = board.Data.Rows.Where(item => !item.Linked).ToList();
        return ServiceResult<IReadOnlyList<CustomerAccountRowDto>>.Ok(rows, rows.Count == 0 ? "Every portal account is linked." : "Unlinked portal accounts loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerLinkReviewDto>>> LinkReviewsAsync(string? status, CancellationToken cancellationToken)
    {
        var query = _db.CustomerLinkReviews.AsNoTracking().Include(item => item.Account).AsQueryable();
        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(item => item.Status == status.Trim());
        }

        var reviews = await query.OrderByDescending(item => item.CreatedAt).Take(100).ToListAsync(cancellationToken);
        var customerIds = reviews.Select(item => item.DeliveryCustomerId).Distinct().ToList();
        var customers = await _db.Customers.AsNoTracking().Where(item => customerIds.Contains(item.Id)).ToListAsync(cancellationToken);
        IReadOnlyList<CustomerLinkReviewDto> rows = reviews.Select(item => MapReview(item, customers.FirstOrDefault(customer => customer.Id == item.DeliveryCustomerId))).ToList();
        return ServiceResult<IReadOnlyList<CustomerLinkReviewDto>>.Ok(rows, "Link reviews loaded.");
    }

    public async Task<ServiceResult<CustomerLinkReviewDto>> ProposeLinkAsync(Guid accountId, string email, string customerCode, CancellationToken cancellationToken)
    {
        var account = await _db.CustomerAccounts.FirstOrDefaultAsync(item => item.Id == accountId, cancellationToken);
        if (account is null) return ServiceResult<CustomerLinkReviewDto>.Fail(404, "Customer account not found.");
        if (account.DeliveryCustomerId is not null) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "This portal account is already linked.");
        if (!string.Equals(account.Email.Trim(), (email ?? "").Trim(), StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<CustomerLinkReviewDto>.Fail(400, "The email must match this portal account.");
        }

        var code = (customerCode ?? "").Trim();
        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Code == code && !item.IsDeleted, cancellationToken);
        if (customer is null) return ServiceResult<CustomerLinkReviewDto>.Fail(404, "No route customer has that ID.");
        var taken = await _db.CustomerAccounts.AnyAsync(item => item.DeliveryCustomerId == customer.Id, cancellationToken);
        if (taken) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "That route customer is already linked to another account.");
        var pending = await _db.CustomerLinkReviews.AnyAsync(item => item.Status == LinkReviewStatus.Pending && (item.CustomerAccountId == account.Id || item.DeliveryCustomerId == customer.Id), cancellationToken);
        if (pending) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "A link review is already waiting for this account or route customer.");
        var review = new CustomerLinkReview
        {
            CustomerAccountId = account.Id,
            DeliveryCustomerId = customer.Id,
            MatchBasis = "EmailAndCustomerId",
            Status = LinkReviewStatus.Pending,
            RequestedByUserId = _current.UserId ?? ""
        };
        review.Account = account;
        _db.CustomerLinkReviews.Add(review);
        AddAudit("ProposeCustomerLink", review.Id.ToString(), "CustomerLinkReview");
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerLinkReviewDto>.Ok(MapReview(review, customer), "Link review submitted. The account stays unlinked until it is approved.");
    }

    public async Task<ServiceResult<CustomerLinkReviewDto>> ReviewLinkAsync(Guid reviewId, string action, string? comment, CancellationToken cancellationToken)
    {
        var review = await _db.CustomerLinkReviews.Include(item => item.Account).FirstOrDefaultAsync(item => item.Id == reviewId, cancellationToken);
        if (review is null) return ServiceResult<CustomerLinkReviewDto>.Fail(404, "Link review not found.");
        if (review.Status != LinkReviewStatus.Pending) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "This link review is already closed.");
        var customer = await _db.Customers.FirstOrDefaultAsync(item => item.Id == review.DeliveryCustomerId && !item.IsDeleted, cancellationToken);
        if (customer is null) return ServiceResult<CustomerLinkReviewDto>.Fail(404, "Route customer not found.");
        var decision = (action ?? "").Trim().ToLowerInvariant();
        if (decision is not ("approve" or "reject")) return ServiceResult<CustomerLinkReviewDto>.Fail(400, "Choose approve or reject.");
        if (decision == "reject" && string.IsNullOrWhiteSpace(comment)) return ServiceResult<CustomerLinkReviewDto>.Fail(400, "A comment is required.");
        if (decision == "approve")
        {
            if (review.Account.DeliveryCustomerId is not null) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "This portal account is already linked.");
            var taken = await _db.CustomerAccounts.AnyAsync(item => item.DeliveryCustomerId == customer.Id, cancellationToken);
            if (taken) return ServiceResult<CustomerLinkReviewDto>.Fail(409, "That route customer is already linked to another account.");
            review.Account.DeliveryCustomerId = customer.Id;
            review.Status = LinkReviewStatus.Approved;
            AddNotification(review.Account.Id, "Account linked", $"Route customer {customer.Code} is linked to this account.", "Account");
        }
        else
        {
            review.Status = LinkReviewStatus.Rejected;
        }

        review.Comment = string.IsNullOrWhiteSpace(comment) ? null : comment.Trim();
        review.ReviewedByUserId = _current.UserId;
        review.ReviewedAt = DateTime.UtcNow;
        AddAudit(decision == "approve" ? "ApproveCustomerLink" : "RejectCustomerLink", review.Id.ToString(), "CustomerLinkReview");
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<CustomerLinkReviewDto>.Ok(MapReview(review, customer), decision == "approve" ? "Link approved." : "Link rejected.");
    }

    public async Task<ServiceResult<PolicyDocumentDto>> PolicyAsync(string kind, CancellationToken cancellationToken)
    {
        var profile = await _db.BusinessProfiles.AsNoTracking().OrderBy(item => item.CreatedAtUtc).FirstOrDefaultAsync(cancellationToken);
        var key = (kind ?? "").Trim().ToLowerInvariant();
        var title = key switch
        {
            "privacy" => "Privacy Policy",
            "terms" => "Terms & Conditions",
            _ => ""
        };
        if (title.Length == 0) return ServiceResult<PolicyDocumentDto>.Fail(404, "That document is not published.");
        var body = key == "privacy" ? PolicyCopy.Privacy : PolicyCopy.Terms;
        body = body
            .Replace("[Insert Official Support Email]", string.IsNullOrWhiteSpace(profile?.SupportEmail) ? "Office contact email is not set." : profile!.SupportEmail)
            .Replace("[Insert Official Contact Number]", string.IsNullOrWhiteSpace(profile?.SupportPhone) ? "Office contact number is not set." : profile!.SupportPhone)
            .Replace("[Insert Registered Business Address]", string.IsNullOrWhiteSpace(profile?.SupportAddress) ? "Office address is not set." : profile!.SupportAddress)
            .Replace("[Insert Official Website]", string.IsNullOrWhiteSpace(profile?.Website) ? "Office website is not set." : profile!.Website);
        return ServiceResult<PolicyDocumentDto>.Ok(new PolicyDocumentDto(title, body), "Document loaded.");
    }

    private static CustomerLinkReviewDto MapReview(CustomerLinkReview review, Customer? customer) => new(
        review.Id,
        review.CustomerAccountId,
        review.Account?.Code ?? "",
        $"{review.Account?.FirstName} {review.Account?.LastName}".Trim(),
        review.Account?.Email ?? "",
        review.DeliveryCustomerId,
        customer?.Code ?? "",
        customer?.BusinessName ?? "",
        review.Status,
        review.Comment,
        review.CreatedAt.ToString("yyyy-MM-dd HH:mm"));

    public async Task<ServiceResult<CustomerAccountDetailDto>> SetStatusAsync(Guid id, string status, CancellationToken cancellationToken)
    {
        var normalized = status.Trim();
        if (normalized is not ("Active" or "Suspended")) return ServiceResult<CustomerAccountDetailDto>.Fail(400, "Choose Active or Suspended.");
        var account = await _db.CustomerAccounts.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (account is null) return ServiceResult<CustomerAccountDetailDto>.Fail(404, "Customer account not found.");
        var previous = account.Status;
        account.Status = normalized;
        AddAudit(normalized == "Suspended" ? "SuspendCustomerAccount" : "ReactivateCustomerAccount", account.Id.ToString(), "CustomerAccount");
        AddNotification(account.Id, normalized == "Suspended" ? "Account suspended" : "Account active", $"Status changed from {previous} to {normalized}.", "Account");
        await _db.SaveChangesAsync(cancellationToken);
        var fresh = await _db.CustomerAccounts.AsNoTracking().FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<CustomerAccountDetailDto>.Ok(await DetailAsync(fresh, cancellationToken), "Account status updated.");
    }

    public async Task<ServiceResult<IReadOnlyList<CustomerRequestDto>>> QueueAsync(string? type, string? status, string? search, string? city, DateOnly? submittedFrom, DateOnly? submittedTo, CancellationToken cancellationToken)
    {
        var query = RequestQuery();
        if (!string.IsNullOrWhiteSpace(type) && !type.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            var normalized = NormalizeType(type);
            if (normalized is null) return ServiceResult<IReadOnlyList<CustomerRequestDto>>.Fail(400, "Unknown request type.");
            query = query.Where(item => item.Type == normalized);
        }

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(item => item.Status == status.Trim());
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item => item.Code.Contains(term) || item.Account.Code.Contains(term) || item.Account.FirstName.Contains(term) || item.Account.LastName.Contains(term));
        }

        if (!string.IsNullOrWhiteSpace(city))
        {
            var place = city.Trim();
            query = query.Where(item => item.Account.City.Contains(place) || item.Account.Area.Contains(place) || (item.City != null && item.City.Contains(place)));
        }

        if (submittedFrom is DateOnly from) query = query.Where(item => item.CreatedAt >= from.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc));
        if (submittedTo is DateOnly to) query = query.Where(item => item.CreatedAt <= to.ToDateTime(TimeOnly.MaxValue, DateTimeKind.Utc));
        var rows = await query.OrderByDescending(item => item.CreatedAt).Take(200).ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<CustomerRequestDto>>.Ok(rows.Select(MapRequest).ToList(), "Requests loaded.");
    }

    public async Task<ServiceResult<CustomerRequestImpactDto>> ImpactAsync(Guid id, CancellationToken cancellationToken)
    {
        var row = await _db.CustomerServiceRequests.AsNoTracking().FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (row is null) return ServiceResult<CustomerRequestImpactDto>.Fail(404, "Request not found.");
        if (row.ScheduleId is not Guid scheduleId) return ServiceResult<CustomerRequestImpactDto>.Fail(400, "This request has no schedule.");
        var schedule = await _db.RecurringSchedules.AsNoTracking().Include(item => item.Occurrences).FirstOrDefaultAsync(item => item.Id == scheduleId, cancellationToken);
        if (schedule is null) return ServiceResult<CustomerRequestImpactDto>.Fail(404, "Schedule not found.");
        var counts = ImpactCounts(schedule, row);
        return ServiceResult<CustomerRequestImpactDto>.Ok(new CustomerRequestImpactDto(
            row.RequestedSummary,
            counts.Scheduled,
            counts.Published,
            counts.Completed,
            "Dispatched visits stay assigned until an operator recalls them.",
            "Inventory availability is not calculated on this request.",
            "Issued invoices and completed sales stay as recorded."), "Impact loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<AdminRequestNoticeDto>>> NoticesAsync(CancellationToken cancellationToken)
    {
        var rows = await _db.AdminRequestNotices.AsNoTracking().OrderByDescending(item => item.CreatedAt).Take(30).ToListAsync(cancellationToken);
        return ServiceResult<IReadOnlyList<AdminRequestNoticeDto>>.Ok(rows.Select(item => new AdminRequestNoticeDto(item.Id, item.Title, item.Body, item.ReadAt != null, item.CreatedAt.ToString("yyyy-MM-dd HH:mm"))).ToList(), "Request notices loaded.");
    }

    public async Task<ServiceResult<object>> ReadNoticesAsync(CancellationToken cancellationToken)
    {
        var rows = await _db.AdminRequestNotices.Where(item => item.ReadAt == null).ToListAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var row in rows) row.ReadAt = now;
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Request notices marked read.");
    }

    public async Task<ServiceResult<CustomerRequestDto>> ReviewAsync(Guid id, ReviewCustomerRequest request, CancellationToken cancellationToken)
    {
        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var open = new[] { CustomerRequestStatus.Pending, CustomerRequestStatus.UnderReview, CustomerRequestStatus.MoreInformationRequired };
        var claimed = await _db.CustomerServiceRequests
            .Where(item => item.Id == id && open.Contains(item.Status))
            .ExecuteUpdateAsync(setters => setters.SetProperty(item => item.Status, CustomerRequestStatus.UnderReview), cancellationToken);
        if (claimed == 0) return ServiceResult<CustomerRequestDto>.Fail(409, "This request is already closed.");
        var row = await _db.CustomerServiceRequests.FirstAsync(item => item.Id == id, cancellationToken);
        var action = request.Action.Trim().ToLowerInvariant();
        var comment = Trim(request.Comment, 500);
        if (action is "reject" or "more" && string.IsNullOrWhiteSpace(comment))
        {
            await transaction.RollbackAsync(cancellationToken);
            return ServiceResult<CustomerRequestDto>.Fail(400, "A comment is required.");
        }

        if (action == "review")
        {
            row.Status = CustomerRequestStatus.UnderReview;
            row.AdminComment = comment;
        }
        else if (action == "reject")
        {
            row.Status = CustomerRequestStatus.Rejected;
            row.AdminComment = comment;
        }
        else if (action == "more")
        {
            row.Status = CustomerRequestStatus.MoreInformationRequired;
            row.AdminComment = comment;
        }
        else if (action == "approve")
        {
            var applied = await ApplyAsync(row, cancellationToken);
            if (applied is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
                return ServiceResult<CustomerRequestDto>.Fail(applied.Value.Status, applied.Value.Message);
            }

            row.Status = CustomerRequestStatus.Applied;
            row.AdminComment = string.IsNullOrWhiteSpace(comment) ? "Approved and applied to eligible future deliveries." : comment;
        }
        else
        {
            await transaction.RollbackAsync(cancellationToken);
            return ServiceResult<CustomerRequestDto>.Fail(400, "Choose approve, reject, more, or review.");
        }

        row.ReviewedBy = _current.UserId;
        row.ReviewedAt = DateTime.UtcNow;
        AddAudit("ReviewCustomerRequest", row.Id.ToString(), "CustomerServiceRequest");
        AddNotification(row.CustomerAccountId, "Request " + row.Status, $"{row.Code}: {row.AdminComment}", row.Type, row.Id);
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        var saved = await RequestQuery().FirstAsync(item => item.Id == row.Id, cancellationToken);
        return ServiceResult<CustomerRequestDto>.Ok(MapRequest(saved), "Request updated.");
    }

    private async Task<(int Status, string Message)?> ApplyAsync(CustomerServiceRequest row, CancellationToken cancellationToken)
    {
        if (row.ScheduleId is not Guid scheduleId) return (400, "This request has no schedule.");
        var schedule = await _db.RecurringSchedules
            .Include(item => item.Customer)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.MonthDays)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .FirstOrDefaultAsync(item => item.Id == scheduleId, cancellationToken);
        if (schedule is null) return (404, "Schedule not found.");
        if (schedule.CustomerId != row.DeliveryCustomerId) return (409, "The linked route customer does not match this request.");
        var today = LocalDate(schedule);
        if (row.Type == CustomerRequestType.Pause)
        {
            if (row.PauseStart is not DateOnly start || row.ResumeDate is not DateOnly resume) return (400, "Pause dates are missing.");
            if (schedule.Occurrences.Any(item => item.Status == OccurrenceStatus.Completed && item.ServiceDate >= start && item.ServiceDate < resume))
            {
                return (409, "This pause includes a completed delivery.");
            }

            var published = schedule.Occurrences.Count(item => item.ServiceDate >= start && item.ServiceDate < resume && item.Status == OccurrenceStatus.Published);
            var paused = await _schedules.PauseAsync(schedule.Id, new PauseScheduleRequest { Mode = "range", StartDate = start, EndDate = resume.AddDays(-1), Reason = $"{row.Code}: {row.Reason}", LeaveDispatched = true }, cancellationToken);
            if (!paused.Success) return (paused.StatusCode, paused.Message);
            row.AffectedDates = Trim($"{row.AffectedDates} {published} dispatched visits were left assigned.", 1000) ?? "";
            return null;
        }

        if (row.Type == CustomerRequestType.QuantityChange)
        {
            if (schedule.Lines.Count != 1) return (409, "This schedule has more than one product. Change it from Recurring Schedules.");
            if (row.RequestedQuantity is not int quantity || row.EffectiveDate is not DateOnly effective) return (400, "Quantity details are missing.");
            if (effective < today) return (400, "The effective date is in the past.");
            var line = schedule.Lines[0];
            var previous = line.Quantity;
            if (line.ExpectedEmpties == previous) line.ExpectedEmpties = quantity;
            line.Quantity = quantity;
            var changed = 0;
            var published = 0;
            foreach (var occurrence in schedule.Occurrences.Where(item => item.ServiceDate >= effective))
            {
                if (occurrence.Status == OccurrenceStatus.Completed || occurrence.Status == OccurrenceStatus.Skipped) continue;
                if (occurrence.Status == OccurrenceStatus.Published)
                {
                    published++;
                    continue;
                }

                if (occurrence.Status == OccurrenceStatus.Scheduled)
                {
                    occurrence.Quantity = quantity;
                    occurrence.UpdatedAt = DateTime.UtcNow;
                    changed++;
                }
            }

            schedule.Version++;
            schedule.UpdatedAt = DateTime.UtcNow;
            row.AffectedDates = Trim($"{changed} future visits updated. {published} published visits were left unchanged.", 1000) ?? "";
            AddAudit("ApplyQuantityRequest", schedule.Id.ToString(), "RecurringSchedule");
            return null;
        }

        if (row.Type == CustomerRequestType.ScheduleChange)
        {
            if (row.EffectiveDate is not DateOnly effective || effective < today) return (400, "The effective date is in the past.");
            schedule.Frequency = row.Frequency ?? schedule.Frequency;
            schedule.TimeWindow = row.TimeWindow ?? schedule.TimeWindow;
            if (row.WeekdayMask is int mask) schedule.WeekdayMask = mask;
            if (schedule.Frequency == ScheduleFrequency.Monthly) ReplaceMonthDays(schedule, ParseDays(row.MonthDays));
            var from = effective;
            var blocked = OpenPauseDates(schedule);
            var input = new RecurrenceInput(schedule.Frequency, schedule.Interval, schedule.WeekdayMask, schedule.MonthDays.Select(item => item.Day).ToList(), schedule.CustomDates.Select(item => item.ServiceDate).ToList(), schedule.StartDate, schedule.EndDate, blocked.ToList());
            var cancelled = 0;
            var held = 0;
            foreach (var occurrence in schedule.Occurrences.Where(item => !item.Detached && item.ServiceDate >= from && item.Status is not OccurrenceStatus.Completed and not OccurrenceStatus.Skipped))
            {
                var matches = RecurrenceEngine.Matches(input, occurrence.ServiceDate) && !blocked.Contains(occurrence.ServiceDate);
                if (matches) continue;
                if (occurrence.Status == OccurrenceStatus.Published)
                {
                    held++;
                    continue;
                }

                if (occurrence.Status != OccurrenceStatus.Scheduled) continue;
                occurrence.Status = OccurrenceStatus.Cancelled;
                occurrence.UpdatedAt = DateTime.UtcNow;
                await CancelOrderAsync(occurrence, "Removed because an approved schedule change no longer includes this date.", cancellationToken);
                cancelled++;
            }

            var existing = schedule.Occurrences.Select(item => item.ServiceDate).ToHashSet();
            var added = 0;
            foreach (var date in RecurrenceEngine.Dates(input, from, from.AddDays(RecurrenceEngine.HorizonDays)))
            {
                if (existing.Contains(date)) continue;
                var occurrence = new DeliveryOccurrence
                {
                    ScheduleId = schedule.Id,
                    CustomerId = schedule.CustomerId,
                    DepotId = schedule.DepotId,
                    AssignedRiderId = schedule.DefaultRiderId,
                    ServiceDate = date,
                    TimeWindow = schedule.TimeWindow,
                    Quantity = schedule.Lines.Sum(line => line.Quantity),
                    Status = OccurrenceStatus.Scheduled,
                    AddressSnapshot = Trim(ScheduleAddress(schedule), 300)
                };
                schedule.Occurrences.Add(occurrence);
                _db.DeliveryOccurrences.Add(occurrence);
                added++;
            }

            schedule.Version++;
            schedule.UpdatedAt = DateTime.UtcNow;
            row.AffectedDates = Trim($"{added} future visits added. {cancelled} future visits cancelled. {held} dispatched visits were left assigned. Completed visits were kept.", 1000) ?? "";
            AddAudit("ApplyScheduleRequest", schedule.Id.ToString(), "RecurringSchedule");
            return null;
        }

        if (row.Type == CustomerRequestType.AddressChange)
        {
            var effective = row.EffectiveDate ?? LocalDate(schedule);
            schedule.DeliveryCity = Trim(row.City, 80);
            schedule.DeliveryArea = Trim(row.Area, 120);
            var street = string.IsNullOrWhiteSpace(row.HouseNumber) ? row.Street : $"{row.HouseNumber}, {row.Street}";
            schedule.DeliveryStreet = Trim(street, 240);
            var line = ScheduleAddress(schedule);
            var updated = 0;
            var held = 0;
            foreach (var occurrence in schedule.Occurrences.Where(item => item.ServiceDate >= effective))
            {
                if (occurrence.Status == OccurrenceStatus.Published)
                {
                    held++;
                    continue;
                }

                if (occurrence.Status != OccurrenceStatus.Scheduled) continue;
                occurrence.AddressSnapshot = line.Length <= 300 ? line : line[..300];
                occurrence.UpdatedAt = DateTime.UtcNow;
                updated++;
            }

            schedule.UpdatedAt = DateTime.UtcNow;
            schedule.Version++;
            row.AffectedDates = Trim($"{updated} future visits use this schedule address. {held} dispatched visits were left assigned. Other schedules are unchanged.", 1000) ?? "";
            if (!string.IsNullOrWhiteSpace(schedule.DefaultRiderId))
            {
                _db.RiderInAppNotifications.Add(new RiderInAppNotification
                {
                    RiderUserId = schedule.DefaultRiderId,
                    Title = "Delivery address updated",
                    Body = $"{schedule.ScheduleCode} future visits use {line}.",
                    DeepLink = "todo",
                    IdempotencyKey = $"address:{row.Id:N}"
                });
            }

            AddAudit("ApplyAddressRequest", schedule.Id.ToString(), "RecurringSchedule");
            return null;
        }

        return (400, "This request type cannot be applied.");
    }

    private void ReplaceMonthDays(RecurringSchedule schedule, IReadOnlyList<int> days)
    {
        foreach (var extra in schedule.MonthDays.Where(item => !days.Contains(item.Day)).ToList())
        {
            schedule.MonthDays.Remove(extra);
            _db.RecurringScheduleMonthDays.Remove(extra);
        }

        foreach (var day in days.Where(day => schedule.MonthDays.All(item => item.Day != day)))
        {
            var row = new RecurringScheduleMonthDay { ScheduleId = schedule.Id, Day = day };
            schedule.MonthDays.Add(row);
            _db.RecurringScheduleMonthDays.Add(row);
        }
    }

    private async Task CancelOrderAsync(DeliveryOccurrence occurrence, string reason, CancellationToken cancellationToken)
    {
        if (occurrence.OrderId is not Guid orderId) return;
        var order = await _db.CustomerOrders.FirstOrDefaultAsync(item => item.Id == orderId, cancellationToken);
        if (order is null || order.Status is CustomerOrderStatus.Delivered or CustomerOrderStatus.Cancelled) return;
        order.Status = CustomerOrderStatus.Cancelled;
        order.CancelledAtUtc = DateTime.UtcNow;
        order.CancelledByUserId = _current.UserId;
        order.CancellationReason = Trim(reason, 300);
    }

    private async Task<CustomerAccountDetailDto> DetailAsync(CustomerAccount account, CancellationToken cancellationToken)
    {
        await EnsureHomeAddressAsync(account, cancellationToken);
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        var plans = customer is null ? [] : await PlansAsync(customer.Id, cancellationToken);
        var history = customer is null ? new List<CustomerVisitDto>() : await VisitsAsync(customer, null, cancellationToken);
        var payments = await BuildPaymentsAsync(customer, cancellationToken);
        var requests = await RequestQuery().Where(item => item.CustomerAccountId == account.Id).OrderByDescending(item => item.CreatedAt).ToListAsync(cancellationToken);
        var pending = requests.Count(item => item.Status is CustomerRequestStatus.Pending or CustomerRequestStatus.UnderReview or CustomerRequestStatus.MoreInformationRequired);
        var active = plans.Count(item => item.Status == ScheduleStatus.Active);
        var row = MapAccount(account, customer, active, pending);
        var ids = requests.Select(item => item.Id.ToString()).Append(account.Id.ToString()).ToList();
        var audits = await _db.AuditLogs.AsNoTracking().Where(item => ids.Contains(item.EntityId)).OrderByDescending(item => item.OccurredAt).Take(40).ToListAsync(cancellationToken);
        var userIds = audits.Select(item => item.UserId).Where(item => !string.IsNullOrWhiteSpace(item)).Distinct().ToList();
        var names = await _db.Users.AsNoTracking().Where(item => userIds.Contains(item.Id)).ToDictionaryAsync(item => item.Id, item => item.FullName, cancellationToken);
        var timeline = requests.Select(item => new CustomerTimelineDto(item.Type, item.CurrentSummary, item.RequestedSummary, item.ReviewedBy is not null && names.TryGetValue(item.ReviewedBy, out var reviewer) ? reviewer : item.ReviewedBy ?? "Customer", (item.ReviewedAt ?? item.CreatedAt).ToString("yyyy-MM-dd HH:mm"), item.AdminComment ?? item.Reason, item.Code))
            .Concat(audits.Select(item => new CustomerTimelineDto(item.Action, "", item.Action, names.TryGetValue(item.UserId, out var name) ? name : item.UserId, item.OccurredAt.ToString("yyyy-MM-dd HH:mm"), "", item.EntityId)))
            .Take(40)
            .ToList();
        return new CustomerAccountDetailDto(row, await ProfileOfAsync(account, cancellationToken), plans, history.Take(30).ToList(), payments, requests.Select(MapRequest).ToList(), timeline);
    }

    private async Task<CustomerProfileDto> ProfileOfAsync(CustomerAccount account, CancellationToken cancellationToken)
    {
        var customer = await LinkedCustomerAsync(account, cancellationToken);
        var addresses = await _db.CustomerSavedAddresses.AsNoTracking().Where(item => item.CustomerAccountId == account.Id).OrderByDescending(item => item.IsDefault).ToListAsync(cancellationToken);
        return new CustomerProfileDto(account.Code, account.FirstName, account.LastName, account.Email, account.Phone, account.Status, account.CreatedAt.ToString("yyyy-MM-dd"), customer is not null, customer?.Code, customer?.BusinessName, addresses.Select(MapAddress).ToList());
    }

    private async Task EnsureHomeAddressAsync(CustomerAccount account, CancellationToken cancellationToken)
    {
        if (await _db.CustomerSavedAddresses.AnyAsync(item => item.CustomerAccountId == account.Id, cancellationToken)) return;
        _db.CustomerSavedAddresses.Add(new CustomerSavedAddress
        {
            CustomerAccountId = account.Id,
            Label = "Home",
            City = account.City,
            Area = account.Area,
            Street = account.Street,
            HouseNumber = account.HouseNumber,
            Landmark = account.Landmark,
            Instructions = account.Instructions,
            Latitude = account.Latitude,
            Longitude = account.Longitude,
            IsDefault = true
        });
        await _db.SaveChangesAsync(cancellationToken);
    }

    private async Task<CustomerAccount?> AccountAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_current.UserId)) return null;
        return await _db.CustomerAccounts.FirstOrDefaultAsync(item => item.UserId == _current.UserId, cancellationToken);
    }

    private async Task<Customer?> LinkedCustomerAsync(CustomerAccount account, CancellationToken cancellationToken)
    {
        if (account.DeliveryCustomerId is not Guid id) return null;
        return await _db.Customers.AsNoTracking().Include(item => item.Route).ThenInclude(item => item.Depot).Include(item => item.Route).ThenInclude(item => item.Zone).FirstOrDefaultAsync(item => item.Id == id && !item.IsDeleted, cancellationToken);
    }

    private async Task<(RecurringSchedule? Schedule, (int Status, string Message)? Error)> OwnedScheduleAsync(Guid id, bool tracked, CancellationToken cancellationToken)
    {
        var account = await AccountAsync(cancellationToken);
        if (account is null) return (null, (404, "Customer account not found."));
        if (account.DeliveryCustomerId is null) return (null, (409, "The office has not placed this account on a delivery route yet."));
        var query = _db.RecurringSchedules
            .Include(item => item.Customer).ThenInclude(item => item.Route)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.MonthDays)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .Where(item => item.Id == id && item.CustomerId == account.DeliveryCustomerId);
        var schedule = tracked
            ? await query.FirstOrDefaultAsync(cancellationToken)
            : await query.AsNoTracking().FirstOrDefaultAsync(cancellationToken);
        return schedule is null ? (null, (404, "Schedule not found.")) : (schedule, null);
    }

    private async Task<IReadOnlyList<CustomerPlanDto>> PlansAsync(Guid customerId, CancellationToken cancellationToken)
    {
        var schedules = await _db.RecurringSchedules.AsNoTracking()
            .Include(item => item.Customer).ThenInclude(item => item.Route).ThenInclude(item => item.Depot)
            .Include(item => item.Customer).ThenInclude(item => item.Route).ThenInclude(item => item.Zone)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.MonthDays)
            .Include(item => item.Occurrences)
            .Where(item => item.CustomerId == customerId && item.Status != ScheduleStatus.Draft)
            .ToListAsync(cancellationToken);
        var riderIds = schedules.Select(item => item.DefaultRiderId).Where(item => !string.IsNullOrWhiteSpace(item)).Cast<string>().Distinct().ToList();
        var riders = await _db.Users.AsNoTracking().Where(item => riderIds.Contains(item.Id)).ToDictionaryAsync(item => item.Id, item => item.FullName, cancellationToken);
        return schedules.Select(item => Plan(item, riders)).ToList();
    }

    private async Task<List<CustomerVisitDto>> VisitsAsync(Customer customer, Guid? scheduleId, CancellationToken cancellationToken)
    {
        var occurrences = await _db.DeliveryOccurrences.AsNoTracking()
            .Include(item => item.Schedule).ThenInclude(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.Schedule).ThenInclude(item => item.Exceptions)
            .Where(item => item.CustomerId == customer.Id)
            .Where(item => scheduleId == null || item.ScheduleId == scheduleId)
            .OrderByDescending(item => item.ServiceDate)
            .Take(200)
            .ToListAsync(cancellationToken);
        var orderIds = occurrences.Where(item => item.OrderId != null).Select(item => item.OrderId!.Value).ToList();
        var orders = await _db.CustomerOrders.AsNoTracking().Where(item => orderIds.Contains(item.Id)).ToDictionaryAsync(item => item.Id, cancellationToken);
        var sales = await _db.Sales.AsNoTracking().Where(item => item.CustomerId == customer.Id && item.Status == SaleStatus.Completed).ToListAsync(cancellationToken);
        var stops = await _db.RouteStops.AsNoTracking().Where(item => item.CustomerId == customer.Id).ToListAsync(cancellationToken);
        return occurrences.Select(item =>
        {
            orders.TryGetValue(item.OrderId ?? Guid.Empty, out var order);
            var sale = sales.FirstOrDefault(entry => DateOnly.FromDateTime(entry.CreatedAt) == item.ServiceDate);
            var stop = stops.FirstOrDefault(entry => entry.ServiceDate == item.ServiceDate);
            var pauses = OpenPauseDates(item.Schedule);
            return Visit(item, customer, item.Schedule, pauses, order, sale, stop);
        }).ToList();
    }

    private async Task<CustomerMoneyDto> MoneyAsync(Customer? customer, CancellationToken cancellationToken)
    {
        if (customer is null)
        {
            return new CustomerMoneyDto(0, 0, 0, 0, null, null, PaymentNote);
        }

        var sales = await _db.Sales.AsNoTracking().Where(item => item.CustomerId == customer.Id && item.Status == SaleStatus.Completed).ToListAsync(cancellationToken);
        var collected = await _db.Collections.AsNoTracking().Where(item => item.CustomerId == customer.Id).SumAsync(item => item.Amount, cancellationToken);
        var billed = sales.Sum(item => item.SaleAmount);
        var paid = sales.Sum(item => item.AmountReceived) + collected;
        var overdue = 0m;
        if (customer.Outstanding > 0)
        {
            var cutoff = DateTime.UtcNow.AddDays(-Math.Max(customer.CreditDays, 0));
            if (customer.LastPaymentAt is null || customer.LastPaymentAt < cutoff) overdue = customer.Outstanding;
        }

        return new CustomerMoneyDto(billed, paid, customer.Outstanding, overdue, customer.LastPaymentAt?.ToString("yyyy-MM-dd"), customer.LastPaymentAmount, PaymentNote);
    }

    private IQueryable<CustomerServiceRequest> RequestQuery() =>
        _db.CustomerServiceRequests.AsNoTracking().Include(item => item.Account);

    private static CustomerRequestDto MapRequest(CustomerServiceRequest item) => new(
        item.Id,
        item.Code,
        item.Type,
        item.Status,
        null,
        item.CurrentSummary,
        item.RequestedSummary,
        item.Reason,
        item.Notes,
        item.EffectiveDate?.ToString("yyyy-MM-dd"),
        item.PauseStart?.ToString("yyyy-MM-dd"),
        item.ResumeDate?.ToString("yyyy-MM-dd"),
        item.AffectedDates,
        item.AdminComment,
        item.ReviewedAt?.ToString("yyyy-MM-dd HH:mm"),
        item.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
        item.Account?.Code ?? "",
        item.Account is null ? "" : $"{item.Account.FirstName} {item.Account.LastName}".Trim(),
        item.ScheduleId,
        item.CurrentQuantity,
        item.RequestedQuantity,
        item.City ?? item.Account?.City);

    private static CustomerAccountRowDto MapAccount(CustomerAccount account, Customer? customer, int activeSchedules, int pending) => new(
        account.Id,
        account.Code,
        $"{account.FirstName} {account.LastName}".Trim(),
        account.Phone,
        account.Email,
        account.City,
        account.Area,
        account.Status,
        account.CreatedAt.ToString("yyyy-MM-dd"),
        customer is not null,
        customer?.Id.ToString(),
        customer?.Code,
        customer?.BusinessName,
        activeSchedules,
        customer?.Outstanding ?? 0,
        pending);

    private static CustomerPlanDto Plan(RecurringSchedule schedule, IReadOnlyDictionary<string, string> riders)
    {
        var rider = schedule.DefaultRiderId is not null && riders.TryGetValue(schedule.DefaultRiderId, out var name) ? name : null;
        return new CustomerPlanDto(
            schedule.Id,
            schedule.ScheduleCode,
            schedule.Status,
            ProductSummary(schedule),
            schedule.Lines.Sum(line => line.Quantity),
            FrequencyLabel(schedule),
            schedule.StartDate.ToString("yyyy-MM-dd"),
            schedule.EndDate?.ToString("yyyy-MM-dd"),
            HasScheduleAddress(schedule) ? ScheduleAddress(schedule) : AddressOf(schedule.Customer),
            schedule.TimeWindow,
            rider,
            schedule.Customer.Route?.Depot?.Name ?? "",
            schedule.Customer.Route?.Zone?.Name ?? "",
            HasScheduleAddress(schedule) ? "Schedule address" : "Route address");
    }

    private static CustomerVisitDto Visit(DeliveryOccurrence occurrence, Customer customer, RecurringSchedule schedule, HashSet<DateOnly> pauses, CustomerOrder? order = null, Sale? sale = null, RouteStop? stop = null)
    {
        var status = pauses.Contains(occurrence.ServiceDate) && occurrence.Status is OccurrenceStatus.Cancelled or OccurrenceStatus.Scheduled
            ? "Paused"
            : occurrence.Status switch
            {
                OccurrenceStatus.Completed => "Delivered",
                OccurrenceStatus.Skipped => "Skipped",
                OccurrenceStatus.Cancelled => "Cancelled",
                OccurrenceStatus.Published when order?.Status == CustomerOrderStatus.InProgress => "Out for Delivery",
                OccurrenceStatus.Published => "Assigned",
                _ => stop?.Status == StopStatus.Missed ? "Missed" : "Scheduled"
            };
        if (order?.Status == CustomerOrderStatus.Delivered) status = "Delivered";
        var proof = sale?.SignatureImage is { Length: > 0 } ? $"A signature is stored with {sale.ReceiptNumber}." : sale is null ? null : $"Cash sale {sale.ReceiptNumber} is recorded.";
        var snapshot = !string.IsNullOrWhiteSpace(occurrence.AddressSnapshot);
        return new CustomerVisitDto(
            occurrence.ServiceDate.ToString("yyyy-MM-dd"),
            occurrence.Quantity,
            status,
            snapshot ? occurrence.AddressSnapshot! : HasScheduleAddress(schedule) ? ScheduleAddress(schedule) : AddressOf(customer),
            occurrence.TimeWindow,
            order?.ReferenceNumber ?? schedule.ScheduleCode,
            ProductSummary(schedule),
            sale?.SignedAt?.ToString("yyyy-MM-dd HH:mm"),
            proof,
            occurrence.ServiceDate.DayOfWeek.ToString(),
            snapshot ? "Saved with this visit" : HasScheduleAddress(schedule) ? "Schedule address" : "Current route address",
            schedule.ScheduleCode,
            schedule.Id.ToString(),
            snapshot,
            schedule.Instructions);
    }

    private static string? FillRequest(CustomerServiceRequest row, SubmitCustomerRequest request, RecurringSchedule schedule)
    {
        var today = LocalDate(schedule);
        if (row.Type == CustomerRequestType.Pause)
        {
            if (request.PauseStart is not DateOnly start || request.ResumeDate is not DateOnly resume) return "Choose a pause start and a resume date.";
            if (start < today) return "Choose a pause start date that is today or later.";
            if (resume <= start) return "The resume date must be after the pause start date.";
            if (schedule.Occurrences.Any(item => item.Status == OccurrenceStatus.Completed && item.ServiceDate >= start && item.ServiceDate < resume)) return "This pause includes a completed delivery.";
            var affected = AffectedPause(schedule, start, resume);
            row.PauseStart = start;
            row.ResumeDate = resume;
            row.RequestedSummary = $"Pause {start:yyyy-MM-dd} through {resume.AddDays(-1):yyyy-MM-dd}. Resume {resume:yyyy-MM-dd}. {affected.Count} visits are in this range.";
            row.AffectedDates = string.Join(", ", affected.Take(40));
            return null;
        }

        if (row.Type == CustomerRequestType.QuantityChange)
        {
            if (schedule.Lines.Count != 1) return "This schedule has more than one product. Ask the office to change it.";
            if (request.Quantity is not int quantity || quantity is < 1 or > 99) return "Enter a quantity from 1 to 99.";
            if (request.EffectiveDate is not DateOnly effective || effective < today) return "Choose an effective date that is today or later.";
            var current = schedule.Lines[0].Quantity;
            row.CurrentQuantity = current;
            row.RequestedQuantity = quantity;
            row.EffectiveDate = effective;
            var direction = quantity == current ? "Unchanged" : quantity > current ? "Increase" : "Decrease";
            var future = schedule.Occurrences.Count(item => item.ServiceDate >= effective && item.Status == OccurrenceStatus.Scheduled);
            row.RequestedSummary = $"{direction} from {current} to {quantity} starting {effective:yyyy-MM-dd}. {future} scheduled visits would change. Published visits stay as dispatched.";
            row.AffectedDates = $"{future} scheduled visits from {effective:yyyy-MM-dd}.";
            return null;
        }

        if (row.Type == CustomerRequestType.ScheduleChange)
        {
            var frequency = request.Frequency?.Trim();
            if (frequency is not (ScheduleFrequency.Weekly or ScheduleFrequency.Monthly)) return "Choose a weekly or monthly frequency.";
            if (request.EffectiveDate is not DateOnly effective || effective < today) return "Choose an effective date that is today or later.";
            var window = request.TimeWindow?.Trim();
            if (window is not ("Morning" or "Afternoon" or "Evening")) return "Choose a Morning, Afternoon, or Evening window.";
            int? mask = null;
            if (frequency == ScheduleFrequency.Weekly)
            {
                if (request.Weekdays.Count == 0 || request.Weekdays.Any(day => day is < 0 or > 6)) return "Choose at least one delivery day.";
                mask = request.Weekdays.Distinct().Aggregate(0, (current, day) => current | (1 << day));
            }

            if (frequency == ScheduleFrequency.Monthly && (request.MonthDays.Count == 0 || request.MonthDays.Any(day => day is < 1 or > 31))) return "Choose month dates from 1 to 31.";
            row.Frequency = frequency;
            row.WeekdayMask = mask;
            row.MonthDays = frequency == ScheduleFrequency.Monthly ? string.Join(",", request.MonthDays.Distinct().OrderBy(day => day)) : null;
            row.TimeWindow = window;
            row.EffectiveDate = effective;
            row.RequestedSummary = $"{frequency} {window} from {effective:yyyy-MM-dd}. Completed deliveries stay as they are.";
            row.AffectedDates = "Eligible future visits are previewed again when the office approves this request.";
            return null;
        }

        if (string.IsNullOrWhiteSpace(request.City) || string.IsNullOrWhiteSpace(request.Area) || string.IsNullOrWhiteSpace(request.Street) || string.IsNullOrWhiteSpace(request.HouseNumber))
        {
            return "City, area, street, and house number are required.";
        }

        row.AddressLabel = Trim(request.AddressLabel, 40) ?? "Other";
        row.City = Trim(request.City, 80);
        row.Area = Trim(request.Area, 120);
        row.Street = Trim(request.Street, 180);
        row.HouseNumber = Trim(request.HouseNumber, 40);
        row.Landmark = Trim(request.Landmark, 160);
        row.Instructions = Trim(request.Instructions, 300);
        row.EffectiveDate = request.EffectiveDate;
        row.RequestedSummary = $"Future visits use {row.HouseNumber}, {row.Street}, {row.Area}, {row.City}.";
        row.AffectedDates = "Completed deliveries keep the address on their existing receipts.";
        return null;
    }

    private static List<string> AffectedPause(RecurringSchedule schedule, DateOnly start, DateOnly resume)
    {
        var dates = schedule.Occurrences
            .Where(item => item.ServiceDate >= start && item.ServiceDate < resume && item.Status is OccurrenceStatus.Scheduled or OccurrenceStatus.Published)
            .Select(item => $"{item.ServiceDate:yyyy-MM-dd} ({item.Status})")
            .ToList();
        return dates;
    }

    private static string CurrentSummary(RecurringSchedule schedule) =>
        $"{schedule.ScheduleCode}: {FrequencyLabel(schedule)}, {schedule.TimeWindow}, {ProductSummary(schedule)} x {schedule.Lines.Sum(line => line.Quantity)}, {ScheduleAddress(schedule)}";

    private static string ProductSummary(RecurringSchedule schedule) =>
        schedule.Lines.Count == 0 ? "No product" : string.Join(", ", schedule.Lines.Select(line => line.Product?.Name ?? "Product"));

    private static string FrequencyLabel(RecurringSchedule schedule)
    {
        if (schedule.Frequency == ScheduleFrequency.Monthly)
        {
            var days = string.Join(", ", schedule.MonthDays.Select(item => item.Day).OrderBy(day => day));
            return string.IsNullOrWhiteSpace(days) ? "Monthly" : $"Monthly on {days}";
        }

        if (schedule.Frequency == ScheduleFrequency.Custom) return "Custom dates";
        var names = new[] { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
        var chosen = names.Where((_, index) => (schedule.WeekdayMask & (1 << index)) != 0);
        var list = string.Join(", ", chosen);
        return string.IsNullOrWhiteSpace(list) ? "Weekly" : $"Weekly on {list}";
    }

    private static string AddressOf(Customer customer) => string.Join(", ", new[] { customer.Street, customer.Area, customer.City }.Where(item => !string.IsNullOrWhiteSpace(item)));

    private static bool HasScheduleAddress(RecurringSchedule schedule) =>
        !string.IsNullOrWhiteSpace(schedule.DeliveryStreet) || !string.IsNullOrWhiteSpace(schedule.DeliveryArea) || !string.IsNullOrWhiteSpace(schedule.DeliveryCity);

    private static string ScheduleAddress(RecurringSchedule schedule) =>
        HasScheduleAddress(schedule)
            ? string.Join(", ", new[] { schedule.DeliveryStreet, schedule.DeliveryArea, schedule.DeliveryCity }.Where(item => !string.IsNullOrWhiteSpace(item)))
            : AddressOf(schedule.Customer);

    private static (int Scheduled, int Published, int Completed) ImpactCounts(RecurringSchedule schedule, CustomerServiceRequest row)
    {
        IEnumerable<DeliveryOccurrence> rows = schedule.Occurrences;
        if (row.Type == CustomerRequestType.Pause && row.PauseStart is DateOnly start && row.ResumeDate is DateOnly resume)
        {
            rows = rows.Where(item => item.ServiceDate >= start && item.ServiceDate < resume);
        }
        else if (row.EffectiveDate is DateOnly effective)
        {
            rows = rows.Where(item => item.ServiceDate >= effective);
        }

        var list = rows.ToList();
        return (
            list.Count(item => item.Status == OccurrenceStatus.Scheduled),
            list.Count(item => item.Status == OccurrenceStatus.Published),
            list.Count(item => item.Status == OccurrenceStatus.Completed));
    }

    private static HashSet<DateOnly> OpenPauseDates(RecurringSchedule schedule)
    {
        var dates = new HashSet<DateOnly>();
        foreach (var exception in schedule.Exceptions.Where(item => item.Status == "Open" && item.ExceptionType == "Pause"))
        {
            for (var day = exception.StartDate; day <= exception.EndDate && dates.Count < 400; day = day.AddDays(1)) dates.Add(day);
        }

        return dates;
    }

    private static DateOnly LocalDate(RecurringSchedule schedule)
    {
        foreach (var candidate in new[] { schedule.TimeZoneId, "Asia/Karachi", "Pakistan Standard Time" })
        {
            if (string.IsNullOrWhiteSpace(candidate)) continue;
            try
            {
                return DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTime.UtcNow, TimeZoneInfo.FindSystemTimeZoneById(candidate)));
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        return DateOnly.FromDateTime(DateTime.Today);
    }

    private static string? NormalizeType(string? value) => value?.Trim().ToLowerInvariant() switch
    {
        "schedulechange" or "schedule" => CustomerRequestType.ScheduleChange,
        "pause" => CustomerRequestType.Pause,
        "quantitychange" or "quantity" => CustomerRequestType.QuantityChange,
        "addresschange" or "address" => CustomerRequestType.AddressChange,
        _ => null
    };

    private static List<int> ParseDays(string? value) =>
        string.IsNullOrWhiteSpace(value) ? [] : value.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(item => int.TryParse(item, out var day) ? day : 0).Where(day => day is >= 1 and <= 31).Distinct().ToList();

    private static string? AddressProblem(SaveCustomerAddressRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Label) || string.IsNullOrWhiteSpace(request.City) || string.IsNullOrWhiteSpace(request.Area) || string.IsNullOrWhiteSpace(request.Street) || string.IsNullOrWhiteSpace(request.HouseNumber))
        {
            return "Label, city, area, street, and house number are required.";
        }

        if (request.Latitude is decimal latitude && latitude is < -90 or > 90) return "Latitude is out of range.";
        if (request.Longitude is decimal longitude && longitude is < -180 or > 180) return "Longitude is out of range.";
        if (request.Latitude is null != request.Longitude is null) return "Enter both latitude and longitude, or leave both empty.";
        return null;
    }

    private static void CopyAddress(CustomerSavedAddress row, SaveCustomerAddressRequest request)
    {
        row.Label = Trim(request.Label, 40) ?? "Home";
        row.City = Trim(request.City, 80) ?? "";
        row.Area = Trim(request.Area, 120) ?? "";
        row.Street = Trim(request.Street, 180) ?? "";
        row.HouseNumber = Trim(request.HouseNumber, 40) ?? "";
        row.Landmark = Trim(request.Landmark, 160);
        row.Instructions = Trim(request.Instructions, 300);
        row.Latitude = request.Latitude;
        row.Longitude = request.Longitude;
    }

    private static CustomerAddressDto MapAddress(CustomerSavedAddress item) => new(item.Id, item.Label, item.City, item.Area, item.Street, item.HouseNumber, item.Landmark, item.Instructions, item.Latitude, item.Longitude, item.IsDefault, item.IsActive);

    private static string ChannelName(PaymentChannel? channel) => channel switch
    {
        PaymentChannel.BankTransfer => "Bank transfer",
        PaymentChannel.Wallet => "Wallet",
        PaymentChannel.Cheque => "Cheque",
        _ => "Cash"
    };

    private static bool InvoiceOverdue(Customer customer, DateTime createdAt, decimal remaining) =>
        remaining > 0 && DateTime.UtcNow > createdAt.AddDays(Math.Max(customer.CreditDays, 0));

    private static string InvoiceState(decimal billed, decimal paid, bool overdue)
    {
        if (paid >= billed && billed > 0) return "Paid";
        if (overdue) return "Overdue";
        if (paid <= 0) return "Unpaid";
        return "Partially Paid";
    }

    private static string? NormalizePhone(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var digits = new string(raw.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("00")) digits = digits[2..];
        if (digits.Length == 11 && digits.StartsWith('0')) digits = "92" + digits[1..];
        if (digits.Length == 10 && digits.StartsWith('3')) digits = "92" + digits;
        if (digits.Length < 10 || digits.Length > 15) return null;
        return "+" + digits;
    }

    private static string PaymentState(decimal billed, decimal paid)
    {
        if (paid <= 0) return "Unpaid";
        return paid >= billed ? "Paid" : "Partially Paid";
    }

    private async Task<string> NextCodeAsync(CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstOrDefaultAsync(item => item.Name == "CustomerRequest", cancellationToken);
        if (sequence is null)
        {
            sequence = new NumberSequence { Name = "CustomerRequest", NextValue = 1 };
            _db.NumberSequences.Add(sequence);
        }

        var value = sequence.NextValue++;
        return $"CSR-{value:000000}";
    }

    private void AddAudit(string action, string id, string entity) =>
        _db.AuditLogs.Add(new AuditLog { UserId = _current.UserId ?? "", Action = action, EntityName = entity, EntityId = id });

    private void AddNotification(Guid accountId, string title, string body, string kind, Guid? requestId = null) =>
        _db.CustomerNotifications.Add(new CustomerNotification { CustomerAccountId = accountId, Title = Trim(title, 160) ?? title, Body = Trim(body, 500) ?? body, Kind = kind, RequestId = requestId });

    private void AddNotice(Guid requestId, string title, string body) =>
        _db.AdminRequestNotices.Add(new AdminRequestNotice { RequestId = requestId, Title = Trim(title, 160) ?? title, Body = Trim(body, 300) ?? body });

    private static string? Trim(string? value, int max)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var trimmed = value.Trim();
        return trimmed.Length <= max ? trimmed : trimmed[..max];
    }
}
