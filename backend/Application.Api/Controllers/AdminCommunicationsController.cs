using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/communication")]
public sealed class AdminCommunicationsController : ControllerBase
{
    private readonly IAdminCommunicationsService _comms;

    public AdminCommunicationsController(IAdminCommunicationsService comms)
    {
        _comms = comms;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.SummaryAsync(date, cancellationToken));

    [HttpGet("gateway")]
    public async Task<IActionResult> Gateway(CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.GatewayStatusAsync(cancellationToken));

    [HttpPost("gateway/test")]
    public async Task<IActionResult> TestGateway(CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.TestGatewayAsync(cancellationToken));

    [HttpGet("templates")]
    public async Task<IActionResult> ListTemplates(CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.ListTemplatesAsync(cancellationToken));

    [HttpGet("templates/{id:guid}")]
    public async Task<IActionResult> GetTemplate(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.GetTemplateAsync(id, cancellationToken));

    [HttpPost("templates")]
    public async Task<IActionResult> CreateTemplate(
        [FromBody] CommunicationTemplateWriteRequest request,
        CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.CreateTemplateAsync(request, cancellationToken));

    [HttpPut("templates/{id:guid}")]
    public async Task<IActionResult> UpdateTemplate(
        Guid id,
        [FromBody] CommunicationTemplateWriteRequest request,
        CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.UpdateTemplateAsync(id, request, cancellationToken));

    [HttpPost("templates/{id:guid}/activate")]
    public async Task<IActionResult> ActivateTemplate(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.SetTemplateActiveAsync(id, true, cancellationToken));

    [HttpPost("templates/{id:guid}/deactivate")]
    public async Task<IActionResult> DeactivateTemplate(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.SetTemplateActiveAsync(id, false, cancellationToken));

    [HttpPost("templates/{id:guid}/archive")]
    public async Task<IActionResult> ArchiveTemplate(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.ArchiveTemplateAsync(id, cancellationToken));

    [HttpPost("preview")]
    public async Task<IActionResult> Preview(
        [FromBody] CommunicationPreviewRequest request,
        CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.PreviewAsync(request, cancellationToken));

    [HttpGet("triggers")]
    public async Task<IActionResult> Triggers(CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.ListTriggersAsync(cancellationToken));

    [HttpGet("messages")]
    public async Task<IActionResult> ListMessages(
        DateOnly? date,
        string? status,
        string? search,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _comms.ListMessagesAsync(date, status, search, page, pageSize, cancellationToken));

    [HttpGet("messages/{id:guid}")]
    public async Task<IActionResult> GetMessage(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.GetMessageAsync(id, cancellationToken));

    [HttpPost("messages")]
    public async Task<IActionResult> Enqueue(
        [FromBody] CommunicationEnqueueRequest request,
        CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.EnqueueAsync(request, cancellationToken));

    [HttpPost("messages/{id:guid}/retry")]
    public async Task<IActionResult> Retry(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _comms.RetryAsync(id, cancellationToken));

    [HttpGet("messages/export.csv")]
    public async Task<IActionResult> ExportMessages(
        DateOnly? date,
        string? status,
        CancellationToken cancellationToken)
    {
        var result = await _comms.ExportMessagesCsvAsync(date, status, cancellationToken);
        if (!result.Success || result.Data is null)
        {
            return ApiResult.From(result);
        }

        var bytes = Encoding.UTF8.GetBytes(result.Data);
        return File(bytes, "text/csv", $"sms-messages-{DateTime.UtcNow:yyyyMMddHHmmss}.csv");
    }
}
