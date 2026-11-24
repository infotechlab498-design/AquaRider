using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/settlements")]
public sealed class DayCloseSettlementController : ControllerBase
{
    private readonly IDayCloseSettlementService _settlements;

    public DayCloseSettlementController(IDayCloseSettlementService settlements)
    {
        _settlements = settlements;
    }

    [HttpGet("day-close/summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.SummaryAsync(date, cancellationToken));

    [HttpGet("gateway-status")]
    public async Task<IActionResult> Gateway(CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.GatewayStatusAsync(cancellationToken));

    [HttpGet("sessions/status-counts")]
    public async Task<IActionResult> StatusCounts(DateOnly? date, string? search, Guid? routeId, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.StatusCountsAsync(date, search, routeId, cancellationToken));

    [HttpGet("sessions")]
    public async Task<IActionResult> Sessions(
        DateOnly? date,
        string? status,
        string? search,
        Guid? routeId,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _settlements.SessionsAsync(date, status, search, routeId, page, pageSize, cancellationToken));

    [HttpGet("sessions/{id:guid}")]
    public async Task<IActionResult> Session(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.SessionAsync(id, cancellationToken));

    [HttpGet("sessions/{id:guid}/cash-ledger")]
    public async Task<IActionResult> CashLedger(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.CashLedgerAsync(id, cancellationToken));

    [HttpGet("sessions/{id:guid}/stock-reconciliation")]
    public async Task<IActionResult> Stock(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.StockAsync(id, cancellationToken));

    [HttpGet("sessions/{id:guid}/audit-trail")]
    public async Task<IActionResult> Audit(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.AuditTrailAsync(id, cancellationToken));

    [HttpPost("sessions/{id:guid}/save-draft")]
    public async Task<IActionResult> SaveDraft(Guid id, SettlementDraftRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.SaveDraftAsync(id, request, cancellationToken));

    [HttpPost("sessions/{id:guid}/verify-cash")]
    public async Task<IActionResult> VerifyCash(Guid id, VerifyCashRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.VerifyCashAsync(id, request, cancellationToken));

    [HttpPost("sessions/{id:guid}/resolve")]
    public async Task<IActionResult> Resolve(Guid id, ResolveSettlementRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.ResolveAsync(id, request, cancellationToken));

    [HttpGet("days/{date}/lock-readiness")]
    public async Task<IActionResult> LockReadiness(DateOnly date, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.LockReadinessAsync(date, cancellationToken));

    [HttpPost("days/{date}/lock")]
    public async Task<IActionResult> LockDay(DateOnly date, [FromBody] BulkLockRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.LockDayAsync(date, request?.AcknowledgementNote, cancellationToken));

    [HttpPost("days/bulk-lock")]
    public async Task<IActionResult> BulkLock(BulkLockRequest? request, CancellationToken cancellationToken) =>
        ApiResult.From(await _settlements.BulkLockAsync(request, cancellationToken));
}
