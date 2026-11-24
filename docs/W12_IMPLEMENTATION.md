# W12 Users & Staff — Implementation

**Locked V1:** Admin + Rider Identity roles only. No custom RBAC (W13 matrix excluded). No migration.

## Backend
- Enriched `UserDto` (email, route/vehicle/depot names, last login, primaryRole)
- `GET /api/users/summary`
- `GET /api/users/role-reference` (read-only Admin/Rider legend)
- `GET /api/users` search / role / isActive / pagination
- Existing create / update / status / reset-password unchanged in spirit (Rider still Admin|Rider only)

## Flutter
- Nav: **Users & Staff**
- Screen: KPIs, role legend, filters, directory, detail drawer (activate/deactivate, reset password, assign route, link to Fleet Couriers)

## Verified
- API tests including summary + role-reference + Rider filter
- Flutter `users_staff_test.dart`
