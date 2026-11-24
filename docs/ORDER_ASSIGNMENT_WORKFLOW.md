# Order assignment workflow

Dispatch keeps a single assignee: `CustomerOrders.RiderId`. Assign and reassign update that column. They do not insert a second assignment row.

Both actions are `POST` under `api/dispatch`, Admin only, in one database transaction with an `AuditLogs` row and an `OrderLifecycleEvents` row.

The rider must exist, be in the Rider role, and have `IsActive = true`.

| Failure | Status | Message |
|---|---|---|
| Order missing | 404 | Order not found. |
| Rider id blank | 400 | Choose a rider. |
| User missing or not in the Rider role | 404 | Rider not found. |
| Rider inactive | 400 | That rider is not active. |

Eligible riders for the picker are `GET /api/dispatch/eligible-riders`. An open shift on the delivery date is reported as `hasOpenShift`. The assign endpoints do not require an open shift and do not read a location.

## Assign

`POST /api/dispatch/orders/{id}/assign-rider` with `{ "riderId": "..." }`.

Allowed only when the order is `Scheduled` and `RiderId` is blank.

| Failure | Status | Message |
|---|---|---|
| Already has a rider | 409 | This order already has a rider. |
| Any other status | 409 | Only a scheduled order without a rider can be assigned. |

On success the stored `RiderId` becomes that user id. Lifecycle code `RiderAssigned`, title "Rider assigned", detail `Assigned rider {id}.` Audit action `AssignRider`. The response is the order detail. Directory `status` becomes `assigned`. Stored `orderStatus` stays `Scheduled`.

Orders created by field `POST /api/orders` or admin `POST /api/dashboard/orders` are saved with a rider already set. Those paths write `OrderCreated` only. They do not also write `RiderAssigned`. Use reassign to change that rider.

## Reassign

`POST /api/dispatch/orders/{id}/reassign-rider` with a different rider id.

Allowed when the order is `Scheduled` or `InProgress` and `RiderId` is already set.

| Failure | Status | Message |
|---|---|---|
| `Delivered` or `Cancelled` | 409 | This order cannot be reassigned. |
| No rider yet | 409 | Assign a rider before reassigning. |
| Same rider id | 400 | Choose a different rider. |

The previous id is replaced. Lifecycle code `RiderReassigned`, title "Rider reassigned", detail `Previous rider {previousId}.` Audit action `ReassignRider`.

There is still one `RiderId` after reassign. The previous rider remains only in the lifecycle detail and in audit history.

## What assignment does not do

- It does not create `OrderLines`.
- It does not open a shift or a route stop.
- It does not mark the order `InProgress` or `Delivered`.
- It does not clear the rider when the order is later cancelled. Cancel keeps `RiderId` so the last assignee stays visible.
