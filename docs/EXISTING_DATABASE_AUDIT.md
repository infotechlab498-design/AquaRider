# Existing Database Audit — AquaRider @ localhost\SQLEXPRESS

Inspected via `sqlcmd` on 2026-11-18. Database was **not** dropped or reseeding for this feature.

## Row counts (live)

| Table | Count |
|---|---|
| AspNetUsers | 3 |
| Customers (not deleted) | 28 |
| Sales | 11 |
| Collections | 1 |
| CustomerOrders | 1 |
| RouteStops | 28 |
| Shifts | 1 |
| ActivityLogs | 13 |
| DeliveryRoutes | 1 |
| Depots | 1 |
| BusinessProfiles | 1 |

## Roles present

- Admin
- Rider (users: `admin` / Admin; `ahmed.khan`, `infotechlab498` / Rider)

## Relevant columns for dashboards

- **Sales:** SaleAmount, Status, SyncStatus, PaymentChannel, AmountReceived, PreviousOutstanding, CreatedAt, RiderId, CustomerId, ReceiptNumber  
- **Collections:** Amount, Channel, CreatedAt, RiderId, CustomerId, ReferenceNumber, SyncStatus  
- **RouteStops:** Status, ServiceDate, Sequence, CustomerId, RouteId  
- **CustomerOrders:** Status, DeliveryDate, EstimatedValue, RiderId, CustomerId  
- **Customers:** Outstanding, IsDeleted, BusinessName, Code  
- **Shifts:** RiderId, ServiceDate, Status, StartedAt, EndedAt  
- **ActivityLogs:** Title, Reference, Amount, SyncStatus, Detail, OccurredAt, UserId  

## Not present (do not invent)

- GPS telemetry tables  
- Geofence tables  
- Spot billing ledger  
- Multibranch / multi-business tenant table beyond single `BusinessProfiles`  
- LocationVerification table  

## Policy

Development seeder runs only when **zero users** exist. New dashboard features must not insert demo operational rows on startup. Existing Development data remains as-is for local verification; production must not rely on seeder content.
