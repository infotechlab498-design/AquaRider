using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Infrastructure.Services;

namespace RouteLedger.Api.Controllers;

[ApiController]
[AllowAnonymous]
[Route("api/policies")]
public sealed class PolicyController : ControllerBase
{
    private readonly ICustomerPortalService _portal;

    public PolicyController(ICustomerPortalService portal)
    {
        _portal = portal;
    }

    [HttpGet("{kind}")]
    public async Task<IActionResult> Get(string kind, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.PolicyAsync(kind, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/office")]
public sealed class OfficeFlowController : ControllerBase
{
    private readonly IOfficeFlowService _office;
    private readonly IProductPricingService _pricing;
    private readonly IDepotOperationsService _depot;

    public OfficeFlowController(IOfficeFlowService office, IProductPricingService pricing, IDepotOperationsService depot)
    {
        _office = office;
        _pricing = pricing;
        _depot = depot;
    }

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken cancellationToken) =>
        ApiResult.From(await _office.SettingsAsync(cancellationToken));

    [HttpPut("settings")]
    public async Task<IActionResult> UpdateSettings(UpdateHqSettingsRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.UpdateSettingsAsync(request, cancellationToken));

    [HttpGet("cash-handovers")]
    public async Task<IActionResult> Handovers(string? status, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.HandoversAsync(status, cancellationToken));

    [HttpPost("cash-handovers/{id:guid}/receive")]
    public async Task<IActionResult> Receive(Guid id, ConfirmCashHandoverRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.ConfirmHandoverAsync(id, request, cancellationToken));

    [HttpGet("documents/invoices/{number}")]
    public async Task<IActionResult> Invoice(string number, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.InvoicePdfAsync(number, cancellationToken));

    [HttpGet("documents/orders/{id:guid}")]
    public async Task<IActionResult> Order(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.OrderPdfAsync(id, cancellationToken));

    [HttpGet("documents/orders/{id:guid}/export.csv")]
    public async Task<IActionResult> OrderCsv(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.OrderCsvAsync(id, cancellationToken));

    [HttpGet("documents/manifests")]
    public async Task<IActionResult> Manifest(Guid routeId, DateOnly date, CancellationToken cancellationToken) =>
        ApiResult.From(await _office.ManifestPdfAsync(routeId, date, cancellationToken));

    [HttpPut("price-lists/{id:guid}")]
    public async Task<IActionResult> UpdatePriceList(Guid id, CreatePriceListRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.UpdatePriceListAsync(id, request, cancellationToken));

    [HttpPost("price-lists/{id:guid}/duplicate")]
    public async Task<IActionResult> DuplicatePriceList(Guid id, DuplicatePriceListRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.DuplicatePriceListAsync(id, request, cancellationToken));

    [HttpPost("price-lists/{id:guid}/assign")]
    public async Task<IActionResult> AssignPriceList(Guid id, AssignPriceListRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.AssignPriceListAsync(id, request, cancellationToken));

    [HttpPost("warehouses")]
    public async Task<IActionResult> CreateWarehouse(CreateWarehouseRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.CreateAsync(request, cancellationToken));

    [HttpPost("inventory-counts")]
    public async Task<IActionResult> Count(InventoryCountRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _depot.CountStockAsync(request, cancellationToken));
}
