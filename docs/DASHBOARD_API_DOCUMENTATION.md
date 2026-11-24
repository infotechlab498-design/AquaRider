# Command dashboard API

Admin command dashboard for RouteLedger. These routes sit under `api/dashboard/...`.

The existing rider field dashboard is unchanged: `GET /api/dashboard` still returns the signed-in rider's `DashboardDto` from `FieldService`.

Every JSON body uses the shared envelope (`success`, `message`, `data`, `errors`, and `pagination` when a list is paged). Role: **Admin**. A rider receives 403. A missing token receives 401.

## Dates

`from` and `to` are `yyyy-MM-dd` (`DateOnly`).

- Both omitted: the server's local today (`DateOnly.FromDateTime(DateTime.Today)`), the same clock as the rider field dashboard.
- Only one bound: that single day.
- Both set: inclusive range. `to` before `from` is 400.

Each local date is the half-open UTC interval from that local midnight to the next local midnight. Stored timestamps (`CreatedAt`, `OccurredAt`) are compared in UTC against that window. `ServiceDate` and `DeliveryDate` are compared as dates, not timestamps.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/dashboard/overview?from=&to=` | Greeting, business name, facility depot, period, ready flags |
| GET | `/api/dashboard/kpis?from=&to=` | Billed sales, collections, fleet, deliveries, orders, outstanding |
| GET | `/api/dashboard/operational-summary?from=&to=` | Orders and stops in the period, plus the 10 latest activity rows |
| GET | `/api/dashboard/attention-items?from=&to=` | Real exceptions only. Empty when there are none |
| GET | `/api/dashboard/sales-summary?from=&to=&bucket=hour\|day` | Completed sales grouped by hour or day |
| GET | `/api/dashboard/collections-summary?from=&to=` | Cash, full credit, and partial cash |
| GET | `/api/dashboard/activity-ledger?from=&to=&search=&status=&page=&pageSize=` | Completed sales and collections |
| POST | `/api/dashboard/orders` | Schedule a customer order for a chosen rider |

### Overview

`data` fields: `greeting`, `adminFullName`, `businessDisplayName`, `facilityDepotName`, `period` (`from`, `to`), `ready`.

- Greeting uses the local hour and the authenticated admin's `FullName`, loaded by `ICurrentUser.UserId`.
- `businessDisplayName` is the earliest `BusinessProfiles.DisplayName` (legal name if display is blank). Empty string when no profile exists. This read does not create a profile.
- `facilityDepotName` is the first depot ordered by name (same primary depot as onboarding).
- `ready.businessProfilePresent`, `ready.businessReady` (`Status == "Ready"`), `ready.facilityPresent`, `ready.ridersPresent`.

### KPIs

See [DASHBOARD_METRIC_CALCULATIONS.md](DASHBOARD_METRIC_CALCULATIONS.md). Comparison fields on sales are null when the previous period has no completed invoices.

### Operational summary

Orders are those whose `DeliveryDate` falls in the range: `total`, `assigned`, `unassigned`, `scheduled`, `delivered`, `cancelled`.

Stops are those whose `ServiceDate` falls in the range: `total`, `completed`, `pending`, `missed`, `inProgress`.

`recentActivity` is up to 10 `ActivityLogs` in the timestamp window, newest first. Fewer than 10 when fewer exist.

### Attention items

Each item: `id`, `severity` (`high` or `warning`), `title`, `detail`, `createdAtUtc`, `status` (`Open`), `actionLabel`, `actionRoute`.

`actionRoute` is a client hint, not an extra API:

- `/rider-operations/riders/{id}`
- `/dashboard/activity-ledger?search={reference}`
- `/dashboard/orders`

The list is empty, with message "No exceptions in this period.", when none of the rules match. Nothing is invented.

### Sales summary

`bucket` omitted (`requestedBucket` = `auto`): `hour` when `from` and `to` are the same day, otherwise `day`. `hour` on a multi-day range is coerced to `day` (`bucket` is the applied value). Any other token is 400.

Buckets contain only hours or days that have completed sales. `label` is server-local (`yyyy-MM-dd HH:00` or `yyyy-MM-dd`). `bucketStartUtc` is that local bucket start converted to UTC. `total` and `invoiceCount` are the sums of the buckets.

### Collections summary

`categories` is always the three approved slices, in order: `Cash`, `FullCredit`, `PartialCash`. Each has `amount`, `count`, and `percent` of the approved total (2 decimal places). Percents are rounded independently and may not add to exactly 100.

`total` is the sum of those three amounts. `reconciliationNote` is set when that sum equals `total`. `excludedUnsupportedAmount` is money left out of the chart (bank transfer, wallet, cheque, or a null sale channel that fully settled). Those channel names are not slices.

### Activity ledger

Rows are a SQL `UNION ALL` of completed sales and all collections in the window.

| Field | Sale | Collection |
|---|---|---|
| `referenceId` | `ReceiptNumber` | `ReferenceNumber` |
| `customerName` | Customer business name | Customer business name |
| `riderName` | User full name, or empty | User full name, or empty |
| `transactionType` | `Sale` | `Collection` |
| `amount` | `SaleAmount` | `Amount` |
| `timestampUtc` | `CreatedAt` | `CreatedAt` |
| `syncStatus` | `Pending`, `Synced`, or `Failed` | same |

`search` matches reference, customer name, or rider name. `status` is `Pending`, `Synced`, `Failed`, or `all`. Page defaults to 1. `pageSize` defaults to 20, and values above 100 are capped at 100. Sort is timestamp descending, then reference.

### Create order

Body: `customerId`, `riderId`, `deliveryDate`, `window` (`Morning`, `Afternoon`, `Evening`), `lines` (`productId`, `quantity`), optional `note`.

The customer must exist and not be deleted. The rider must exist, be in the Rider role, and be active. Prices come from `Products`, not the client. A missing order-number sequence returns 500 and does not invent a number. Success is 201 with `OrderDto` and a stored `CustomerOrders` row. Unknown customer or rider is 404. Validation failures are 400. There is no success response without a saved order.
