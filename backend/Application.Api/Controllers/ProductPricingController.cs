using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/products")]
public sealed class ProductPricingController : ControllerBase
{
    private readonly IProductPricingService _pricing;

    public ProductPricingController(IProductPricingService pricing)
    {
        _pricing = pricing;
    }

    [HttpGet("pricing/coverage")]
    public async Task<IActionResult> Coverage(CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.CoverageAsync(cancellationToken));

    [HttpGet("categories")]
    public async Task<IActionResult> Categories(CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.CategoriesAsync(cancellationToken));

    [HttpGet("catalogue")]
    public async Task<IActionResult> Catalogue(
        string? categoryKey,
        string? search,
        string? status,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _pricing.CatalogueAsync(categoryKey, search, status, page, pageSize, cancellationToken));

    [HttpGet("base-prices")]
    public async Task<IActionResult> BasePrices(
        string? categoryKey,
        string? search,
        string? status,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _pricing.CatalogueAsync(categoryKey, search, status, page, pageSize, cancellationToken));

    [HttpGet("pricing/unpriced")]
    public async Task<IActionResult> Unpriced(CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.UnpricedAsync(cancellationToken));

    [HttpGet("{id:guid}/base-price")]
    public async Task<IActionResult> BasePrice(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.BasePriceAsync(id, cancellationToken));

    [HttpGet("{id:guid}/price-history")]
    public async Task<IActionResult> PriceHistory(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.PriceHistoryAsync(id, cancellationToken));

    [HttpGet("price-lists")]
    public async Task<IActionResult> PriceLists(CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.PriceListsAsync(cancellationToken));

    [HttpGet("price-lists/{id:guid}")]
    public async Task<IActionResult> PriceList(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.PriceListAsync(id, cancellationToken));

    [HttpPost("price-lists")]
    public async Task<IActionResult> CreatePriceList(CreatePriceListRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.CreatePriceListAsync(request, cancellationToken));

    [HttpGet("pricing/validate")]
    public async Task<IActionResult> Validate(Guid productId, int quantity = 1, CancellationToken cancellationToken = default) =>
        ApiResult.From(await _pricing.ValidateAsync(productId, quantity, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/customers")]
public sealed class CustomerPricingController : ControllerBase
{
    private readonly IProductPricingService _pricing;

    public CustomerPricingController(IProductPricingService pricing)
    {
        _pricing = pricing;
    }

    [HttpGet("{id:guid}/base-price-lookup")]
    public async Task<IActionResult> Lookup(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _pricing.CustomerLookupAsync(id, cancellationToken));
}
