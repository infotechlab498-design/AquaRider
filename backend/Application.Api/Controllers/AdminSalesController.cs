using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/sales")]
public sealed class AdminSalesController : ControllerBase
{
    private readonly IAdminSalesService _sales;

    public AdminSalesController(IAdminSalesService sales)
    {
        _sales = sales;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _sales.SummaryAsync(date, cancellationToken));

    [HttpGet]
    public async Task<IActionResult> List(
        DateOnly? date,
        string? type,
        string? syncStatus,
        string? riderId,
        string? search,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _sales.ListAsync(date, type, syncStatus, riderId, search, page, pageSize, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _sales.GetAsync(id, cancellationToken));

    [HttpGet("{id:guid}/receipt")]
    public async Task<IActionResult> Receipt(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _sales.ReceiptAsync(id, cancellationToken));

    [HttpPost("drafts")]
    public async Task<IActionResult> CreateDraft(AdminCreateSaleDraftRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _sales.CreateDraftAsync(request, cancellationToken));

    [HttpPost("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id, AdminCompleteSaleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _sales.CompleteAsync(id, request, cancellationToken));
}
