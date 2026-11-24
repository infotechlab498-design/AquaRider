using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/rider-operations")]
public sealed class RiderOperationsController : ControllerBase
{
    private readonly IRiderOperationsService _riders;

    public RiderOperationsController(IRiderOperationsService riders)
    {
        _riders = riders;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.SummaryAsync(date, cancellationToken));

    [HttpGet("riders")]
    public async Task<IActionResult> Riders(string? search, string? status, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.RidersAsync(search, status, date, cancellationToken));

    [HttpGet("riders/{id}/activity")]
    public async Task<IActionResult> Activity(string id, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.ActivityAsync(id, cancellationToken));

    [HttpGet("riders/{id}/assignments")]
    public async Task<IActionResult> Assignments(string id, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.AssignmentsAsync(id, date, cancellationToken));

    [HttpGet("riders/{id}")]
    public async Task<IActionResult> Rider(string id, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.RiderAsync(id, date, cancellationToken));

    [HttpGet("exceptions")]
    public async Task<IActionResult> Exceptions(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.ExceptionsAsync(date, cancellationToken));

    [HttpGet("location-verifications")]
    public async Task<IActionResult> LocationVerifications(CancellationToken cancellationToken) =>
        ApiResult.From(await _riders.LocationVerificationsAsync(cancellationToken));
}
