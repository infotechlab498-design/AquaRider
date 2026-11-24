# Dispatch order API

Admin order directory and dispatch actions. Route prefix: `api/dispatch`. Role: **Admin**. Riders and anonymous callers do not get these routes (rider receives 403).

Field `POST /api/orders` and admin `POST /api/dashboard/orders` are unchanged. This prefix does not replace them.

There is no priority field, no GPS availability, and no shift target in the database. `priorityLabel` is always an empty string. Eligible riders do not include a location. Operational summary returns `targetConfigured: false` and `target: null`.

## Date window

`from` and `to` are `yyyy-MM-dd` and filter `CustomerOrders.DeliveryDate` (inclusive). Omit both to include every stored order. Pass one date to use that single day. If `to` is before `from`, the response is 400: "The end date is before the start date."

`summary` and `status-counts` use the same window, plus optional `search`, `riderId`, and `unassignedOnly`. They do **not** apply the status tab, so the counts describe the filtered universe behind the tabs.

`operational-summary` uses `date`. Omitted means the server's local today.

## Status

Query `status` is `all` (or omitted), `pendingAssignment`, `assigned`, `inProgress`, `completed`, or `cancelled`. Anything else, including the stored enum name `Scheduled`, is 400.

| Tab | Stored row |
|---|---|
| `pendingAssignment` | `Scheduled` and blank `RiderId` |
| `assigned` | `Scheduled` and a non-blank `RiderId` |
| `inProgress` | `InProgress` |
| `completed` | `Delivered` |
| `cancelled` | `Cancelled` |

List and detail `status` is that tab token. `orderStatus` is the stored value (`Scheduled`, `InProgress`, `Delivered`, `Cancelled`). An order is in exactly one tab.

