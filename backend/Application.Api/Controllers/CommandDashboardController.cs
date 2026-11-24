using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/dashboard")]
public sealed class CommandDashboardController : ControllerBase
{
    private readonly ICommandDashboardService _dashboard;

    public CommandDashboardController(ICommandDashboardService dashboard)
    {
        _dashboard = dashboard;
    }

    [HttpGet("overview")]
    public async Task<IActionResult> Overview(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.OverviewAsync(from, to, cancellationToken));

    [HttpGet("kpis")]
    public async Task<IActionResult> Kpis(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.KpisAsync(from, to, cancellationToken));

    [HttpGet("operational-summary")]
    public async Task<IActionResult> OperationalSummary(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.OperationalSummaryAsync(from, to, cancellationToken));

    [HttpGet("attention-items")]
    public async Task<IActionResult> AttentionItems(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.AttentionItemsAsync(from, to, cancellationToken));

    [HttpGet("sales-summary")]
    public async Task<IActionResult> SalesSummary(DateOnly? from, DateOnly? to, string? bucket, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.SalesSummaryAsync(from, to, bucket, cancellationToken));

    [HttpGet("collections-summary")]
    public async Task<IActionResult> CollectionsSummary(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.CollectionsSummaryAsync(from, to, cancellationToken));

    [HttpGet("activity-ledger")]
    public async Task<IActionResult> ActivityLedger(
        DateOnly? from,
        DateOnly? to,
        string? search,
        string? status,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _dashboard.ActivityLedgerAsync(from, to, search, status, page, pageSize, cancellationToken));

    [HttpPost("orders")]
    public async Task<IActionResult> CreateOrder(AdminCreateOrderRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _dashboard.CreateOrderAsync(request, cancellationToken));
}
