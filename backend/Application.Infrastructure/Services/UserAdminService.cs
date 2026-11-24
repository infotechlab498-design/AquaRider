using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RouteLedger.Application;
using RouteLedger.Domain;
using RouteLedger.Infrastructure.Data;
using RouteLedger.Infrastructure.Identity;

namespace RouteLedger.Infrastructure.Services;

public sealed class UserAdminService : IUserAdminService
{
    private readonly UserManager<ApplicationUser> _users;
    private readonly RoleManager<IdentityRole> _roles;
    private readonly AppDbContext _db;
    private readonly ICurrentUser _current;

    public UserAdminService(
        UserManager<ApplicationUser> users,
        RoleManager<IdentityRole> roles,
        AppDbContext db,
        ICurrentUser current)
    {
        _users = users;
        _roles = roles;
        _db = db;
        _current = current;
    }

    public async Task<ServiceResult<StaffSummaryDto>> SummaryAsync(CancellationToken cancellationToken)
    {
        var users = await _db.Users.AsNoTracking().ToListAsync(cancellationToken);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var admins = 0;
        var riders = 0;
        foreach (var user in users)
        {
            var roles = await _users.GetRolesAsync(user);
            if (roles.Contains(AppRoles.Admin))
            {
                admins++;
            }

            if (roles.Contains(AppRoles.Rider) || !string.IsNullOrWhiteSpace(user.RiderCode))
            {
                riders++;
            }
        }

        var dto = new StaffSummaryDto(
            users.Count,
            users.Count(item => item.IsActive),
            users.Count(item => !item.IsActive),
            riders,
            admins,
            users.Count(item =>
                item.LastLoginAtUtc is not null
                && DateOnly.FromDateTime(item.LastLoginAtUtc.Value) == today));
        return ServiceResult<StaffSummaryDto>.Ok(dto, "Staff summary loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<RoleReferenceDto>>> RoleReferenceAsync(CancellationToken cancellationToken)
    {
        var users = await _db.Users.AsNoTracking().ToListAsync(cancellationToken);
        var adminCount = 0;
        var riderCount = 0;
        foreach (var user in users)
        {
            var roles = await _users.GetRolesAsync(user);
            if (roles.Contains(AppRoles.Admin))
            {
                adminCount++;
            }

            if (roles.Contains(AppRoles.Rider))
            {
                riderCount++;
            }
        }

        IReadOnlyList<RoleReferenceDto> rows =
        [
            new RoleReferenceDto(
                AppRoles.Admin,
                "Administrator",
                "Full HQ access: dashboard, dispatch, settlements, catalogue, zones, customers, and staff.",
                adminCount),
            new RoleReferenceDto(
                AppRoles.Rider,
                "Delivery Rider",
                "Field app access: stops, sales, collections, shift stock, and route-scoped customers.",
                riderCount)
        ];
        return ServiceResult<IReadOnlyList<RoleReferenceDto>>.Ok(rows, "Locked V1 role reference loaded.");
    }

    public async Task<ServiceResult<IReadOnlyList<UserDto>>> ListAsync(
        string? search,
        string? role,
        bool? isActive,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var (pageIndex, size) = ReportingWindow.NormalizePage(page, pageSize);
        var query = _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .Include(item => item.Zone)
            .Include(item => item.WarehousePerson)
            .AsQueryable();

        if (isActive is not null)
        {
            query = query.Where(item => item.IsActive == isActive);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(item =>
                item.FullName.Contains(term)
                || (item.UserName != null && item.UserName.Contains(term))
                || (item.RiderCode != null && item.RiderCode.Contains(term))
                || (item.PhoneNumber != null && item.PhoneNumber.Contains(term))
                || (item.Email != null && item.Email.Contains(term)));
        }

        var users = await query.OrderBy(item => item.FullName).ToListAsync(cancellationToken);
        var roleFilter = string.IsNullOrWhiteSpace(role) || role.Equals("all", StringComparison.OrdinalIgnoreCase)
            ? null
            : role.Trim();
        if (roleFilter is not null && !await _roles.RoleExistsAsync(roleFilter))
        {
            return ServiceResult<IReadOnlyList<UserDto>>.Fail(400, "Choose a role that exists.");
        }

        var mapped = new List<UserDto>();
        foreach (var user in users)
        {
            var dto = await ToDtoAsync(user);
            if (roleFilter is not null && !dto.Roles.Contains(roleFilter, StringComparer.OrdinalIgnoreCase))
            {
                continue;
            }

            mapped.Add(dto);
        }

        var total = mapped.Count;
        IReadOnlyList<UserDto> pageRows = mapped.Skip((pageIndex - 1) * size).Take(size).ToList();
        var pages = size == 0 ? 0 : (int)Math.Ceiling(total / (double)size);
        return ServiceResult<IReadOnlyList<UserDto>>.Ok(
            pageRows,
            pageRows.Count == 0 ? "No staff matched the filters." : "Users loaded.",
            new PaginationMeta { Page = pageIndex, PageSize = size, TotalRecords = total, TotalPages = pages });
    }

    public async Task<ServiceResult<UserDto>> GetAsync(string id, CancellationToken cancellationToken)
    {
        var user = await _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .Include(item => item.Zone)
            .Include(item => item.WarehousePerson)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (user is null)
        {
            return ServiceResult<UserDto>.Fail(404, "User not found.");
        }

        return ServiceResult<UserDto>.Ok(await ToDtoAsync(user), "User loaded.");
    }

    public async Task<ServiceResult<UserDto>> CreateAsync(CreateUserRequest request, CancellationToken cancellationToken)
    {
        var roleName = (request.Role ?? "").Trim();
        if (!await _roles.RoleExistsAsync(roleName))
        {
            return ServiceResult<UserDto>.Fail(400, "Choose a role that already exists.");
        }

        var isRider = roleName.Equals(AppRoles.Rider, StringComparison.OrdinalIgnoreCase);
        if (request.RouteId is not null && !await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Assign a valid route.");
        }

        if (request.VehicleId is not null && !await _db.Vehicles.AnyAsync(item => item.Id == request.VehicleId, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Assign a valid vehicle.");
        }

        Zone? zone = null;
        if (request.ZoneId is Guid zoneId)
        {
            zone = await _db.Zones.AsNoTracking().FirstOrDefaultAsync(item => item.Id == zoneId, cancellationToken);
            if (zone is null)
            {
                return ServiceResult<UserDto>.Fail(400, "Choose a zone that exists.");
            }
        }

        var depotId = request.DepotId ?? (isRider ? zone?.DepotId : null);
        if (depotId is Guid chosenDepot && !await _db.Depots.AnyAsync(item => item.Id == chosenDepot, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Choose a warehouse that exists.");
        }

        if (zone is not null && depotId is Guid warehouseId && zone.DepotId != warehouseId)
        {
            return ServiceResult<UserDto>.Fail(400, "That warehouse is not on the selected zone.");
        }

        if (isRider && depotId is null)
        {
            depotId = await _db.Depots.OrderBy(item => item.Name).Select(item => (Guid?)item.Id).FirstOrDefaultAsync(cancellationToken);
        }

        var personId = string.IsNullOrWhiteSpace(request.WarehousePersonUserId) ? null : request.WarehousePersonUserId.Trim();
        if (personId is not null)
        {
            if (!isRider)
            {
                return ServiceResult<UserDto>.Fail(400, "Only a rider is labeled with a warehouse person.");
            }

            if (depotId is null)
            {
                return ServiceResult<UserDto>.Fail(400, "Choose a warehouse before labeling the rider.");
            }

            var person = await _users.FindByIdAsync(personId);
            if (person is null)
            {
                return ServiceResult<UserDto>.Fail(400, "Choose a warehouse person who already has an account.");
            }

            if (await _users.IsInRoleAsync(person, AppRoles.Rider))
            {
                return ServiceResult<UserDto>.Fail(400, "A rider cannot be the warehouse person.");
            }

            if (person.DepotId != depotId)
            {
                return ServiceResult<UserDto>.Fail(400, "That person is not assigned to this warehouse.");
            }
        }

        var username = request.Username.Trim();
        var riderCode = string.IsNullOrWhiteSpace(request.RiderCode) ? null : request.RiderCode.Trim();
        if (isRider && riderCode is null)
        {
            riderCode = await NextRiderCodeAsync(cancellationToken);
        }

        var user = new ApplicationUser
        {
            UserName = username,
            Email = string.IsNullOrWhiteSpace(request.Email) ? $"{username}@rider.local" : request.Email.Trim(),
            FullName = request.FullName.Trim(),
            PhoneNumber = request.Phone?.Trim(),
            RiderCode = riderCode,
            RouteId = request.RouteId,
            VehicleId = request.VehicleId,
            DepotId = depotId,
            ZoneId = isRider ? zone?.Id : null,
            WarehousePersonUserId = personId,
            IsActive = true
        };
        var created = await _users.CreateAsync(user, request.Password);
        if (!created.Succeeded)
        {
            var detail = string.Join(" ", created.Errors.Select(error => error.Description));
            return ServiceResult<UserDto>.Fail(400, string.IsNullOrWhiteSpace(detail) ? "User was not created." : detail);
        }

        await _users.AddToRoleAsync(user, roleName);
        if (isRider)
        {
            _db.RiderSettings.Add(new RiderSettings { UserId = user.Id });
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? user.Id,
            Action = "CreateUser",
            EntityName = "User",
            EntityId = user.Id
        });
        await _db.SaveChangesAsync(cancellationToken);
        var stored = await _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .Include(item => item.Zone)
            .Include(item => item.WarehousePerson)
            .FirstAsync(item => item.Id == user.Id, cancellationToken);
        return ServiceResult<UserDto>.Created(await ToDtoAsync(stored), "User created.");
    }

    public async Task<ServiceResult<UserDto>> UpdateAsync(string id, UpdateUserRequest request, CancellationToken cancellationToken)
    {
        var user = await _db.Users.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (user is null)
        {
            return ServiceResult<UserDto>.Fail(404, "User not found.");
        }

        if (request.RouteId is not null && !await _db.DeliveryRoutes.AnyAsync(item => item.Id == request.RouteId, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Assign a valid route.");
        }

        if (request.VehicleId is not null && !await _db.Vehicles.AnyAsync(item => item.Id == request.VehicleId, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Assign a valid vehicle.");
        }

        if (request.DepotId is not null && !await _db.Depots.AnyAsync(item => item.Id == request.DepotId, cancellationToken))
        {
            return ServiceResult<UserDto>.Fail(400, "Assign a valid depot.");
        }

        user.FullName = request.FullName.Trim();
        user.PhoneNumber = request.Phone?.Trim();
        user.RiderCode = string.IsNullOrWhiteSpace(request.RiderCode) ? null : request.RiderCode.Trim();
        user.RouteId = request.RouteId;
        user.VehicleId = request.VehicleId;
        user.DepotId = request.DepotId;
        var updated = await _users.UpdateAsync(user);
        if (!updated.Succeeded)
        {
            return ServiceResult<UserDto>.Fail(400, "User was not updated.", updated.Errors.Select(error => error.Description).ToArray());
        }

        var stored = await _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .Include(item => item.Zone)
            .Include(item => item.WarehousePerson)
            .FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<UserDto>.Ok(await ToDtoAsync(stored), "User updated.");
    }

    public async Task<ServiceResult<UserDto>> SetStatusAsync(string id, bool isActive, CancellationToken cancellationToken)
    {
        if (id == _current.UserId && !isActive)
        {
            return ServiceResult<UserDto>.Fail(400, "You cannot deactivate your own account.");
        }

        var user = await _db.Users.FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (user is null)
        {
            return ServiceResult<UserDto>.Fail(404, "User not found.");
        }

        user.IsActive = isActive;
        if (!isActive)
        {
            var tokens = await _db.RefreshTokens.Where(token => token.UserId == id && token.RevokedAt == null).ToListAsync(cancellationToken);
            foreach (var token in tokens)
            {
                token.RevokedAt = DateTime.UtcNow;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
        var stored = await _db.Users.AsNoTracking()
            .Include(item => item.Route)
            .Include(item => item.Vehicle)
            .Include(item => item.Depot)
            .Include(item => item.Zone)
            .Include(item => item.WarehousePerson)
            .FirstAsync(item => item.Id == id, cancellationToken);
        return ServiceResult<UserDto>.Ok(await ToDtoAsync(stored), isActive ? "User activated." : "User deactivated.");
    }

    public async Task<ServiceResult<object>> ResetPasswordAsync(string id, string newPassword, CancellationToken cancellationToken)
    {
        var user = await _users.FindByIdAsync(id);
        if (user is null)
        {
            return ServiceResult<object>.Fail(404, "User not found.");
        }

        var token = await _users.GeneratePasswordResetTokenAsync(user);
        var result = await _users.ResetPasswordAsync(user, token, newPassword);
        if (!result.Succeeded)
        {
            return ServiceResult<object>.Fail(400, "Password was not reset.", result.Errors.Select(error => error.Description).ToArray());
        }

        var requests = await _db.PasswordResetRequests
            .Where(item => item.UserId == id && item.Status == ResetRequestStatus.Pending)
            .ToListAsync(cancellationToken);
        foreach (var request in requests)
        {
            request.Status = ResetRequestStatus.Completed;
        }

        var tokens = await _db.RefreshTokens.Where(item => item.UserId == id && item.RevokedAt == null).ToListAsync(cancellationToken);
        foreach (var refresh in tokens)
        {
            refresh.RevokedAt = DateTime.UtcNow;
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? id,
            Action = "ResetPassword",
            EntityName = "User",
            EntityId = id
        });
        await _db.SaveChangesAsync(cancellationToken);
        return ServiceResult<object>.Ok(new { }, "Password reset.");
    }

    private async Task<UserDto> ToDtoAsync(ApplicationUser user)
    {
        var roles = await _users.GetRolesAsync(user);
        var roleList = roles.ToArray();
        return new UserDto(
            user.Id,
            user.UserName ?? "",
            user.FullName,
            user.RiderCode,
            user.PhoneNumber,
            user.IsActive,
            roleList,
            user.RouteId,
            user.Email,
            user.VehicleId,
            user.Vehicle?.Name,
            user.Vehicle?.Plate,
            user.DepotId,
            user.Depot?.Name,
            user.Route?.Name,
            user.LastLoginAtUtc,
            user.CreatedAt,
            AppRoles.Primary(roleList),
            user.ZoneId,
            user.Zone?.Name,
            user.WarehousePersonUserId,
            user.WarehousePerson?.FullName);
    }

    public async Task<ServiceResult<RoleAccessMatrixDto>> AccessMatrixAsync(CancellationToken cancellationToken)
    {
        await EnsureSystemProfilesAsync(cancellationToken);
        var profiles = await _db.RoleProfiles.AsNoTracking().OrderBy(item => item.RoleName).ToListAsync(cancellationToken);
        var grants = await _db.RoleScreenGrants.AsNoTracking().ToListAsync(cancellationToken);
        var users = await _db.Users.AsNoTracking().ToListAsync(cancellationToken);
        var depots = await _db.Depots.AsNoTracking().ToDictionaryAsync(item => item.Id, item => item.Name, cancellationToken);
        var zones = await _db.Zones.AsNoTracking().ToDictionaryAsync(item => item.Id, item => item.Name, cancellationToken);
        var names = users.ToDictionary(item => item.Id, item => item.FullName);
        var membership = new Dictionary<string, List<ApplicationUser>>(StringComparer.OrdinalIgnoreCase);
        foreach (var user in users)
        {
            foreach (var role in await _users.GetRolesAsync(user))
            {
                if (!membership.TryGetValue(role, out var list))
                {
                    list = [];
                    membership[role] = list;
                }

                list.Add(user);
            }
        }

        var rows = new List<RoleAccessRowDto>();
        foreach (var profile in profiles)
        {
            membership.TryGetValue(profile.RoleName, out var members);
            members ??= [];
            var keys = profile.RoleName.Equals(AppRoles.Admin, StringComparison.OrdinalIgnoreCase)
                ? AdminScreens.Keys
                : grants.Where(item => item.RoleName == profile.RoleName).Select(item => item.ScreenKey).Distinct().ToArray();
            rows.Add(new RoleAccessRowDto(
                profile.RoleName,
                profile.RoleName,
                profile.Description,
                members.Count,
                profile.IsSystem,
                keys,
                members.Take(8).Select(item => new RoleAccessMemberDto(
                    item.Id,
                    item.FullName,
                    item.RiderCode,
                    item.DepotId is Guid depotId && depots.TryGetValue(depotId, out var depotName) ? depotName : null,
                    item.WarehousePersonUserId is string personId && names.TryGetValue(personId, out var personName) ? personName : null,
                    item.ZoneId is Guid zoneId && zones.TryGetValue(zoneId, out var zoneName) ? zoneName : null)).ToList()));
        }

        var dto = new RoleAccessMatrixDto(
            AdminScreens.Catalog.Select(item => new RoleAccessScreenDto(item.Key, item.Group, item.Label, item.Detail)).ToList(),
            rows,
            users.Count,
            "Screen access is stored per role. The Admin role keeps every screen. Knox device policy is not configured.");
        return ServiceResult<RoleAccessMatrixDto>.Ok(dto, "Role access loaded.");
    }

    public async Task<ServiceResult<RoleAccessRowDto>> SaveAccessAsync(
        string role,
        SaveRoleAccessRequest request,
        CancellationToken cancellationToken)
    {
        var name = (role ?? "").Trim();
        if (name.Equals(AppRoles.Admin, StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<RoleAccessRowDto>.Fail(400, "The Admin role keeps every screen.");
        }

        if (!await _roles.RoleExistsAsync(name))
        {
            return ServiceResult<RoleAccessRowDto>.Fail(404, "Role was not found.");
        }

        var keys = (request.ScreenKeys ?? [])
            .Where(item => AdminScreens.Keys.Contains(item, StringComparer.Ordinal))
            .Distinct(StringComparer.Ordinal)
            .ToList();
        var existing = await _db.RoleScreenGrants.Where(item => item.RoleName == name).ToListAsync(cancellationToken);
        _db.RoleScreenGrants.RemoveRange(existing);
        foreach (var key in keys)
        {
            _db.RoleScreenGrants.Add(new RoleScreenGrant { RoleName = name, ScreenKey = key });
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? "",
            Action = "SaveRoleScreens",
            EntityName = "Role",
            EntityId = name
        });
        await _db.SaveChangesAsync(cancellationToken);
        return await RowAsync(name, cancellationToken);
    }

    public async Task<ServiceResult<RoleAccessRowDto>> CreateRoleAsync(
        CreateRoleAccessRequest request,
        CancellationToken cancellationToken)
    {
        var name = (request.Name ?? "").Trim();
        if (name.Length < 2 || name.Length > 64)
        {
            return ServiceResult<RoleAccessRowDto>.Fail(400, "Enter a role name.");
        }

        if (await _roles.RoleExistsAsync(name))
        {
            return ServiceResult<RoleAccessRowDto>.Fail(400, "That role already exists.");
        }

        var created = await _roles.CreateAsync(new IdentityRole(name));
        if (!created.Succeeded)
        {
            return ServiceResult<RoleAccessRowDto>.Fail(400, "The role was not created.", created.Errors.Select(error => error.Description).ToArray());
        }

        _db.RoleProfiles.Add(new RoleProfile
        {
            RoleName = name,
            Description = string.IsNullOrWhiteSpace(request.Description) ? "Custom role." : request.Description.Trim(),
            IsSystem = false
        });
        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? "",
            Action = "CreateRole",
            EntityName = "Role",
            EntityId = name
        });
        await _db.SaveChangesAsync(cancellationToken);
        return await RowAsync(name, cancellationToken);
    }

    public async Task<ServiceResult<RoleAccessRowDto>> AssignMemberAsync(
        string role,
        string userId,
        CancellationToken cancellationToken)
    {
        var name = (role ?? "").Trim();
        if (!await _roles.RoleExistsAsync(name))
        {
            return ServiceResult<RoleAccessRowDto>.Fail(404, "Role was not found.");
        }

        var user = await _users.FindByIdAsync(userId);
        if (user is null)
        {
            return ServiceResult<RoleAccessRowDto>.Fail(404, "Staff member was not found.");
        }

        if (!await _users.IsInRoleAsync(user, name))
        {
            var added = await _users.AddToRoleAsync(user, name);
            if (!added.Succeeded)
            {
                return ServiceResult<RoleAccessRowDto>.Fail(400, "The role was not assigned.", added.Errors.Select(error => error.Description).ToArray());
            }
        }

        _db.AuditLogs.Add(new AuditLog
        {
            UserId = _current.UserId ?? "",
            Action = "AssignRole",
            EntityName = "Role",
            EntityId = name
        });
        await _db.SaveChangesAsync(cancellationToken);
        return await RowAsync(name, cancellationToken);
    }

    public async Task<IReadOnlyList<string>> ScreensForRolesAsync(IEnumerable<string> roles, CancellationToken cancellationToken)
    {
        var names = roles.Where(item => !string.IsNullOrWhiteSpace(item)).Select(item => item.Trim()).ToArray();
        if (names.Any(item => item.Equals(AppRoles.Admin, StringComparison.OrdinalIgnoreCase)))
        {
            return AdminScreens.Keys;
        }

        return await _db.RoleScreenGrants.AsNoTracking()
            .Where(item => names.Contains(item.RoleName))
            .Select(item => item.ScreenKey)
            .Distinct()
            .ToListAsync(cancellationToken);
    }

    private async Task<string> NextRiderCodeAsync(CancellationToken cancellationToken)
    {
        var codes = await _db.Users.AsNoTracking()
            .Where(item => item.RiderCode != null && item.RiderCode.StartsWith("RDR-"))
            .Select(item => item.RiderCode!)
            .ToListAsync(cancellationToken);
        var max = 1000;
        foreach (var code in codes)
        {
            var tail = code.Length > 4 ? code[4..] : "";
            if (int.TryParse(tail, out var number) && number > max)
            {
                max = number;
            }
        }

        var next = $"RDR-{max + 1}";
        while (await _db.Users.AnyAsync(item => item.RiderCode == next, cancellationToken))
        {
            max++;
            next = $"RDR-{max + 1}";
        }

        return next;
    }

    private async Task EnsureSystemProfilesAsync(CancellationToken cancellationToken)
    {
        foreach (var role in new[] { AppRoles.Admin, AppRoles.Rider, AppRoles.Customer })
        {
            if (!await _roles.RoleExistsAsync(role))
            {
                await _roles.CreateAsync(new IdentityRole(role));
            }
        }

        if (!await _db.RoleProfiles.AnyAsync(item => item.RoleName == AppRoles.Admin, cancellationToken))
        {
            _db.RoleProfiles.Add(new RoleProfile
            {
                RoleName = AppRoles.Admin,
                Description = "Full HQ access to every stored screen.",
                IsSystem = true
            });
        }

        if (!await _db.RoleProfiles.AnyAsync(item => item.RoleName == AppRoles.Rider, cancellationToken))
        {
            _db.RoleProfiles.Add(new RoleProfile
            {
                RoleName = AppRoles.Rider,
                Description = "Field app access. Admin screens stay closed unless granted here.",
                IsSystem = true
            });
        }

        if (!await _db.RoleProfiles.AnyAsync(item => item.RoleName == AppRoles.Customer, cancellationToken))
        {
            _db.RoleProfiles.Add(new RoleProfile
            {
                RoleName = AppRoles.Customer,
                Description = "Customer app access. Rider and HQ screens stay closed.",
                IsSystem = true
            });
        }

        await _db.SaveChangesAsync(cancellationToken);
    }

    private async Task<ServiceResult<RoleAccessRowDto>> RowAsync(string role, CancellationToken cancellationToken)
    {
        var matrix = await AccessMatrixAsync(cancellationToken);
        var row = matrix.Data?.Roles.FirstOrDefault(item => item.Role.Equals(role, StringComparison.OrdinalIgnoreCase));
        return row is null
            ? ServiceResult<RoleAccessRowDto>.Fail(404, "Role was not found.")
            : ServiceResult<RoleAccessRowDto>.Ok(row, "Role access saved.");
    }
}