`InProgress` is stored as the string `InProgress` on `CustomerOrders.Status`. Nothing in this API moves an order into `InProgress`; a later rider flow can. Reassign and cancel already accept it.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/dispatch/orders` | Paged directory |
| GET | `/api/dispatch/orders/summary` | Counts and combined estimated value |
| GET | `/api/dispatch/orders/status-counts` | The same counts for tabs |
| GET | `/api/dispatch/orders/{id}` | Customer card, rider card, notes, totals |
| GET | `/api/dispatch/orders/{id}/items` | Stored lines, or an empty list |
| GET | `/api/dispatch/orders/{id}/lifecycle` | Events, oldest first |
| GET | `/api/dispatch/orders/{id}/picklist` | Lines plus header. 400 when there are no lines |
| GET | `/api/dispatch/eligible-riders?deliveryDate=` | Active users in the Rider role |
| GET | `/api/dispatch/operational-summary?date=` | Zone counts and stop progress |
| POST | `/api/dispatch/orders/{id}/assign-rider` | `{ "riderId": "..." }` |
| POST | `/api/dispatch/orders/{id}/reassign-rider` | `{ "riderId": "..." }` |
| POST | `/api/dispatch/orders/{id}/cancel` | `{ "reason": "..." }` optional |
| POST | `/api/dispatch/orders/{id}/prepare-picklist` | Writes a lifecycle event. Does not create lines |

Unknown order id is 404 "Order not found."

## Directory

Query: `page`, `pageSize` (default 20, max 100), `search`, `status`, `from`, `to`, `riderId`, `unassignedOnly`.

`search` matches reference number, customer business name, customer code, or primary mobile.

`unassignedOnly=true` keeps rows whose `RiderId` is blank.

Rows are ordered by delivery date descending, then `CreatedAt` descending, then reference number. The page envelope is `pagination`: `page`, `pageSize`, `totalRecords`, `totalPages`. An empty match is 200 with `data: []`, `totalRecords: 0`, and `totalPages: 0`.

Each row:

| Field | Source |
|---|---|
| `id`, `referenceNumber`, `deliveryDate`, `window` | `CustomerOrders` |
| `customerName`, `customerCode`, `customerPhone` | Customer business name, code, primary mobile |
| `address` | Street, area, and city, joined |
| `riderId` | Stored assignee. Blank when unassigned |
| `riderName`, `riderCode` | User row when `riderId` matches. Null when unassigned or the user is gone |
| `estimatedValue` | Header `EstimatedValue`, even when there are no lines |
| `status` | Tab token |
| `orderStatus` | Stored status |
| `syncStatus` | `Pending`, `Synced`, or `Failed` |
| `createdAtUtc` | `CreatedAt` |
| `lineCount` | Count of `OrderLines`. Zero is a real zero |
| `priorityLabel` | Always `""` |

## Summary and status counts

`total`, `pendingAssignment`, `assigned`, `inProgress`, `completed`, `cancelled`.

Summary also returns `combinedEstimatedValue`, the sum of `EstimatedValue` for that same universe (every status in the date/search filter, not only open work). A date range with no orders returns zeros, including `combinedEstimatedValue: 0`.

## Detail

Customer card: `id`, `name`, `code`, `phone`, `address`, `street`, `area`, `city`.

Rider card: `id`, `fullName`, `riderCode`, `isActive`. Null when `riderId` is blank or the user no longer exists. The stored `riderId` is still returned on the order.

Totals:

| Field | Meaning |
|---|---|
| `estimatedValue` | Header value saved on the order |
| `linesSubtotal` | Sum of `quantity * unitPrice` on stored lines |
| `lineCount` | Stored line count |

A header can carry an estimated value while `lineCount` and `linesSubtotal` are 0. The API does not invent lines to explain that value.

Cancellation fields are null until a cancel succeeds: `cancelledAtUtc`, `cancelledByUserId`, `cancellationReason`. `notes` is the original order note and is not overwritten.

## Items

200 with the stored lines: `lineId`, `productId`, `productName`, `sku`, `quantity`, `unitLabel`, `unitPrice`, `subtotal`. No lines returns 200 and `data: []` with message "This order has no lines." Ordered by product name.

## Lifecycle

`id`, `orderId`, `eventCode`, `title`, `detail`, `actorUserId`, `occurredAtUtc`, ascending.

Orders created before this table existed have an empty timeline. That is not filled in. New field and admin creates write `OrderCreated`.

| Code | When |
|---|---|
| `OrderCreated` | Field `POST /api/orders` or admin `POST /api/dashboard/orders` |
| `RiderAssigned` | Assign |
| `RiderReassigned` | Reassign. `detail` contains the previous rider id |
| `Cancelled` | Cancel. `detail` is the reason, or "Cancelled by dispatch." |
| `PickListPrepared` | Prepare pick list |

## Pick list

Header plus lines: `orderId`, `referenceNumber`, `deliveryDate`, `window`, `orderStatus` (stored status), `estimatedValue`, `notes`, `customer`, `lines`, `linesTotal`.

`linesTotal` is the sum of stored line subtotals. If the order has no `OrderLines`, both GET and POST return 400 "This order has no lines to pick." and no event is written.

## Eligible riders

Active users in the Rider role, ordered by name: `id`, `fullName`, `riderCode`, `routeName`, `hasOpenShift`.

`hasOpenShift` is true only when a `Shifts` row exists with `Status = Open` and `ServiceDate` equal to `deliveryDate` (or today when omitted). It is not a GPS or capacity claim. Inactive riders are omitted. Admins are omitted unless they also have the Rider role and are active.

## Operational summary

One row per `DeliveryRoutes` record: `routeId`, `routeName`, `sector`, `city`, `orderCount`, `stopCount`.

`orderCount` is `CustomerOrders` whose delivery date is `date` and whose customer is on that route. `stopCount` is `RouteStops` for that route and service date. Routes with no work are still listed, with zeros. No extra zones are created.

`shiftProgress.completedStops` and `totalStops` count `RouteStops` for that service date (`Completed` versus all statuses). There is no configured numeric target, so `targetConfigured` is false and `target` is null.
