# Database relationships

```text
Depot 1──* DeliveryRoute 1──* Customer 1──* RouteStop
                              │
                              ├──* Sale 1──* SaleLine *──1 Product
                              ├──* Collection
                              ├──* CustomerOrder 1──* OrderLine *──1 Product
                              └──* LedgerEntry

Vehicle 1──* VehicleStock *──1 Product
Vehicle 1──* Shift 1──* ShiftStock *──1 Product
DeliveryRoute 1──* Shift
AspNetUsers 1──* Shift
AspNetUsers 1──0..1 RiderSettings
AspNetUsers 1──* RefreshToken
AspNetUsers 1──* Sale / Collection / CustomerOrder / ActivityLog / AuditLog
PrinterDevice 0..1── RiderSettings.PrinterId
Sale 0..1──* PrintJob
```

A rider is assigned one route and one vehicle. Field APIs only read and write stops, customers, sales, and stock on that assignment. An admin without a route receives 403 from field endpoints.

A sale may attach to the open shift when one exists. Starting the day is not required before a sale, because the mobile sale screen does not block on a shift.

Completing a sale and recording a collection each run in one database transaction: stock or balance is checked before any write, then the ledger, the customer balance, the stop, and the activity row change together. A failed check leaves the database unchanged.

Future orders insert `CustomerOrder` and `OrderLine` rows only. They do not deduct `VehicleStock`.

Opening debt and opening empties are written only when the customer is created, or when an existing customer still has no ledger rows. Later edits keep the ledger balance.
