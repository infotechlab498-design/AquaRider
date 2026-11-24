using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/dispatch")]
public sealed class DispatchOrderController : ControllerBase
{
    private readonly IDispatchOrderService _dispatch;

    public DispatchOrderController(IDispatchOrderService dispatch)
    {
        _dispatch = dispatch;
    }

    [HttpGet("orders")]
    public async Task<IActionResult> Orders(
        int page = 1,
        int pageSize = 20,
        string? search = null,
        string? status = null,
        DateOnly? from = null,
        DateOnly? to = null,
        string? riderId = null,
        bool unassignedOnly = false,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _dispatch.OrdersAsync(page, pageSize, search, status, from, to, riderId, unassignedOnly, cancellationToken));

    [HttpGet("orders/summary")]
    public async Task<IActionResult> Summary(
        DateOnly? from,
        DateOnly? to,
        string? search = null,
        string? riderId = null,
        bool unassignedOnly = false,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _dispatch.SummaryAsync(from, to, search, riderId, unassignedOnly, cancellationToken));

    [HttpGet("orders/status-counts")]
    public async Task<IActionResult> StatusCounts(
        DateOnly? from,
        DateOnly? to,
        string? search = null,
        string? riderId = null,
        bool unassignedOnly = false,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _dispatch.StatusCountsAsync(from, to, search, riderId, unassignedOnly, cancellationToken));

    [HttpGet("orders/{id:guid}/items")]
    public async Task<IActionResult> Items(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.ItemsAsync(id, cancellationToken));

    [HttpGet("orders/{id:guid}/lifecycle")]
    public async Task<IActionResult> Lifecycle(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.LifecycleAsync(id, cancellationToken));

    [HttpGet("orders/{id:guid}/picklist")]
    public async Task<IActionResult> PickList(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.PickListAsync(id, cancellationToken));

    [HttpPost("orders/{id:guid}/assign-rider")]
    public async Task<IActionResult> Assign(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.AssignRiderAsync(id, request, cancellationToken));

    [HttpPost("orders/{id:guid}/reassign-rider")]
    public async Task<IActionResult> Reassign(Guid id, AssignRiderRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.ReassignRiderAsync(id, request, cancellationToken));

    [HttpPost("orders/{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancelOrderRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.CancelAsync(id, request, cancellationToken));

    [HttpPost("orders/{id:guid}/prepare-picklist")]
    public async Task<IActionResult> PreparePickList(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.PreparePickListAsync(id, cancellationToken));

    [HttpGet("orders/{id:guid}")]
    public async Task<IActionResult> Order(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.OrderAsync(id, cancellationToken));

    [HttpGet("eligible-riders")]
    public async Task<IActionResult> EligibleRiders(DateOnly? deliveryDate, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.EligibleRidersAsync(deliveryDate, cancellationToken));

    [HttpGet("operational-summary")]
    public async Task<IActionResult> OperationalSummary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _dispatch.OperationalSummaryAsync(date, cancellationToken));
}
