# W10 Zones & Routes + W11 Customers & Parties — Phase 1 & 2 Audit

**Scope:** Audit only. No new entities, migrations, seed data, or UI components were created for this document.  
**Date:** 2026-11-18  
**Sources:** Live AquaRider SQL Server, ASP.NET Core 10 solution, Flutter `riderfrontend`, Sentinel-04 Locked V1 docs, reference screenshots W10 / W11.

---

## 1. Existing functionality

### 1.1 Backend (functional today)

| Capability | Where | Notes |
|---|---|---|
| Customer get / create / update | `GET/POST/PUT /api/customers…` via `FieldService` | Rider-authenticated field API |
| Customer sale context | `GET /api/customers/{id}/sale-context` | Products + empties |
| Customer ledger | `GET /api/customers/{id}/ledger` | `LedgerEntries` |
| Visit log | `POST /api/customers/{id}/visit` | |
| Day stops (route sequence) | `GET /api/stops` | Rider’s route `RouteStops` for today |
| Rider↔route binding | `AspNetUsers.RouteId` / `VehicleId` | Assign courier at user level |
| Dispatch zone summary | `GET /api/dispatch/operational-summary` | One card per `DeliveryRoutes` row (order/stop counts) |
| Rider ops assignments | `GET /api/rider-operations/riders/{id}/assignments` | Stops for date |
| Users admin | `GET/POST /api/users` | Can change rider route indirectly via user admin |

### 1.2 Flutter (functional today)

| Capability | Where |
|---|---|
| Field customer view / create / edit | `lib/screens/field_screens.dart`, `customerselection.dart` |
| Field stops list + live map widget | `live_route_map.dart` (`flutter_map` + device location) — **action-time / local**, not admin geospatial manifest |
| Location permission gate | `location_access.dart` |
| Admin shell / Locked V1 nav | `adminDashboard/` — Day Close, Base Pricing, Dispatch, Fleet exist |
| Route Manifests nav stub | `AdminNav.manifests` → `AdminUnavailableScreen` |

### 1.3 Not present as admin modules

- No **Zones & Routes Management** admin screen  
- No **Customers & Parties Directory** admin screen  
- No admin paged customer directory API  
- No zone CRUD, route resequence admin API, geofence polygon storage  
- No “unassigned store pool” entity (every customer **must** have `RouteId`)

---

## 2. Missing functionality (vs screenshots, Locked V1–filtered)

### W10 — Zones & Routes (screenshot gaps)

| Screenshot feature | Status under Locked V1 |
|---|---|
| Multi-zone directory (8 clusters) | **Missing** — DB has **1** `DeliveryRoutes` row; no `Zones` table |
| Routes-per-zone list with reassign courier | **Partial** — rider has `RouteId`; no admin route board UI/API |
| “No Rider” / Assign Courier CTA | **Missing** as route-centric workflow (users API only) |
| Manage customers on route / reorder SEQ | **Missing** admin resequence; field uses `RouteStops.Sequence` for a **service date**, not a master route template |
| Geospatial Manifest map + geofence + live speed | **Excluded** by Locked V1 (no live GPS / geofence / continuous tracking) |
| Capacity utilization % | **Missing** — no capacity model |
| Add from Unassigned Pool | **Conflict** — `Customers.RouteId` is required; no unassigned pool today |
| Morning/Afternoon split shifts as route variants | **Missing** — one route row; delivery window lives on orders, not routes |

### W11 — Customers & Parties (screenshot gaps)

| Screenshot feature | Status under Locked V1 |
|---|---|
| Admin directory + filters + pagination | **Missing** (field get-by-id only) |
| KPI strip (total/active/inactive/new/outstanding) | **Missing** admin summary API |
| Side drawer with ledger snippet | **Reusable** ledger API; **missing** admin drawer UI |
| Import CSV / Export catalog | **Missing** |
| Credit limit / utilization / lifetime sales | **Missing columns** |
| Multi-branch hub switcher | **Excluded** (single depot) |
| LIVE SYNC badge as live claim | **Excluded** — connectivity ≠ fabricated sync |
| Direct GPS pin map in admin drawer | **Compliant alternative:** show lat/long if present; static pin via existing `flutter_map` **without** live courier telemetry; only **1/28** customers have GPS today |
| Roles & Permissions / Price Lists / Trackboard nav | **Excluded** or already replaced (Base Pricing, Fleet Couriers) |

---

## 3. Existing database tables and relationships

### 3.1 Core ER (relevant)

```
Depots 1──* DeliveryRoutes 1──* Customers
                │                    │
                │                    └──* LedgerEntries
                │                    └──* Sales / Collections / CustomerOrders
                └──* RouteStops *── Customers   (per ServiceDate + Sequence)
AspNetUsers (Rider) ──> DeliveryRoutes (RouteId), Vehicles (VehicleId)
```

