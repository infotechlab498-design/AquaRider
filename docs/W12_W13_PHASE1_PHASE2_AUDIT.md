# W12 Users & Staff + W13 Roles & Permissions — Phase 1 & 2 Audit

**Scope:** Audit and implementation plan only. No entities, migrations, seed data, UI, or API code were modified for this document.  
**Date:** 2026-11-18  
**Sources:** Live AquaRider SQL Server, ASP.NET Core Identity + JWT, `UserAdminService` / `AuthService`, Flutter admin shell, Sentinel-04 Locked V1 docs, reference screenshots W12 / W13.

---

## Executive verdict

| Screen | Locked V1 disposition |
|---|---|
| **W12 Users & Staff** | **Implement** as Admin-only staff directory over existing `AspNetUsers` + `Admin`/`Rider` roles. Reuse `/api/users` and Rider Operations for field detail. |
| **W13 Roles & Permissions** | **Do not implement custom RBAC.** Screenshot’s multi-role matrix, Knox MFA, hot-sync policies, and custom roles conflict with Locked V1. Keep exactly two Identity roles: `Admin`, `Rider`. |

Wait for explicit approval before any implementation.

---

## 1. Existing database entity mapping

### 1.1 Identity / staff entities (authoritative)

| Store | Purpose |
|---|---|
| `AspNetUsers` → `ApplicationUser` | Staff + riders. Fields: `FullName`, `RiderCode?`, `RouteId?`, `VehicleId?`, `DepotId?`, `IsActive`, `CreatedAt`, `LastLoginAtUtc`, plus Identity (`UserName`, `Email`, `PhoneNumber`, lockout, password hash) |
| `AspNetRoles` | Only `Admin`, `Rider` |
| `AspNetUserRoles` | User ↔ role links |
| `AspNetRoleClaims` / `AspNetUserClaims` / logins / tokens | Standard Identity tables (unused for custom permissions today) |
| `RefreshTokens` | Hashed refresh tokens; `DeviceInformation?`, revoke on deactivate/password reset |
| `PasswordResetRequests` | Forgot/reset workflow status |
| `RiderSettings` | Per-rider field app prefs (created when role = Rider) |
| `AuditLogs` | Actions including `Login`, `CreateUser`, `ResetPassword` |

### 1.2 Operational links (staff → field)

```
ApplicationUser
  ├── Role: Admin | Rider   (AspNetUserRoles)
  ├── RouteId ──► DeliveryRoutes ──► Zones
  ├── VehicleId ──► Vehicles
  └── DepotId ──► Depots
```

There is **no** separate `Employee`, `Staff`, `Invite`, `Permission`, `DeviceInventory`, or Knox profile table.

### 1.3 Live AquaRider counts (read-only)

| Metric | Count |
|---:|---|
| Users | 3 (`admin`, `ahmed.khan`, `infotechlab498`) |
| Role Admin | 1 |
| Role Rider | 2 |
| RiderSettings | 2 |
| RefreshTokens | 37 |
| AuditLogs | 39 |
| PasswordResetRequests | 0 |
| AspNetRoles | **Admin**, **Rider** only |

Screenshot KPIs (32 staff, 8 roles, pending invites) are **not** in SQL and must not be fabricated.

---

## 2. Existing Identity and JWT architecture

### 2.1 Stack

- ASP.NET Core **IdentityCore** + `IdentityRole` + EF stores (`AppDbContext`)
- Authentication: **JWT Bearer** (`Jwt:Issuer`, `Jwt:Audience`, symmetric `Jwt:Key`)
- Fallback authorization policy: **authenticated user required**
- Password policy: min length 8, digit + lowercase; lockout 5 failures / 5 minutes
- SSO config exists but is **disabled** (`SsoStatus` reports unavailable)

### 2.2 Token issuance (`AuthService`)

- Login rejects inactive or locked users (generic 401 message)
- Access token claims: `NameIdentifier`, `Name`, one or more `ClaimTypes.Role`
- Refresh tokens stored hashed; rotation + revoke-on-reuse; revoke all on deactivate / admin password reset
- `LastLoginAtUtc` updated on successful login
- `ICurrentUser` exposes `UserId` + `IsAdmin` (role check)

### 2.3 Locked V1 role model (hard boundary)

