using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin")]
public sealed class AdminLiveTrackingController : ControllerBase
{
    private readonly ILiveTrackingService _tracking;

    public AdminLiveTrackingController(ILiveTrackingService tracking)
    {
        _tracking = tracking;
    }

    [HttpGet("live-tracking/overview")]
    public async Task<IActionResult> Overview(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.OverviewAsync(cancellationToken));

    [HttpGet("live-tracking/riders")]
    public async Task<IActionResult> Riders(CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.LiveRidersAsync(cancellationToken));

    [HttpGet("live-tracking/riders/{riderId}")]
    public async Task<IActionResult> Rider(string riderId, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.LiveRiderAsync(riderId, cancellationToken));

    [HttpGet("route-anomalies")]
    public async Task<IActionResult> Anomalies(string? status, string? riderUserId, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.AdminAnomaliesAsync(status, riderUserId, cancellationToken));

    [HttpGet("route-anomalies/{id:guid}")]
    public async Task<IActionResult> Anomaly(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.AdminAnomalyAsync(id, cancellationToken));

    [HttpPost("route-anomalies/{id:guid}/review")]
    public async Task<IActionResult> Review(Guid id, [FromBody] AnomalyReviewRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.ReviewAsync(id, request, cancellationToken));

    [HttpPost("route-anomalies/{id:guid}/query")]
    public async Task<IActionResult> Query(Guid id, [FromBody] AnomalyQueryRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.QueryRiderAsync(id, request, cancellationToken));

    [HttpPost("route-anomalies/{id:guid}/resolve")]
    public async Task<IActionResult> Resolve(Guid id, [FromBody] AnomalyResolveRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _tracking.ResolveAsync(id, request, cancellationToken));
}