### 3.2 Live counts (AquaRider)

| Table | Count | Notes |
|---|---:|---|
| `Customers` (not deleted) | 28 | All `Status=Active`; all have `RouteId` |
| With GPS (`Latitude`/`Longitude`) | 1 | Ali General Store only |
| `DeliveryRoutes` | 1 | `Satellite Town – Route 03`, Sector `4B` |
| `RouteStops` | 28 | Day stops for a service date |
| `Depots` | 1 | Main warehouse |
| `Vehicles` | 1 | |
| Active riders with route | 2 | Both on the same route |

### 3.3 Tables that do **not** exist

`Zones`, `Geofences`, `RoutePolygons`, `Parties`, `CustomerCreditLimits`, `CustomerPriceAssignments`, unassigned-customer staging tables.

### 3.4 Important columns

**`Customers`:** Code, BusinessName, phones, Category, Street/Area/City, Lat/Long, RouteId, Status, Outstanding, bottle fields, CreditDays, soft delete — **no CreditLimit, LifetimeSales**.

**`DeliveryRoutes`:** Name, Sector, City, DepotId — **Sector is the closest “zone” attribute**.

**`RouteStops`:** CustomerId, RouteId, ServiceDate, Sequence, Status — operational day plan, not permanent master sequence alone.

---

## 4. Existing APIs that can be reused

| Need | Reuse |
|---|---|
| Customer detail / edit payload shape | `CustomerDetailDto`, `CustomerWriteRequest` |
| Create/update customer | `POST/PUT /api/customers` (today Rider role — may need Admin policy extension, not a new body shape) |
| Ledger in drawer | `GET /api/customers/{id}/ledger` |
| Stop sequence for a day | `GET /api/stops` (rider-scoped) + `RouteStops` queries |
| Zone-like cards | Pattern from `DispatchOperationalSummary` zones |
| Rider assignment to route | `AspNetUsers.RouteId` via `/api/users` |
| Bottle balance | `BottlesIssued/Returned/Held` on customer |
| Outstanding KPI | Sum `Customers.Outstanding` (dashboard already does similar) |

---

## 5. Required new APIs (proposed — not implemented)

### W10 (admin, Locked V1 compliant)

| Method | Path (proposed) | Purpose |
|---|---|---|
| GET | `/api/routes/summary` | Counts: routes, riders assigned, customers assigned, customers missing GPS (not fake 8 zones) |
| GET | `/api/routes` | Paged/filterable `DeliveryRoutes` (+ sector/city as zone label) |
| GET | `/api/routes/{id}` | Route detail: riders, customer count, vehicle |
| GET | `/api/routes/{id}/customers` | Customers on route (master list) |
| GET | `/api/routes/{id}/stops?date=` | Day stop sequence from `RouteStops` |
| POST | `/api/routes/{id}/assign-rider` | Set rider `RouteId` (reuse users rules) |
| PUT | `/api/routes/{id}/stops/sequence` | Resequence **day** stops or define policy for master order |
| POST | `/api/routes` / PUT | Create/update route (Name, Sector, City, DepotId) — only if product allows |

**Do not add:** live GPS stream, geofence CRUD, fabricated multi-zone seed.

### W11 (admin)

| Method | Path (proposed) | Purpose |
|---|---|---|
| GET | `/api/admin/customers` or `/api/customers` (Admin) | Paged directory: search, status, area, routeId, outstandingOnly |
| GET | `/api/admin/customers/summary` | Real KPI counts from SQL |
| GET | `/api/admin/customers/{id}` | Detail + recent ledger snippet (or compose existing ledger) |
| PUT | `/api/admin/customers/{id}` | Update including route change / deactivate |
| GET | `/api/admin/customers/{id}/recent-activity` | Optional thin sales/collections feed |

**Do not add:** credit-limit engine, multi-branch filters, Price List assignment, live sync fabrication.

---

## 6. Required database changes (proposed — not applied)

| Change | Needed? | Rationale |
|---|---|---|
| New `Zones` table | **Avoid if possible** | Use `DeliveryRoutes.Sector` / `City` / `Area` groupings first |
| Nullable `Customers.RouteId` + unassigned pool | **Product decision** | Screenshot needs unassigned stores; Locked V1 can show “missing route” only if schema allows null or a sentinel |
| Master route sequence table | **Maybe** | If day `RouteStops` is insufficient for “permanent SEQ” |
| Geofence / polygon tables | **No** (Locked V1) | |
| CreditLimit / LifetimeSales columns | **No unless approved** | Compute lifetime from `Sales`/`Collections` in API instead of new columns |
| Additive indexes on `Customers(RouteId)`, `(Status)`, `(Area)` | **Yes** if directory grows | Performance only |

