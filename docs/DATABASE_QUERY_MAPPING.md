# Database query mapping

Command dashboard and rider operations read the existing AquaRider database. No new tables, no migration, and no startup seed of operational data. `GET /api/dashboard` remains the rider field query in `FieldService`.

Dates: local calendar day, converted to a UTC half-open range for timestamp columns. `DateOnly` columns are filtered directly.

## Command dashboard

| API field | Table | Filter | Aggregate |
|---|---|---|---|
| Business display name | `BusinessProfiles` | earliest `CreatedAtUtc` | none; read does not insert |
| Facility depot | `Depots` | order by `Name` | first name |
| Admin name | `AspNetUsers` | `Id` = `ICurrentUser.UserId` | `FullName` |
| Total billed sales, invoice count | `Sales` | `Status = Completed`, `CreatedAt` in range | `SUM(SaleAmount)`, `COUNT` |
| Previous period sales | `Sales` | same, previous window | `COUNT` then `SUM` only when count > 0 |
| Collections received, count | `Collections` | `CreatedAt` in range | `SUM(Amount)`, `COUNT` |
| Fleet registered | `AspNetUserRoles` + `AspNetRoles` | role name `Rider` | `COUNT` |
| Fleet on duty | `Shifts` | `Status = Open`, `ServiceDate` in range | distinct `RiderId` |
| Deliveries | `RouteStops` | `ServiceDate` in range | count by `Status` |
| Pending / unassigned orders | `CustomerOrders` | `Status = Scheduled`; unassigned also `TRIM(RiderId) = ''` | `COUNT` (not date-filtered) |
| Outstanding dues | `Customers` | `IsDeleted = 0` | `SUM(Outstanding)`, count `Outstanding > 0` |
| Operational orders | `CustomerOrders` | `DeliveryDate` in range | counts by blank rider and `Status` |
| Operational stops | `RouteStops` | `ServiceDate` in range | counts by `Status` |
| Recent activity | `ActivityLogs` | `OccurredAt` in range | `ORDER BY OccurredAt DESC`, `TAKE 10` |
| Missing shift | `AspNetUsers` in Rider role, `Shifts` | active riders, open shift on range end date, and that date is local today | riders with no matching open shift |
| Failed sale attention | `Sales` | `SyncStatus = Failed`, `CreatedAt` in range | row list, customer name via `CustomerId` |
| Failed activity attention | `ActivityLogs` | `SyncStatus = Failed`, `OccurredAt` in range | row list |
| Unassigned order attention | `CustomerOrders` | `Scheduled`, blank `RiderId`, `DeliveryDate` in range | row list |
| Sales buckets | `Sales` | completed, `CreatedAt` in range | `GROUP BY` UTC year/month/day/hour, then local merge |
| Pie: full credit | `Sales` | completed, `AmountReceived = 0`, in range | `SUM(SaleAmount)`, `COUNT` |
| Pie: partial sales | `Sales` | completed, `AmountReceived > 0` and `< SaleAmount + PreviousOutstanding` | `SUM(AmountReceived)`, `COUNT` |
| Pie: cash sales | `Sales` | completed, `AmountReceived >= SaleAmount + PreviousOutstanding`, `PaymentChannel = Cash` | `SUM(AmountReceived)`, `COUNT` |
| Pie excluded sales | `Sales` | completed, received covers the due, channel is not Cash | `SUM(AmountReceived)` |
| Pie: partial collections | `Collections` | `CreatedAt` in range, `Amount < OutstandingBefore` | `SUM(Amount)`, `COUNT` |
| Pie: cash collections | `Collections` | `Channel = Cash`, `Amount >= OutstandingBefore` | `SUM(Amount)`, `COUNT` |
| Pie excluded collections | `Collections` | channel is not Cash, `Amount >= OutstandingBefore` | `SUM(Amount)` |
| Ledger sales | `Sales` join `Customers` left join `AspNetUsers` | completed, `CreatedAt` in range, optional search and sync status | `UNION ALL` with collections, then `ORDER BY`, `OFFSET/FETCH` |
| Ledger collections | `Collections` join `Customers` left join `AspNetUsers` | `CreatedAt` in range, optional search and sync status | same union |
| Admin create order | `Customers`, `AspNetUsers`, `AspNetUserRoles`, `Products`, `NumberSequences` | customer not deleted; user in Rider role and active; products exist; sequence name `Order` | insert `CustomerOrders`, `OrderLines`, `ActivityLogs`, `AuditLogs` |

Ledger `UNION ALL` is translated by EF `Concat` on scalar columns. The page projection to the API row happens after the SQL page is loaded. Search uses `Contains` on receipt/reference, customer `BusinessName`, and rider `FullName`.

## Rider operations

| API field | Table | Filter | Aggregate |
|---|---|---|---|
| Rider directory | `AspNetUsers` + `AspNetUserRoles` | role `Rider` | includes `Vehicles`, `DeliveryRoutes` |
| Open shift | `Shifts` | `Status = Open`, `ServiceDate = date`, rider in the directory | `MIN(StartedAt)` per rider |
| Stop progress | `RouteStops` | `ServiceDate = date`, route in the directory | `GROUP BY RouteId`, count, count `Completed` |
| Billed and cash sales | `Sales` | completed, `CreatedAt` in the local day, rider in the directory | `GROUP BY RiderId`, `SUM(SaleAmount)`, conditional `SUM(AmountReceived)` for Cash |
| Cash collections | `Collections` | `Channel = Cash`, `CreatedAt` in the local day | `GROUP BY RiderId`, `SUM(Amount)` |
| Failed sales (status) | `Sales` | `SyncStatus = Failed`, `CreatedAt` in the day | distinct `RiderId` |
| Failed activity (status) | `ActivityLogs` | `SyncStatus = Failed`, `OccurredAt` in the day | distinct `UserId` |
| Last activity | `ActivityLogs` | rider in the directory | `MAX(OccurredAt)` per user, then the title at that timestamp |
| Deliveries in progress | `RouteStops` | `ServiceDate = date`, `Status = InProgress` | `COUNT` |
| Assignments | `RouteStops` join `Customers` | `RouteId` = rider route, `ServiceDate = date` | order by `Sequence` |
| Rider activity | `ActivityLogs` | `UserId` = rider | newest 100 |
| Exceptions | same sale, activity, shift, and user rows | the rules in the rider operations doc | one item per stored row |
| Location verifications | none | — | empty list; no table is queried for coordinates |

Search and status on the directory are applied after those SQL aggregates, in memory, because the fleet status is derived from the joined aggregates. The fleet is the Rider role, not the customer list.

## Not queried

Bank transfer, wallet, and cheque are stored on `PaymentChannel` / `Collections.Channel` and are not returned as chart categories. Customer latitude and longitude are not read by these endpoints. No GPS, heartbeat, or location-verification table is read or written.
