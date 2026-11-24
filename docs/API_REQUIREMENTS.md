# API Requirements — Rider Operations + Dispatch

## Reuse

| Prefix | Status |
|---|---|
| `/api/rider-operations/*` | Exists — keep; harden filters/docs only |
| `/api/dashboard/orders` POST | Exists — keep for create |
| `/api/orders` POST | Rider field create — keep |

## New (Admin) — Dispatch

| Method | Path |
|---|---|
| GET | `/api/dispatch/orders` |
| GET | `/api/dispatch/orders/summary` |
| GET | `/api/dispatch/orders/status-counts` |
| GET | `/api/dispatch/orders/{id}` |
| GET | `/api/dispatch/orders/{id}/items` |
| GET | `/api/dispatch/orders/{id}/lifecycle` |
| GET | `/api/dispatch/orders/{id}/picklist` |
| GET | `/api/dispatch/eligible-riders` |
| GET | `/api/dispatch/operational-summary` |
| POST | `/api/dispatch/orders/{id}/assign-rider` |
| POST | `/api/dispatch/orders/{id}/reassign-rider` |
| POST | `/api/dispatch/orders/{id}/cancel` |
| POST | `/api/dispatch/orders/{id}/prepare-picklist` |

Query: `page`, `pageSize`, `search`, `status` (all|pendingAssignment|assigned|inProgress|completed|cancelled), `from`, `to`, `riderId`, `unassignedOnly`.

Prefix `api/dispatch` avoids colliding with field `POST /api/orders`.
