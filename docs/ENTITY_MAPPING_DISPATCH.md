# Entity mapping — Riders, Orders, Customers, Assignments, Manifests, Items

Read-only inventory of the live AquaRider SQL Server model used by Dispatch & Order Management. No duplicate tables were created for this work.

## Conceptual → physical

| Concept (prompt) | Exists as table? | Physical mapping | Assignment / join key |
|---|---|---|---|
| **Riders** | No dedicated `Riders` table | `AspNetUsers` + `AspNetUserRoles` where role = `Rider`; profile fields on `ApplicationUser` (`FullName`, `RiderCode`, `IsActive`, `RouteId`); optional `RiderSettings` | User `Id` (string) |
| **Customers** | **Yes** — `Customers` | `Customer` entity | `Customer.Id` (Guid) |
| **Orders** | **Yes** — `CustomerOrders` | `CustomerOrder` | `CustomerOrder.Id`; customer via `CustomerId`; **assigned rider via `CustomerOrders.RiderId`** (string FK to user id, not a separate assignment row) |
| **OrderItems** | **Yes** — `OrderLines` | `OrderLine` (`OrderId`, `ProductId`, `Quantity`, `UnitPrice`) | This is the pick-list / “manifest lines” source |
| **DeliveryAssignments** | **No** | Order assignment is `CustomerOrders.RiderId`. Day-route stops are `RouteStops` (customer + route + service date), not per-order assignment rows | Do not invent a `DeliveryAssignments` table |
| **Manifests** | **No** | Flag `CustomerOrders.ShowOnManifest`; pick-list is projected from `OrderLines` + product names | Do not invent a `Manifests` table |

## Related tables (supporting, not duplicates)

| Table | Role |
|---|---|
| `OrderLifecycleEvents` | Dispatch lifecycle (`RiderAssigned`, `RiderReassigned`, `Cancelled`, `PickListPrepared`, …) |
| `AuditLogs` | Admin actions (`AssignRider`, `ReassignRider`, `CancelOrder`, `PreparePickList`) |
| `DeliveryRoutes` / `Depots` / `Vehicles` | Route / depot / vehicle catalog |
| `RouteStops` | Planned stops for a service date (rider ops “assignments” list) |
| `Shifts` / `ShiftStocks` | Open-shift signal for eligible riders |
| `Products` | Line / pick-list product names |

## Functional APIs (already wired)

### Dispatch (`/api/dispatch`, Admin)

| Method | Path | Status |
|---|---|---|
| GET | `/orders`, `/orders/summary`, `/orders/status-counts` | Functional |
| GET | `/orders/{id}`, `/items`, `/lifecycle`, `/picklist` | Functional |
| GET | `/eligible-riders`, `/operational-summary` | Functional |
| POST | `/orders/{id}/assign-rider`, `/reassign-rider`, `/cancel`, `/prepare-picklist` | Functional |

Reassignment updates **`CustomerOrders.RiderId`**, writes **`OrderLifecycleEvents`** (`RiderReassigned` with previous + new rider), and **`AuditLogs`**. Directory / detail / eligible-rider views read that same column — no parallel assignment store.

### Rider operations (`/api/rider-operations`)

Roster, activity, route-stop assignments, exceptions. Stop list comes from `RouteStops`, not from inventing delivery-assignment entities.

### Existing order create (unchanged)

| Method | Path | Audience |
|---|---|---|
| POST | `/api/orders` | Field rider |
| POST | `/api/dashboard/orders` | Admin command dashboard |

## Live SQL snapshot (AquaRider / SQLEXPRESS)

Observed while auditing (no seed, no drop):

- `CustomerOrders`: `ORD-OPEN-ALI` present; assignment is `RiderId` → Ahmed Khan.
- Active riders: Ahmed Khan (`RDR-1042`), Infotech (`RDR-1498`).
- `OrderLines` for that open order: **0** (pick-list correctly fails until lines exist).
- No `Manifests` / `DeliveryAssignments` tables in the model.

## Reuse rules

1. Assign / reassign only through `CustomerOrders.RiderId`.
2. Items / pick-list only through `OrderLines`.
3. History only through `OrderLifecycleEvents` (+ `AuditLogs` for admin trail).
4. Do not create duplicate entities, alter unrelated rows, drop tables, or generate seed data for dispatch workflows.
