using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/recurring-schedules")]
public sealed class RecurringScheduleController : ControllerBase
{
    private readonly IRecurringScheduleService _schedules;

    public RecurringScheduleController(IRecurringScheduleService schedules)
    {
        _schedules = schedules;
    }

    [HttpGet]
    public async Task<IActionResult> Board(string? search, string? tab, Guid? depotId, Guid? productId, string? riderId, int page = 1, int pageSize = 20, CancellationToken cancellationToken = default) =>
        ApiResult.From(await _schedules.BoardAsync(search, tab, depotId, productId, riderId, page, pageSize, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.GetAsync(id, cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create(SaveScheduleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.SaveAsync(null, request, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, SaveScheduleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.SaveAsync(id, request, cancellationToken));

    [HttpPost("preview")]
    public async Task<IActionResult> Preview(SaveScheduleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.PreviewAsync(request, cancellationToken));

    [HttpPatch("{id:guid}/pause")]
    public async Task<IActionResult> Pause(Guid id, PauseScheduleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.PauseAsync(id, request, cancellationToken));

    [HttpPatch("{id:guid}/resume")]
    public async Task<IActionResult> Resume(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.ResumeAsync(id, cancellationToken));

    [HttpPatch("{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, [FromBody] PauseScheduleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.CancelAsync(id, request.Reason, cancellationToken));

    [HttpPost("{id:guid}/duplicate")]
    public async Task<IActionResult> Duplicate(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.DuplicateAsync(id, cancellationToken));

    [HttpGet("calendar")]
    public async Task<IActionResult> Calendar(int year, int month, Guid? scheduleId, string? riderId, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.CalendarAsync(year, month, scheduleId, riderId, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/delivery-occurrences")]
public sealed class DeliveryOccurrenceController : ControllerBase
{
    private readonly IRecurringScheduleService _schedules;

    public DeliveryOccurrenceController(IRecurringScheduleService schedules)
    {
        _schedules = schedules;
    }

    [HttpPatch("{id:guid}/skip")]
    public async Task<IActionResult> Skip(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.SkipAsync(id, cancellationToken));

    [HttpPatch("{id:guid}/reschedule")]
    public async Task<IActionResult> Reschedule(Guid id, OccurrenceDateRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.RescheduleAsync(id, request.Date, cancellationToken));

    [HttpPatch("{id:guid}/reassign-rider")]
    public async Task<IActionResult> Reassign(Guid id, OccurrenceRiderRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.ReassignAsync(id, request.RiderId, cancellationToken));

    [HttpPatch("{id:guid}/quantity")]
    public async Task<IActionResult> Quantity(Guid id, OccurrenceQuantityRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _schedules.ChangeQuantityAsync(id, request.Quantity, cancellationToken));
}
