using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/audit")]
public sealed class AdminSecurityAuditController : ControllerBase
{
    private readonly IAdminSecurityAuditService _audit;

    public AdminSecurityAuditController(IAdminSecurityAuditService audit)
    {
        _audit = audit;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _audit.SummaryAsync(date, cancellationToken));

    [HttpGet("events")]
    public async Task<IActionResult> List(
        DateOnly? date,
        string? category,
        string? search,
        string? outcome,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _audit.ListAsync(date, category, search, outcome, page, pageSize, cancellationToken));

    [HttpGet("events/{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _audit.GetAsync(id, cancellationToken));

    [HttpPost("events/{id:guid}/verify")]
    public async Task<IActionResult> Verify(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _audit.VerifyAsync(id, cancellationToken));

    [HttpGet("export.csv")]
    public async Task<IActionResult> ExportCsv(
        DateOnly? date,
        string? category,
        string? search,
        CancellationToken cancellationToken)
    {
        var result = await _audit.ExportCsvAsync(date, category, search, cancellationToken);
        if (!result.Success || result.Data is null)
        {
            return ApiResult.From(result);
        }

        var bytes = Encoding.UTF8.GetBytes(result.Data);
        return File(bytes, "text/csv", $"audit-log-{DateTime.UtcNow:yyyyMMddHHmmss}.csv");
    }
}
