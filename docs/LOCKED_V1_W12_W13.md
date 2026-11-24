# Locked V1 — W12 Users & Staff + W13 Roles & Permissions

Companion to `W12_W13_PHASE1_PHASE2_AUDIT.md`.

## Allowed (when implementation is authorized)

- Admin-only **Users & Staff** directory over `AspNetUsers`
- Create / update / activate / deactivate / reset password via existing `/api/users`
- Roles limited to **Admin** and **Rider** only
- Route / vehicle / depot assignment using existing FKs
- Optional rider detail via Rider Operations / settlements (SQL-true)
- Honest KPIs from live user counts

## Excluded

| Feature | Disposition |
|---|---|
| Custom RBAC / Roles & Permissions editor | Do not build |
| New roles (Dispatcher, Cashier, Ops Manager, Auditor, …) | Rejected by `UserAdminService` and Locked V1 |
| Pending invites / SMS queue | No entity |
| Knox / MFA / device fingerprint UI | Excluded |
| Live GPS staff map | Excluded |
| Multi-branch hub switcher | Single depot |
| Fabricated 32-staff / 8-role KPIs | Show SQL counts |

## Nav target

Administration: **Users & Staff** (plus existing Fleet Couriers for rider ops).  
No Roles & Permissions matrix destination.
