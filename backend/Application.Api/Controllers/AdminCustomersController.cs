using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/customers")]
public sealed class AdminCustomersController : ControllerBase
{
    private readonly IAdminCustomerService _customers;

    public AdminCustomersController(IAdminCustomerService customers)
    {
        _customers = customers;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.SummaryAsync(cancellationToken));

    [HttpGet]
    public async Task<IActionResult> List(
        string? search,
        string? status,
        Guid? routeId,
        Guid? zoneId,
        string? area,
        bool? withOutstanding,
        bool? missingGps,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _customers.ListAsync(
            search,
            status,
            routeId,
            zoneId,
            area,
            withOutstanding,
            missingGps,
            page,
            pageSize,
            cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.GetAsync(id, cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create(AdminCustomerWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.CreateAsync(request, cancellationToken));

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, AdminCustomerWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.UpdateAsync(id, request, cancellationToken));

    [HttpPost("{id:guid}/change-route")]
    public async Task<IActionResult> ChangeRoute(Guid id, ChangeCustomerRouteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.ChangeRouteAsync(id, request, cancellationToken));

    [HttpPost("{id:guid}/status")]
    public async Task<IActionResult> SetStatus(Guid id, SetCustomerStatusRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.SetStatusAsync(id, request, cancellationToken));

    [HttpGet("{id:guid}/ledger")]
    public async Task<IActionResult> Ledger(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _customers.LedgerAsync(id, cancellationToken));
}
