using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/collections")]
public sealed class AdminCollectionsController : ControllerBase
{
    private readonly IAdminCollectionsService _collections;

    public AdminCollectionsController(IAdminCollectionsService collections)
    {
        _collections = collections;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _collections.SummaryAsync(date, cancellationToken));

    [HttpGet]
    public async Task<IActionResult> List(
        DateOnly? date,
        string? type,
        string? riderId,
        string? search,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _collections.ListAsync(date, type, riderId, search, page, pageSize, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _collections.GetAsync(id, cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Record(AdminRecordCollectionRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _collections.RecordAsync(request, cancellationToken));

    [HttpGet("~/api/admin/receivables/exposure")]
    public async Task<IActionResult> Exposure(CancellationToken cancellationToken) =>
        ApiResult.From(await _collections.ExposureAsync(cancellationToken));
}