**Migration policy:** additive only; no drop; no seed of 8 fake zones / 486 stores.

---

## 7. Conflicts with Locked V1 / existing business rules

| Conflict | Compliant disposition |
|---|---|
| Geospatial Manifest + live speed 28 km/h | **Omit live map.** Optional static stop list + coords; no continuous GPS |
| Geofence boundary | **Omit** |
| 8 zones / 24 routes / 486 stores KPIs | Show **actual** counts (today: 1 route, 28 customers) or empty |
| Unassigned pool of 12 | Not in DB; either don’t show or require approved schema change |
| Multibranch “Rawalpindi Central Hub #01” switcher | Single `Depots` row only |
| Price Lists / Trackboard / Roles RBAC in W11 sidebar | Keep existing Locked V1 nav; no custom RBAC |
| “Zone” as separate entity | Prefer **sector/route grouping** until product expands scope |
| Field `POST /api/customers` is Rider-scoped | Admin directory needs Admin authorization without inventing Owner/Manager roles |
| Map packages | `flutter_map` already present for field; admin must not claim live courier tracking |

---

## 8. Flutter files that would need modification (later phases)

| File / area | Change (future) |
|---|---|
| `admin_nav.dart` | Add `zonesRoutes`, `customers` keys |
| `admin_sidebar.dart` | Nav labels (Zones & Routes; Customers & Parties) — not Price Lists / Trackboard |
| `admin_workspace.dart` | Route to new screens |
| New `zones_routes_screen.dart` + widgets | Compliant layout (no live geospatial) |
| New `customers_directory_screen.dart` + drawer | Directory + detail |
| `route_api.dart` + `memory_route_api.dart` | New admin endpoints |
| Tests under `test/` | Empty/honest KPI tests |
| Possibly reuse `live_route_map.dart` | Only for **static** pin if approved — rename/clarify so it is not “live courier” |

**Do not touch** for audit: no UI creation in this phase.

---

## 9. Dependencies for maps and integrations

### Already in `pubspec.yaml`

| Package | Use today | W10/W11 guidance |
|---|---|---|
| `flutter_map` ^8.3.2 | Field live route map | Reuse for **optional static** customer/route pins only |
| `latlong2` | Coordinates | Keep |
| `location` | Device GPS at action time | Field only; not admin live tracking |
| `url_launcher` | Open Google Maps directions | Keep for “open in maps” deep link |
| `http` | API | Keep |

### Not required / avoid adding for Locked V1

| Package / service | Why avoid |
|---|---|
| Google Maps SDK / Mapbox live traffic | Screenshot live telemetry excluded |
| Background geolocation / websocket GPS | Continuous tracking excluded |
| New geofencing SDKs | Excluded |

### Backend integrations

- No map tile key required if admin omits map or uses OSM tiles like field map.  
- If static pins stay, document tile attribution; no new paid dependency mandatory for Phase 1–2.

---

## 10. Phase 2 wireframe map (compliant)

### W10 — Zones & Routes (no live map)

```
[Summary KPIs from SQL]
[Left: Routes list grouped by Sector/City]
[Right: Selected route — riders, customer count, day stops table]
Actions: Assign rider (users), Manage customers (directory filter), Resequence day stops
Replace Geospatial Manifest with: Stop list + optional static coordinate column / “Open in maps”
```

### W11 — Customers & Parties

```
[KPI strip from SQL]
[Filters: status, area, route, outstanding]
[Table: code, name, category, area, route, outstanding, bottles, status]
[Drawer: identity, bottles, recent ledger via existing API, edit/deactivate/change route]
No LIVE SYNC badge; no credit-limit meter unless columns approved
```

---

## 11. Phase gate

| Phase | Status |
|---|---|
| Phase 1 — Inspect Flutter / API / SQL / Locked V1 | **Complete** (this report) |
| Phase 2 — Map workflows + wireframes + gap list | **Complete** (this report) |
| Phase 3+ — Implementation | **Not started** — waiting for explicit go-ahead after audit review |

---

## 12. Verdict

W10 and W11 screenshots describe a multi-zone geospatial + rich CRM admin that **partially** maps onto existing `DeliveryRoutes`, `Customers`, `RouteStops`, and field customer APIs.  

**Reusable foundation is strong for customer master data and single-route stop sequencing.**  

**Major gaps:** admin directory/APIs, route management UX, and almost all screenshot geospatial/live/unassigned-pool KPIs.  

**Locked V1 requires stripping live maps/geofences/fabricated scale and avoiding Zone/PriceList/RBAC sprawl.**  

Implementation must extend the existing RouteLedger admin app and APIs—not a parallel product—and must not claim features complete until Flutter → API → SQL Server is tested end-to-end.
