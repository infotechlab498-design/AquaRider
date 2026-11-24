# W10 / W11 Implementation Notes

**Status:** Implemented on existing RouteLedger stack (Flutter admin + ASP.NET Core 10 + SQL Server).  
**Locked V1:** No Google Maps, no background GPS, no geofencing SDKs, no new RBAC, no fabricated KPIs/seed rows for demo scale.

## W10 — Zones & Routes

### Database (additive)
- `Zones` table
- `DeliveryRoutes.ZoneId` (backfilled from Sector/City/Depot)
- `Customers.RouteSortOrder` (backfilled from latest RouteStops)

### APIs (`Authorize: Admin`)
- `/api/zones/*` CRUD + summary
- `/api/routes/*` CRUD, assign/unassign rider, customers allocate/sequence, stops ensure/sequence, static `map-pins`

### Flutter
- Nav: **Zones & Routes**
- Screen: zone list, route detail, rider assign, master + day sequencing, `StaticPinsMap` (OSM tiles, static pins only)

### Verified
- Migration applied on AquaRider
- `Zones_and_routes_are_sql_backed_for_admin` API test
- Live admin login → create zone/route, resequence customers, ensure stops → SQL counts updated
- Flutter `zones_routes_test.dart`

## W11 — Customers & Parties

### APIs (`Authorize: Admin`)
- `/api/admin/customers/summary`
- `/api/admin/customers` (search/filter/pagination)
- GET/POST/PUT detail
- `change-route`, `status`, `ledger`
- Lifetime sales/collections computed from `Sales` / `Collections` (no new credit-limit columns)

### Flutter
- Nav: **Customers & Parties**
- Directory + detail drawer, filters, pagination, route change, status, static GPS pin when present, recent ledger

### Cross-module
- Same `Customers.RouteId` → `DeliveryRoutes` → `Zones`
- Route change updates future/today `RouteStops.RouteId` and `RouteSortOrder`

## Excluded (Locked V1)
Live courier telemetry, geofences, multi-branch switcher, Price Lists UI, credit utilization meters, LIVE SYNC badge, CSV import/export (not in this phase).
