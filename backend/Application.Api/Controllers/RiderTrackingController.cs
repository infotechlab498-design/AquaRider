using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Roles = $"{AppRoles.Rider},{AppRoles.Admin}")]
[Route("api/rider")]
public sealed class RiderTrackingController : ControllerBase
{
    private readonly ILiveTrackingService _tracking;

    public RiderTrackingController(ILiveTrackingService tracking)
    {
        _tracking = tracking;
    }

    [HttpPost("tracking/start")]
    public async Task<IActionResult> Start(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.StartAsync(cancellationToken));

    [HttpPost("tracking/stop")]
    public async Task<IActionResult> Stop([FromBody] TrackingStopRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.StopAsync(request ?? new TrackingStopRequest(null), cancellationToken));

    [HttpPost("tracking/location")]
    public async Task<IActionResult> Location([FromBody] TrackingLocationBatchRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.IngestLocationsAsync(request, cancellationToken));

    [HttpGet("tracking/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.StatusAsync(cancellationToken));

    [HttpGet("assignments/active")]
    public async Task<IActionResult> ActiveAssignment(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.ActiveAssignmentAsync(null, cancellationToken));

    [HttpGet("route-compliance/current")]
    public async Task<IActionResult> Compliance(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.CurrentComplianceAsync(cancellationToken));

    [HttpGet("route-anomalies")]
    public async Task<IActionResult> Anomalies(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.RiderAnomaliesAsync(cancellationToken));

    [HttpPost("route-anomalies/{id:guid}/explanation")]
    public async Task<IActionResult> Explain(Guid id, [FromBody] AnomalyExplanationRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.SubmitExplanationAsync(id, request, cancellationToken));

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.RiderNotificationsAsync(cancellationToken));

    [HttpPost("notifications/{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.MarkNotificationReadAsync(id, cancellationToken));
}
