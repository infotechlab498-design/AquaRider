using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/shifts")]
public sealed class AdminShiftRecordController : ControllerBase
{
    private readonly IAdminShiftRecordService _shifts;

    public AdminShiftRecordController(IAdminShiftRecordService shifts)
    {
        _shifts = shifts;
    }

    [HttpGet]
    public async Task<IActionResult> Day(DateOnly? date, string? riderId, CancellationToken cancellationToken) =>
        ApiResult.From(await _shifts.DayAsync(date, riderId, cancellationToken));
}
