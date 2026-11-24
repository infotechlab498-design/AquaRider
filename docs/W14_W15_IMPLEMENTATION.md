# W14 / W15 Implementation (Locked V1)

**Approved scope:** single Main Warehouse + Admin sales ledger (Cash / Credit / Pending Sync). Compute-first; no multi-depot migration.

## Backend

| Endpoint | Purpose |
|---|---|
| `GET /api/depot` | Main warehouse identity |
| `GET /api/depot/summary?date=` | KPIs, capacity, fleet, stock rollup |
| `GET /api/depot/fleet` | Vehicles + assigned riders |
| `GET /api/depot/stock` | Van stock vs depot expected |
| `PUT /api/depot` | Edit name / gate / address |
| `GET /api/admin/sales/summary?date=` | Billed, cash, credit, avg, sync counts |
| `GET /api/admin/sales` | Paged ledger (`type=All\|Cash\|Credit\|PendingSync`) |
| `GET /api/admin/sales/{id}` | Full detail |
| `POST /api/admin/sales/drafts` | Manual invoice draft (on behalf of rider) |
| `POST /api/admin/sales/{id}/complete` | Post sale (Cash only channel; credit via amount) |
| `GET /api/admin/sales/{id}/receipt` | Receipt DTO |

Services: `DepotOperationsService`, `AdminSalesService`  
Tests: `Admin_depot_summary_is_single_main_warehouse`, `Admin_sales_ledger_is_sql_backed`

## Flutter

- Nav: **Sales** (Operations), **Branches & Warehouses** (Administration)
- Screens: `warehouse_screen.dart`, `sales_management_screen.dart`
- API: `route_api.dart` depot + admin sales methods
- Unavailable (honest notice): Add Hub/Branch, Export PDF/WhatsApp/thermal, Configure Bays, Transfer Van, Audit Vault, Schedule Audit

## Known V1 limits

- One `Depots` row; satellite hubs = 0
- Bank/Wallet tabs not activated; existing enum values may appear as tender labels only
- Manual invoice requires rider with route + vehicle; customer must be on that route
- No sale reversal engine in this slice
