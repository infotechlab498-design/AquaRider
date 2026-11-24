using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api")]
public sealed class ZonesRoutesController : ControllerBase
{
    private readonly IZonesRoutesService _zonesRoutes;

    public ZonesRoutesController(IZonesRoutesService zonesRoutes)
    {
        _zonesRoutes = zonesRoutes;
    }

    [HttpGet("zones/summary")]
    public async Task<IActionResult> Summary(CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.SummaryAsync(cancellationToken));

    [HttpGet("zones")]
    public async Task<IActionResult> ListZones(string? search, bool? activeOnly, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.ListZonesAsync(search, activeOnly, cancellationToken));

    [HttpGet("zones/{id:guid}")]
    public async Task<IActionResult> GetZone(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.GetZoneAsync(id, cancellationToken));

    [HttpPost("zones")]
    public async Task<IActionResult> CreateZone(ZoneWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.CreateZoneAsync(request, cancellationToken));

    [HttpPut("zones/{id:guid}")]
    public async Task<IActionResult> UpdateZone(Guid id, ZoneWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.UpdateZoneAsync(id, request, cancellationToken));

    [HttpDelete("zones/{id:guid}")]
    public async Task<IActionResult> DeactivateZone(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.DeactivateZoneAsync(id, cancellationToken));

    [HttpGet("routes")]
    public async Task<IActionResult> ListRoutes(Guid? zoneId, string? search, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.ListRoutesAsync(zoneId, search, cancellationToken));

    [HttpGet("routes/eligible-riders")]
    public async Task<IActionResult> EligibleRiders(string? search, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.EligibleRidersAsync(search, cancellationToken));

    [HttpGet("routes/{id:guid}")]
    public async Task<IActionResult> GetRoute(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.GetRouteAsync(id, cancellationToken));

    [HttpPost("routes")]
    public async Task<IActionResult> CreateRoute(RouteWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.CreateRouteAsync(request, cancellationToken));

    [HttpPut("routes/{id:guid}")]
    public async Task<IActionResult> UpdateRoute(Guid id, RouteWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.UpdateRouteAsync(id, request, cancellationToken));

    [HttpDelete("routes/{id:guid}")]
    public async Task<IActionResult> DeleteRoute(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.DeleteRouteAsync(id, cancellationToken));

    [HttpPost("routes/{id:guid}/assign-rider")]
    public async Task<IActionResult> AssignRider(Guid id, AssignRouteRiderRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.AssignRiderAsync(id, request, cancellationToken));

    [HttpPost("routes/{id:guid}/unassign-rider")]
    public async Task<IActionResult> UnassignRider(Guid id, AssignRouteRiderRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.UnassignRiderAsync(id, request, cancellationToken));

    [HttpGet("routes/{id:guid}/customers")]
    public async Task<IActionResult> RouteCustomers(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.RouteCustomersAsync(id, cancellationToken));

    [HttpPut("routes/{id:guid}/customers/allocate")]
    public async Task<IActionResult> AllocateCustomers(Guid id, AllocateCustomersRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.AllocateCustomersAsync(id, request, cancellationToken));

    [HttpPut("routes/{id:guid}/customers/sequence")]
    public async Task<IActionResult> SequenceCustomers(Guid id, CustomerSequenceRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.SequenceCustomersAsync(id, request, cancellationToken));

    [HttpGet("routes/{id:guid}/stops")]
    public async Task<IActionResult> Stops(Guid id, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.StopsAsync(id, date, cancellationToken));

    [HttpPost("routes/{id:guid}/stops/ensure")]
    public async Task<IActionResult> EnsureStops(Guid id, EnsureStopsRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.EnsureStopsAsync(id, request, cancellationToken));

    [HttpPut("routes/{id:guid}/stops/sequence")]
    public async Task<IActionResult> SequenceStops(Guid id, StopSequenceRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.SequenceStopsAsync(id, request, cancellationToken));

    [HttpGet("routes/{id:guid}/map-pins")]
    public async Task<IActionResult> MapPins(Guid id, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _zonesRoutes.MapPinsAsync(id, date, cancellationToken));
}
