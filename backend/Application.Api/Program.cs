using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using RouteLedger.Application;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;
using RouteLedger.Infrastructure.Services;
using RouteLedger.Api.Http;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("Default");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("ConnectionStrings:Default is not configured.");
}

var jwtKey = builder.Configuration["Jwt:Key"] ?? "";
if (Encoding.UTF8.GetByteCount(jwtKey) < 32)
{
    throw new InvalidOperationException("Jwt:Key must be at least 32 characters. Store it with dotnet user-secrets.");
}

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(connectionString));
builder.Services
    .AddIdentityCore<ApplicationUser>(options =>
    {
        options.Password.RequiredLength = 8;
        options.Password.RequireDigit = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireUppercase = false;
        options.Password.RequireNonAlphanumeric = false;
        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
        options.User.RequireUniqueEmail = true;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddSignInManager()
    .AddDefaultTokenProviders();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
builder.Services.AddAuthorizationBuilder()
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())
    .AddPolicy("Hq", policy => policy.RequireAssertion(context =>
        context.User.IsInRole(RouteLedger.Domain.AppRoles.Admin)
        || context.User.Claims.Any(claim =>
            claim.Type == System.Security.Claims.ClaimTypes.Role
            && !string.Equals(claim.Value, RouteLedger.Domain.AppRoles.Rider, StringComparison.OrdinalIgnoreCase)
            && !string.Equals(claim.Value, RouteLedger.Domain.AppRoles.Admin, StringComparison.OrdinalIgnoreCase)
            && !string.Equals(claim.Value, RouteLedger.Domain.AppRoles.Customer, StringComparison.OrdinalIgnoreCase))));

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, HttpCurrentUser>();
builder.Services.Configure<SsoOptions>(builder.Configuration.GetSection(SsoOptions.SectionName));
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserAdminService, UserAdminService>();
builder.Services.AddScoped<IOnboardingService, OnboardingService>();
builder.Services.AddScoped<IFieldService, FieldService>();
builder.Services.AddScoped<ICommandDashboardService, CommandDashboardService>();
builder.Services.AddScoped<IRiderOperationsService, RiderOperationsService>();
builder.Services.AddScoped<IDispatchOrderService, DispatchOrderService>();
builder.Services.AddScoped<IDayCloseSettlementService, DayCloseSettlementService>();
builder.Services.AddScoped<IProductPricingService, ProductPricingService>();
builder.Services.AddScoped<IZonesRoutesService, ZonesRoutesService>();
builder.Services.AddScoped<IAdminCustomerService, AdminCustomerService>();
builder.Services.AddScoped<IDepotOperationsService, DepotOperationsService>();
builder.Services.AddScoped<IAdminSalesService, AdminSalesService>();
builder.Services.AddScoped<IAdminShiftRecordService, AdminShiftRecordService>();
builder.Services.AddScoped<IRecurringScheduleService, RecurringScheduleService>();
builder.Services.AddScoped<ICustomerPortalService, CustomerPortalService>();
builder.Services.AddScoped<IOfficeFlowService, OfficeFlowService>();
builder.Services.AddHostedService<RecurringScheduleWorker>();
builder.Services.AddScoped<IAdminCollectionsService, AdminCollectionsService>();
builder.Services.AddScoped<IAdminReportsService, AdminReportsService>();
builder.Services.AddScoped<IAdminSecurityAuditService, AdminSecurityAuditService>();
builder.Services.AddScoped<IAdminCommunicationsService, AdminCommunicationsService>();
builder.Services.Configure<FleetTrackingOptions>(builder.Configuration.GetSection(FleetTrackingOptions.SectionName));
builder.Services.AddScoped<ILiveTrackingService, LiveTrackingService>();
builder.Services.AddScoped<DevelopmentSeeder>();

builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddPolicy("clients", policy =>
    {
        if (builder.Environment.IsDevelopment() || origins.Length == 0)
        {
            policy.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin();
        }
        else
        {
            policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("auth", limiter =>
    {
        limiter.PermitLimit = 30;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
});

var app = builder.Build();

app.UseExceptionHandler(handler =>
{
    handler.Run(async context =>
    {
        var logger = context.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("RouteLedger");
        var error = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
        logger.LogError(error, "Unhandled API exception");
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new ApiResponse<object>
        {
            Success = false,
            Message = "The server could not complete this request."
        });
    });
});

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseDefaultFiles();
app.UseStaticFiles();
app.UseCors("clients");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.UseMiddleware<ScreenAccessMiddleware>();
app.MapControllers();
app.MapFallbackToFile("index.html").AllowAnonymous();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
    if (app.Configuration.GetValue("Seed:Enabled", false))
    {
        await scope.ServiceProvider.GetRequiredService<DevelopmentSeeder>().SeedAsync();
    }
}

app.Run();

public partial class Program;

