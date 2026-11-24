using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _users;
    private readonly RoleManager<IdentityRole> _roles;
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;
    private readonly ICurrentUser _current;
    private readonly IHttpContextAccessor _http;
    private readonly SsoOptions _sso;
    private readonly IUserAdminService _staff;

    public AuthService(
        UserManager<ApplicationUser> users,
        RoleManager<IdentityRole> roles,
        AppDbContext db,
        IConfiguration config,
        ICurrentUser current,
        IHttpContextAccessor http,
        IOptions<SsoOptions> sso,
        IUserAdminService staff)
    {
        _users = users;
        _roles = roles;
        _db = db;
        _config = config;
        _current = current;
        _http = http;
        _sso = sso.Value;
        _staff = staff;
    }

    public async Task<ServiceResult<AuthResponseDto>> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var username = request.Identifier;
        if (username.Length == 0 || string.IsNullOrEmpty(request.Password))
        {
            return ServiceResult<AuthResponseDto>.Fail(400, "Enter your username and password.");
        }

        var user = await FindUserAsync(username);

        if (user is null || !user.IsActive)
        {
            return ServiceResult<AuthResponseDto>.Fail(401, "Incorrect username or password.");
        }

        if (await _users.IsLockedOutAsync(user))
        {
            return ServiceResult<AuthResponseDto>.Fail(401, "Incorrect username or password.");
        }

        var passwordOk = await _users.CheckPasswordAsync(user, request.Password);
        if (!passwordOk)
        {
            await _users.AccessFailedAsync(user);
            return ServiceResult<AuthResponseDto>.Fail(401, "Incorrect username or password.");
        }

        var customerAccount = await _db.CustomerAccounts.AsNoTracking().FirstOrDefaultAsync(item => item.UserId == user.Id, cancellationToken);
        if (customerAccount is not null && customerAccount.Status.Equals("Suspended", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<AuthResponseDto>.Fail(403, "This customer account is suspended.");
        }

        user.LastLoginAtUtc = DateTime.UtcNow;
        await _users.ResetAccessFailedCountAsync(user);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = user.Id,
            Action = "Login",
            EntityName = "User",
            EntityId = user.Id
        });
        var response = await IssueAsync(user, request.RememberMe, cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<AuthResponseDto>.Ok(response, "Signed in.");
    }

    public async Task<ServiceResult<AuthResponseDto>> RefreshAsync(string refreshToken, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return ServiceResult<AuthResponseDto>.Fail(401, "The refresh token is missing.");
        }

        var hash = Hash(refreshToken);
        var stored = await _db.RefreshTokens.FirstOrDefaultAsync(token => token.TokenHash == hash, cancellationToken);
        if (stored is null)
        {
            return ServiceResult<AuthResponseDto>.Fail(401, "The refresh token is invalid.");
        }

        if (stored.RevokedAt is not null || stored.ExpiresAt <= DateTime.UtcNow)
        {
            await RevokeActiveAsync(stored.UserId, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);
            return ServiceResult<AuthResponseDto>.Fail(401, "The refresh token is invalid.");
        }

        var user = await _users.FindByIdAsync(stored.UserId);
        if (user is null || !user.IsActive)
        {
            return ServiceResult<AuthResponseDto>.Fail(401, "The refresh token is invalid.");
        }

        stored.RevokedAt = DateTime.UtcNow;
        var response = await IssueAsync(user, stored.RememberMe, cancellationToken);
        stored.ReplacedByHash = Hash(response.RefreshToken);
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<AuthResponseDto>.Ok(response, "Token refreshed.");
    }

    public async Task<ServiceResult<object>> LogoutAsync(string? refreshToken, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<object>.Fail(401, "Sign in required.");
        }

        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            var hash = Hash(refreshToken);
            var stored = await _db.RefreshTokens.FirstOrDefaultAsync(
                token => token.TokenHash == hash && token.UserId == _current.UserId,
                cancellationToken);
            if (stored is not null && stored.RevokedAt is null)
            {
                stored.RevokedAt = DateTime.UtcNow;
            }
        }
        else
        {
            await RevokeActiveAsync(_current.UserId, cancellationToken);
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId,
            Action = "Logout",
            EntityName = "User",
            EntityId = _current.UserId
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Signed out.");
    }

    public async Task<ServiceResult<object>> ForgotPasswordAsync(string username, CancellationToken cancellationToken)
    {
        const string message = "Ask your fleet admin to reset this password.";
        if (!string.IsNullOrWhiteSpace(username))
        {
            var user = await FindUserAsync(username.Trim());
            if (user is not null && user.IsActive)
            {
                // Identity can mint a reset token, but SMTP is not configured.
                // The token is not stored and is never returned to the caller.
                _ = await _users.GeneratePasswordResetTokenAsync(user);
                _db.PasswordResetRequests.Add(new PasswordResetRequest { UserId = user.Id });
                await _db.SaveChangesAsync(cancellationToken);
            }
        }

        return ServiceResult<object>.Ok(new { }, message);
    }

    public async Task<ServiceResult<object>> ResetPasswordAsync(PasswordResetConfirmRequest request, CancellationToken cancellationToken)
    {
        var identifier = request.Identifier;
        if (identifier.Length == 0 || string.IsNullOrWhiteSpace(request.Token) || string.IsNullOrWhiteSpace(request.NewPassword))
        {
            return ServiceResult<object>.Fail(400, "Email or username, reset token, and a new password are required.");
        }

        var user = await FindUserAsync(identifier);
        if (user is null || !user.IsActive)
        {
            return ServiceResult<object>.Fail(400, "The password was not reset.");
        }

        var result = await _users.ResetPasswordAsync(user, request.Token, request.NewPassword);
        if (!result.Succeeded)
        {
            return ServiceResult<object>.Fail(400, "The password was not reset.", result.Errors.Select(error => error.Description).ToArray());
        }

        await RevokeActiveAsync(user.Id, cancellationToken);
        var pending = await _db.PasswordResetRequests
            .Where(item => item.UserId == user.Id && item.Status == ResetRequestStatus.Pending)
            .ToListAsync(cancellationToken);
        foreach (var item in pending)
        {
            item.Status = ResetRequestStatus.Completed;
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = user.Id,
            Action = "ResetPassword",
            EntityName = "User",
            EntityId = user.Id
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Password reset. Sign in with the new password.");
    }

    public Task<ServiceResult<SsoStatusDto>> SsoStatusAsync(CancellationToken cancellationToken)
    {
        var status = new SsoStatusDto(
            new SsoProviderStatusDto("Okta", _sso.Okta.IsConfigured),
            new SsoProviderStatusDto("AzureAd", _sso.AzureAd.IsConfigured));
        return Task.FromResult(ServiceResult<SsoStatusDto>.Ok(status, "SSO status loaded."));
    }

    public async Task<ServiceResult<AuthUserDto>> MeAsync(CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<AuthUserDto>.Fail(401, "Sign in required.");
        }

        var user = await LoadUserAsync(_current.UserId, cancellationToken);
        if (user is null)
        {
            return ServiceResult<AuthUserDto>.Fail(401, "Sign in required.");
        }

        return ServiceResult<AuthUserDto>.Ok(await ToDtoAsync(user), "Profile loaded.");
    }

    public async Task<ServiceResult<object>> ChangePasswordAsync(ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        if (_current.UserId is null)
        {
            return ServiceResult<object>.Fail(401, "Sign in required.");
        }

        var user = await _users.FindByIdAsync(_current.UserId);
        if (user is null)
        {
            return ServiceResult<object>.Fail(401, "Sign in required.");
        }

        var result = await _users.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword);
        if (!result.Succeeded)
        {
            return ServiceResult<object>.Fail(400, "The password was not changed.", result.Errors.Select(error => error.Description).ToArray());
        }

        await RevokeActiveAsync(user.Id, cancellationToken);
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = user.Id,
            Action = "ChangePassword",
            EntityName = "User",
            EntityId = user.Id
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Password changed. Sign in again.");
    }

    private async Task<AuthResponseDto> IssueAsync(ApplicationUser user, bool rememberMe, CancellationToken cancellationToken)
    {
        var loaded = await LoadUserAsync(user.Id, cancellationToken) ?? user;
        var roles = await _users.GetRolesAsync(loaded);
        var role = AppRoles.Primary(roles);
        var minutes = _config.GetValue("Jwt:AccessMinutes", 30);
        var days = rememberMe
            ? _config.GetValue("Jwt:RememberRefreshDays", 30)
            : _config.GetValue("Jwt:RefreshDays", 14);
        var now = DateTime.UtcNow;
        var expires = now.AddMinutes(minutes);
        var access = CreateAccessToken(loaded, roles, role, expires);
        var refresh = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        _db.RefreshTokens.Add(new RefreshToken
        {
            UserId = loaded.Id,
            TokenHash = Hash(refresh),
            ExpiresAt = now.AddDays(days),
            CreatedAt = now,
            RememberMe = rememberMe,
            DeviceInformation = DeviceInformation()
        });
        return new AuthResponseDto(access, refresh, expires, await ToDtoAsync(loaded));
    }

    private string CreateAccessToken(ApplicationUser user, IList<string> roles, string role, DateTime expires)
    {
        var keyText = _config["Jwt:Key"] ?? "";
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(keyText));
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id),
            new(ClaimTypes.Name, user.UserName ?? ""),
            new(ClaimTypes.Role, role)
        };
        foreach (var extra in roles)
        {
            if (!string.Equals(extra, role, StringComparison.Ordinal))
            {
                claims.Add(new Claim(ClaimTypes.Role, extra));
            }
        }

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: expires,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private async Task<ApplicationUser?> LoadUserAsync(string id, CancellationToken cancellationToken)
    {
        return await _db.Users
            .Include(user => user.Route)
            .Include(user => user.Vehicle)
            .Include(user => user.Depot)
            .FirstOrDefaultAsync(user => user.Id == id, cancellationToken);
    }

    private async Task<AuthUserDto> ToDtoAsync(ApplicationUser user)
    {
        var roles = await _users.GetRolesAsync(user);
        var roleList = roles.ToArray();
        var screens = await _staff.ScreensForRolesAsync(roleList, CancellationToken.None);
        return new AuthUserDto(
            user.Id,
            user.UserName ?? "",
            user.FullName,
            user.RiderCode,
            AppRoles.Primary(roleList),
            user.Route?.Name,
            user.Vehicle?.Name,
            user.Vehicle?.Plate,
            user.Vehicle?.FleetCode,
            user.Depot?.Gate,
            user.Depot?.Name,
            roleList,
            screens,
            await _db.CustomerAccounts.AsNoTracking()
                .Where(account => account.UserId == user.Id)
                .Select(account => account.Code)
                .FirstOrDefaultAsync());
    }

    public async Task<ServiceResult<AdminLoginPreviewDto>> LoginPreviewAsync(CancellationToken cancellationToken)
    {
        var day = ReportingWindow.Today();
        var (start, end) = ReportingWindow.UtcBounds(day, day);
        var previousDay = day.AddDays(-1);
        var (prevStart, prevEnd) = ReportingWindow.UtcBounds(previousDay, previousDay);

        // Same day window and ledgers as CommandDashboard sales / collections summaries.
        var todaySales = await _db.Sales.AsNoTracking()
            .Where(item => item.Status == SaleStatus.Completed && item.CreatedAt >= start && item.CreatedAt < end)
            .Select(item => new
            {
                item.SaleAmount,
                item.AmountReceived,
                item.PreviousOutstanding,
                item.PaymentChannel
            })
            .ToListAsync(cancellationToken);
        var previousBilled = await _db.Sales.AsNoTracking()
            .Where(item => item.Status == SaleStatus.Completed && item.CreatedAt >= prevStart && item.CreatedAt < prevEnd)
            .SumAsync(item => (decimal?)item.SaleAmount, cancellationToken) ?? 0;

        var billed = todaySales.Sum(item => item.SaleAmount);
        var cashSalesInward = todaySales
            .Where(item =>
                item.AmountReceived > 0
                && item.AmountReceived >= item.SaleAmount + item.PreviousOutstanding
                && item.PaymentChannel == PaymentChannel.Cash)
            .Sum(item => item.AmountReceived);
        var cashCollections = await _db.Collections.AsNoTracking()
            .Where(item =>
                item.CreatedAt >= start
                && item.CreatedAt < end
                && item.Channel == PaymentChannel.Cash
                && item.Amount >= item.OutstandingBefore)
            .SumAsync(item => (decimal?)item.Amount, cancellationToken) ?? 0;
        var cashReconciled = cashSalesInward + cashCollections;

        var dropsTotal = await _db.RouteStops.AsNoTracking()
            .CountAsync(item => item.ServiceDate == day, cancellationToken);
        var dropsBalanced = await _db.RouteStops.AsNoTracking()
            .CountAsync(item => item.ServiceDate == day && item.Status == StopStatus.Completed, cancellationToken);

        decimal? changePercent = previousBilled == 0
            ? null
            : ReportingWindow.Percent(billed - previousBilled, previousBilled);

        var dto = new AdminLoginPreviewDto(
            day,
            billed,
            previousBilled,
            changePercent,
            cashReconciled,
            dropsBalanced,
            dropsTotal,
            "Login preview uses the same sales, cash collection and route-stop ledgers as Sales / Collections / Day Close.");
        return ServiceResult<AdminLoginPreviewDto>.Ok(dto, "Login preview loaded.");
    }

    public async Task<ServiceResult<CustomerRegistrationDto>> RegisterCustomerAsync(RegisterCustomerRequest request, CancellationToken cancellationToken)
    {
        var first = request.FirstName.Trim();
        var last = request.LastName.Trim();
        var email = request.Email.Trim().ToLowerInvariant();
        var city = request.City.Trim();
        var area = request.Area.Trim();
        var street = request.Street.Trim();
        var house = request.HouseNumber.Trim();
        var phone = NormalizePhone(request.Phone);
        if (first.Length == 0 || last.Length == 0)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "First name and last name are required.");
        }

        if (phone is null)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "Enter a valid phone number.");
        }

        if (!IsEmail(email))
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "Enter a valid email address.");
        }

        if (city.Length == 0 || area.Length == 0 || street.Length == 0 || house.Length == 0)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "City, area, street, and house number are required.");
        }

        if ((request.Latitude is null) != (request.Longitude is null)
            || request.Latitude is < -90 or > 90
            || request.Longitude is < -180 or > 180)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "The delivery location is incomplete.");
        }

        if (!request.AcceptedTerms)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "Accept the terms to create an account.");
        }

        if (request.Password != request.ConfirmPassword)
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(400, "Passwords do not match.");
        }

        if (await _users.FindByEmailAsync(email) is not null
            || await _db.CustomerAccounts.AnyAsync(item => item.Email == email, cancellationToken))
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(409, "An account with this email already exists.");
        }

        var knownPhones = await _db.Users.AsNoTracking()
            .Where(item => item.PhoneNumber != null)
            .Select(item => item.PhoneNumber!)
            .ToListAsync(cancellationToken);
        var accountPhones = await _db.CustomerAccounts.AsNoTracking()
            .Select(item => item.Phone)
            .ToListAsync(cancellationToken);
        if (knownPhones.Concat(accountPhones).Any(item => NormalizePhone(item) == phone))
        {
            return ServiceResult<CustomerRegistrationDto>.Fail(409, "An account with this phone number already exists.");
        }

        if (!await _roles.RoleExistsAsync(AppRoles.Customer))
        {
            await _roles.CreateAsync(new IdentityRole(AppRoles.Customer));
        }

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            FullName = $"{first} {last}",
            PhoneNumber = phone,
            IsActive = true
        };
        await using var transaction = await _db.Database.BeginTransactionAsync(cancellationToken);
        var created = await _users.CreateAsync(user, request.Password);
        if (!created.Succeeded)
        {
            var detail = string.Join(" ", created.Errors.Select(error => error.Description));
            return ServiceResult<CustomerRegistrationDto>.Fail(400, string.IsNullOrWhiteSpace(detail) ? "The password is too weak." : detail);
        }

        await _users.AddToRoleAsync(user, AppRoles.Customer);
        var sequence = await _db.NumberSequences.FirstOrDefaultAsync(item => item.Name == "CustomerAccount", cancellationToken);
        if (sequence is null)
        {
            sequence = new NumberSequence { Name = "CustomerAccount", NextValue = 1 };
            _db.NumberSequences.Add(sequence);
        }

        var code = $"CUS-{sequence.NextValue:000000}";
        sequence.NextValue++;
        _db.CustomerAccounts.Add(new CustomerAccount
        {
            UserId = user.Id,
            Code = code,
            FirstName = first,
            LastName = last,
            Phone = phone,
            Email = email,
            City = city,
            Area = area,
            Street = street,
            HouseNumber = house,
            Landmark = TrimOrNull(request.Landmark, 160),
            Instructions = TrimOrNull(request.Instructions, 300),
            Latitude = request.Latitude,
            Longitude = request.Longitude
        });
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = user.Id,
            Action = "RegisterCustomer",
            EntityName = "CustomerAccount",
            EntityId = user.Id
        });
        await _db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return ServiceResult<CustomerRegistrationDto>.Ok(
            new CustomerRegistrationDto(code, user.FullName, email),
            "Customer account created.");
    }

    private static string? NormalizePhone(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var digits = new string(raw.Where(char.IsDigit).ToArray());
        if (digits.StartsWith("00")) digits = digits[2..];
        if (digits.Length == 11 && digits.StartsWith('0')) digits = "92" + digits[1..];
        if (digits.Length == 10 && digits.StartsWith('3')) digits = "92" + digits;
        if (digits.Length < 10 || digits.Length > 15) return null;
        return "+" + digits;
    }

    private static bool IsEmail(string value)
    {
        if (value.Length is < 6 or > 180 || !value.Contains('@')) return false;
        var parts = value.Split('@');
        return parts.Length == 2 && parts[0].Length > 0 && parts[1].Contains('.') && !parts[1].StartsWith('.') && !parts[1].EndsWith('.');
    }

    private static string? TrimOrNull(string? value, int max)
    {
        var text = value?.Trim();
        if (string.IsNullOrEmpty(text)) return null;
        return text.Length <= max ? text : text[..max];
    }

    private async Task<ApplicationUser?> FindUserAsync(string identifier)
    {
        var user = await _users.FindByNameAsync(identifier);
        if (user is null)
        {
            user = await _users.FindByEmailAsync(identifier);
        }

        return user;
    }

    private string? DeviceInformation()
    {
        var value = _http.HttpContext?.Request.Headers.UserAgent.ToString();
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Length <= 512 ? trimmed : trimmed[..512];
    }

    private async Task RevokeActiveAsync(string userId, CancellationToken cancellationToken)
    {
        var active = await _db.RefreshTokens
            .Where(token => token.UserId == userId && token.RevokedAt == null)
            .ToListAsync(cancellationToken);
        var now = DateTime.UtcNow;
        foreach (var token in active)
        {
            token.RevokedAt = now;
        }
    }

    private static string Hash(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes);
    }
}
