# Dashboard metric calculations

Server local calendar. Default period is today: `DateOnly.FromDateTime(DateTime.Today)`. Timestamp filters use local midnight converted to UTC. Date columns (`ServiceDate`, `DeliveryDate`) are inclusive `DateOnly` comparisons.

Reads use `AsNoTracking`. Sums and counts run in SQL. Sales chart buckets are summed in SQL by UTC hour, then merged onto the server local hour or local date so a local day is not split on the UTC date line.

## Command KPIs

### Total billed sales

Completed sales (`Sales.Status = Completed`) with `CreatedAt` in the period.

- `totalBilledSales` = sum of `SaleAmount`
- `invoiceCount` = count of those sales

### Previous period

The window immediately before `from`, with the same number of days. A one-day selection compares with the previous local day.

`previousPeriodSales`, `changeAmount`, and `changePercent` are set only when that previous window has at least one completed invoice. Otherwise all three are null.

- `changeAmount` = current billed sales minus previous billed sales
- `changePercent` = `changeAmount / previousPeriodSales * 100`, rounded to 2 decimals. Null when previous sales are 0, so the API does not divide by zero.

### Collections received

All `Collections` with `CreatedAt` in the period, every channel.

- `collectionsReceived` = sum of `Amount`
- `collectionCount` = count
- `recoveryPercent` = `collectionsReceived / totalBilledSales * 100` when billed sales are greater than 0, else null. It can exceed 100 when collections are larger than billed sales in the same window.

This KPI is not the collections pie. The pie uses the partition below.

### Fleet

- `fleetRegistered` = users in the Rider role, including inactive
- `fleetOnDuty` = distinct `Shifts.RiderId` where `Status = Open` and `ServiceDate` is inside `from`..`to`

### Deliveries

`RouteStops` with `ServiceDate` inside the period.

- `deliveriesCompleted` = status `Completed`
- `deliveriesTotal` = all stops in the period
- `percent` = completed / total * 100, or 0 when total is 0. Rounded to 2 decimals.

### Pending orders

These two figures are the live backlog. They are not limited to `from`/`to`.

- `pendingOrders` = `CustomerOrders` with `Status = Scheduled`
- `unassignedOrders` = those scheduled orders whose `RiderId` is empty or whitespace. A non-blank id counts as assigned even if it does not match a user.

### Outstanding dues

Current customer balances, not a period sum.

- `outstandingDues` = sum of `Customers.Outstanding` where `IsDeleted` is false
- `accountsWithDues` = those customers with `Outstanding > 0`

## Operational summary

- Orders: `DeliveryDate` inside the period. Assigned means `RiderId` is not blank. Unassigned means it is blank. Status counts are `Scheduled`, `Delivered`, and `Cancelled` inside that delivery-date window.
- Stops: `ServiceDate` inside the period, split into completed, pending, missed, and in progress.
- Recent activity: the 10 newest `ActivityLogs` whose `OccurredAt` is in the period. The API does not pad the list.

## Attention items

Included only when the underlying row exists.

1. **No open shift today.** Only when the range end date is the server's local today. Each active Rider with no `Shifts` row where `Status = Open` and `ServiceDate` equals that day. Severity `warning`. `createdAtUtc` is local midnight of that day, in UTC. Past ranges do not flag closed historical shifts.
2. **Failed sales.** `Sales.SyncStatus = Failed` and `CreatedAt` in the period. Severity `high`. A failed sale and its activity log are separate items when both rows exist.
3. **Failed activity.** `ActivityLogs.SyncStatus = Failed` and `OccurredAt` in the period. Severity `high`.
4. **Unassigned scheduled orders.** `Status = Scheduled`, blank `RiderId`, and `DeliveryDate` inside the period. Severity `high`. The KPI unassigned count is the full backlog and can be larger than this period list.

## Collections pie

A sale or collection is counted in one place. Approved slices are only `Cash`, `FullCredit`, and `PartialCash`.

Completed sale, `due = SaleAmount + PreviousOutstanding`:

| Condition | Slice | Amount |
|---|---|---|
| `AmountReceived = 0` | FullCredit | `SaleAmount` |
| `AmountReceived > 0` and `AmountReceived < due` | PartialCash | `AmountReceived` |
| `AmountReceived >= due` and `PaymentChannel = Cash` | Cash | `AmountReceived` |
| `AmountReceived >= due` and channel is not Cash (including null) | excluded | `AmountReceived` |

Collection:

| Condition | Slice | Amount |
|---|---|---|
| `Amount < OutstandingBefore` | PartialCash | `Amount` |
| `Channel = Cash` and `Amount >= OutstandingBefore` | Cash | `Amount` |
| Any other channel and `Amount >= OutstandingBefore` | excluded | `Amount` |

Partial wins over the channel name so a row is not counted twice. A partial bank, wallet, or cheque collection is PartialCash and the channel is not shown. A full settlement on those channels is excluded from the chart.

`total` is Cash + FullCredit + PartialCash. `reconciliationNote` is present when those amounts add up to `total`. Excluded money is `excludedUnsupportedAmount` only.

Percent for a slice is its amount divided by `total`, times 100, rounded to 2 decimals. Zero total yields 0.

## Sales buckets

SQL groups completed sales in the period by the UTC year, month, day, and hour of `CreatedAt`, summing `SaleAmount` and counting invoices. Those hour totals are then folded into the server local hour (single-day chart) or server local date (multi-day chart). Empty hours and days are omitted.

## Activity ledger amounts

A sale row uses `SaleAmount` (billed), not `AmountReceived`. A collection row uses `Collections.Amount`. The ledger includes every completed sale and every collection in the period, including channels the pie excludes.

## Rider operations figures

Documented with the status rules in [RIDER_OPERATIONS_API.md](RIDER_OPERATIONS_API.md).

- Registered riders: Rider role count.
- On duty: open shift on the requested service date.
- Available: active and not on duty.
- Attention: on duty plus a failed sale, a failed activity, or an open shift older than 2 hours with stops on the route and zero completed stops.
- Billed today: completed `SaleAmount` for that rider and date.
- Cash collected today: cash `AmountReceived` on completed sales plus cash collection `Amount`.
- Deliveries in progress: stops with status `InProgress` on that service date.
- Requiring attention: riders whose status is `attention` or `inactive`.

No metric uses a fabricated GPS position.
