# RouteLedger Enterprise Admin Login — Implementation Plan

## Project audit (existing)

### Flutter (`riderfrontend`)

| Area | Finding |
|---|---|
| Entry | `main.dart` → `SplashScreen` → mobile `LoginScreen` |
| Auth client | `HttpRouteApi` + `flutter_secure_storage` (`routeledger.access` / `routeledger.refresh`) |
| Login UI | Mobile Locked V1 frame (`lib/screens/login.dart`), Noto Sans, primary `#1565C0` |
| State | No Riverpod/BLoC; API via `ApiScope` InheritedWidget |
| Admin UI | `lib/adminDashboard/` exists as an empty folder; no admin screens |
| Theme | `AquaColors` / `AppType` (Noto Sans) |

### .NET (`backend`)

| Area | Finding |
|---|---|
| Stack | ASP.NET Core Web API 10, Identity, EF Core, SQL Server `AquaRider` on `localhost\SQLEXPRESS` |
| Auth | JWT + hashed refresh tokens, rotation, reuse detection, lockout |
| Endpoints | `login`, `refresh-token`, `logout`, `me`, `forgot-password`, `change-password` |
| User | `ApplicationUser`: FullName, RiderCode, Route/Vehicle/Depot, IsActive, CreatedAt |
| Gaps vs enterprise brief | No `RememberMe` on login DTO, no `LastLoginAtUtc`, no SSO config, no email reset delivery, no admin Flutter login |

### Decision: reuse, do not duplicate

- Extend `AuthService` / `LoginRequest` (optional `rememberMe`, accept `emailOrUsername` alias).
- Keep rider mobile login intact.
- Add desktop enterprise login under `lib/adminDashboard/` for web/wide viewports and Admin role post-auth routing.
- SSO: configuration + unavailable UX only until IdP credentials exist.
- Password reset email: infrastructure stub + documented blocker (no SMTP provider).

## Dependencies

- Flutter: existing `http`, `flutter_secure_storage`, `flutter_svg`, `shared_preferences`
- Backend: existing Identity / JWT packages; new `BusinessProfile` + onboarding completion tables for W03
- SQL Server: existing `AquaRider` connection string (unchanged host)

## Phases

1. Docs (this file + auth/security/database companions)
2. Backend auth deltas (remember-me lifetime, LastLoginAtUtc, SSO options, reset token service stub)
3. Flutter enterprise login UI + API wiring
4. W03 onboarding (separate analysis + API + UI)
5. Build, test, test report

## Acceptance path

Admin opens Flutter (desktop/web) → enterprise login → SQL Identity credentials → JWT + refresh in secure storage → Admin role → onboarding workspace.
