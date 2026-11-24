# Dispatch & Order Management — Audit

## Existing assets

| Asset | Location | Notes |
|---|---|---|
| `CustomerOrder` / `OrderLine` | Domain + `CustomerOrders` / `OrderLines` | Status: Scheduled, Cancelled, Delivered, InProgress. Window enum. RiderId string. |
| Field create order | `POST /api/orders` (rider) | Existing FieldService |
| Admin create order | `POST /api/dashboard/orders` | CommandDashboardService |
| Admin shell | `AdminShell`, `AdminNav`, tokens | `dispatch` nav key |
| Rider ops | `/api/rider-operations/*` | Roster / route stops; assignment column remains `CustomerOrders.RiderId` |
| Dispatch API | `/api/dispatch/*` | Directory, detail, assign/reassign/cancel/pick-list, lifecycle |

See also: [ENTITY_MAPPING_DISPATCH.md](ENTITY_MAPPING_DISPATCH.md), [DISPATCH_ORDER_API.md](DISPATCH_ORDER_API.md), [DISPATCH_DRAWER_AUDIT.md](DISPATCH_DRAWER_AUDIT.md).

## Live SQL (AquaRider)

- CustomerOrders: `ORD-OPEN-ALI` (Scheduled, EstimatedValue 970, **0 OrderLines**)
- Reassignment verified: Ahmed → Infotech; `OrderLifecycleEvents` records previous + new rider; `AuditLogs.ReassignRider`
- Empty directory/detail must show honest zeros — never invent 248/18/64

## Status mapping (Locked V1)

| Tab | Rule |
|---|---|
| Pending Assignment | `Scheduled` and blank `RiderId` |
| Assigned | `Scheduled` and non-blank `RiderId` |
| In Progress | `InProgress` |
| Completed | `Delivered` |
| Cancelled | `Cancelled` |

## Screenshot exclusions

- Price Lists nav, Live GPS density map, fabricated shift targets → Operational Zone Summary + Shift Progress from real stops/orders only; “Not Configured” when no target.
