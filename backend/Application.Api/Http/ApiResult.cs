using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using RouteLedger.Application;
using RouteLedger.Domain;

namespace RouteLedger.Api.Http;

public static class ApiResult
{
    public static IActionResult From<T>(ServiceResult<T> result)
    {
        var body = new ApiResponse<T>
        {
            Success = result.Success,
            Message = result.Message,
            Data = result.Data,
            Errors = result.Errors,
            Pagination = result.Pagination
        };
        return new ObjectResult(body) { StatusCode = result.StatusCode };
    }
}

public sealed class HttpCurrentUser : ICurrentUser
{
    private readonly IHttpContextAccessor _http;

    public HttpCurrentUser(IHttpContextAccessor http)
    {
        _http = http;
    }

    public string? UserId => _http.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier);

    public bool IsAdmin => _http.HttpContext?.User.IsInRole(AppRoles.Admin) == true;

    public bool IsAuthenticated => _http.HttpContext?.User.Identity?.IsAuthenticated == true;
}
