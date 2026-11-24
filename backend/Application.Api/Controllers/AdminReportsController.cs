using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/reports")]
public sealed class AdminReportsController : ControllerBase
{
    private readonly IAdminReportsService _reports;

    public AdminReportsController(IAdminReportsService reports)
    {
        _reports = reports;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _reports.SummaryAsync(from, to, cancellationToken));

    [HttpGet("catalog")]
    public async Task<IActionResult> Catalog(CancellationToken cancellationToken) =>
        ApiResult.From(await _reports.CatalogAsync(cancellationToken));

    [HttpGet("{key}")]
    public async Task<IActionResult> Run(string key, DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _reports.RunAsync(key, from, to, cancellationToken));

    [HttpGet("{key}/export.csv")]
    public async Task<IActionResult> ExportCsv(string key, DateOnly? from, DateOnly? to, CancellationToken cancellationToken)
    {
        var result = await _reports.ExportCsvAsync(key, from, to, cancellationToken);
        if (!result.Success || result.Data is null)
        {
            return ApiResult.From(result);
        }

        var bytes = Encoding.UTF8.GetBytes(result.Data);
        return File(bytes, "text/csv", $"{key}-{DateTime.UtcNow:yyyyMMddHHmmss}.csv");
    }
}
