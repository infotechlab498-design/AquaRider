# Database Entity Mapping — Rider Ops + Dispatch

| Screen concept | Existing table / entity | Notes |
|---|---|---|
| Rider | `AspNetUsers` + role Rider | RiderCode, RouteId, VehicleId, IsActive |
| Vehicle | `Vehicles` | Name, Plate |
| Route / zone | `DeliveryRoutes` | Name, Sector, City |
| Assignment (field day) | `RouteStops` + `Shifts` | Stop progress; open shift = on duty |
| Future order | `CustomerOrders` | ReferenceNumber, RiderId, Status, Window, Notes, EstimatedValue |
| Order lines / pick-list | `OrderLines` + `Products` | Qty × UnitPrice; pick-list is a projection, not a new Manifest table |
| Lifecycle | `AuditLogs` (+ optional `OrderLifecycleEvents`) | Prefer dedicated events for timeline clarity |
| Activity | `ActivityLogs` | Rider activity panel |
| Collections / cash | `Collections`, `Sales` | Cash-only figures for Locked V1 cards |
| Business / facility | `BusinessProfiles`, `Depots` | Header context |

**Do not create** second Rider/Order tables, GPS ping tables, geofences, or Price Lists.