```csharp
AppRoles.Admin  // "Admin"
AppRoles.Rider  // "Rider"
```

`UserAdminService.CreateAsync` **rejects any role other than Admin or Rider**.

---

## 3. Existing authorization policy mapping

| API area | Policy |
|---|---|
| `/api/users/*` | `[Authorize(Roles = Admin)]` |
| Command dashboard, rider-ops, dispatch, settlements, pricing, zones/routes, admin customers, onboarding | Admin only |
| Field `/api/stops`, `/api/customers`, sales, collections, shift… | Rider **or** Admin |
| Auth login / refresh / forgot / SSO status | Anonymous (rate-limited) |
| Health | Open |

**No** permission claims, policy handlers, or resource-based RBAC beyond these two roles.

W13 screenshot features that would require new authorization architecture:

- Operations Manager / Dispatcher / Cashier / Auditor roles  
- Checkbox permission matrix  
- MFA-mandatory Admin / Knox engine  
- Hot-sync permission push to live sessions  

→ **Excluded** under “Do not introduce custom RBAC or new security roles.”

---

## 4. Staff-to-rider relationship mapping

| Concept | How it works today |
|---|---|
| Staff account | Any `ApplicationUser` row |
| Rider | User with Identity role `Rider` **and** usually non-null `RiderCode` |
| Admin | Role `Admin`; typically null `RiderCode` / `RouteId` / `VehicleId` |
| Route assignment | `ApplicationUser.RouteId` (also used by W10 assign-rider) |
| Vehicle | `ApplicationUser.VehicleId` |
| Depot / hub | `ApplicationUser.DepotId` (single-depot Locked V1) |
| Field settings | `RiderSettings` row keyed by `UserId` |
| Operational roster | `IRiderOperationsService` filters users with `RiderCode != null` |
| Active / suspended | `IsActive`; deactivate revokes refresh tokens |
| Last login | `LastLoginAtUtc` (no device/app-version table) |

**Important overlap:** Fleet Couriers (Rider Ops) is the **operational** rider console. W12 should be the **identity / HR-style** directory for all users (Admin + Rider), not a second Trackboard.

---

## 5. Existing API reuse report

### Reuse as-is (or thin enrichment)

| Endpoint | Use for W12 |
|---|---|
| `GET /api/users` | Staff directory list |
| `GET /api/users/{id}` | Detail header |
| `POST /api/users` | Create Admin or Rider |
| `PUT /api/users/{id}` | Edit name/phone/riderCode/route/vehicle/depot |
| `POST /api/users/{id}/status` | Activate / suspend (`IsActive`) |
| `POST /api/users/{id}/reset-password` | Reset password (revokes sessions) |
| `GET /api/routes`, `eligible-riders` | Route/vehicle context for assignment UI |
| `GET /api/rider-operations/riders/{id}` (+ assignments, activity) | Optional “today’s field performance” for riders only — SQL-true, no fake 43% |
| `GET /api/settlements/...` | Optional cash-in-hand only if session exists for rider/day |

### Gaps in current `/api/users` payloads

`UserDto` today: `Id`, `Username`, `FullName`, `RiderCode`, `Phone`, `IsActive`, `Roles`, `RouteId`  

Missing for a Locked-V1 staff UI (additive DTO fields only — **no new tables required**):

- Email, DepotId/Name, VehicleId/Plate, RouteName, LastLoginAtUtc, CreatedAt  
- Summary KPIs (total / active / riders / inactive) computed from SQL  
- Search / role filter / status filter / pagination  

### Not reusable for W13

There is **no** permissions API to extend. Building W13 as drawn would be new RBAC — forbidden.

---

## 6. Missing backend functionality

### W12 (allowed, additive)

1. **Staff summary** — counts from `AspNetUsers` + roles (honest zeros if empty buckets)  
2. **Filtered/paged directory** — search, role (`Admin`/`Rider`), status (`IsActive`)  
3. **Enriched detail DTO** — route/vehicle/depot names, last login, roles  
4. Optional: compose rider-ops + day-close snippets for Rider users only  
5. Flutter client methods for `/api/users` (currently **absent** in `route_api.dart`)

### W12 (screenshot → exclude)

