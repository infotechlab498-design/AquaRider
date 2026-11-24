using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;

[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace RouteLedger.Tests;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public string DatabaseName { get; } = "AquaRider_Test_" + Guid.NewGuid().ToString("N")[..12];

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        var connection = $"Server=localhost\\SQLEXPRESS;Database={DatabaseName};Trusted_Connection=True;TrustServerCertificate=True;";
        builder.UseSetting("ConnectionStrings:Default", connection);
        builder.UseSetting("Jwt:Key", "routeledger-test-key-32-characters-min");
        builder.UseSetting("Jwt:Issuer", "RouteLedger");
        builder.UseSetting("Jwt:Audience", "RouteLedger.Mobile");
        builder.UseSetting("Seed:Enabled", "true");
        builder.UseSetting("Seed:RiderPassword", "routeledger1");
        builder.UseSetting("Seed:AdminPassword", "Admin#2026x");
        builder.UseSetting("Seed:AdminUserName", "admin");
        builder.UseSetting("Seed:AdminEmail", "admin@routeledger.local");
        builder.UseSetting("Seed:AdminFullName", "HQ Super Admin");
        builder.UseEnvironment("Development");
    }

    protected override void Dispose(bool disposing)
    {
        try
        {
            using var scope = Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureDeleted();
        }
        catch
        {
            // The test host may already be stopped.
        }

        base.Dispose(disposing);
    }
}

[CollectionDefinition("api")]
public sealed class ApiCollection : ICollectionFixture<ApiFactory>;

[Collection("api")]
public sealed class ApiTests
{
    private static readonly JsonSerializerOptions Json = CreateJson();

