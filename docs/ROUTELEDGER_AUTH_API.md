# RouteLedger auth and onboarding API

Base path: `/api`. Every JSON body uses `ApiResponse<T>`: `success`, `message`, `data`, optional `errors`, optional `pagination`.

Flutter login still posts `{ "username", "password" }`. The same endpoint also accepts `{ "emailOrUsername", "password", "rememberMe" }`. The login identifier is the first non-empty value of `emailOrUsername`, then `username`.

## Auth

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/auth/login` | Anonymous | Issue access + refresh tokens |
| POST | `/api/auth/refresh-token` | Anonymous | Rotate a refresh token |
| POST | `/api/auth/logout` | Bearer | Revoke the refresh token, or all active tokens when it is omitted |
| POST | `/api/auth/forgot-password` | Anonymous | Record a reset request. Does not reveal whether the account exists |
| POST | `/api/auth/reset-password` | Anonymous | Apply an Identity reset token |
| GET | `/api/auth/sso/status` | Anonymous | Report which SSO providers are actually configured |
| GET | `/api/auth/me` | Bearer | Current user |
| POST | `/api/auth/change-password` | Bearer | Change the signed-in user's password |

### Login

```json
{ "username": "ahmed.khan", "password": "routeledger1" }
```

```json
{ "emailOrUsername": "ahmed.khan@rider.local", "password": "routeledger1", "rememberMe": true }
```

`data` is `accessToken`, `refreshToken`, `expiresAt`, and `user`.

- `expiresAt` is the access-token expiry. It stays short (`Jwt:AccessMinutes`, default 30). `rememberMe` does not lengthen it.
- `rememberMe: true` sets the refresh-token lifetime to `Jwt:RememberRefreshDays` (default 30). Otherwise it is `Jwt:RefreshDays` (default 14).
- Refresh rotation keeps the same remember-me lifetime.
- Only the SHA-256 hash of the refresh token is stored. `deviceInformation` is the User-Agent, truncated to 512 characters, when the client sends one.
- A successful login sets `LastLoginAtUtc` and writes an audit log with action `Login`.

`user.role` remains the single role Flutter already reads. `user.roles` is the full role list.

### SSO status

`GET /api/auth/sso/status` returns Okta and Azure AD. A provider is `enabled: true` only when `Sso:<Provider>:Enabled` is true and both `Authority` and `ClientId` are non-empty.

There is no SSO login endpoint. This API does not report a successful Okta or Azure AD sign-in.

Current configuration leaves both providers disabled with empty authority and client id. SSO sign-in is not available.

### Password reset

`POST /api/auth/forgot-password` with `{ "username": "..." }` looks up the name, then the email. For an active user it calls Identity `GeneratePasswordResetTokenAsync` and stores a `PasswordResetRequest`.

The reset token is not saved and is not returned. SMTP is not configured, so the token is never emailed. The response is always: "Ask your fleet admin to reset this password."

`POST /api/auth/reset-password` accepts `email` or `username` or `emailOrUsername`, plus `token` and `newPassword`, and calls Identity `ResetPasswordAsync`. Until a mailer exists, clients do not receive a token, so this call cannot succeed in normal use. Fleet admins reset passwords with `POST /api/users/{id}/reset-password`.

## Onboarding

All `/api/onboarding` routes require the Admin role. Riders receive 403.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/onboarding/overview` | Business profile, six steps, progress, facility, support flags |
| GET | `/api/onboarding/steps` | The six steps |
| GET | `/api/onboarding/steps/{stepCode}` | One step |
| GET | `/api/onboarding/progress` | `completedCount`, `totalSteps` (6), `progressPercent` |
| POST | `/api/onboarding/steps/{stepCode}/validate` | Recompute that step from live data |
| POST | `/api/onboarding/steps/{stepCode}/complete` | Confirm a step that live data already satisfies, and write an audit log |
| GET | `/api/onboarding/next-step` | First step that is not completed |
| GET | `/api/onboarding/readiness` | Ready only when all six steps are completed |
| GET | `/api/onboarding/activity` | Onboarding audit rows, or step completion times when no audit exists yet |

`stepCode` is one of `PlantDetails`, `ItemsAndOpenings`, `Customers`, `Zones`, `RiderAndLoad`, `FirstSyncedSale`.

Progress is `completedCount * 100 / 6`, computed on the server. Each overview, steps, progress, validate, and complete call recomputes statuses from live rows. `CompletedAtUtc` is stored when a step first becomes complete and cleared if the live data later fails the rule.

Completion rules:

| Step | Rule |
|---|---|
| PlantDetails | A depot with a non-empty name and address |
| ItemsAndOpenings | A product with `ShowOnSale` |
| Customers | A customer with `IsDeleted = false` |
| Zones | A delivery route |
| RiderAndLoad | At least one active user in role Rider and at least one vehicle-stock row |
| FirstSyncedSale | A sale with status Completed and sync status Synced |

`PendingVerification` and `Blocked` exist on the status enum. Current rules use `NotStarted`, `InProgress`, and `Completed` only.

A `BusinessProfile` is created on first read when none exists. Its display name comes from the first depot name, or `RouteLedger` when no depot exists. Status is `Ready` when all six steps are complete, otherwise `SetupInProgress`.

Support chat and scheduling are not configured. Overview returns both flags as false.

## Blockers

- No SMTP settings and no mail sender. Forgot-password cannot deliver a reset token.
- SSO authority and client id are empty. `GET /api/auth/sso/status` reports both providers disabled. There is no SSO login.
