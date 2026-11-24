using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/depot")]
public sealed class DepotController : ControllerBase
{
    private readonly IDepotOperationsService _depot;

    public DepotController(IDepotOperationsService depot)
    {
        _depot = depot;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.GetAsync(cancellationToken));

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.SummaryAsync(date, cancellationToken));

    [HttpGet("fleet")]
    public async Task<IActionResult> Fleet(CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.FleetAsync(cancellationToken));

    [HttpGet("stock")]
    public async Task<IActionResult> Stock(CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.StockAsync(cancellationToken));

    [HttpPut]
    public async Task<IActionResult> Update(UpdateDepotRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.UpdateAsync(request, cancellationToken));
}