| Feature | Reason |
|---|---|
| Pending invites / SMS queue | No invite entity |
| Multi-hub warehouse switcher | Single depot Locked V1 |
| Live GPS map / Knox / 2FA / device model / app build | Excluded telemetry & new security stack |
| Fabricated 32/27/18 KPIs | Show live counts (today: 3 users) |
| Dispatcher / Finance / Ops Manager tabs | No such roles |
| Soft “Suspend” as separate from `IsActive` | Map to `IsActive = false` |

### W13 (entire screen → exclude as custom RBAC)

Replace with a **read-only Role Reference** panel *only if product insists on a nav entry*:

- List Identity roles `Admin`, `Rider`  
- User counts per role  
- Fixed capability text (Admin = HQ modules; Rider = field app)  
- **No** checkbox editor, no custom roles, no save-permissions API  

Preferred Locked V1 approach: **omit W13 nav** and document roles on the Users screen (“Role: Admin | Rider”).

---

## 7. Flutter files requiring changes (when approved)

| File / area | Change |
|---|---|
| `admin_nav.dart` | Add `usersStaff` (and **not** `rolesPermissions` unless read-only stub approved) |
| `admin_sidebar.dart` | “Users & Staff” under Administration; no Roles matrix, Trackboard, Price Lists |
| `admin_workspace.dart` | Route to new screen |
| New `users_staff_screen.dart` (+ light widgets) | Directory, filters, detail drawer, create/edit/suspend/reset password |
| New `users_staff_models.dart` | DTOs |
| `route_api.dart` + `memory_route_api.dart` | `/api/users` client + tests doubles |
| Tests under `test/` | Honest empty/small roster tests |
| Optionally deep-link to `RiderOperationsScreen` | For rider field performance instead of duplicating Trackboard |

**Do not touch** Identity server code for new roles. **Do not** add Google Maps / Knox / MFA UI.

---

## 8. Implementation sequence (after approval)

### Phase gate

| Phase | Status |
|---|---|
| Phase 1 — Inspect Identity / SQL / Flutter / Locked V1 | **Complete** (this report) |
| Phase 2 — Gap analysis + compliant wireframe plan | **Complete** (this report) |
| Phase 3+ — Implementation | **Blocked** until you approve |

### Recommended build order (post-approval)

1. **Backend enrich `/api/users`** (summary + filters/paging + detail enrichment) — still only Admin/Rider  
2. **Automated API tests** against SQL Identity tables  
3. **Flutter Users & Staff screen** wired to real APIs  
4. **Cross-check** with W10 route assignment + Fleet Couriers (same `RouteId` / `RiderCode`)  
5. **W13:** skip custom RBAC; optionally add read-only role legend on Users screen  
6. Build, migrate only if additive DTO needs zero schema (prefer **no migration**); verify Flutter → API → SQL  

### Compliant W12 wireframe (target)

```
[KPIs from SQL: Total / Active / Riders / Inactive]
[Tabs or filters: All | Admins | Riders | Inactive]
[Table: Name, Username, Role, Route, Vehicle/Depot, Last login, Status, Actions]
[Drawer: profile, route/vehicle/depot, IsActive, Reset password, Edit]
[Riders only: link or embedded SQL snippets from Rider Ops — no live GPS]
```

### Explicit non-goals

- New Identity roles or permission claims  
- Migrations for invites / devices / Knox / MFA  
- Seed of 32 fake staff or 8 roles  
- Parallel “Users” microservice or parallel Flutter app  

---

## Conflict register (screenshot vs Locked V1)

| Screenshot claim | Compliant mapping |
|---|---|
| 8 roles + permission matrix | Keep Admin + Rider only; no W13 editor |
| Pending invites = 3 | Omit or show 0 / “Not configured” |
| Multi-hub selector | Single depot label from SQL |
| Live GPS / Knox / 2FA | Omit |
| “Online today” active users | Prefer `IsActive` + optional `LastLoginAtUtc` same calendar day — not fabricated presence |
| SysAdmin / Dispatcher / Accountant | Display as Admin or Rider only; do not invent titles as security roles |

---

## Approval ask

Please confirm:

1. Proceed with **W12 Users & Staff** on existing Identity + `/api/users` (Admin/Rider only).  
2. **Skip custom W13 RBAC**; either omit nav or allow a read-only Admin/Rider legend.  
3. Prefer **no DB migration** unless enrichment proves a column is required (none identified as mandatory).  

No implementation will start until you approve.
