using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using RouteLedger.Application;
using RouteLedger.Api.Http;
using RouteLedger.Domain;

namespace RouteLedger.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth)
    {
        _auth = auth;
    }

    [AllowAnonymous]
    [HttpGet("login-preview")]
    public async Task<IActionResult> LoginPreview(CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.LoginPreviewAsync(cancellationToken));

    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    [HttpPost("register-customer")]
    public async Task<IActionResult> RegisterCustomer(RegisterCustomerRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.RegisterCustomerAsync(request, cancellationToken));

    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.LoginAsync(request, cancellationToken));

    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    [HttpPost("refresh-token")]
    public async Task<IActionResult> Refresh(RefreshRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.RefreshAsync(request.RefreshToken, cancellationToken));

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.LogoutAsync(request.RefreshToken, cancellationToken));

    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    [HttpPost("forgot-password")]
    public async Task<IActionResult> Forgot(ForgotPasswordRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.ForgotPasswordAsync(request.Username, cancellationToken));

    [AllowAnonymous]
    [EnableRateLimiting("auth")]
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(PasswordResetConfirmRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.ResetPasswordAsync(request, cancellationToken));

    [AllowAnonymous]
    [HttpGet("sso/status")]
    public async Task<IActionResult> SsoStatus(CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.SsoStatusAsync(cancellationToken));

    [HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.MeAsync(cancellationToken));

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _auth.ChangePasswordAsync(request, cancellationToken));
}

[ApiController]
[Authorize(Policy = "Hq")]
[Route("api/users")]
public sealed class UsersController : ControllerBase
{
    private readonly IUserAdminService _users;

    public UsersController(IUserAdminService users)
    {
        _users = users;
    }

    [HttpGet("summary")]
    public async Task<IActionResult> Summary(CancellationToken cancellationToken) =>
        ApiResult.From(await _users.SummaryAsync(cancellationToken));

    [HttpGet("role-reference")]
    public async Task<IActionResult> RoleReference(CancellationToken cancellationToken) =>
        ApiResult.From(await _users.RoleReferenceAsync(cancellationToken));

    [HttpGet("access")]
    public async Task<IActionResult> Access(CancellationToken cancellationToken) =>
        ApiResult.From(await _users.AccessMatrixAsync(cancellationToken));

    [HttpPut("access/{role}")]
    public async Task<IActionResult> SaveAccess(string role, SaveRoleAccessRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.SaveAccessAsync(role, request, cancellationToken));

    [HttpPost("access")]
    public async Task<IActionResult> CreateRole(CreateRoleAccessRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.CreateRoleAsync(request, cancellationToken));

    [HttpPost("access/{role}/members")]
    public async Task<IActionResult> AssignMember(string role, AssignRoleMemberRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.AssignMemberAsync(role, request.UserId, cancellationToken));

    [HttpGet]
    public async Task<IActionResult> List(
        string? search,
        string? role,
        bool? isActive,
        int page = 1,
        int pageSize = 50,
        CancellationToken cancellationToken = default) =>
        ApiResult.From(await _users.ListAsync(search, role, isActive, page, pageSize, cancellationToken));

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.GetAsync(id, cancellationToken));

    [HttpPost]
    public async Task<IActionResult> Create(CreateUserRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.CreateAsync(request, cancellationToken));

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, UpdateUserRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.UpdateAsync(id, request, cancellationToken));

    [HttpPost("{id}/status")]
    public async Task<IActionResult> Status(string id, UserStatusRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.SetStatusAsync(id, request.IsActive, cancellationToken));

    [HttpPost("{id}/reset-password")]
    public async Task<IActionResult> Reset(string id, ResetPasswordRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _users.ResetPasswordAsync(id, request.NewPassword, cancellationToken));
}

[ApiController]
[Authorize(Roles = $"{AppRoles.Rider},{AppRoles.Admin}")]
[Route("api")]
public sealed class FieldController : ControllerBase
{
    private readonly IFieldService _field;

