# RouteLedger Login + W03 Test Report

Executed: 2026-11-18 (local agent verification after implementation).

## Backend (`E:\AquaRider\backend`)

Commands:

```text
dotnet restore
dotnet build
dotnet test
```

Result: **Passed 12 / 12**, Failed 0.

Coverage exercised by `Application.Tests`:

- Valid / invalid login
- Refresh rotation and reuse detection
- Remember-me refresh lifetime
- Admin onboarding overview (six Locked V1 steps, live progress)
- Rider forbidden on `/api/onboarding/*`
- SSO status endpoint (providers disabled when not configured)

Migration applied additively: `20261118191051_AuthAndOnboarding` (no database drop).

## Flutter (`E:\AquaRider\riderfrontend`)

Command:

```text
flutter test
```

Result: **Passed 12 / 12**, Failed 0.

Includes:

- Rider login validation and sale flow (existing)
- Locked V1 six-step merge (drops marketing seventh task)
- Missing onboarding payload does not invent a percentage
- Admin vs rider post-login routing
- Enterprise login empty credentials and non-fake SSO
- Admin sign-in opens onboarding checklist shell

## Manual acceptance path

1. Ensure SQL Server `localhost\SQLEXPRESS` database `AquaRider` is reachable.
2. Set secrets (if missing):

```text
dotnet user-secrets set "Jwt:Key" "<32+ char key>" --project Application.Api
dotnet user-secrets set "Seed:AdminPassword" "<dev admin password>" --project Application.Api
```

3. Run API: `dotnet run --project Application.Api` (port 5266 in Development).
4. Run Flutter web/desktop at width ≥ 900 → enterprise login after splash.
5. Sign in as `admin` with the seeded admin password → W03 onboarding checklist.
6. Confirm progress matches SQL data (seeded depot/products/customers/routes/riders/sales should mark most steps completed).

## Known blockers (not failures of the executed suites)

- SMTP is not configured; Identity reset tokens are not emailed.
- Okta / Azure AD credentials are not configured; SSO remains unavailable by design.
- NU1902/NU1903 warnings on `System.Security.Cryptography.Pkcs` from Identity/EF packages.
