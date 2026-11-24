# RouteLedger security

## Tokens

- Access tokens are JWTs signed with `Jwt:Key` (at least 32 characters, user secrets in development). Issuer `RouteLedger`, audience `RouteLedger.Mobile`. Lifetime is `Jwt:AccessMinutes` (default 30). `rememberMe` does not extend the access token.
- Refresh tokens are 64 random bytes, returned once. The database stores SHA-256 hex in `RefreshTokens.TokenHash`, plus expiry, revoke time, and the replacement hash after rotation.
- Presenting a revoked or expired refresh token revokes every active refresh token for that user.
- `rememberMe: true` sets refresh expiry from `Jwt:RememberRefreshDays` (default 30). Otherwise `Jwt:RefreshDays` (default 14). Rotation copies that choice onto the new token.
- `DeviceInformation` stores the request User-Agent (max 512 characters). It is not an authenticator.
- Successful login sets `AspNetUsers.LastLoginAtUtc` and writes an `AuditLogs` row. Failed passwords call Identity access-failed counting. Five failures lock the account for five minutes. Failures use the same "Incorrect username or password." message as an unknown user.

## Passwords

Identity password rules: length 8, one digit, one lowercase letter. Uppercase and symbols are not required. Email addresses must be unique.

`POST /api/auth/forgot-password` generates an Identity reset token for an active matching user and does not put that token in the response, the database, or logs. SMTP is not configured, so the token is discarded and the user is told to ask a fleet admin. The message is the same when the account does not exist.

`POST /api/auth/reset-password` calls `ResetPasswordAsync` when a caller already has a token. Without email delivery, normal users do not have a token. Admins set a new password with `POST /api/users/{id}/reset-password`, which does not use the Identity reset token.

Changing or resetting a password revokes active refresh tokens.

## SSO

`Sso:Okta` and `Sso:AzureAd` are placeholders: `Enabled`, `Authority`, `ClientId`. `GET /api/auth/sso/status` is anonymous and sets `enabled` only when the flag is true and both authority and client id are present. Both are empty and disabled today.

The API does not accept an SSO assertion, does not exchange an authorization code, and does not issue a RouteLedger session from Okta or Azure AD.

## Onboarding

`/api/onboarding/*` requires role Admin. The fallback policy still requires a bearer token on every other route except login, refresh, forgot-password, reset-password, SSO status, health, and receipt verify.

Complete writes an audit row only after live data already satisfies the step. The client cannot mark a step complete by sending a status.

Support chat and scheduling are hard-coded unavailable. There is no third-party support credential in configuration.

## Operations

Do not drop `AquaRider`. Ship schema changes as EF migrations and let `MigrateAsync` apply them. Test hosts use a separate `AquaRider_Test_*` database.
