using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using RouteLedger.Api.Http;
using RouteLedger.Application;
using RouteLedger.Infrastructure.Services;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Authorize(Roles = "Customer")]
[Route("api/customer")]
public sealed class CustomerPortalController : ControllerBase
{
    private readonly ICustomerPortalService _portal;
    private readonly IOfficeFlowService _office;

    public CustomerPortalController(ICustomerPortalService portal, IOfficeFlowService office)
    {
        _portal = portal;
        _office = office;
    }

    [HttpGet("home")]
    public async Task<IActionResult> Home(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.HomeAsync(cancellationToken));

    [HttpGet("schedules")]
    public async Task<IActionResult> Schedules(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.SchedulesAsync(cancellationToken));

    [HttpGet("schedules/{id:guid}/calendar")]
    public async Task<IActionResult> Calendar(Guid id, int year, int month, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.CalendarAsync(id, year, month, cancellationToken));

    [HttpGet("history")]
    public async Task<IActionResult> History(Guid? scheduleId, string? status, DateOnly? from, DateOnly? to, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.HistoryAsync(scheduleId, status, from, to, cancellationToken));

    [HttpGet("payments")]
    public async Task<IActionResult> Payments(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.PaymentsAsync(cancellationToken));

    [HttpGet("invoices/{number}")]
    public async Task<IActionResult> Invoice(string number, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.InvoiceAsync(number, cancellationToken));

    [HttpGet("invoices/{number}/pdf")]
    public async Task<IActionResult> InvoicePdf(string number, CancellationToken cancellationToken)
    {
        var owned = await _portal.InvoiceAsync(number, cancellationToken);
        if (!owned.Success) return ApiResult.From(owned);
        return ApiResult.From(await _office.InvoicePdfAsync(number, cancellationToken));
    }

    [HttpGet("requests")]
    public async Task<IActionResult> Requests(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.RequestsAsync(cancellationToken));

    [HttpGet("requests/{id:guid}")]
    public async Task<IActionResult> GetRequest(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.RequestAsync(id, cancellationToken));

    [EnableRateLimiting("auth")]
    [HttpPost("requests")]
    public async Task<IActionResult> Submit(SubmitCustomerRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.SubmitAsync(request, cancellationToken));

    [HttpPost("requests/preview")]
    public async Task<IActionResult> Preview(SubmitCustomerRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.PreviewAsync(request, cancellationToken));

    [HttpPost("requests/{id:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.CancelAsync(id, cancellationToken));

    [HttpPost("requests/{id:guid}/reply")]
    public async Task<IActionResult> Reply(Guid id, CustomerRequestReply request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReplyAsync(id, request.Notes, cancellationToken));

    [HttpGet("profile")]
    public async Task<IActionResult> Profile(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ProfileAsync(cancellationToken));

    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile(UpdateCustomerProfileRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.UpdateProfileAsync(request, cancellationToken));

    [HttpPost("addresses")]
    public async Task<IActionResult> AddAddress(SaveCustomerAddressRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.SaveAddressAsync(null, request, cancellationToken));

    [HttpPut("addresses/{id:guid}")]
    public async Task<IActionResult> EditAddress(Guid id, SaveCustomerAddressRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.SaveAddressAsync(id, request, cancellationToken));

    [HttpPost("addresses/{id:guid}/default")]
    public async Task<IActionResult> DefaultAddress(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.DefaultAddressAsync(id, cancellationToken));

    [HttpPost("addresses/{id:guid}/deactivate")]
    public async Task<IActionResult> DeactivateAddress(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.DeactivateAddressAsync(id, cancellationToken));

    [HttpGet("notifications")]
    public async Task<IActionResult> Notifications(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.NotificationsAsync(cancellationToken));

    [HttpPost("notifications/read-all")]
    public async Task<IActionResult> ReadAllNotifications(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReadAllNotificationsAsync(cancellationToken));

    [HttpPost("notifications/{id:guid}/read")]
    public async Task<IActionResult> ReadNotification(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReadNotificationAsync(id, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/customer-accounts")]
public sealed class CustomerAccountAdminController : ControllerBase
{
    private readonly ICustomerPortalService _portal;

    public CustomerAccountAdminController(ICustomerPortalService portal)
    {
        _portal = portal;
    }

    [HttpGet("overview")]
    public async Task<IActionResult> Overview(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.OverviewAsync(cancellationToken));

    [HttpGet]
    public async Task<IActionResult> Board(string? search, string? status, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.AccountBoardAsync(search, status, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Detail(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.AccountAsync(id, cancellationToken));

    [HttpPatch("{id:guid}/link")]
    public async Task<IActionResult> Link(Guid id, LinkCustomerAccountRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.LinkAsync(id, request.DeliveryCustomerId, cancellationToken));

    [HttpGet("unlinked")]
    public async Task<IActionResult> Unlinked(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.UnlinkedAsync(cancellationToken));

    [HttpGet("link-reviews")]
    public async Task<IActionResult> LinkReviews(string? status, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.LinkReviewsAsync(status, cancellationToken));

    [HttpPost("{id:guid}/link-reviews")]
    public async Task<IActionResult> ProposeLink(Guid id, ProposeCustomerLinkRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ProposeLinkAsync(id, request.Email, request.CustomerCode, cancellationToken));

    [HttpPost("link-reviews/{id:guid}/review")]
    public async Task<IActionResult> ReviewLink(Guid id, ReviewCustomerLinkRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReviewLinkAsync(id, request.Action, request.Comment, cancellationToken));

    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> Status(Guid id, CustomerAccountStatusRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.SetStatusAsync(id, request.Status, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/admin/customer-requests")]
public sealed class CustomerRequestAdminController : ControllerBase
{
    private readonly ICustomerPortalService _portal;

    public CustomerRequestAdminController(ICustomerPortalService portal)
    {
        _portal = portal;
    }

    [HttpGet]
    public async Task<IActionResult> Queue(string? type, string? status, string? search, string? city, DateOnly? submittedFrom, DateOnly? submittedTo, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.QueueAsync(type, status, search, city, submittedFrom, submittedTo, cancellationToken));

    [HttpGet("notices")]
    public async Task<IActionResult> Notices(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.NoticesAsync(cancellationToken));

    [HttpPost("notices/read")]
    public async Task<IActionResult> ReadNotices(CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReadNoticesAsync(cancellationToken));

    [HttpGet("{id:guid}/impact")]
    public async Task<IActionResult> Impact(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ImpactAsync(id, cancellationToken));

    [HttpPost("{id:guid}/review")]
    public async Task<IActionResult> Review(Guid id, ReviewCustomerRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _portal.ReviewAsync(id, request, cancellationToken));
}