    private static JsonSerializerOptions CreateJson()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }
    private readonly ApiFactory _factory;

    public ApiTests(ApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Health_reaches_sql_server()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Login_rejects_a_wrong_password_and_accepts_the_rider()
    {
        var client = _factory.CreateClient();
        var wrong = await client.PostAsJsonAsync("/api/auth/login", new { username = "ahmed.khan", password = "not-the-password" });
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);

        var ok = await LoginAsync(client, "ahmed.khan", "routeledger1");
        Assert.Equal("Ahmed Khan", ok.User.FullName);
        Assert.False(string.IsNullOrWhiteSpace(ok.AccessToken));
    }

    [Fact]
    public async Task Protected_route_requires_a_token_and_me_returns_the_rider()
    {
        var anonymous = _factory.CreateClient();
        var denied = await anonymous.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, denied.StatusCode);

        var client = await RiderClientAsync();
        var me = await client.GetFromJsonAsync<ApiResponse<AuthUserDto>>("/api/auth/me", Json);
        Assert.Equal("RDR-1042", me!.Data!.RiderCode);
    }

    [Fact]
    public async Task Refresh_rotates_the_token_and_rejects_the_old_one()
    {
        var client = _factory.CreateClient();
        var first = await LoginAsync(client, "ahmed.khan", "routeledger1");
        var refreshed = await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = first.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refreshed.StatusCode);
        var second = (await refreshed.Content.ReadFromJsonAsync<ApiResponse<AuthResponseDto>>(Json))!.Data!;
        Assert.NotEqual(first.RefreshToken, second.RefreshToken);

        var reused = await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = first.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, reused.StatusCode);
    }

    [Fact]
    public async Task Rider_cannot_list_users_and_admin_can_create_one()
    {
        var rider = await RiderClientAsync();
        var forbidden = await rider.GetAsync("/api/users");
        Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);

        var adminClient = _factory.CreateClient();
        var admin = await LoginAsync(adminClient, "admin", "Admin#2026x");
        adminClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", admin.AccessToken);
        var created = await adminClient.PostAsJsonAsync("/api/users", new
        {
            username = "sara.rider",
            password = "routeledger2",
            fullName = "Sara Malik",
            phone = "03001112223",
            riderCode = "RDR-2001",
            role = "Rider"
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);

        var summary = await adminClient.GetFromJsonAsync<ApiResponse<StaffSummaryDto>>("/api/users/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.TotalStaff >= 2);
        Assert.True(summary.Data.ActiveRiders >= 1);
        Assert.True(summary.Data.Admins >= 1);

        var roles = await adminClient.GetFromJsonAsync<ApiResponse<List<RoleReferenceDto>>>("/api/users/role-reference", Json);
        Assert.NotNull(roles?.Data);
        Assert.Equal(2, roles!.Data!.Count);
        Assert.Contains(roles.Data, item => item.Role == "Admin");
        Assert.Contains(roles.Data, item => item.Role == "Rider");

        var filtered = await adminClient.GetFromJsonAsync<ApiResponse<List<UserDto>>>("/api/users?role=Rider&page=1&pageSize=20", Json);
        Assert.NotNull(filtered?.Data);
        Assert.NotEmpty(filtered!.Data!);
        Assert.All(filtered.Data, item => Assert.Contains("Rider", item.Roles));
        Assert.NotNull(filtered.Pagination);
    }

    [Fact]
    public async Task Dashboard_changes_when_a_sale_is_stored()
    {
        var client = await RiderClientAsync();
        var before = await client.GetFromJsonAsync<ApiResponse<DashboardDto>>("/api/dashboard", Json);
        var stops = await client.GetFromJsonAsync<ApiResponse<List<StopDto>>>("/api/stops?search=Ali&pageSize=10", Json);
        var stop = stops!.Data!.Single(item => item.CustomerCode == "CUS-1001");
        var context = await client.GetFromJsonAsync<ApiResponse<SaleContextDto>>($"/api/customers/{stop.CustomerId}/sale-context", Json);
        var bottle = context!.Data!.Products.Single(product => product.Name == "19L Water Bottle");
        var stockBefore = bottle.VanStock;

        var tooMany = await client.PostAsJsonAsync("/api/sales", new
        {
            customerId = stop.CustomerId,
            stopId = stop.Id,
            lines = new[] { new { productId = bottle.Id, quantity = stockBefore + 5 } }
        });
        var tooManyBody = await tooMany.Content.ReadFromJsonAsync<ApiResponse<SaleDraftDto>>(Json);
        var rejected = await client.PostAsJsonAsync($"/api/sales/{tooManyBody!.Data!.Id}/complete", new
        {
            paymentMethod = "Cash",
            signerName = "Tariq Ali"
        });
        Assert.Equal(HttpStatusCode.Conflict, rejected.StatusCode);

        var draft = await client.PostAsJsonAsync("/api/sales", new
        {
            customerId = stop.CustomerId,
            stopId = stop.Id,
            lines = new[] { new { productId = bottle.Id, quantity = 2 } }
        });
        Assert.Equal(HttpStatusCode.Created, draft.StatusCode);
        var sale = (await draft.Content.ReadFromJsonAsync<ApiResponse<SaleDraftDto>>(Json))!.Data!;
        Assert.Equal(360, sale.SaleAmount);

        var completed = await client.PostAsJsonAsync($"/api/sales/{sale.Id}/complete", new
        {
            paymentMethod = "Cash",
            signerName = "Tariq Ali",
            signerRole = "Store Manager"
        });
        Assert.Equal(HttpStatusCode.OK, completed.StatusCode);
        var receipt = (await completed.Content.ReadFromJsonAsync<ApiResponse<ReceiptDto>>(Json))!.Data!;
        Assert.Equal(0, receipt.BalanceAfter);
        Assert.StartsWith("RCP-", receipt.ReceiptNumber);

        var afterContext = await client.GetFromJsonAsync<ApiResponse<SaleContextDto>>($"/api/customers/{stop.CustomerId}/sale-context", Json);
        Assert.Equal(stockBefore - 2, afterContext!.Data!.Products.Single(product => product.Id == bottle.Id).VanStock);

        var after = await client.GetFromJsonAsync<ApiResponse<DashboardDto>>("/api/dashboard", Json);
        Assert.Equal(before!.Data!.Performance.BilledSales + 360, after!.Data!.Performance.BilledSales);
        Assert.Equal(before.Data.Performance.SalesCount + 1, after.Data.Performance.SalesCount);
    }

    [Fact]
    public async Task Collection_cannot_exceed_the_balance_and_customer_validation_is_enforced()
    {
        var client = await RiderClientAsync();
        var stops = await client.GetFromJsonAsync<ApiResponse<List<StopDto>>>("/api/stops?search=Madina&pageSize=10", Json);
        var madina = stops!.Data!.Single();
        var over = await client.PostAsJsonAsync("/api/collections", new
        {
            customerId = madina.CustomerId,
            amount = 50,
            channel = "Cash",
            signerName = "Counter"
        });
        Assert.Equal(HttpStatusCode.BadRequest, over.StatusCode);

        var invalid = await client.PostAsJsonAsync("/api/customers", new { businessName = "", primaryMobile = "", category = "", street = "", area = "", city = "", bottleOwnership = "Rented", openingDebt = 0, openingEmpties = 0 });
        Assert.Equal(HttpStatusCode.BadRequest, invalid.StatusCode);

        var created = await client.PostAsJsonAsync("/api/customers", new
        {
            businessName = "New Kiryana",
            primaryMobile = "03009990001",
            category = "Retail Store",
            street = "Shop 2",
            area = "Satellite Town",
            city = "Rawalpindi",
            bottleOwnership = "Own",
            openingDebt = 100,
            openingEmpties = 1
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var customer = (await created.Content.ReadFromJsonAsync<ApiResponse<CustomerDetailDto>>(Json))!.Data!;
        Assert.Equal(100, customer.Outstanding);
        Assert.StartsWith("CUS-", customer.Code);
    }

    [Fact]
    public async Task Stops_support_search_and_pagination()
    {
        var client = await RiderClientAsync();
        var page = await client.GetFromJsonAsync<ApiResponse<List<StopDto>>>("/api/stops?page=1&pageSize=5", Json);
        Assert.Equal(5, page!.Data!.Count);
        Assert.Equal(28, page.Pagination!.TotalRecords);
        var missed = await client.GetFromJsonAsync<ApiResponse<List<StopDto>>>("/api/stops?filter=missed&pageSize=50", Json);
        Assert.Single(missed!.Data!);
    }

    [Fact]
    public async Task Remember_me_extends_only_the_refresh_token()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.UserAgent.ParseAdd("RouteLedgerTest/1.0");

        var sso = await client.GetFromJsonAsync<ApiResponse<SsoStatusDto>>("/api/auth/sso/status", Json);
        Assert.NotNull(sso);
        Assert.False(sso.Data!.Okta.Enabled);
        Assert.False(sso.Data.AzureAd.Enabled);

        var standardResponse = await client.PostAsJsonAsync("/api/auth/login", new { username = "ahmed.khan", password = "routeledger1" });
        standardResponse.EnsureSuccessStatusCode();
        var standard = (await standardResponse.Content.ReadFromJsonAsync<ApiResponse<AuthResponseDto>>(Json))!.Data!;
        Assert.InRange((standard.ExpiresAt - DateTime.UtcNow).TotalMinutes, 25, 35);
        Assert.Equal("Rider", standard.User.Role);
        Assert.Contains("Rider", standard.User.Roles!);

        var rememberedResponse = await client.PostAsJsonAsync("/api/auth/login", new
        {
            emailOrUsername = "ahmed.khan@rider.local",
            password = "routeledger1",
            rememberMe = true
        });
        rememberedResponse.EnsureSuccessStatusCode();
        var remembered = (await rememberedResponse.Content.ReadFromJsonAsync<ApiResponse<AuthResponseDto>>(Json))!.Data!;
        Assert.Equal("Ahmed Khan", remembered.User.FullName);
        Assert.InRange((remembered.ExpiresAt - DateTime.UtcNow).TotalMinutes, 25, 35);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var user = await db.Users.SingleAsync(item => item.UserName == "ahmed.khan");
            Assert.NotNull(user.LastLoginAtUtc);
            var normal = await db.RefreshTokens
                .Where(token => token.UserId == user.Id && !token.RememberMe && token.RevokedAt == null)
                .OrderByDescending(token => token.CreatedAt)
                .FirstAsync();
            var longLived = await db.RefreshTokens
                .Where(token => token.UserId == user.Id && token.RememberMe && token.RevokedAt == null)
                .OrderByDescending(token => token.CreatedAt)
                .FirstAsync();
            Assert.InRange((normal.ExpiresAt - normal.CreatedAt).TotalDays, 13, 15);
            Assert.InRange((longLived.ExpiresAt - longLived.CreatedAt).TotalDays, 29, 31);
            Assert.Contains("RouteLedgerTest", longLived.DeviceInformation);
        }

        var refreshed = await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = remembered.RefreshToken });
        refreshed.EnsureSuccessStatusCode();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var user = await db.Users.SingleAsync(item => item.UserName == "ahmed.khan");
            var rotated = await db.RefreshTokens
                .Where(token => token.UserId == user.Id && token.RememberMe && token.RevokedAt == null)
                .OrderByDescending(token => token.CreatedAt)
                .FirstAsync();
            Assert.InRange((rotated.ExpiresAt - rotated.CreatedAt).TotalDays, 29, 31);
            Assert.NotEqual(remembered.RefreshToken, (await refreshed.Content.ReadFromJsonAsync<ApiResponse<AuthResponseDto>>(Json))!.Data!.RefreshToken);
        }
    }

    [Fact]
    public async Task Admin_onboarding_overview_matches_live_data()
    {
        var client = _factory.CreateClient();
        var admin = await LoginAsync(client, "admin", "Admin#2026x");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", admin.AccessToken);

        var overview = await client.GetFromJsonAsync<ApiResponse<OnboardingOverviewDto>>("/api/onboarding/overview", Json);
        Assert.NotNull(overview);
        Assert.Equal(6, overview.Data!.CompletedCount);
        Assert.Equal(6, overview.Data.TotalSteps);
        Assert.Equal(100, overview.Data.ProgressPercent);
        Assert.True(overview.Data.Ready);
        Assert.Equal(6, overview.Data.Steps.Count);
        Assert.Equal(OnboardingStepCode.PlantDetails, overview.Data.Steps[0].StepCode);
        Assert.Equal(OnboardingStepStatus.Completed, overview.Data.Steps[0].Status);
        Assert.Equal("Warehouse Depot Hub 02", overview.Data.Business.DisplayName);
        Assert.Equal("Ready", overview.Data.Business.Status);
        Assert.Null(overview.Data.NextStep);
        Assert.False(overview.Data.Support.ChatAvailable);
        Assert.False(overview.Data.Support.SchedulingAvailable);

        var progress = await client.GetFromJsonAsync<ApiResponse<OnboardingProgressDto>>("/api/onboarding/progress", Json);
        Assert.Equal(100, progress!.Data!.ProgressPercent);

        var readiness = await client.GetFromJsonAsync<ApiResponse<OnboardingReadinessDto>>("/api/onboarding/readiness", Json);
        Assert.True(readiness!.Data!.Ready);
        Assert.Empty(readiness.Data.BlockingSteps);

        var complete = await client.PostAsync("/api/onboarding/steps/PlantDetails/complete", null);
        Assert.Equal(HttpStatusCode.OK, complete.StatusCode);

        var activity = await client.GetFromJsonAsync<ApiResponse<List<OnboardingActivityDto>>>("/api/onboarding/activity", Json);
        Assert.Contains(activity!.Data!, item => item.Title == "OnboardingComplete" && item.Detail == "PlantDetails");
    }

    [Fact]
    public async Task Rider_cannot_open_onboarding()
    {
        var rider = await RiderClientAsync();
        var denied = await rider.GetAsync("/api/onboarding/overview");
        Assert.Equal(HttpStatusCode.Forbidden, denied.StatusCode);
    }

    [Fact]
    public async Task Admin_command_kpis_match_stored_totals()
    {
        var client = await AdminClientAsync();
        var kpis = await client.GetFromJsonAsync<ApiResponse<CommandKpisDto>>("/api/dashboard/kpis", Json);
        Assert.NotNull(kpis);
        Assert.True(kpis.Success);

        var today = DateOnly.FromDateTime(DateTime.Today);
        var (start, end) = LocalDayBounds(today, today);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var sales = db.Sales.Where(sale => sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end);
        var billed = await sales.SumAsync(sale => (decimal?)sale.SaleAmount) ?? 0;
        var invoices = await sales.CountAsync();
        Assert.True(invoices > 0);
        Assert.Equal(billed, kpis.Data!.Sales.TotalBilledSales);
        Assert.Equal(invoices, kpis.Data.Sales.InvoiceCount);

        var yesterday = today.AddDays(-1);
        var (previousStart, previousEnd) = LocalDayBounds(yesterday, yesterday);
        var previousInvoices = await db.Sales.CountAsync(sale =>
            sale.Status == SaleStatus.Completed && sale.CreatedAt >= previousStart && sale.CreatedAt < previousEnd);
        if (previousInvoices == 0)
        {
            Assert.Null(kpis.Data.Sales.PreviousPeriodSales);
            Assert.Null(kpis.Data.Sales.ChangeAmount);
            Assert.Null(kpis.Data.Sales.ChangePercent);
        }
        else
        {
            var previous = await db.Sales
                .Where(sale => sale.Status == SaleStatus.Completed && sale.CreatedAt >= previousStart && sale.CreatedAt < previousEnd)
                .SumAsync(sale => sale.SaleAmount);
            Assert.Equal(previous, kpis.Data.Sales.PreviousPeriodSales);
        }

        var received = await db.Collections
            .Where(item => item.CreatedAt >= start && item.CreatedAt < end)
            .SumAsync(item => (decimal?)item.Amount) ?? 0;
        Assert.Equal(received, kpis.Data.Collections.CollectionsReceived);
        var outstanding = await db.Customers.Where(customer => !customer.IsDeleted).SumAsync(customer => customer.Outstanding);
        var accounts = await db.Customers.CountAsync(customer => !customer.IsDeleted && customer.Outstanding > 0);
        Assert.Equal(outstanding, kpis.Data.Outstanding.OutstandingDues);
        Assert.Equal(accounts, kpis.Data.Outstanding.AccountsWithDues);

        var riderRole = await db.Roles.SingleAsync(role => role.Name == AppRoles.Rider);
        var fleet = await db.UserRoles.CountAsync(link => link.RoleId == riderRole.Id);
        var onDuty = await db.Shifts
            .Where(shift => shift.Status == "Open" && shift.ServiceDate == today)
            .Select(shift => shift.RiderId)
            .Distinct()
            .CountAsync();
        Assert.Equal(fleet, kpis.Data.Fleet.FleetRegistered);
        Assert.Equal(onDuty, kpis.Data.Fleet.FleetOnDuty);
        Assert.True(fleet >= 1);

        var stopTotal = await db.RouteStops.CountAsync(stop => stop.ServiceDate == today);
        var stopCompleted = await db.RouteStops.CountAsync(stop => stop.ServiceDate == today && stop.Status == StopStatus.Completed);
        Assert.Equal(stopTotal, kpis.Data.Deliveries.DeliveriesTotal);
        Assert.Equal(stopCompleted, kpis.Data.Deliveries.DeliveriesCompleted);

        var pending = await db.CustomerOrders.CountAsync(order => order.Status == CustomerOrderStatus.Scheduled);
        Assert.Equal(pending, kpis.Data.Orders.PendingOrders);

        var overview = await client.GetFromJsonAsync<ApiResponse<CommandOverviewDto>>("/api/dashboard/overview", Json);
        Assert.Equal("Fleet Admin", overview!.Data!.AdminFullName);
        Assert.Contains("Fleet", overview.Data.Greeting);
        Assert.Equal(today, overview.Data.Period.From);
        var depot = await db.Depots.OrderBy(item => item.Name).Select(item => item.Name).FirstAsync();
        Assert.Equal(depot, overview.Data.FacilityDepotName);
    }

    [Fact]
    public async Task Rider_cannot_open_the_command_dashboard()
    {
        var rider = await RiderClientAsync();
        var kpis = await rider.GetAsync("/api/dashboard/kpis");
        Assert.Equal(HttpStatusCode.Forbidden, kpis.StatusCode);
        var overview = await rider.GetAsync("/api/dashboard/overview");
        Assert.Equal(HttpStatusCode.Forbidden, overview.StatusCode);
        var operations = await rider.GetAsync("/api/rider-operations/riders");
        Assert.Equal(HttpStatusCode.Forbidden, operations.StatusCode);

        var field = await rider.GetAsync("/api/dashboard");
        Assert.Equal(HttpStatusCode.OK, field.StatusCode);
    }

    [Fact]
    public async Task Admin_can_list_rider_operations()
    {
        var client = await AdminClientAsync();
        var list = await client.GetFromJsonAsync<ApiResponse<List<RiderOpsCardDto>>>("/api/rider-operations/riders", Json);
        Assert.NotNull(list);
        Assert.True(list.Success);
        var ahmed = list.Data!.Single(rider => rider.RiderCode == "RDR-1042");
        Assert.Equal("Ahmed Khan", ahmed.FullName);
        Assert.Equal("Toyota HiAce", ahmed.VehicleName);
        Assert.False(string.IsNullOrWhiteSpace(ahmed.RouteName));

        var today = DateOnly.FromDateTime(DateTime.Today);
        var (start, end) = LocalDayBounds(today, today);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.SingleAsync(item => item.RiderCode == "RDR-1042");
        var billed = await db.Sales
            .Where(sale => sale.RiderId == user.Id && sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end)
            .SumAsync(sale => (decimal?)sale.SaleAmount) ?? 0;
        var cashSales = await db.Sales
            .Where(sale => sale.RiderId == user.Id && sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end && sale.PaymentChannel == PaymentChannel.Cash)
            .SumAsync(sale => (decimal?)sale.AmountReceived) ?? 0;
        var cashCollections = await db.Collections
            .Where(item => item.RiderId == user.Id && item.Channel == PaymentChannel.Cash && item.CreatedAt >= start && item.CreatedAt < end)
            .SumAsync(item => (decimal?)item.Amount) ?? 0;
        Assert.Equal(billed, ahmed.BilledSalesToday);
        Assert.Equal(cashSales + cashCollections, ahmed.CashCollectedToday);
        Assert.True(billed > 0);

        var open = await db.Shifts.AnyAsync(shift => shift.RiderId == user.Id && shift.Status == "Open" && shift.ServiceDate == today);
        if (!open)
        {
            Assert.Equal("available", ahmed.Status);
        }

        var stops = await db.RouteStops.CountAsync(stop => stop.RouteId == user.RouteId && stop.ServiceDate == today);
        var completed = await db.RouteStops.CountAsync(stop => stop.RouteId == user.RouteId && stop.ServiceDate == today && stop.Status == StopStatus.Completed);
        Assert.Equal(stops, ahmed.StopsTotal);
        Assert.Equal(completed, ahmed.StopsCompleted);

        var summary = await client.GetFromJsonAsync<ApiResponse<RiderOpsSummaryDto>>("/api/rider-operations/summary", Json);
        Assert.Equal(list.Data!.Count, summary!.Data!.RidersRegistered);
        Assert.True(summary.Data.RidersRegistered >= 1);

        var detail = await client.GetFromJsonAsync<ApiResponse<RiderOpsCardDto>>($"/api/rider-operations/riders/{user.Id}", Json);
        Assert.Equal(ahmed.BilledSalesToday, detail!.Data!.BilledSalesToday);

        var locations = await client.GetFromJsonAsync<ApiResponse<LocationVerificationsDto>>("/api/rider-operations/location-verifications", Json);
        Assert.Empty(locations!.Data!.Items);
        Assert.Contains("not persisted", locations.Data.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Activity_ledger_pages_through_stored_rows()
    {
        var client = await AdminClientAsync();
        var today = DateOnly.FromDateTime(DateTime.Today);
        var (start, end) = LocalDayBounds(today, today);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var saleCount = await db.Sales.CountAsync(sale => sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end);
        var collectionCount = await db.Collections.CountAsync(item => item.CreatedAt >= start && item.CreatedAt < end);
        var expected = saleCount + collectionCount;
        Assert.True(expected >= 2);

        var page = await client.GetFromJsonAsync<ApiResponse<List<ActivityLedgerRowDto>>>("/api/dashboard/activity-ledger?page=1&pageSize=2", Json);
        Assert.Equal(2, page!.Data!.Count);
        Assert.Equal(1, page.Pagination!.Page);
        Assert.Equal(2, page.Pagination.PageSize);
        Assert.Equal(expected, page.Pagination.TotalRecords);
        Assert.Equal((int)Math.Ceiling(expected / 2d), page.Pagination.TotalPages);

        var next = await client.GetFromJsonAsync<ApiResponse<List<ActivityLedgerRowDto>>>("/api/dashboard/activity-ledger?page=2&pageSize=2", Json);
        var firstKeys = page.Data.Select(row => row.TransactionType + row.ReferenceId).ToHashSet();
        Assert.DoesNotContain(next!.Data!, row => firstKeys.Contains(row.TransactionType + row.ReferenceId));

        var sample = page.Data[0];
        var searched = await client.GetFromJsonAsync<ApiResponse<List<ActivityLedgerRowDto>>>(
            "/api/dashboard/activity-ledger?search=" + Uri.EscapeDataString(sample.ReferenceId),
            Json);
        Assert.Contains(searched!.Data!, row => row.ReferenceId == sample.ReferenceId);
        Assert.True(searched.Pagination!.TotalRecords <= expected);

        var failedSales = await db.Sales.CountAsync(sale =>
            sale.Status == SaleStatus.Completed && sale.SyncStatus == SyncStatus.Failed && sale.CreatedAt >= start && sale.CreatedAt < end);
        var failedCollections = await db.Collections.CountAsync(item =>
            item.SyncStatus == SyncStatus.Failed && item.CreatedAt >= start && item.CreatedAt < end);
        var failed = await client.GetFromJsonAsync<ApiResponse<List<ActivityLedgerRowDto>>>("/api/dashboard/activity-ledger?status=Failed&pageSize=50", Json);
        Assert.Equal(failedSales + failedCollections, failed!.Pagination!.TotalRecords);
        Assert.All(failed.Data!, row => Assert.Equal("Failed", row.SyncStatus));
    }

    [Fact]
    public async Task Admin_order_is_stored_and_unknown_customer_is_rejected()
    {
        var client = await AdminClientAsync();
        var missing = await client.PostAsJsonAsync("/api/dashboard/orders", new
        {
            customerId = Guid.NewGuid(),
            riderId = "missing-rider",
            deliveryDate = DateOnly.FromDateTime(DateTime.Today).AddDays(1),
            window = "Morning",
            lines = new[] { new { productId = Guid.NewGuid(), quantity = 1 } }
        });
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var customer = await db.Customers.FirstAsync(item => item.Code == "CUS-1001");
        var rider = await db.Users.SingleAsync(item => item.RiderCode == "RDR-1042");
        var product = await db.Products.SingleAsync(item => item.Sku == "19L");
        var created = await client.PostAsJsonAsync("/api/dashboard/orders", new
        {
            customerId = customer.Id,
            riderId = rider.Id,
            deliveryDate = DateOnly.FromDateTime(DateTime.Today).AddDays(3),
            window = "Morning",
            lines = new[] { new { productId = product.Id, quantity = 2 } }
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var order = (await created.Content.ReadFromJsonAsync<ApiResponse<OrderDto>>(Json))!.Data!;
        Assert.StartsWith("ORD-", order.ReferenceNumber);
        Assert.Equal(product.UnitPrice * 2, order.EstimatedValue);
        Assert.Equal("Scheduled", order.Status);

        using var check = _factory.Services.CreateScope();
        var stored = await check.ServiceProvider.GetRequiredService<AppDbContext>().CustomerOrders
            .Include(item => item.Lines)
            .SingleAsync(item => item.ReferenceNumber == order.ReferenceNumber);
        Assert.Equal(rider.Id, stored.RiderId);
        Assert.Equal(2, stored.Lines.Single().Quantity);
    }

    [Fact]
    public async Task Collections_summary_uses_only_approved_categories()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<CollectionsSummaryDto>>("/api/dashboard/collections-summary", Json);
        Assert.NotNull(summary);
        Assert.Equal(["Cash", "FullCredit", "PartialCash"], summary.Data!.Categories.Select(category => category.Category));
        Assert.DoesNotContain(summary.Data.Categories, category => category.Category is "BankTransfer" or "Wallet" or "Cheque");
        Assert.Equal(summary.Data.Categories.Sum(category => category.Amount), summary.Data.Total);
        Assert.NotNull(summary.Data.ReconciliationNote);

        var today = DateOnly.FromDateTime(DateTime.Today);
        var (start, end) = LocalDayBounds(today, today);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var sales = await db.Sales.AsNoTracking()
            .Where(sale => sale.Status == SaleStatus.Completed && sale.CreatedAt >= start && sale.CreatedAt < end)
            .Select(sale => new { sale.SaleAmount, sale.PreviousOutstanding, sale.AmountReceived, sale.PaymentChannel })
            .ToListAsync();
        var collections = await db.Collections.AsNoTracking()
            .Where(item => item.CreatedAt >= start && item.CreatedAt < end)
            .Select(item => new { item.Amount, item.OutstandingBefore, item.Channel })
            .ToListAsync();

        decimal cash = 0, full = 0, partial = 0, excluded = 0;
        foreach (var sale in sales)
        {
            var due = sale.SaleAmount + sale.PreviousOutstanding;
            if (sale.AmountReceived == 0)
            {
                full += sale.SaleAmount;
            }
            else if (sale.AmountReceived < due)
            {
                partial += sale.AmountReceived;
            }
            else if (sale.PaymentChannel == PaymentChannel.Cash)
            {
                cash += sale.AmountReceived;
            }
            else
            {
                excluded += sale.AmountReceived;
            }
        }

        foreach (var item in collections)
        {
            if (item.Amount < item.OutstandingBefore)
            {
                partial += item.Amount;
            }
            else if (item.Channel == PaymentChannel.Cash)
            {
                cash += item.Amount;
            }
            else
            {
                excluded += item.Amount;
            }
        }

        Assert.Equal(cash, summary.Data.Categories.Single(category => category.Category == "Cash").Amount);
        Assert.Equal(full, summary.Data.Categories.Single(category => category.Category == "FullCredit").Amount);
        Assert.Equal(partial, summary.Data.Categories.Single(category => category.Category == "PartialCash").Amount);
        Assert.Equal(excluded, summary.Data.ExcludedUnsupportedAmount);
    }

    private async Task<HttpClient> AdminClientAsync()
    {
        var client = _factory.CreateClient();
        var session = await LoginAsync(client, "admin", "Admin#2026x");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);
        return client;
    }

    private static (DateTime Start, DateTime End) LocalDayBounds(DateOnly from, DateOnly to)
    {
        var startLocal = DateTime.SpecifyKind(from.ToDateTime(TimeOnly.MinValue), DateTimeKind.Local);
        var endLocal = DateTime.SpecifyKind(to.AddDays(1).ToDateTime(TimeOnly.MinValue), DateTimeKind.Local);
        return (startLocal.ToUniversalTime(), endLocal.ToUniversalTime());
    }

    [Fact]
    public async Task Forgot_password_does_not_reveal_whether_the_account_exists()
    {
        var client = _factory.CreateClient();
        var known = await client.PostAsJsonAsync("/api/auth/forgot-password", new { username = "ahmed.khan" });
        var unknown = await client.PostAsJsonAsync("/api/auth/forgot-password", new { username = "nobody" });
        var knownBody = await known.Content.ReadFromJsonAsync<ApiResponse<object>>(Json);
        var unknownBody = await unknown.Content.ReadFromJsonAsync<ApiResponse<object>>(Json);
        Assert.Equal(knownBody!.Message, unknownBody!.Message);
    }

    private async Task<HttpClient> RiderClientAsync()
    {
        var client = _factory.CreateClient();
        var session = await LoginAsync(client, "ahmed.khan", "routeledger1");
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.AccessToken);
        return client;
    }

    private static async Task<AuthResponseDto> LoginAsync(HttpClient client, string username, string password)
    {
        var response = await client.PostAsJsonAsync("/api/auth/login", new { username, password });
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<ApiResponse<AuthResponseDto>>(Json);
        return body!.Data!;
    }

    [Fact]
    public async Task Dispatch_directory_is_empty_safe_and_matches_stored_orders()
    {
        var client = await AdminClientAsync();
        var badStatus = await client.GetAsync("/api/dispatch/orders?status=Scheduled");
        Assert.Equal(HttpStatusCode.BadRequest, badStatus.StatusCode);
        var inverted = await client.GetAsync("/api/dispatch/orders?from=2099-02-01&to=2099-01-01");
        Assert.Equal(HttpStatusCode.BadRequest, inverted.StatusCode);

        var emptyList = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderRowDto>>>(
            "/api/dispatch/orders?from=2099-01-01&to=2099-01-02&search=ORD-OPEN-ALI", Json);
        Assert.Empty(emptyList!.Data!);
        Assert.Equal(0, emptyList.Pagination!.TotalRecords);
        Assert.Equal(0, emptyList.Pagination.TotalPages);

        var emptySummary = await client.GetFromJsonAsync<ApiResponse<DispatchOrderSummaryDto>>(
            "/api/dispatch/orders/summary?from=2099-01-01&to=2099-01-02", Json);
        Assert.Equal(0, emptySummary!.Data!.Total);
        Assert.Equal(0, emptySummary.Data.PendingAssignment);
        Assert.Equal(0, emptySummary.Data.Assigned);
        Assert.Equal(0, emptySummary.Data.InProgress);
        Assert.Equal(0, emptySummary.Data.Completed);
        Assert.Equal(0, emptySummary.Data.Cancelled);
        Assert.Equal(0, emptySummary.Data.CombinedEstimatedValue);

        var emptyCounts = await client.GetFromJsonAsync<ApiResponse<DispatchStatusCountsDto>>(
            "/api/dispatch/orders/status-counts?from=2099-01-01&to=2099-01-02", Json);
        Assert.Equal(0, emptyCounts!.Data!.Total);

        var summary = await client.GetFromJsonAsync<ApiResponse<DispatchOrderSummaryDto>>("/api/dispatch/orders/summary", Json);
        var counts = await client.GetFromJsonAsync<ApiResponse<DispatchStatusCountsDto>>("/api/dispatch/orders/status-counts", Json);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var stored = await db.CustomerOrders.AsNoTracking()
            .Select(order => new { order.Status, order.RiderId, order.EstimatedValue })
            .ToListAsync();
        var pending = stored.Count(order => order.Status == CustomerOrderStatus.Scheduled && string.IsNullOrWhiteSpace(order.RiderId));
        var assigned = stored.Count(order => order.Status == CustomerOrderStatus.Scheduled && !string.IsNullOrWhiteSpace(order.RiderId));
        var inProgress = stored.Count(order => order.Status == CustomerOrderStatus.InProgress);
        var completed = stored.Count(order => order.Status == CustomerOrderStatus.Delivered);
        var cancelled = stored.Count(order => order.Status == CustomerOrderStatus.Cancelled);
        Assert.Equal(stored.Count, summary!.Data!.Total);
        Assert.Equal(pending, summary.Data.PendingAssignment);
        Assert.Equal(assigned, summary.Data.Assigned);
        Assert.Equal(inProgress, summary.Data.InProgress);
        Assert.Equal(completed, summary.Data.Completed);
        Assert.Equal(cancelled, summary.Data.Cancelled);
        Assert.Equal(pending + assigned + inProgress + completed + cancelled, summary.Data.Total);
        Assert.Equal(stored.Sum(order => order.EstimatedValue), summary.Data.CombinedEstimatedValue);
        Assert.Equal(summary.Data.Total, counts!.Data!.Total);
        Assert.Equal(summary.Data.PendingAssignment, counts.Data.PendingAssignment);
        Assert.Equal(summary.Data.Assigned, counts.Data.Assigned);
        Assert.Equal(summary.Data.Cancelled, counts.Data.Cancelled);

        var listed = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderRowDto>>>("/api/dispatch/orders?search=ORD-OPEN-ALI", Json);
        var row = listed!.Data!.Single();
        Assert.Equal(0, row.LineCount);
        Assert.Equal("", row.PriorityLabel);
        Assert.Equal("assigned", row.Status);
        Assert.Equal("Scheduled", row.OrderStatus);
        Assert.Equal(970, row.EstimatedValue);
        Assert.False(string.IsNullOrWhiteSpace(row.RiderId));
        Assert.Equal("RDR-1042", row.RiderCode);
        Assert.Contains("Ali General Store", row.CustomerName);
        Assert.Equal("CUS-1001", row.CustomerCode);

        var detail = await client.GetFromJsonAsync<ApiResponse<DispatchOrderDetailDto>>($"/api/dispatch/orders/{row.Id}", Json);
        Assert.Equal(0, detail!.Data!.Totals.LineCount);
        Assert.Equal(0, detail.Data.Totals.LinesSubtotal);
        Assert.Equal(970, detail.Data.Totals.EstimatedValue);
        Assert.Equal("", detail.Data.PriorityLabel);
        Assert.NotNull(detail.Data.Rider);
        Assert.Null(detail.Data.CancellationReason);

        var items = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderItemDto>>>($"/api/dispatch/orders/{row.Id}/items", Json);
        Assert.Empty(items!.Data!);
        var lifecycle = await client.GetFromJsonAsync<ApiResponse<List<OrderLifecycleEventDto>>>($"/api/dispatch/orders/{row.Id}/lifecycle", Json);
        Assert.Empty(lifecycle!.Data!);

        var missing = await client.GetAsync($"/api/dispatch/orders/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);

        var today = DateOnly.FromDateTime(DateTime.Today);
        var operations = await client.GetFromJsonAsync<ApiResponse<DispatchOperationalSummaryDto>>($"/api/dispatch/operational-summary?date={today:yyyy-MM-dd}", Json);
        Assert.False(operations!.Data!.ShiftProgress.TargetConfigured);
        Assert.Null(operations.Data.ShiftProgress.Target);
        var routes = await db.DeliveryRoutes.AsNoTracking().ToListAsync();
        Assert.Equal(routes.Count, operations.Data.Zones.Count);
        foreach (var zone in operations.Data.Zones)
        {
            var orderCount = await db.CustomerOrders.CountAsync(order => order.DeliveryDate == today && order.Customer.RouteId == zone.RouteId);
            var stopCount = await db.RouteStops.CountAsync(stop => stop.ServiceDate == today && stop.RouteId == zone.RouteId);
            Assert.Equal(orderCount, zone.OrderCount);
            Assert.Equal(stopCount, zone.StopCount);
        }

        var stopTotal = await db.RouteStops.CountAsync(stop => stop.ServiceDate == today);
        var stopCompleted = await db.RouteStops.CountAsync(stop => stop.ServiceDate == today && stop.Status == StopStatus.Completed);
        Assert.Equal(stopTotal, operations.Data.ShiftProgress.TotalStops);
        Assert.Equal(stopCompleted, operations.Data.ShiftProgress.CompletedStops);

        var quiet = await client.GetFromJsonAsync<ApiResponse<DispatchOperationalSummaryDto>>("/api/dispatch/operational-summary?date=2099-01-01", Json);
        Assert.False(quiet!.Data!.ShiftProgress.TargetConfigured);
        Assert.Equal(0, quiet.Data.ShiftProgress.TotalStops);
        Assert.Equal(0, quiet.Data.ShiftProgress.CompletedStops);
        Assert.All(quiet.Data.Zones, zone => Assert.Equal(0, zone.OrderCount + zone.StopCount));

        var ridersRaw = await client.GetStringAsync("/api/dispatch/eligible-riders");
        Assert.DoesNotContain("latitude", ridersRaw, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("longitude", ridersRaw, StringComparison.OrdinalIgnoreCase);
        var riders = await client.GetFromJsonAsync<ApiResponse<List<EligibleRiderDto>>>("/api/dispatch/eligible-riders", Json);
        Assert.Contains(riders!.Data!, rider => rider.RiderCode == "RDR-1042");
        var me = await client.GetFromJsonAsync<ApiResponse<AuthUserDto>>("/api/auth/me", Json);
        Assert.DoesNotContain(riders.Data!, rider => rider.Id == me!.Data!.Id);
    }

    [Fact]
    public async Task Rider_cannot_call_dispatch()
    {
        var rider = await RiderClientAsync();
        var list = await rider.GetAsync("/api/dispatch/orders");
        Assert.Equal(HttpStatusCode.Forbidden, list.StatusCode);
        var summary = await rider.GetAsync("/api/dispatch/orders/summary");
        Assert.Equal(HttpStatusCode.Forbidden, summary.StatusCode);
        var cancel = await rider.PostAsJsonAsync($"/api/dispatch/orders/{Guid.NewGuid()}/cancel", new { reason = "no" });
        Assert.Equal(HttpStatusCode.Forbidden, cancel.StatusCode);
    }

    [Fact]
    public async Task Dispatch_assigns_reassigns_and_cancels_a_single_rider()
    {
        var client = await AdminClientAsync();
        var me = await client.GetFromJsonAsync<ApiResponse<AuthUserDto>>("/api/auth/me", Json);
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var customer = await db.Customers.FirstAsync(item => item.Code == "CUS-1001");
        var ahmed = await db.Users.SingleAsync(item => item.RiderCode == "RDR-1042");
        var reference = "ORD-DISP-" + Guid.NewGuid().ToString("N")[..8];
        var order = new CustomerOrder
        {
            ReferenceNumber = reference,
            CustomerId = customer.Id,
            RiderId = "",
            DeliveryDate = DateOnly.FromDateTime(DateTime.Today).AddDays(6),
            Window = DeliveryWindow.Evening,
            EstimatedValue = 180,
            Notes = "Leave at counter",
            Status = CustomerOrderStatus.Scheduled,
            SyncStatus = SyncStatus.Synced
        };
        db.CustomerOrders.Add(order);
        await db.SaveChangesAsync();
        var id = order.Id;

        var pending = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderRowDto>>>(
            "/api/dispatch/orders?status=pendingAssignment&search=" + reference, Json);
        var pendingRow = pending!.Data!.Single();
        Assert.Equal("", pendingRow.RiderId);
        Assert.Null(pendingRow.RiderName);
        Assert.Equal(0, pendingRow.LineCount);
        Assert.Equal("pendingAssignment", pendingRow.Status);
        var assignedBefore = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderRowDto>>>(
            "/api/dispatch/orders?status=assigned&search=" + reference, Json);
        Assert.Empty(assignedBefore!.Data!);

        var assigned = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/assign-rider", new { riderId = ahmed.Id });
        Assert.Equal(HttpStatusCode.OK, assigned.StatusCode);
        var assignedBody = (await assigned.Content.ReadFromJsonAsync<ApiResponse<DispatchOrderDetailDto>>(Json))!.Data!;
        Assert.Equal(ahmed.Id, assignedBody.RiderId);
        Assert.Equal("assigned", assignedBody.Status);
        Assert.Equal("Scheduled", assignedBody.OrderStatus);
        Assert.Equal("Ahmed Khan", assignedBody.Rider!.FullName);

        var assignAgain = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/assign-rider", new { riderId = ahmed.Id });
        Assert.Equal(HttpStatusCode.Conflict, assignAgain.StatusCode);

        var suffix = Guid.NewGuid().ToString("N")[..8];
        var createdRider = await client.PostAsJsonAsync("/api/users", new
        {
            username = "dispatch." + suffix,
            password = "routeledger2",
            fullName = "Dispatch Rider",
            riderCode = "RDR-" + suffix,
            role = "Rider"
        });
        Assert.Equal(HttpStatusCode.Created, createdRider.StatusCode);
        var nextRider = (await createdRider.Content.ReadFromJsonAsync<ApiResponse<UserDto>>(Json))!.Data!;

        using (var update = _factory.Services.CreateScope())
        {
            var updateDb = update.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await updateDb.CustomerOrders.SingleAsync(item => item.Id == id);
            stored.Status = CustomerOrderStatus.InProgress;
            await updateDb.SaveChangesAsync();
        }

        var inProgress = await client.GetFromJsonAsync<ApiResponse<List<DispatchOrderRowDto>>>(
            "/api/dispatch/orders?status=inProgress&search=" + reference, Json);
        Assert.Equal(id, inProgress!.Data!.Single().Id);

        var reassigned = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/reassign-rider", new { riderId = nextRider.Id });
        Assert.Equal(HttpStatusCode.OK, reassigned.StatusCode);
        var reassignedBody = (await reassigned.Content.ReadFromJsonAsync<ApiResponse<DispatchOrderDetailDto>>(Json))!.Data!;
        Assert.Equal(nextRider.Id, reassignedBody.RiderId);
        Assert.Equal("inProgress", reassignedBody.Status);

        var same = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/reassign-rider", new { riderId = nextRider.Id });
        Assert.Equal(HttpStatusCode.BadRequest, same.StatusCode);

        var idleSuffix = Guid.NewGuid().ToString("N")[..8];
        var idleCreated = await client.PostAsJsonAsync("/api/users", new
        {
            username = "idle." + idleSuffix,
            password = "routeledger2",
            fullName = "Idle Rider",
            riderCode = "RDR-I" + idleSuffix[..6],
            role = "Rider"
        });
        var idle = (await idleCreated.Content.ReadFromJsonAsync<ApiResponse<UserDto>>(Json))!.Data!;
        var deactivated = await client.PostAsJsonAsync($"/api/users/{idle.Id}/status", new { isActive = false });
        Assert.Equal(HttpStatusCode.OK, deactivated.StatusCode);
        var inactive = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/reassign-rider", new { riderId = idle.Id });
        Assert.Equal(HttpStatusCode.BadRequest, inactive.StatusCode);
        var notRider = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/reassign-rider", new { riderId = me!.Data!.Id });
        Assert.Equal(HttpStatusCode.NotFound, notRider.StatusCode);

        using (var check = _factory.Services.CreateScope())
        {
            var checkDb = check.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await checkDb.CustomerOrders.Include(item => item.Lines).SingleAsync(item => item.Id == id);
            Assert.Equal(nextRider.Id, stored.RiderId);
            Assert.Empty(stored.Lines);
            Assert.True(await checkDb.AuditLogs.AnyAsync(item => item.Action == "AssignRider" && item.EntityId == id.ToString()));
            Assert.True(await checkDb.AuditLogs.AnyAsync(item => item.Action == "ReassignRider" && item.EntityId == id.ToString()));
        }

        using (var delivered = _factory.Services.CreateScope())
        {
            var deliveredDb = delivered.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await deliveredDb.CustomerOrders.SingleAsync(item => item.Id == id);
            stored.Status = CustomerOrderStatus.Delivered;
            await deliveredDb.SaveChangesAsync();
        }

        var cannotCancel = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/cancel", new { reason = "Too late" });
        Assert.Equal(HttpStatusCode.Conflict, cannotCancel.StatusCode);

        using (var progress = _factory.Services.CreateScope())
        {
            var progressDb = progress.ServiceProvider.GetRequiredService<AppDbContext>();
            var stored = await progressDb.CustomerOrders.SingleAsync(item => item.Id == id);
            Assert.Equal(CustomerOrderStatus.Delivered, stored.Status);
            stored.Status = CustomerOrderStatus.InProgress;
            await progressDb.SaveChangesAsync();
        }

        var cancelled = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/cancel", new { reason = "Shop closed" });
        Assert.Equal(HttpStatusCode.OK, cancelled.StatusCode);
        var cancelledBody = (await cancelled.Content.ReadFromJsonAsync<ApiResponse<DispatchOrderDetailDto>>(Json))!.Data!;
        Assert.Equal("cancelled", cancelledBody.Status);
        Assert.Equal("Cancelled", cancelledBody.OrderStatus);
        Assert.Equal(nextRider.Id, cancelledBody.RiderId);
        Assert.Equal("Shop closed", cancelledBody.CancellationReason);
        Assert.Equal(me.Data!.Id, cancelledBody.CancelledByUserId);
        Assert.NotNull(cancelledBody.CancelledAtUtc);

        var cancelAgain = await client.PostAsJsonAsync($"/api/dispatch/orders/{id}/cancel", new { reason = "Again" });
        Assert.Equal(HttpStatusCode.Conflict, cancelAgain.StatusCode);

        var events = await client.GetFromJsonAsync<ApiResponse<List<OrderLifecycleEventDto>>>($"/api/dispatch/orders/{id}/lifecycle", Json);
        Assert.Equal("RiderAssigned", events!.Data![0].EventCode);
        var reassignment = events.Data.Single(item => item.EventCode == "RiderReassigned");
        Assert.Contains(ahmed.Id, reassignment.Detail);
        Assert.Contains(nextRider.Id, reassignment.Detail);
        Assert.Contains("Previous rider", reassignment.Detail);
        Assert.Contains("new rider", reassignment.Detail);
        Assert.Contains(events.Data, item => item.EventCode == "Cancelled" && item.Detail == "Shop closed");
        Assert.DoesNotContain(events.Data, item => item.EventCode == "PickListPrepared");

        var pick = await client.GetAsync($"/api/dispatch/orders/{id}/picklist");
        Assert.Equal(HttpStatusCode.BadRequest, pick.StatusCode);
        var prepare = await client.PostAsync($"/api/dispatch/orders/{id}/prepare-picklist", null);
        Assert.Equal(HttpStatusCode.BadRequest, prepare.StatusCode);
    }

    [Fact]
    public async Task Picklist_uses_stored_lines_and_rejects_an_empty_order()
    {
        var admin = await AdminClientAsync();
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var open = await db.CustomerOrders.SingleAsync(order => order.ReferenceNumber == "ORD-OPEN-ALI");
        var emptyPick = await admin.GetAsync($"/api/dispatch/orders/{open.Id}/picklist");
        Assert.Equal(HttpStatusCode.BadRequest, emptyPick.StatusCode);
        var emptyBody = await emptyPick.Content.ReadFromJsonAsync<ApiResponse<PickListDto>>(Json);
        Assert.Contains("no lines", emptyBody!.Message, StringComparison.OrdinalIgnoreCase);
        var emptyPrepare = await admin.PostAsync($"/api/dispatch/orders/{open.Id}/prepare-picklist", null);
        Assert.Equal(HttpStatusCode.BadRequest, emptyPrepare.StatusCode);
        Assert.Equal(0, await db.OrderLines.CountAsync(line => line.OrderId == open.Id));

        var customer = await db.Customers.FirstAsync(item => item.Code == "CUS-1001");
        var product = await db.Products.SingleAsync(item => item.Sku == "19L");
        var rider = await db.Users.SingleAsync(item => item.RiderCode == "RDR-1042");
        var me = await admin.GetFromJsonAsync<ApiResponse<AuthUserDto>>("/api/auth/me", Json);
        var created = await admin.PostAsJsonAsync("/api/dashboard/orders", new
        {
            customerId = customer.Id,
            riderId = rider.Id,
            deliveryDate = DateOnly.FromDateTime(DateTime.Today).AddDays(4),
            window = "Morning",
            note = "Side gate",
            lines = new[] { new { productId = product.Id, quantity = 2 } }
        });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var order = (await created.Content.ReadFromJsonAsync<ApiResponse<OrderDto>>(Json))!.Data!;

        var lifecycle = await admin.GetFromJsonAsync<ApiResponse<List<OrderLifecycleEventDto>>>($"/api/dispatch/orders/{order.Id}/lifecycle", Json);
        var createdEvent = lifecycle!.Data!.Single(item => item.EventCode == "OrderCreated");
        Assert.Equal(me!.Data!.Id, createdEvent.ActorUserId);
        Assert.Contains("Side gate", createdEvent.Detail);

        var pick = await admin.GetFromJsonAsync<ApiResponse<PickListDto>>($"/api/dispatch/orders/{order.Id}/picklist", Json);
        var line = pick!.Data!.Lines.Single();
        Assert.Equal(product.Name, line.ProductName);
        Assert.Equal("19L", line.Sku);
        Assert.Equal(2, line.Quantity);
        Assert.Equal(product.UnitPrice, line.UnitPrice);
        Assert.Equal(product.UnitPrice * 2, line.Subtotal);
        Assert.Equal(product.UnitPrice * 2, pick.Data.LinesTotal);
        Assert.Equal(customer.BusinessName, pick.Data.Customer.Name);
        Assert.Equal(order.ReferenceNumber, pick.Data.ReferenceNumber);

        var before = await db.OrderLines.CountAsync(item => item.OrderId == order.Id);
        var prepared = await admin.PostAsync($"/api/dispatch/orders/{order.Id}/prepare-picklist", null);
        Assert.Equal(HttpStatusCode.OK, prepared.StatusCode);
        var preparedBody = (await prepared.Content.ReadFromJsonAsync<ApiResponse<PickListDto>>(Json))!.Data!;
        Assert.Equal(2, preparedBody.Lines.Single().Quantity);
        using var afterScope = _factory.Services.CreateScope();
        var afterDb = afterScope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(before, await afterDb.OrderLines.CountAsync(item => item.OrderId == order.Id));
        Assert.True(await afterDb.OrderLifecycleEvents.AnyAsync(item => item.OrderId == order.Id && item.EventCode == "PickListPrepared"));
        Assert.True(await afterDb.AuditLogs.AnyAsync(item => item.Action == "PreparePickList" && item.EntityId == order.Id.ToString()));

        var riderClient = await RiderClientAsync();
        var field = await riderClient.PostAsJsonAsync("/api/orders", new
        {
            customerId = customer.Id,
            deliveryDate = DateOnly.FromDateTime(DateTime.Today).AddDays(5),
            window = "Afternoon",
            note = "Gate code 12",
            lines = new[] { new { productId = product.Id, quantity = 1 } }
        });
        Assert.Equal(HttpStatusCode.Created, field.StatusCode);
        var fieldOrder = (await field.Content.ReadFromJsonAsync<ApiResponse<OrderDto>>(Json))!.Data!;
        var fieldEvents = await admin.GetFromJsonAsync<ApiResponse<List<OrderLifecycleEventDto>>>($"/api/dispatch/orders/{fieldOrder.Id}/lifecycle", Json);
        Assert.Equal(rider.Id, fieldEvents!.Data!.Single(item => item.EventCode == "OrderCreated").ActorUserId);
        var fieldPick = await admin.GetFromJsonAsync<ApiResponse<PickListDto>>($"/api/dispatch/orders/{fieldOrder.Id}/picklist", Json);
        Assert.Equal(1, fieldPick!.Data!.Lines.Single().Quantity);
        Assert.Equal(product.UnitPrice, fieldPick.Data.LinesTotal);
    }

    [Fact]
    public async Task Day_close_summary_and_pricing_are_sql_backed()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<DayCloseSummaryDto>>("/api/settlements/day-close/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.False(summary!.Data!.Gateway.Configured);
        Assert.Contains("Not Configured", summary.Data.Gateway.Message, StringComparison.OrdinalIgnoreCase);
        Assert.True(summary.Data.RidersEligible >= 1);
        Assert.True(summary.Data.ExpectedCash >= 0);

        var sessions = await client.GetFromJsonAsync<ApiResponse<List<SettlementSessionRowDto>>>("/api/settlements/sessions", Json);
        Assert.NotNull(sessions?.Data);
        Assert.NotEmpty(sessions!.Data!);

        var coverage = await client.GetFromJsonAsync<ApiResponse<PricingCoverageDto>>("/api/products/pricing/coverage", Json);
        Assert.NotNull(coverage?.Data);
        Assert.True(coverage!.Data!.ActiveProducts >= 1);

        var catalogue = await client.GetFromJsonAsync<ApiResponse<List<ProductBasePriceRowDto>>>("/api/products/catalogue", Json);
        Assert.NotNull(catalogue?.Data);
        Assert.Contains(catalogue!.Data!, item => item.Sku == "19L" && item.BaseSystemPrice == 180m);

        var product = catalogue.Data!.First(item => item.Sku == "19L");
        var validation = await client.GetFromJsonAsync<ApiResponse<BasePriceValidationDto>>(
            $"/api/products/pricing/validate?productId={product.Id}&quantity=10", Json);
        Assert.Equal(1800m, validation!.Data!.Subtotal);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/settlements/day-close/summary")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/products/catalogue")).StatusCode);
    }

    [Fact]
    public async Task Zones_and_routes_are_sql_backed_for_admin()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<ZonesRoutesSummaryDto>>("/api/zones/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.TotalZones >= 1);
        Assert.True(summary.Data.ActiveRoutes >= 1);
        Assert.True(summary.Data.AssignedStores >= 1);

        var zones = await client.GetFromJsonAsync<ApiResponse<List<ZoneListItemDto>>>("/api/zones", Json);
        Assert.NotNull(zones?.Data);
        Assert.NotEmpty(zones!.Data!);
        var zone = zones.Data![0];
        Assert.False(string.IsNullOrWhiteSpace(zone.Name));

        var detail = await client.GetFromJsonAsync<ApiResponse<ZoneDetailDto>>($"/api/zones/{zone.Id}", Json);
        Assert.NotNull(detail?.Data);
        Assert.NotEmpty(detail!.Data!.Routes);

        var route = detail.Data.Routes[0];
        var routeDetail = await client.GetFromJsonAsync<ApiResponse<RouteDetailDto>>($"/api/routes/{route.Id}", Json);
        Assert.NotNull(routeDetail?.Data);
        Assert.True(routeDetail!.Data!.CustomerCount >= 1);

        var customers = await client.GetFromJsonAsync<ApiResponse<List<RouteCustomerRowDto>>>($"/api/routes/{route.Id}/customers", Json);
        Assert.NotNull(customers?.Data);
        Assert.NotEmpty(customers!.Data!);

        var ordered = customers.Data!.OrderByDescending(item => item.RouteSortOrder).Select(item => item.Id).ToList();
        var sequenceResponse = await client.PutAsJsonAsync(
            $"/api/routes/{route.Id}/customers/sequence",
            new { orderedCustomerIds = ordered });
        Assert.Equal(HttpStatusCode.OK, sequenceResponse.StatusCode);

        var stopsEnsure = await client.PostAsJsonAsync($"/api/routes/{route.Id}/stops/ensure", new { });
        Assert.Equal(HttpStatusCode.OK, stopsEnsure.StatusCode);
        var stops = await client.GetFromJsonAsync<ApiResponse<List<RouteStopRowDto>>>($"/api/routes/{route.Id}/stops", Json);
        Assert.NotNull(stops?.Data);
        Assert.NotEmpty(stops!.Data!);

        var map = await client.GetFromJsonAsync<ApiResponse<RouteMapDto>>($"/api/routes/{route.Id}/map-pins", Json);
        Assert.NotNull(map?.Data);

        var riders = await client.GetFromJsonAsync<ApiResponse<List<EligibleRouteRiderDto>>>("/api/routes/eligible-riders", Json);
        Assert.NotNull(riders?.Data);
        Assert.NotEmpty(riders!.Data!);
        var rider = riders.Data!.First(item => item.IsActive);
        var assign = await client.PostAsJsonAsync(
            $"/api/routes/{route.Id}/assign-rider",
            new { riderUserId = rider.UserId });
        Assert.Equal(HttpStatusCode.OK, assign.StatusCode);

        var forbidden = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await forbidden.GetAsync("/api/zones/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_customers_directory_is_sql_backed()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<AdminCustomersSummaryDto>>("/api/admin/customers/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.TotalCustomers >= 1);
        Assert.True(summary.Data.ActiveCustomers >= 1);

        var page = await client.GetFromJsonAsync<ApiResponse<List<AdminCustomerRowDto>>>(
            "/api/admin/customers?page=1&pageSize=10", Json);
        Assert.NotNull(page?.Data);
        Assert.NotEmpty(page!.Data!);
        Assert.NotNull(page.Pagination);
        Assert.True(page.Pagination!.TotalRecords >= page.Data!.Count);

        var first = page.Data[0];
        var detail = await client.GetFromJsonAsync<ApiResponse<AdminCustomerDetailDto>>(
            $"/api/admin/customers/{first.Id}", Json);
        Assert.NotNull(detail?.Data);
        Assert.Equal(first.Code, detail!.Data!.Customer.Code);
        Assert.True(detail.Data.LifetimeSales >= 0);

        var ledger = await client.GetFromJsonAsync<ApiResponse<LedgerDto>>(
            $"/api/admin/customers/{first.Id}/ledger", Json);
        Assert.NotNull(ledger?.Data);
        Assert.Equal(first.Id, ledger!.Data!.CustomerId);

        var routes = await client.GetFromJsonAsync<ApiResponse<List<RouteListItemDto>>>("/api/routes", Json);
        Assert.NotNull(routes?.Data);
        Assert.NotEmpty(routes!.Data!);
        var targetRoute = routes.Data.First().Id;
        var changed = await client.PostAsJsonAsync(
            $"/api/admin/customers/{first.Id}/change-route",
            new { routeId = targetRoute });
        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/customers/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_depot_summary_is_single_main_warehouse()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<DepotOperationsDto>>("/api/depot/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.Equal(1, summary!.Data!.Kpis.TotalDepots);
        Assert.Equal(0, summary.Data.Kpis.SatelliteHubs);
        Assert.Equal(1, summary.Data.Kpis.CentralWarehouses);
        Assert.False(string.IsNullOrWhiteSpace(summary.Data.Depot.Name));
        Assert.Contains("single Main Warehouse", summary.Data.ScopeNote, StringComparison.OrdinalIgnoreCase);

        var depot = await client.GetFromJsonAsync<ApiResponse<DepotDetailDto>>("/api/depot", Json);
        Assert.NotNull(depot?.Data);
        Assert.Equal(summary.Data.Depot.Id, depot!.Data!.Id);

        var fleet = await client.GetFromJsonAsync<ApiResponse<List<DepotFleetMemberDto>>>("/api/depot/fleet", Json);
        Assert.NotNull(fleet?.Data);
        Assert.True(fleet!.Data!.Count >= 0);

        var stock = await client.GetFromJsonAsync<ApiResponse<List<DepotStockLineDto>>>("/api/depot/stock", Json);
        Assert.NotNull(stock?.Data);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/depot/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_sales_ledger_is_sql_backed()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<AdminSalesSummaryDto>>("/api/admin/sales/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.CompletedSales >= 0);
        Assert.True(summary.Data.TodaysBilledSales >= 0);
        Assert.True(summary.Data.PendingSyncCount >= 0);

        var page = await client.GetFromJsonAsync<ApiResponse<List<AdminSaleRowDto>>>(
            "/api/admin/sales?page=1&pageSize=10&type=All", Json);
        Assert.NotNull(page?.Data);
        Assert.NotNull(page!.Pagination);

        if (page.Data!.Count > 0)
        {
            var first = page.Data[0];
            var detail = await client.GetFromJsonAsync<ApiResponse<AdminSaleDetailDto>>(
                $"/api/admin/sales/{first.Id}", Json);
            Assert.NotNull(detail?.Data);
            Assert.Equal(first.Id, detail!.Data!.Id);
            Assert.Equal(first.ReceiptNumber, detail.Data.ReceiptNumber);
        }

        var cash = await client.GetFromJsonAsync<ApiResponse<List<AdminSaleRowDto>>>(
            "/api/admin/sales?type=Cash&page=1&pageSize=5", Json);
        Assert.NotNull(cash?.Data);
        Assert.All(cash!.Data!, row => Assert.Equal("Cash", row.TenderClass));

        var credit = await client.GetFromJsonAsync<ApiResponse<List<AdminSaleRowDto>>>(
            "/api/admin/sales?type=Credit&page=1&pageSize=5", Json);
        Assert.NotNull(credit?.Data);
        Assert.All(credit!.Data!, row => Assert.Equal("Credit", row.TenderClass));

        var pending = await client.GetFromJsonAsync<ApiResponse<List<AdminSaleRowDto>>>(
            "/api/admin/sales?type=PendingSync&page=1&pageSize=5", Json);
        Assert.NotNull(pending?.Data);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/sales/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_collections_ledger_is_sql_backed()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<AdminCollectionsSummaryDto>>(
            "/api/admin/collections/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.ReceivablesLedger >= 0);
        Assert.True(summary.Data.PendingSyncCount >= 0);

        var pending = await client.GetFromJsonAsync<ApiResponse<List<AdminCollectionRowDto>>>(
            "/api/admin/collections?type=PendingSync&page=1&pageSize=10", Json);
        Assert.NotNull(pending?.Data);

        var exposure = await client.GetFromJsonAsync<ApiResponse<List<AdminReceivableExposureDto>>>(
            "/api/admin/receivables/exposure", Json);
        Assert.NotNull(exposure?.Data);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/collections/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_reports_hub_is_sql_backed()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<AdminReportsSummaryDto>>(
            "/api/admin/reports/summary?from=2026-11-01&to=2026-11-19", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.TotalRealizedSales >= 0);
        Assert.NotEmpty(summary.Data.SalesSeries);
        Assert.NotEmpty(summary.Data.Fulfillment);

        var catalog = await client.GetFromJsonAsync<ApiResponse<List<AdminReportCatalogItemDto>>>(
            "/api/admin/reports/catalog", Json);
        Assert.NotNull(catalog?.Data);
        Assert.NotEmpty(catalog!.Data!);

        var key = catalog.Data[0].Key;
        var table = await client.GetFromJsonAsync<ApiResponse<AdminReportTableDto>>(
            $"/api/admin/reports/{key}?from=2026-11-01&to=2026-11-19", Json);
        Assert.NotNull(table?.Data);
        Assert.Equal(key, table!.Data!.Key);

        var csv = await client.GetAsync($"/api/admin/reports/{key}/export.csv?from=2026-11-01&to=2026-11-19");
        Assert.Equal(HttpStatusCode.OK, csv.StatusCode);
        Assert.Equal("text/csv", csv.Content.Headers.ContentType?.MediaType);
        var body = await csv.Content.ReadAsStringAsync();
        Assert.False(string.IsNullOrWhiteSpace(body));

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/reports/catalog")).StatusCode);
    }

    [Fact]
    public async Task Admin_security_audit_trail_is_read_only()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<AdminAuditSummaryDto>>(
            "/api/admin/audit/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.True(summary!.Data!.TotalEventsToday >= 0);
        Assert.Contains("VerificationUnavailable", summary.Data.IntegrityNote, StringComparison.OrdinalIgnoreCase);

        var list = await client.GetFromJsonAsync<ApiResponse<List<AdminAuditEventRowDto>>>(
            "/api/admin/audit/events?page=1&pageSize=10", Json);
        Assert.NotNull(list?.Data);

        if (list!.Data!.Count > 0)
        {
            var id = list.Data[0].Id;
            var detail = await client.GetFromJsonAsync<ApiResponse<AdminAuditEventDetailDto>>(
                $"/api/admin/audit/events/{id}", Json);
            Assert.NotNull(detail?.Data);
            Assert.Equal("VerificationUnavailable", detail!.Data!.VerificationStatus);

            var verify = await client.PostAsync($"/api/admin/audit/events/{id}/verify", null);
            Assert.Equal(HttpStatusCode.OK, verify.StatusCode);
            var verifyBody = await verify.Content.ReadFromJsonAsync<ApiResponse<AdminAuditVerifyResultDto>>(Json);
            Assert.Equal("VerificationUnavailable", verifyBody?.Data?.Status);
        }

        var csv = await client.GetAsync("/api/admin/audit/export.csv");
        Assert.Equal(HttpStatusCode.OK, csv.StatusCode);
        Assert.Equal("text/csv", csv.Content.Headers.ContentType?.MediaType);

        Assert.Equal(HttpStatusCode.MethodNotAllowed, (await client.DeleteAsync("/api/admin/audit/events")).StatusCode);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/audit/summary")).StatusCode);
    }

    [Fact]
    public async Task Admin_communication_sms_templates_and_gateway()
    {
        var client = await AdminClientAsync();
        var summary = await client.GetFromJsonAsync<ApiResponse<CommunicationDashboardSummaryDto>>(
            "/api/admin/communication/summary", Json);
        Assert.NotNull(summary?.Data);
        Assert.False(summary!.Data!.Gateway.IsConfigured);
        Assert.Equal("NotConfigured", summary.Data.Gateway.Status);

        var templates = await client.GetFromJsonAsync<ApiResponse<List<CommunicationTemplateDto>>>(
            "/api/admin/communication/templates", Json);
        Assert.NotNull(templates?.Data);
        Assert.NotEmpty(templates!.Data!);

        var create = await client.PostAsJsonAsync("/api/admin/communication/templates", new CommunicationTemplateWriteRequest(
            "QA Order Confirm",
            "en",
            "OrderConfirmed",
            "Hello {customer_name}, order {order_id} confirmed.",
            $"T-QA-{Guid.NewGuid():N}"[..12].ToUpperInvariant()), Json);
        Assert.Equal(HttpStatusCode.Created, create.StatusCode);
        var created = await create.Content.ReadFromJsonAsync<ApiResponse<CommunicationTemplateDto>>(Json);
        Assert.NotNull(created?.Data);

        var preview = await client.PostAsJsonAsync("/api/admin/communication/preview", new CommunicationPreviewRequest(
            created!.Data!.Id,
            new Dictionary<string, string>
            {
                ["customer_name"] = "Ali Store",
                ["order_id"] = "ORD-1"
            }), Json);
        Assert.Equal(HttpStatusCode.OK, preview.StatusCode);
        var previewBody = await preview.Content.ReadFromJsonAsync<ApiResponse<CommunicationPreviewDto>>(Json);
        Assert.Contains("Ali Store", previewBody?.Data?.RenderedContent ?? "");

        var enqueue = await client.PostAsJsonAsync("/api/admin/communication/messages", new CommunicationEnqueueRequest(
            null,
            created.Data.Id,
            "03001234567",
            "TXN-TEST-1",
            new Dictionary<string, string>
            {
                ["customer_name"] = "Ali Store",
                ["order_id"] = "ORD-1"
            },
            $"idem-{Guid.NewGuid():N}"), Json);
        Assert.True(enqueue.IsSuccessStatusCode);
        var message = await enqueue.Content.ReadFromJsonAsync<ApiResponse<CommunicationMessageDetailDto>>(Json);
        Assert.NotNull(message?.Data);
        Assert.Equal("NotConfigured", message!.Data!.Status);
        Assert.Equal("SMS", message.Data.Channel);

        var retry = await client.PostAsync($"/api/admin/communication/messages/{message.Data.Id}/retry", null);
        Assert.Equal(HttpStatusCode.OK, retry.StatusCode);

        var gatewayTest = await client.PostAsync("/api/admin/communication/gateway/test", null);
        Assert.Equal(HttpStatusCode.OK, gatewayTest.StatusCode);

        var messagesCsv = await client.GetAsync("/api/admin/communication/messages/export.csv");
        Assert.Equal(HttpStatusCode.OK, messagesCsv.StatusCode);

        var rider = await RiderClientAsync();
        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/communication/templates")).StatusCode);
    }

    [Fact]
    public async Task Live_tracking_requires_open_shift_and_admin_can_read_empty_board()
    {
        var rider = await RiderClientAsync();
        var status = await rider.GetAsync("/api/rider/tracking/status");
        Assert.Equal(HttpStatusCode.OK, status.StatusCode);

        var start = await rider.PostAsync("/api/rider/tracking/start", null);
        Assert.Equal(HttpStatusCode.Conflict, start.StatusCode);

        var assignment = await rider.GetAsync("/api/rider/assignments/active");
        Assert.Equal(HttpStatusCode.OK, assignment.StatusCode);

        var admin = await AdminClientAsync();
        var overview = await admin.GetAsync("/api/admin/live-tracking/overview");
        Assert.Equal(HttpStatusCode.OK, overview.StatusCode);
        var overviewBody = await overview.Content.ReadFromJsonAsync<ApiResponse<LiveTrackingOverviewDto>>(Json);
        Assert.NotNull(overviewBody?.Data);
        Assert.Equal(0, overviewBody!.Data!.RidersOnDuty);

        var riders = await admin.GetAsync("/api/admin/live-tracking/riders");
        Assert.Equal(HttpStatusCode.OK, riders.StatusCode);

        var anomalies = await admin.GetAsync("/api/admin/route-anomalies");
        Assert.Equal(HttpStatusCode.OK, anomalies.StatusCode);

        Assert.Equal(HttpStatusCode.Forbidden, (await rider.GetAsync("/api/admin/live-tracking/overview")).StatusCode);
    }
}