    public FieldController(IFieldService field)
    {
        _field = field;
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(CancellationToken cancellationToken) =>
        ApiResult.From(await _field.DashboardAsync(cancellationToken));

    [HttpGet("stops")]
    public async Task<IActionResult> Stops(string? search, string? filter, int page = 1, int pageSize = 50, CancellationToken cancellationToken = default) =>
        ApiResult.From(await _field.StopsAsync(search, filter, page, pageSize, cancellationToken));

    [HttpPut("stops/sequence")]
    public async Task<IActionResult> SequenceStops(StopSequenceRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.SequenceTodayStopsAsync(request, cancellationToken));

    [HttpGet("customers/{id:guid}")]
    public async Task<IActionResult> Customer(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CustomerAsync(id, cancellationToken));

    [HttpPost("customers")]
    public async Task<IActionResult> CreateCustomer(CustomerWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CreateCustomerAsync(request, cancellationToken));

    [HttpPut("customers/{id:guid}")]
    public async Task<IActionResult> UpdateCustomer(Guid id, CustomerWriteRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.UpdateCustomerAsync(id, request, cancellationToken));

    [HttpGet("customers/{id:guid}/sale-context")]
    public async Task<IActionResult> SaleContext(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.SaleContextAsync(id, cancellationToken));

    [HttpGet("customers/{id:guid}/ledger")]
    public async Task<IActionResult> Ledger(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.LedgerAsync(id, cancellationToken));

    [HttpPost("sales")]
    public async Task<IActionResult> CreateSale(CreateSaleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CreateSaleAsync(request, cancellationToken));

    [HttpPost("sales/{id:guid}/complete")]
    public async Task<IActionResult> CompleteSale(Guid id, CompleteSaleRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CompleteSaleAsync(id, request, cancellationToken));

    [HttpGet("sales/{id:guid}/receipt")]
    public async Task<IActionResult> Receipt(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.ReceiptAsync(id, cancellationToken));

    [HttpPost("receipts/{id:guid}/print")]
    public async Task<IActionResult> Print(Guid id, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.QueuePrintAsync(id, cancellationToken));

    [HttpPost("collections")]
    public async Task<IActionResult> Collect(CreateCollectionRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CreateCollectionAsync(request, cancellationToken));

    [HttpPost("cash-handovers")]
    public async Task<IActionResult> SubmitHandover(SubmitCashHandoverRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.SubmitHandoverAsync(request.BusinessDate, request.DepotId, cancellationToken));

    [HttpPost("customers/{id:guid}/visit")]
    public async Task<IActionResult> Visit(Guid id, VisitOutcomeRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.LogVisitAsync(id, request.Outcome, cancellationToken));

    [HttpPost("orders")]
    public async Task<IActionResult> Order(CreateOrderRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CreateOrderAsync(request, cancellationToken));

    [HttpGet("shifts/current")]
    public async Task<IActionResult> Shift(CancellationToken cancellationToken) =>
        ApiResult.From(await _field.CurrentShiftAsync(cancellationToken));

    [HttpPost("shifts/start")]
    public async Task<IActionResult> Start(StartShiftRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.StartShiftAsync(request, cancellationToken));

    [HttpPost("shifts/end")]
    public async Task<IActionResult> End(EndShiftRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.EndShiftAsync(request, cancellationToken));

    [HttpGet("history")]
    public async Task<IActionResult> History(string? search, DateOnly? date, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.HistoryAsync(search, date, cancellationToken));

    [HttpGet("settings")]
    public async Task<IActionResult> Settings(CancellationToken cancellationToken) =>
        ApiResult.From(await _field.SettingsAsync(cancellationToken));

    [HttpPut("settings")]
    public async Task<IActionResult> UpdateSettings(UpdateSettingsRequest request, CancellationToken cancellationToken) =>
        ApiResult.From(await _field.UpdateSettingsAsync(request, cancellationToken));

    [HttpGet("printers")]
    public async Task<IActionResult> Printers(CancellationToken cancellationToken) =>
        ApiResult.From(await _field.PrintersAsync(cancellationToken));
}

[ApiController]
[AllowAnonymous]
[Route("verify")]
public sealed class ReceiptVerifyController : ControllerBase
{
    private readonly IFieldService _field;

    public ReceiptVerifyController(IFieldService field)
    {
        _field = field;
    }

    [HttpGet("{number}")]
    public async Task<IActionResult> Get(string number, CancellationToken cancellationToken)
    {
        var page = await _field.VerifyReceiptPageAsync(number, cancellationToken);
        return new ContentResult
        {
            Content = page.Html,
            ContentType = "text/html; charset=utf-8",
            StatusCode = page.Found ? StatusCodes.Status200OK : StatusCodes.Status404NotFound
        };
    }
}

[ApiController]
[AllowAnonymous]
[Route("api/health")]
public sealed class HealthController : ControllerBase
{
    private readonly Infrastructure.Data.AppDbContext _db;

    public HealthController(Infrastructure.Data.AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var connected = await _db.Database.CanConnectAsync(cancellationToken);
        return ApiResult.From(connected
            ? ServiceResult<object>.Ok(new { database = "AquaRider" }, "Database connection succeeded.")
            : ServiceResult<object>.Fail(503, "Database connection failed."));
    }
}
