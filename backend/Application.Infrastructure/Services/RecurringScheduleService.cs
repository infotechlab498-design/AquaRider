using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class RecurringScheduleService : IRecurringScheduleService
{
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public RecurringScheduleService(AppDbContext db, ICurrentUser current)
    {
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<RecurringBoardDto>> BoardAsync(string? search, string? tab, Guid? depotId, Guid? productId, string? riderId, int page, int pageSize, CancellationToken cancellationToken)
    {
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var query = Filtered(search, tab, depotId, productId, riderId);
        var total = await query.CountAsync(cancellationToken);
        var schedules = await query
            .OrderBy(item => item.ScheduleCode)
            .Skip((pageIndex - 1) * size)
            .Take(size)
            .Include(item => item.Customer)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.Occurrences)
            .ToListAsync(cancellationToken);
        var riderIds = schedules.Select(item => item.DefaultRiderId).Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().Cast<string>().ToList();
        var riders = await RiderNamesAsync(riderIds, cancellationToken);
        var monthStart = new DateOnly(DateTime.Today.Year, DateTime.Today.Month, 1);
        var monthEnd = monthStart.AddMonths(1).AddDays(-1);
        var rows = schedules.Select(item =>
        {
            riders.TryGetValue(item.DefaultRiderId ?? "", out var rider);
            var next = item.Occurrences
                .Where(occurrence => occurrence.ServiceDate >= DateOnly.FromDateTime(DateTime.Today) && occurrence.Status is OccurrenceStatus.Scheduled or OccurrenceStatus.Published)
                .Select(occurrence => (DateOnly?)occurrence.ServiceDate)
                .OrderBy(date => date)
                .FirstOrDefault();
            var monthly = item.Occurrences.Count(occurrence => occurrence.ServiceDate >= monthStart && occurrence.ServiceDate <= monthEnd && occurrence.Status != OccurrenceStatus.Cancelled);
            return ToRow(item, rider, next, monthly);
        }).ToList();
        var active = await _db.RecurringSchedules.CountAsync(item => item.Status == ScheduleStatus.Active, cancellationToken);
        var paused = await _db.RecurringSchedules.CountAsync(item => item.Status == ScheduleStatus.Paused, cancellationToken);
        var unassigned = await _db.RecurringSchedules.CountAsync(item => item.Status == ScheduleStatus.Active && (item.DefaultRiderId == null || item.DefaultRiderId == ""), cancellationToken);
        var deliveries = await _db.DeliveryOccurrences.CountAsync(item => item.ServiceDate >= monthStart && item.ServiceDate <= monthEnd && item.Status != OccurrenceStatus.Cancelled, cancellationToken);
        var riderCount = await _db.RecurringSchedules.Where(item => item.Status == ScheduleStatus.Active && item.DefaultRiderId != null && item.DefaultRiderId != "").Select(item => item.DefaultRiderId).Distinct().CountAsync(cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.Today);
        var tabs = new RecurringTabCounts(
            await _db.RecurringSchedules.CountAsync(cancellationToken),
            await _db.RecurringSchedules.CountAsync(item => item.Frequency == ScheduleFrequency.Weekly, cancellationToken),
            await _db.RecurringSchedules.CountAsync(item => item.Frequency == ScheduleFrequency.Monthly, cancellationToken),
            paused,
            await _db.RecurringSchedules.CountAsync(item => item.Status == ScheduleStatus.Active && item.EndDate != null && item.EndDate <= today.AddDays(14), cancellationToken),
            await _db.RecurringSchedules.CountAsync(item => item.Exceptions.Any(exception => exception.Status == "Open"), cancellationToken),
            unassigned);
        var depots = await _db.Depots.AsNoTracking().OrderBy(item => item.Name).Select(item => new ScheduleDepotOptionDto(item.Id, item.Name)).ToListAsync(cancellationToken);
        var board = new RecurringBoardDto(active, deliveries, paused, unassigned, riderCount, total, pageIndex, size, tabs, rows, depots);
        return ServiceResult<RecurringBoardDto>.Ok(board, rows.Count == 0 ? "No recurring schedules are saved." : "Schedules loaded.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> GetAsync(Guid id, CancellationToken cancellationToken)
    {
        var schedule = await LoadAsync(id, cancellationToken);
        if (schedule is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync(schedule, cancellationToken), "Schedule loaded.");
    }

    public async Task<ServiceResult<SchedulePreviewDto>> PreviewAsync(SaveScheduleRequest request, CancellationToken cancellationToken)
    {
        var built = BuildInput(request, []);
        if (built.Error is not null) return ServiceResult<SchedulePreviewDto>.Fail(400, built.Error);
        var monthStart = new DateOnly(request.StartDate.Year, request.StartDate.Month, 1);
        var dates = RecurrenceEngine.Dates(built.Input!, monthStart, monthStart.AddMonths(1).AddDays(-1));
        var bottles = dates.Count * request.Lines.Sum(line => Math.Max(0, line.Quantity));
        return ServiceResult<SchedulePreviewDto>.Ok(
            new SchedulePreviewDto(dates, dates.Count, bottles, "A month day that the month does not contain is skipped."),
            "Preview calculated.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> SaveAsync(Guid? id, SaveScheduleRequest request, CancellationToken cancellationToken)
    {
        var built = BuildInput(request, []);
        if (built.Error is not null) return ServiceResult<RecurringScheduleDetailDto>.Fail(400, built.Error);
        if (!Enum.TryParse<DeliveryWindow>(request.TimeWindow, true, out _))
        {
            return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "Choose a delivery window.");
        }

        if (!TimeOnly.TryParse(request.PublicationTime, out var publicationTime))
        {
            return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "Publication time must be HH:mm.");
        }

        var customer = await _db.Customers.Include(item => item.Route).ThenInclude(route => route.Zone).ThenInclude(zone => zone.Depot)
            .FirstOrDefaultAsync(item => item.Id == request.CustomerId && !item.IsDeleted, cancellationToken);
        if (customer is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Customer not found.");
        if (!string.Equals(customer.Status, "Active", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "An inactive customer cannot receive a new recurring delivery.");
        }

        if (id is null)
        {
            var linked = await _db.CustomerAccounts.AnyAsync(item => item.DeliveryCustomerId == customer.Id, cancellationToken);
            if (!linked) return ServiceResult<RecurringScheduleDetailDto>.Fail(409, "Approve a customer account link before creating a new schedule.");
        }

        var depotId = customer.Route?.DepotId ?? Guid.Empty;
        if (depotId == Guid.Empty)
        {
            return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "This customer's route has no warehouse.");
        }

        var lines = await LinesAsync(request.Lines, cancellationToken);
        if (lines.Error is not null) return ServiceResult<RecurringScheduleDetailDto>.Fail(400, lines.Error);
        var riderError = await RiderAllowedAsync(request.RiderId, depotId, required: request.Activate, cancellationToken);
        if (riderError is not null) return ServiceResult<RecurringScheduleDetailDto>.Fail(riderError.Value.Status, riderError.Value.Message);
        if (request.Activate)
        {
            var overlap = await OverlapsAsync(id, customer.Id, request, cancellationToken);
            if (overlap is not null) return ServiceResult<RecurringScheduleDetailDto>.Fail(409, overlap);
        }

        RecurringSchedule schedule;
        if (id is null)
        {
            schedule = new RecurringSchedule
            {
                ScheduleCode = await NextCodeAsync("Schedule", "SCH", cancellationToken),
                CustomerId = customer.Id,
                CreatedBy = _current.UserId ?? ""
            };
            _db.RecurringSchedules.Add(schedule);
        }
        else
        {
            schedule = await LoadTrackedAsync(id.Value, cancellationToken) ?? null!;
            if (schedule is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
            if (schedule.Status == ScheduleStatus.Cancelled) return ServiceResult<RecurringScheduleDetailDto>.Fail(409, "A cancelled schedule cannot be edited.");
            if (request.Version is int version && version != schedule.Version)
            {
                return ServiceResult<RecurringScheduleDetailDto>.Fail(409, "This schedule was saved by someone else. Reload it and try again.");
            }
        }

        schedule.DepotId = depotId;
        schedule.DefaultRiderId = string.IsNullOrWhiteSpace(request.RiderId) ? null : request.RiderId.Trim();
        schedule.Frequency = built.Input!.Frequency;
        schedule.Interval = built.Input.Interval;
        schedule.WeekdayMask = built.Input.WeekdayMask;
        schedule.StartDate = request.StartDate;
        schedule.EndDate = request.EndDate;
        schedule.TimeWindow = request.TimeWindow.Trim();
        schedule.TimeZoneId = string.IsNullOrWhiteSpace(request.TimeZoneId) ? "Asia/Karachi" : request.TimeZoneId.Trim();
        schedule.AutoPublish = request.AutoPublish;
        schedule.PublicationTime = publicationTime;
        schedule.AssignmentMode = request.AssignmentMode.Equals("Flexible", StringComparison.OrdinalIgnoreCase) ? "Flexible" : "Fixed";
        schedule.Instructions = string.IsNullOrWhiteSpace(request.Instructions) ? null : request.Instructions.Trim();
        schedule.UpdatedAt = DateTime.UtcNow;
        schedule.Version += id is null ? 0 : 1;
        ReplaceChildren(schedule, request, lines.Lines!);
        if (request.Activate) schedule.Status = ScheduleStatus.Active;
        else if (id is null) schedule.Status = ScheduleStatus.Draft;
        AddAudit(id is null ? "CreateSchedule" : "UpdateSchedule", schedule.Id);
        if (schedule.Status == ScheduleStatus.Active)
        {
            await _db.SaveChangesAsync(cancellationToken);
            await EnsureRangeAsync(schedule, LocalDate(schedule), LocalDate(schedule).AddDays(RecurrenceEngine.HorizonDays), cancellationToken);
            await ReconcileAsync(schedule, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);
        var saved = await LoadAsync(schedule.Id, cancellationToken);
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync(saved!, cancellationToken), request.Activate ? "Schedule activated." : "Schedule saved.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> PauseAsync(Guid id, PauseScheduleRequest request, CancellationToken cancellationToken)
    {
        var schedule = await LoadTrackedAsync(id, cancellationToken);
        if (schedule is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
        if (string.IsNullOrWhiteSpace(request.Reason)) return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "A reason is required.");
        var today = LocalDate(schedule);
        var start = request.Mode.Equals("range", StringComparison.OrdinalIgnoreCase) ? request.StartDate ?? today : today;
        var end = request.Mode.Equals("range", StringComparison.OrdinalIgnoreCase) ? request.EndDate ?? start : schedule.EndDate ?? today.AddYears(2);
        if (end < start) return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "The pause end date is before the start date.");
        if (!request.Mode.Equals("range", StringComparison.OrdinalIgnoreCase)) schedule.Status = ScheduleStatus.Paused;
        var exception = new ScheduleException
        {
            ScheduleId = schedule.Id,
            ExceptionType = "Pause",
            StartDate = start,
            EndDate = end,
            Reason = request.Reason.Trim(),
            CreatedBy = _current.UserId ?? ""
        };
        schedule.Exceptions.Add(exception);
        _db.ScheduleExceptions.Add(exception);
        schedule.UpdatedAt = DateTime.UtcNow;
        schedule.Version++;
        await CancelOccurrencesAsync(schedule, start, end, request.Reason.Trim(), !request.LeaveDispatched, cancellationToken);
        AddAudit("PauseSchedule", schedule.Id);
        await NotifyAsync(schedule.DefaultRiderId, "Schedule paused", $"{schedule.Customer.BusinessName} is paused from {start:yyyy-MM-dd} to {end:yyyy-MM-dd}. {request.Reason.Trim()}", $"pause:{schedule.Id:N}:{start:yyyyMMdd}", cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync((await LoadAsync(id, cancellationToken))!, cancellationToken), "Schedule paused.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> ResumeAsync(Guid id, CancellationToken cancellationToken)
    {
        var schedule = await LoadTrackedAsync(id, cancellationToken);
        if (schedule is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
        if (schedule.Status == ScheduleStatus.Cancelled) return ServiceResult<RecurringScheduleDetailDto>.Fail(409, "A cancelled schedule cannot be resumed.");
        schedule.Status = ScheduleStatus.Active;
        foreach (var exception in schedule.Exceptions.Where(item => item.Status == "Open")) exception.Status = "Closed";
        var today = LocalDate(schedule);
        var input = InputOf(schedule, []);
        foreach (var occurrence in schedule.Occurrences.Where(item => !item.Detached && item.ServiceDate >= today && item.Status == OccurrenceStatus.Cancelled))
        {
            if (!RecurrenceEngine.Matches(input, occurrence.ServiceDate)) continue;
            occurrence.Status = OccurrenceStatus.Scheduled;
            occurrence.UpdatedAt = DateTime.UtcNow;
        }

        schedule.UpdatedAt = DateTime.UtcNow;
        schedule.Version++;
        await EnsureRangeAsync(schedule, today, today.AddDays(RecurrenceEngine.HorizonDays), cancellationToken);
        AddAudit("ResumeSchedule", schedule.Id);
        await NotifyAsync(schedule.DefaultRiderId, "Schedule resumed", $"{schedule.Customer.BusinessName} deliveries are active again.", $"resume:{schedule.Id:N}:{today:yyyyMMdd}", cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync((await LoadAsync(id, cancellationToken))!, cancellationToken), "Schedule resumed.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> CancelAsync(Guid id, string reason, CancellationToken cancellationToken)
    {
        var schedule = await LoadTrackedAsync(id, cancellationToken);
        if (schedule is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
        if (string.IsNullOrWhiteSpace(reason)) return ServiceResult<RecurringScheduleDetailDto>.Fail(400, "A reason is required.");
        schedule.Status = ScheduleStatus.Cancelled;
        schedule.UpdatedAt = DateTime.UtcNow;
        schedule.Version++;
        await CancelOccurrencesAsync(schedule, LocalDate(schedule), DateOnly.MaxValue, reason.Trim(), true, cancellationToken);
        AddAudit("CancelSchedule", schedule.Id);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync((await LoadAsync(id, cancellationToken))!, cancellationToken), "Schedule cancelled.");
    }

    public async Task<ServiceResult<RecurringScheduleDetailDto>> DuplicateAsync(Guid id, CancellationToken cancellationToken)
    {
        var source = await LoadAsync(id, cancellationToken);
        if (source is null) return ServiceResult<RecurringScheduleDetailDto>.Fail(404, "Schedule not found.");
        var copy = new RecurringSchedule
        {
            ScheduleCode = await NextCodeAsync("Schedule", "SCH", cancellationToken),
            CustomerId = source.CustomerId,
            DepotId = source.DepotId,
            DefaultRiderId = source.DefaultRiderId,
            Status = ScheduleStatus.Draft,
            Frequency = source.Frequency,
            Interval = source.Interval,
            WeekdayMask = source.WeekdayMask,
            StartDate = source.StartDate,
            EndDate = source.EndDate,
            TimeWindow = source.TimeWindow,
            TimeZoneId = source.TimeZoneId,
            AutoPublish = source.AutoPublish,
            PublicationTime = source.PublicationTime,
            AssignmentMode = source.AssignmentMode,
            Instructions = source.Instructions,
            CreatedBy = _current.UserId ?? "",
            Lines = source.Lines.Select(line => new RecurringScheduleLine { ProductId = line.ProductId, Quantity = line.Quantity, ExpectedEmpties = line.ExpectedEmpties }).ToList(),
            MonthDays = source.MonthDays.Select(day => new RecurringScheduleMonthDay { Day = day.Day }).ToList(),
            CustomDates = source.CustomDates.Select(day => new RecurringScheduleCustomDate { ServiceDate = day.ServiceDate }).ToList()
        };
        _db.RecurringSchedules.Add(copy);
        AddAudit("DuplicateSchedule", copy.Id);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<RecurringScheduleDetailDto>.Ok(await ToDetailAsync((await LoadAsync(copy.Id, cancellationToken))!, cancellationToken), "A draft copy was saved.");
    }

    public async Task<ServiceResult<ScheduleCalendarDto>> CalendarAsync(int year, int month, Guid? scheduleId, string? riderId, CancellationToken cancellationToken)
    {
        if (month is < 1 or > 12 || year < 2024) return ServiceResult<ScheduleCalendarDto>.Fail(400, "Choose a valid month.");
        var start = new DateOnly(year, month, 1);
        var end = start.AddMonths(1).AddDays(-1);
        var schedules = await _db.RecurringSchedules
            .Include(item => item.Lines)
            .Include(item => item.MonthDays)
            .Include(item => item.CustomDates)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .Where(item => item.Status == ScheduleStatus.Active || item.Status == ScheduleStatus.Paused)
            .Where(item => scheduleId == null || item.Id == scheduleId)
            .ToListAsync(cancellationToken);
        foreach (var schedule in schedules.Where(item => item.Status == ScheduleStatus.Active))
        {
            await EnsureRangeAsync(schedule, start < LocalDate(schedule) ? LocalDate(schedule) : start, end, cancellationToken);
        }

        await _db.SaveChangesAsync(cancellationToken);
        var occurrences = await _db.DeliveryOccurrences.AsNoTracking()
            .Include(item => item.Schedule).ThenInclude(item => item.Customer)
            .Include(item => item.Schedule).ThenInclude(item => item.Lines).ThenInclude(line => line.Product)
            .Where(item => item.ServiceDate >= start && item.ServiceDate <= end)
            .Where(item => scheduleId == null || item.ScheduleId == scheduleId)
            .Where(item => riderId == null || item.AssignedRiderId == riderId)
            .ToListAsync(cancellationToken);
        var names = await RiderNamesAsync(occurrences.Select(item => item.AssignedRiderId).Where(id => id != null).Cast<string>().Distinct().ToList(), cancellationToken);
        var days = new List<ScheduleCalendarDayDto>();
        for (var date = start; date <= end; date = date.AddDays(1))
        {
            var items = occurrences.Where(item => item.ServiceDate == date).Select(item => ToItem(item, names)).ToList();
            days.Add(new ScheduleCalendarDayDto(date, items.Count, items.Sum(item => item.Quantity), items));
        }

        return ServiceResult<ScheduleCalendarDto>.Ok(new ScheduleCalendarDto(year, month, days), "Calendar loaded.");
    }

    public Task<ServiceResult<ScheduleCalendarItemDto>> SkipAsync(Guid occurrenceId, CancellationToken cancellationToken) =>
        ChangeOccurrenceAsync(occurrenceId, async occurrence =>
        {
            if (occurrence.Status is OccurrenceStatus.Completed) return "A completed delivery cannot be skipped.";
            occurrence.Status = OccurrenceStatus.Skipped;
            occurrence.Detached = true;
            await CancelOrderAsync(occurrence, "Skipped from the recurring schedule.", cancellationToken);
            await NotifyAsync(occurrence.AssignedRiderId, "Delivery skipped", $"{occurrence.Schedule.Customer.BusinessName} on {occurrence.ServiceDate:yyyy-MM-dd} was skipped.", $"skip:{occurrence.Id:N}", cancellationToken);
            return null;
        }, cancellationToken);

    public Task<ServiceResult<ScheduleCalendarItemDto>> RescheduleAsync(Guid occurrenceId, DateOnly date, CancellationToken cancellationToken) =>
        ChangeOccurrenceAsync(occurrenceId, async occurrence =>
        {
            if (occurrence.Status is OccurrenceStatus.Completed) return "A completed delivery cannot be moved.";
            var taken = await _db.DeliveryOccurrences.AnyAsync(item => item.ScheduleId == occurrence.ScheduleId && item.ServiceDate == date && item.Id != occurrence.Id, cancellationToken);
            if (taken) return "That date already has a delivery for this schedule.";
            await CancelOrderAsync(occurrence, "Moved to another date.", cancellationToken);
            occurrence.OrderId = null;
            occurrence.ServiceDate = date;
            occurrence.Status = OccurrenceStatus.Scheduled;
            occurrence.Detached = true;
            await NotifyAsync(occurrence.AssignedRiderId, "Delivery moved", $"{occurrence.Schedule.Customer.BusinessName} moved to {date:yyyy-MM-dd}.", $"move:{occurrence.Id:N}:{date:yyyyMMdd}", cancellationToken);
            return null;
        }, cancellationToken);

    public Task<ServiceResult<ScheduleCalendarItemDto>> ReassignAsync(Guid occurrenceId, string riderId, CancellationToken cancellationToken) =>
        ChangeOccurrenceAsync(occurrenceId, async occurrence =>
        {
            if (occurrence.Status is OccurrenceStatus.Completed) return "A completed delivery cannot be reassigned.";
            var allowed = await RiderAllowedAsync(riderId, occurrence.DepotId, required: true, cancellationToken);
            if (allowed is not null) return allowed.Value.Message;
            var previous = occurrence.AssignedRiderId;
            occurrence.AssignedRiderId = riderId.Trim();
            occurrence.Detached = true;
            _db.OccurrenceAssignments.Add(new OccurrenceAssignment
            {
                OccurrenceId = occurrence.Id,
                RiderId = riderId.Trim(),
                PreviousRiderId = previous,
                AssignedBy = _current.UserId ?? "",
                Reason = "Reassigned from the calendar."
            });
            if (occurrence.OrderId is Guid orderId)
            {
                var order = await _db.CustomerOrders.FirstOrDefaultAsync(item => item.Id == orderId, cancellationToken);
                if (order is not null && order.Status is CustomerOrderStatus.Scheduled or CustomerOrderStatus.InProgress) order.RiderId = riderId.Trim();
            }

            await NotifyAsync(previous, "Delivery reassigned", $"{occurrence.Schedule.Customer.BusinessName} on {occurrence.ServiceDate:yyyy-MM-dd} was assigned to another rider.", $"reassign-off:{occurrence.Id:N}:{riderId}", cancellationToken);
            await NotifyAsync(riderId, "Delivery assigned", $"{occurrence.Schedule.Customer.BusinessName} on {occurrence.ServiceDate:yyyy-MM-dd} is now on your route.", $"reassign-on:{occurrence.Id:N}:{riderId}", cancellationToken);
            return null;
        }, cancellationToken);

    public Task<ServiceResult<ScheduleCalendarItemDto>> ChangeQuantityAsync(Guid occurrenceId, int quantity, CancellationToken cancellationToken) =>
        ChangeOccurrenceAsync(occurrenceId, async occurrence =>
        {
            if (quantity < 1) return "Quantity must be at least 1.";
            if (occurrence.Status is OccurrenceStatus.Completed) return "A completed delivery cannot be changed.";
            if (occurrence.Schedule.Lines.Count != 1) return "This schedule has more than one product. Edit the schedule to change quantities.";
            occurrence.Quantity = quantity;
            occurrence.Detached = true;
            if (occurrence.OrderId is Guid orderId)
            {
                var order = await _db.CustomerOrders.Include(item => item.Lines).FirstOrDefaultAsync(item => item.Id == orderId, cancellationToken);
                if (order is not null && order.Status is CustomerOrderStatus.Scheduled or CustomerOrderStatus.InProgress && order.Lines.Count == 1)
                {
                    order.Lines[0].Quantity = quantity;
                    order.EstimatedValue = quantity * order.Lines[0].UnitPrice;
                }
            }

            return null;
        }, cancellationToken);

    public async Task RunDueAsync(CancellationToken cancellationToken)
    {
        var schedules = await _db.RecurringSchedules
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.MonthDays)
            .Include(item => item.CustomDates)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .Include(item => item.Customer)
            .Where(item => item.Status == ScheduleStatus.Active)
            .ToListAsync(cancellationToken);
        foreach (var schedule in schedules)
        {
            var today = LocalDate(schedule);
            await EnsureRangeAsync(schedule, today, today.AddDays(RecurrenceEngine.HorizonDays), cancellationToken);
            var local = TimeZoneInfo.ConvertTime(DateTime.UtcNow, Zone(schedule.TimeZoneId));
            if (schedule.AutoPublish && local.TimeOfDay >= schedule.PublicationTime.ToTimeSpan())
            {
                await PublishDateAsync(schedule, today, cancellationToken);
            }
        }

        try
        {
            await _db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            _db.ChangeTracker.Clear();
        }
    }

    public static async Task CompleteLinkedAsync(AppDbContext db, IEnumerable<Guid> orderIds, CancellationToken cancellationToken)
    {
        var ids = orderIds.Distinct().ToList();
        if (ids.Count == 0) return;
        var rows = await db.DeliveryOccurrences
            .Where(item => item.OrderId != null && ids.Contains(item.OrderId.Value) && item.Status != OccurrenceStatus.Completed)
            .ToListAsync(cancellationToken);
        foreach (var row in rows)
        {
            row.Status = OccurrenceStatus.Completed;
            row.UpdatedAt = DateTime.UtcNow;
        }
    }

    private async Task PublishDateAsync(RecurringSchedule schedule, DateOnly date, CancellationToken cancellationToken)
    {
        foreach (var occurrence in schedule.Occurrences.Where(item => item.ServiceDate == date && item.Status == OccurrenceStatus.Scheduled))
        {
            if (string.IsNullOrWhiteSpace(occurrence.AssignedRiderId))
            {
                occurrence.FailureReason = "No rider is assigned.";
                continue;
            }

            if (occurrence.OrderId is not null)
            {
                occurrence.Status = OccurrenceStatus.Published;
                continue;
            }

            var rider = await _db.Users.FirstOrDefaultAsync(item => item.Id == occurrence.AssignedRiderId, cancellationToken);
            if (rider?.RouteId is not Guid routeId)
            {
                occurrence.FailureReason = "The rider has no route.";
                _db.SchedulePublicationLogs.Add(new SchedulePublicationLog { OccurrenceId = occurrence.Id, RiderId = occurrence.AssignedRiderId, Status = "Failed", FailureReason = occurrence.FailureReason, Attempt = 1 });
                continue;
            }

            if (!Enum.TryParse<DeliveryWindow>(occurrence.TimeWindow, true, out var window)) window = DeliveryWindow.Morning;
            var single = schedule.Lines.Count == 1;
            var order = new CustomerOrder
            {
                ReferenceNumber = await NextCodeAsync("Order", "ORD", cancellationToken),
                CustomerId = occurrence.CustomerId,
                RiderId = occurrence.AssignedRiderId,
                DeliveryDate = occurrence.ServiceDate,
                Window = window,
                EstimatedValue = schedule.Lines.Sum(line => (single ? occurrence.Quantity : line.Quantity) * line.Product.UnitPrice),
                Notes = Trim(string.Join(" ", new[] { schedule.Instructions, schedule.Lines.Sum(line => line.ExpectedEmpties) > 0 ? $"Expected empty returns: {schedule.Lines.Sum(line => line.ExpectedEmpties)}." : null }.Where(part => !string.IsNullOrWhiteSpace(part))), 300),
                ShowOnManifest = true,
                Origin = OrderOrigin.Hq,
                Status = CustomerOrderStatus.Scheduled,
                Lines = schedule.Lines.Select(line => new OrderLine
                {
                    ProductId = line.ProductId,
                    Quantity = single ? occurrence.Quantity : line.Quantity,
                    UnitPrice = line.Product.UnitPrice
                }).ToList(),
                Lifecycle =
                [
                    new OrderLifecycleEvent
                    {
                        EventCode = "OrderCreated",
                        Title = "Published from a recurring schedule",
                        Detail = schedule.ScheduleCode,
                        ActorUserId = _current.UserId
                    }
                ]
            };
            _db.CustomerOrders.Add(order);
            await AssignedRouteStop.EnsureAsync(_db, routeId, occurrence.CustomerId, occurrence.ServiceDate, cancellationToken);
            occurrence.OrderId = order.Id;
            occurrence.Status = OccurrenceStatus.Published;
            occurrence.FailureReason = null;
            occurrence.UpdatedAt = DateTime.UtcNow;
            _db.SchedulePublicationLogs.Add(new SchedulePublicationLog { OccurrenceId = occurrence.Id, RiderId = occurrence.AssignedRiderId, Status = "Published", Attempt = 1 });
            await NotifyAsync(occurrence.AssignedRiderId, "Delivery published", $"{schedule.Customer.BusinessName} · {occurrence.Quantity} units · {occurrence.ServiceDate:yyyy-MM-dd}", $"publish:{occurrence.Id:N}", cancellationToken);
        }
    }

    private async Task EnsureRangeAsync(RecurringSchedule schedule, DateOnly from, DateOnly to, CancellationToken cancellationToken)
    {
        var blocked = OpenBlocks(schedule);
        var input = InputOf(schedule, blocked);
        var existing = schedule.Occurrences.Select(item => item.ServiceDate).ToHashSet();
        foreach (var date in RecurrenceEngine.Dates(input, from, to))
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
                AddressSnapshot = VisitAddress(schedule)
            };
            schedule.Occurrences.Add(occurrence);
            _db.DeliveryOccurrences.Add(occurrence);
            existing.Add(date);
        }

        await Task.CompletedTask;
    }

    private async Task ReconcileAsync(RecurringSchedule schedule, CancellationToken cancellationToken)
    {
        var today = LocalDate(schedule);
        var blocked = OpenBlocks(schedule);
        var blockedDays = blocked.ToHashSet();
        var input = InputOf(schedule, blocked);
        foreach (var occurrence in schedule.Occurrences.Where(item => !item.Detached && item.ServiceDate >= today && item.Status != OccurrenceStatus.Completed && item.Status != OccurrenceStatus.Skipped))
        {
            var matches = RecurrenceEngine.Matches(input, occurrence.ServiceDate) && !blockedDays.Contains(occurrence.ServiceDate);
            if (matches && occurrence.Status == OccurrenceStatus.Cancelled)
            {
                occurrence.Status = OccurrenceStatus.Scheduled;
                occurrence.UpdatedAt = DateTime.UtcNow;
            }
            else if (!matches && occurrence.Status is OccurrenceStatus.Scheduled or OccurrenceStatus.Published)
            {
                occurrence.Status = OccurrenceStatus.Cancelled;
                occurrence.UpdatedAt = DateTime.UtcNow;
                await CancelOrderAsync(occurrence, "Removed because the schedule rule changed.", cancellationToken);
            }
        }
    }

    private async Task CancelOccurrencesAsync(RecurringSchedule schedule, DateOnly start, DateOnly end, string reason, bool includePublished, CancellationToken cancellationToken)
    {
        foreach (var occurrence in schedule.Occurrences.Where(item => item.ServiceDate >= start && item.ServiceDate <= end && (item.Status == OccurrenceStatus.Scheduled || (includePublished && item.Status == OccurrenceStatus.Published))))
        {
            occurrence.Status = OccurrenceStatus.Cancelled;
            occurrence.UpdatedAt = DateTime.UtcNow;
            await CancelOrderAsync(occurrence, reason, cancellationToken);
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
        var other = await _db.CustomerOrders.AnyAsync(item => item.CustomerId == order.CustomerId && item.DeliveryDate == order.DeliveryDate && item.Id != order.Id && (item.Status == CustomerOrderStatus.Scheduled || item.Status == CustomerOrderStatus.InProgress), cancellationToken);
        if (!other)
        {
            var stop = await _db.RouteStops.FirstOrDefaultAsync(item => item.CustomerId == order.CustomerId && item.ServiceDate == order.DeliveryDate && item.Status == StopStatus.Pending, cancellationToken);
            if (stop is not null) stop.Status = StopStatus.Missed;
        }
    }

    private async Task<ServiceResult<ScheduleCalendarItemDto>> ChangeOccurrenceAsync(Guid id, Func<DeliveryOccurrence, Task<string?>> change, CancellationToken cancellationToken)
    {
        var occurrence = await _db.DeliveryOccurrences
            .Include(item => item.Schedule).ThenInclude(item => item.Customer)
            .Include(item => item.Schedule).ThenInclude(item => item.Lines).ThenInclude(line => line.Product)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (occurrence is null) return ServiceResult<ScheduleCalendarItemDto>.Fail(404, "Delivery not found.");
        var error = await change(occurrence);
        if (error is not null) return ServiceResult<ScheduleCalendarItemDto>.Fail(400, error);
        occurrence.UpdatedAt = DateTime.UtcNow;
        AddAudit("ChangeOccurrence", occurrence.ScheduleId);
        await _db.SaveChangesAsync(cancellationToken);
        var names = await RiderNamesAsync(occurrence.AssignedRiderId is null ? [] : [occurrence.AssignedRiderId], cancellationToken);
        return ServiceResult<ScheduleCalendarItemDto>.Ok(ToItem(occurrence, names), "Delivery updated.");
    }

    private IQueryable<RecurringSchedule> Filtered(string? search, string? tab, Guid? depotId, Guid? productId, string? riderId)
    {
        var query = _db.RecurringSchedules.AsNoTracking();
        var today = DateOnly.FromDateTime(DateTime.Today);
        query = (tab ?? "all").Trim().ToLowerInvariant() switch
        {
            "weekly" => query.Where(item => item.Frequency == ScheduleFrequency.Weekly),
            "monthly" => query.Where(item => item.Frequency == ScheduleFrequency.Monthly),
            "paused" => query.Where(item => item.Status == ScheduleStatus.Paused),
            "expiring" => query.Where(item => item.Status == ScheduleStatus.Active && item.EndDate != null && item.EndDate <= today.AddDays(14)),
            "exceptions" => query.Where(item => item.Exceptions.Any(exception => exception.Status == "Open")),
            "unassigned" => query.Where(item => item.Status == ScheduleStatus.Active && (item.DefaultRiderId == null || item.DefaultRiderId == "")),
            _ => query
        };
        if (depotId is Guid depot) query = query.Where(item => item.DepotId == depot);
        if (productId is Guid product) query = query.Where(item => item.Lines.Any(line => line.ProductId == product));
        if (!string.IsNullOrWhiteSpace(riderId)) query = query.Where(item => item.DefaultRiderId == riderId.Trim());
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.ScheduleCode.Contains(term)
                || item.Customer.BusinessName.Contains(term)
                || item.Customer.Code.Contains(term)
                || item.Customer.PrimaryMobile.Contains(term)
                || _db.Users.Any(user => user.Id == item.DefaultRiderId && (user.FullName.Contains(term) || (user.RiderCode != null && user.RiderCode.Contains(term)))));
        }

        return query;
    }

    private async Task<RecurringSchedule?> LoadAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.RecurringSchedules.AsNoTracking()
            .Include(item => item.Customer).ThenInclude(item => item.Route).ThenInclude(item => item.Zone)
            .Include(item => item.Depot)
            .Include(item => item.Lines).ThenInclude(line => line.Product)
            .Include(item => item.MonthDays)
            .Include(item => item.CustomDates)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

    private async Task<RecurringSchedule?> LoadTrackedAsync(Guid id, CancellationToken cancellationToken) =>
        await _db.RecurringSchedules
            .Include(item => item.Customer)
            .Include(item => item.Lines)
            .Include(item => item.MonthDays)
            .Include(item => item.CustomDates)
            .Include(item => item.Exceptions)
            .Include(item => item.Occurrences)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

    private async Task<RecurringScheduleDetailDto> ToDetailAsync(RecurringSchedule schedule, CancellationToken cancellationToken)
    {
        ApplicationUser? rider = null;
        if (!string.IsNullOrWhiteSpace(schedule.DefaultRiderId))
        {
            rider = await _db.Users.AsNoTracking().FirstOrDefaultAsync(item => item.Id == schedule.DefaultRiderId, cancellationToken);
        }

        var shiftOpen = rider is not null && await _db.Shifts.AnyAsync(item => item.RiderId == rider.Id && item.Status == "Open", cancellationToken);
        var today = LocalDate(schedule);
        var workload = rider is null ? 0 : await _db.DeliveryOccurrences.CountAsync(item => item.AssignedRiderId == rider.Id && item.ServiceDate == today && (item.Status == OccurrenceStatus.Scheduled || item.Status == OccurrenceStatus.Published), cancellationToken);
        var monthStart = new DateOnly(today.Year, today.Month, 1);
        var dates = RecurrenceEngine.Dates(InputOf(schedule, OpenBlocks(schedule)), monthStart, monthStart.AddMonths(1).AddDays(-1));
        var quantity = schedule.Lines.Sum(line => line.Quantity);
        return new RecurringScheduleDetailDto(
            schedule.Id,
            schedule.ScheduleCode,
            schedule.Status,
            schedule.Version,
            schedule.CustomerId,
            schedule.Customer.BusinessName,
            schedule.Customer.Code,
            schedule.Customer.PrimaryMobile,
            Address(schedule.Customer),
            schedule.Customer.Latitude,
            schedule.Customer.Longitude,
            schedule.Customer.Route?.Name ?? "",
            schedule.Depot?.Name ?? "",
            schedule.DepotId,
            schedule.DefaultRiderId,
            rider?.FullName,
            rider?.RiderCode,
            rider?.IsActive ?? false,
            shiftOpen,
            workload,
            schedule.Frequency,
            schedule.Interval,
            Weekdays(schedule.WeekdayMask),
            schedule.MonthDays.Select(day => day.Day).OrderBy(day => day).ToList(),
            schedule.CustomDates.Select(day => day.ServiceDate).OrderBy(day => day).ToList(),
            schedule.StartDate,
            schedule.EndDate,
            schedule.TimeWindow,
            schedule.TimeZoneId,
            schedule.AutoPublish,
            schedule.PublicationTime.ToString("HH:mm"),
            schedule.AssignmentMode,
            schedule.Instructions,
            dates.Count,
            dates.Count * quantity,
            schedule.Lines.Select(line => new ScheduleLineDto(line.ProductId, line.Product.Name, line.Product.Sku, line.Product.UnitLabel, line.Quantity, line.ExpectedEmpties, line.Product.UnitPrice)).ToList(),
            schedule.Exceptions.OrderByDescending(item => item.CreatedAt).Select(item => new ScheduleExceptionDto(item.Id, item.ExceptionType, item.StartDate, item.EndDate, item.Reason, item.Status)).ToList(),
            "A month day that the month does not contain is skipped.");
    }

    private static RecurringScheduleRowDto ToRow(RecurringSchedule item, (string Name, string Code)? rider, DateOnly? next, int monthly) =>
        new(
            item.Id,
            item.ScheduleCode,
            item.CustomerId,
            item.Customer.BusinessName,
            item.Customer.Code,
            item.Customer.PrimaryMobile,
            Address(item.Customer),
            ProductSummary(item),
            item.Lines.Sum(line => line.Quantity),
            item.Frequency,
            monthly,
            item.DefaultRiderId,
            rider?.Name,
            rider?.Code,
            next,
            item.Status,
            item.Version);

    private static ScheduleCalendarItemDto ToItem(DeliveryOccurrence item, Dictionary<string, (string Name, string Code)> names)
    {
        names.TryGetValue(item.AssignedRiderId ?? "", out var rider);
        return new ScheduleCalendarItemDto(
            item.Id,
            item.ScheduleId,
            item.Schedule.ScheduleCode,
            item.Schedule.Customer.BusinessName,
            item.Schedule.Customer.Code,
            Address(item.Schedule.Customer),
            ProductSummary(item.Schedule),
            item.Quantity,
            item.TimeWindow,
            item.AssignedRiderId,
            rider.Name,
            rider.Code,
            item.Status);
    }

    private static (RecurrenceInput? Input, string? Error) BuildInput(SaveScheduleRequest request, IReadOnlyList<DateOnly> blocked)
    {
        var frequency = request.Frequency.Trim();
        if (frequency is not (ScheduleFrequency.Weekly or ScheduleFrequency.Monthly or ScheduleFrequency.Custom))
        {
            return (null, "Choose a weekly, monthly, or custom schedule.");
        }

        if (request.EndDate is DateOnly end && end < request.StartDate) return (null, "The end date is before the start date.");
        var mask = 0;
        foreach (var day in request.Weekdays.Distinct())
        {
            if (day is < 0 or > 6) return (null, "Weekdays must be 0 (Sunday) through 6 (Saturday).");
            mask |= 1 << day;
        }

        var monthDays = request.MonthDays.Distinct().ToList();
        if (monthDays.Any(day => day is < 1 or > 31)) return (null, "Month days must be from 1 to 31.");
        if (frequency == ScheduleFrequency.Weekly && mask == 0) return (null, "Choose at least one weekday.");
        if (frequency == ScheduleFrequency.Monthly && monthDays.Count == 0) return (null, "Choose at least one day of the month.");
        if (frequency == ScheduleFrequency.Custom && request.CustomDates.Count == 0) return (null, "Choose at least one date.");
        var interval = frequency == ScheduleFrequency.Weekly ? Math.Clamp(request.Interval, 1, 8) : 1;
        return (new RecurrenceInput(frequency, interval, mask, monthDays, request.CustomDates.Distinct().ToList(), request.StartDate, request.EndDate, blocked), null);
    }

    private static RecurrenceInput InputOf(RecurringSchedule schedule, IReadOnlyList<DateOnly> blocked) =>
        new(
            schedule.Frequency,
            schedule.Interval,
            schedule.WeekdayMask,
            schedule.MonthDays.Select(day => day.Day).ToList(),
            schedule.CustomDates.Select(day => day.ServiceDate).ToList(),
            schedule.StartDate,
            schedule.EndDate,
            blocked);

    private static List<DateOnly> OpenBlocks(RecurringSchedule schedule)
    {
        var dates = new List<DateOnly>();
        foreach (var exception in schedule.Exceptions.Where(item => item.Status == "Open"))
        {
            for (var day = exception.StartDate; day <= exception.EndDate; day = day.AddDays(1)) dates.Add(day);
        }

        return dates;
    }

    private async Task<(List<RecurringScheduleLine>? Lines, string? Error)> LinesAsync(List<ScheduleLineRequest> requested, CancellationToken cancellationToken)
    {
        var usable = requested.Where(line => line.Quantity > 0).ToList();
        if (usable.Count == 0) return (null, "Add at least one product.");
        var ids = usable.Select(line => line.ProductId).Distinct().ToList();
        var products = await _db.Products.Where(product => ids.Contains(product.Id)).Select(product => product.Id).ToListAsync(cancellationToken);
        if (products.Count != ids.Count) return (null, "One or more products are not available.");
        return (usable.Select(line => new RecurringScheduleLine { ProductId = line.ProductId, Quantity = line.Quantity, ExpectedEmpties = Math.Max(0, line.ExpectedEmpties) }).ToList(), null);
    }

    private void ReplaceChildren(RecurringSchedule schedule, SaveScheduleRequest request, List<RecurringScheduleLine> lines)
    {
        var incoming = lines.ToDictionary(line => line.ProductId);
        foreach (var existing in schedule.Lines.ToList())
        {
            if (!incoming.TryGetValue(existing.ProductId, out var next))
            {
                _db.RecurringScheduleLines.Remove(existing);
                continue;
            }

            existing.Quantity = next.Quantity;
            existing.ExpectedEmpties = next.ExpectedEmpties;
            incoming.Remove(existing.ProductId);
        }

        foreach (var line in incoming.Values)
        {
            line.ScheduleId = schedule.Id;
            schedule.Lines.Add(line);
            _db.RecurringScheduleLines.Add(line);
        }

        foreach (var day in schedule.MonthDays.ToList()) _db.RecurringScheduleMonthDays.Remove(day);
        foreach (var date in schedule.CustomDates.ToList()) _db.RecurringScheduleCustomDates.Remove(date);
        foreach (var day in request.MonthDays.Distinct().Where(day => day is >= 1 and <= 31))
        {
            var row = new RecurringScheduleMonthDay { ScheduleId = schedule.Id, Day = day };
            schedule.MonthDays.Add(row);
            _db.RecurringScheduleMonthDays.Add(row);
        }

        foreach (var date in request.CustomDates.Distinct())
        {
            var row = new RecurringScheduleCustomDate { ScheduleId = schedule.Id, ServiceDate = date };
            schedule.CustomDates.Add(row);
            _db.RecurringScheduleCustomDates.Add(row);
        }
    }

    private async Task<(int Status, string Message)?> RiderAllowedAsync(string? riderId, Guid depotId, bool required, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(riderId))
        {
            return required ? (400, "Choose a rider before activating the schedule.") : null;
        }

        var roleId = await _db.Roles.AsNoTracking().Where(role => role.Name == AppRoles.Rider).Select(role => role.Id).FirstOrDefaultAsync(cancellationToken);
        var rider = await _db.Users.FirstOrDefaultAsync(item => item.Id == riderId.Trim(), cancellationToken);
        var isRider = rider is not null && roleId is not null && await _db.UserRoles.AnyAsync(link => link.UserId == rider.Id && link.RoleId == roleId, cancellationToken);
        if (!isRider) return (404, "Rider not found.");
        if (!rider!.IsActive) return (400, "An inactive rider cannot receive a new assignment.");
        if (rider.DepotId != depotId) return (400, "This rider is assigned to a different warehouse than the customer's route.");
        return null;
    }

    private async Task<string?> OverlapsAsync(Guid? id, Guid customerId, SaveScheduleRequest request, CancellationToken cancellationToken)
    {
        var productIds = request.Lines.Where(line => line.Quantity > 0).Select(line => line.ProductId).ToHashSet();
        var others = await _db.RecurringSchedules.AsNoTracking().Include(item => item.Lines)
            .Where(item => item.CustomerId == customerId && item.Status == ScheduleStatus.Active && item.Id != id)
            .ToListAsync(cancellationToken);
        foreach (var other in others)
        {
            if (other.EndDate is DateOnly end && end < request.StartDate) continue;
            if (request.EndDate is DateOnly requestEnd && other.StartDate > requestEnd) continue;
            if (other.Lines.Any(line => productIds.Contains(line.ProductId)))
            {
                return $"This customer already has active schedule {other.ScheduleCode} for the same product.";
            }
        }

        return null;
    }

    private async Task<Dictionary<string, (string Name, string Code)>> RiderNamesAsync(IReadOnlyList<string> ids, CancellationToken cancellationToken)
    {
        if (ids.Count == 0) return [];
        var rows = await _db.Users.AsNoTracking().Where(user => ids.Contains(user.Id)).Select(user => new { user.Id, user.FullName, user.RiderCode }).ToListAsync(cancellationToken);
        return rows.ToDictionary(row => row.Id, row => (row.FullName, row.RiderCode ?? ""));
    }

    private async Task NotifyAsync(string? riderId, string title, string body, string key, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(riderId)) return;
        if (await _db.RiderInAppNotifications.AnyAsync(item => item.IdempotencyKey == key, cancellationToken)) return;
        _db.RiderInAppNotifications.Add(new RiderInAppNotification
        {
            RiderUserId = riderId,
            Title = Trim(title, 160) ?? title,
            Body = Trim(body, 500) ?? body,
            DeepLink = "todo",
            IdempotencyKey = key
        });
    }

    private async Task<string> NextCodeAsync(string name, string prefix, CancellationToken cancellationToken)
    {
        var sequence = await _db.NumberSequences.FirstOrDefaultAsync(item => item.Name == name, cancellationToken);
        if (sequence is null)
        {
            sequence = new NumberSequence { Name = name, NextValue = 1 };
            _db.NumberSequences.Add(sequence);
        }

        var value = sequence.NextValue++;
        return $"{prefix}-{DateTime.Today:yyyyMMdd}-{value:0000}";
    }

    private void AddAudit(string action, Guid id)
    {
        _db.AuditLogs.Add(new AuditLog { UserId = _current.UserId ?? "", Action = action, EntityName = "RecurringSchedule", EntityId = id.ToString() });
    }

    private static List<int> Weekdays(int mask)
    {
        var days = new List<int>();
        for (var day = 0; day <= 6; day++)
        {
            if ((mask & (1 << day)) != 0) days.Add(day);
        }

        return days;
    }

    private static DateOnly LocalDate(RecurringSchedule schedule) =>
        DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTime.UtcNow, Zone(schedule.TimeZoneId)));

    private static TimeZoneInfo Zone(string id)
    {
        foreach (var candidate in new[] { id, "Asia/Karachi", "Pakistan Standard Time" })
        {
            if (string.IsNullOrWhiteSpace(candidate)) continue;
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(candidate);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        return TimeZoneInfo.Local;
    }

    private static string? VisitAddress(RecurringSchedule schedule)
    {
        if (!string.IsNullOrWhiteSpace(schedule.DeliveryStreet) || !string.IsNullOrWhiteSpace(schedule.DeliveryArea) || !string.IsNullOrWhiteSpace(schedule.DeliveryCity))
        {
            var line = string.Join(", ", new[] { schedule.DeliveryStreet, schedule.DeliveryArea, schedule.DeliveryCity }.Where(item => !string.IsNullOrWhiteSpace(item)));
            return line.Length <= 300 ? line : line[..300];
        }

        return AddressLine(schedule.Customer);
    }

    private static string? AddressLine(Customer? customer)
    {
        if (customer is null) return null;
        var line = string.Join(", ", new[] { customer.Street, customer.Area, customer.City }.Where(item => !string.IsNullOrWhiteSpace(item)));
        return line.Length <= 300 ? line : line[..300];
    }

    private static string ProductSummary(RecurringSchedule schedule)
    {
        var names = schedule.Lines.Select(line => $"{line.Product?.Name ?? "Product"} x {line.Quantity}").ToList();
        return names.Count == 0 ? "No product" : string.Join(", ", names);
    }

    private static string Address(Customer customer) =>
        string.Join(", ", new[] { customer.Street, customer.Area, customer.City }.Where(part => !string.IsNullOrWhiteSpace(part)));

    private static string? Trim(string? value, int length)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var text = value.Trim();
        return text.Length <= length ? text : text[..length];
    }
}
