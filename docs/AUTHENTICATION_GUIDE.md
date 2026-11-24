# Authentication

The API uses ASP.NET Core Identity for users, roles, password hashes, and lockout. It does not store or compare plaintext passwords.

## Tokens

- Access token: JWT, issuer `RouteLedger`, audience `RouteLedger.Mobile`, lifetime 30 minutes. Claims include the user id, username, and roles.
- Refresh token: 14 days. Only the SHA-256 hash is stored in `RefreshTokens`.
- Refresh rotates the token. The old hash is marked revoked and points at the replacement hash. Presenting a revoked token revokes every active token for that user.
- Logout revokes the refresh token sent with the request.
- The signing key lives in .NET user secrets (`Jwt:Key`, id `routeledger-aquarider-api`). It is not in source control. The key must be at least 32 characters.

## Passwords and lockout

Minimum length 8, at least one digit and one lowercase letter. Uppercase and symbols are not required, so the rider password already on the login screen is valid. Five failed attempts lock the account for five minutes.

## Roles

| Role | Can do |
|---|---|
| Rider | Login, own route, sales, collections, orders, shift, settings |
| Admin | Everything a rider can do on field APIs only when the admin has a route, plus `/api/users` |

The fallback authorization policy requires a valid access token. Anonymous endpoints are login, refresh, forgot-password, and health.

## Password recovery

`POST /api/auth/forgot-password` records a `PasswordResetRequest` and returns the same message whether or not the username exists. There is no email or SMS provider. A fleet admin resets the password with `POST /api/users/{id}/reset-password`.

The signed-in rider can change their own password with `POST /api/auth/change-password`.

## Development accounts

Seeding runs only when `Seed:Enabled` is true and the database has no users.

- Rider `ahmed.khan` / `routeledger1` (role Rider). The password is the one already shown on the login screen and in `appsettings.Development.json`.
- Admin `admin`. The password is user secret `Seed:AdminPassword` and is not written here. If that secret is missing, the seeder skips the admin and logs a warning.

## Flutter

`HttpRouteApi` stores the access token and refresh token in `flutter_secure_storage` (`routeledger.access`, `routeledger.refresh`). A 401 retries the request once after refresh. Logout clears local tokens even if the server call fails.
