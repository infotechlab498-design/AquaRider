using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

namespace RouteLedger.Api.Http;

public sealed class ScreenAccessMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, AppDbContext db)
    {
        var screen = AdminScreens.ForPath(context.Request.Path.Value ?? "");
        if (screen is null || context.User.Identity?.IsAuthenticated != true)
        {
            await next(context);
            return;
        }

        var roles = context.User.FindAll(ClaimTypes.Role).Select(claim => claim.Value).ToArray();
        if (roles.Any(role => role.Equals(AppRoles.Admin, StringComparison.OrdinalIgnoreCase)))
        {
            await next(context);
            return;
        }

        var allowed = await db.RoleScreenGrants.AsNoTracking()
            .AnyAsync(item => item.ScreenKey == screen && roles.Contains(item.RoleName));
        if (!allowed)
        {
            context.Response.StatusCode = StatusCodes.Status403Forbidden;
            await context.Response.WriteAsJsonAsync(new
            {
                success = false,
                message = "This role cannot open that screen."
            });
            return;
        }

        await next(context);
    }
}
