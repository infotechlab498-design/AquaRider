# Database schema

Database: `AquaRider` on `localhost\SQLEXPRESS` (Windows authentication).

The existing `RouteLedger_Db` database is a different application and is not used.

Money columns are `decimal(18,2)`. Enums are stored as strings. Most business rows use a `uniqueidentifier` primary key. Identity users and roles use the ASP.NET Core Identity string keys.

## Identity

| Table | Purpose | Notable columns |
|---|---|---|
| AspNetUsers | Riders and fleet admins | FullName, RiderCode, RouteId, VehicleId, DepotId, IsActive, CreatedAt, plus Identity password hash and lockout |
| AspNetRoles | `Rider`, `Admin` | Name |
| AspNetUserRoles | User-to-role | UserId, RoleId |
| AspNetUserClaims, AspNetRoleClaims, AspNetUserLogins, AspNetUserTokens | Identity infrastructure | Unused by the mobile app |

## Operations

| Table | Purpose | Notable columns |
|---|---|---|
| Depots | Depot the route leaves from | Name, Gate, Address |
| Vehicles | The van | Name, Plate, FleetCode, CurrentOdometer |
| DeliveryRoutes | Named route | Name, Sector, City, DepotId |
| Customers | Shops on a route | Code (unique while IsDeleted = 0), BusinessName, phones, address, GPS, RouteId, Outstanding, bottle counts, BottleOwnership, CreditDays, IsDeleted |
| Products | Catalog and prices | Name, Sku, UnitPrice, UnitLabel, IsReturnable, ShowOnSale, ShowOnShift |
| VehicleStocks | Current van quantity | VehicleId, ProductId, Quantity, DepotExpected. Unique (VehicleId, ProductId) |
| Shifts | A rider's day | RiderId, RouteId, VehicleId, ServiceDate, odometers, Status, StartedAt, EndedAt |
| ShiftStocks | Counted stock at start | ShiftId, ProductId, ExpectedQuantity, CountedQuantity |
| RouteStops | Today's manifest | CustomerId, RouteId, ServiceDate, Sequence, ScheduledTime, Status, DistanceMeters |
| Sales | Draft or completed sale | ReceiptNumber, CustomerId, RiderId, ShiftId, StopId, amounts, PaymentChannel, Status, signer, SyncStatus |
| SaleLines | Sale quantities | SaleId, ProductId, Quantity, UnitPrice (copied from Product) |
| Collections | Debt recovery | ReferenceNumber, CustomerId, RiderId, Amount, Channel, outstanding before/after, signer, SyncStatus |
| CustomerOrders | Future orders | ReferenceNumber, CustomerId, RiderId, DeliveryDate, Window, EstimatedValue, Status. Does not change van stock |
| OrderLines | Order quantities | OrderId, ProductId, Quantity, UnitPrice |
| LedgerEntries | Running customer balance | CustomerId, Kind (Opening, Sale, Payment), Description, Amount, BalanceAfter, Reference, OccurredAt |
| ActivityLogs | History and sync queue | UserId, Title, Reference, Amount, SyncStatus, Detail, OccurredAt |
| AuditLogs | Sensitive writes | UserId, Action, EntityName, EntityId, OccurredAt |
| RiderSettings | One row per rider | UserId (PK), AutoSync, ShowOrdersTab, Language, AutoPrint, DeleteOnLogout, PaperSize, PrinterId |
| PrinterDevices | Known printers | Name, Meta, IsOnline |
| PrintJobs | Queued print requests | SaleId, CollectionId, UserId, PrinterName, Status, RequestedAt |
| NumberSequences | Receipt and order numbers | Name (PK), NextValue |
| RefreshTokens | Hashed refresh tokens | UserId, TokenHash, ExpiresAt, RevokedAt, ReplacedByHash |
| PasswordResetRequests | Forgot-password audit only | UserId, RequestedAt, Status. No email or SMS is sent |

## Indexes and constraints

- Customer.Code is unique for rows that are not soft-deleted.
- Vehicle stock is unique per vehicle and product.
- Refresh token hash is indexed.
- Foreign keys point at the parent row (route to depot, customer to route, stop and sale and ledger to customer, lines to their header and product).
- Deleting a customer is not exposed. `IsDeleted` exists for a future soft delete.
