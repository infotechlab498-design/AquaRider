# Screen → API Mapping

## Business Overview (Command Dashboard)

| UI region | Method | Path |
|---|---|---|
| Header greeting, business name, facility | GET | `/api/dashboard/overview` |
| Six KPI cards | GET | `/api/dashboard/kpis?from=&to=` |
| Operational activity overview | GET | `/api/dashboard/operational-summary?from=&to=` |
| Needs attention | GET | `/api/dashboard/attention-items?from=&to=` |
| Sales chart | GET | `/api/dashboard/sales-summary?from=&to=&bucket=hour\|day` |
| Collections summary (approved types) | GET | `/api/dashboard/collections-summary?from=&to=` |
| Activity ledger table | GET | `/api/dashboard/activity-ledger?from=&to=&search=&page=&pageSize=&status=` |
| Create order | POST | `/api/dashboard/orders` (admin-scoped create) |

Note: Existing rider `GET /api/dashboard` remains unchanged for the field app.

## Rider Operations (Fleet Couriers)

| UI region | Method | Path |
|---|---|---|
| Page KPIs | GET | `/api/rider-operations/summary?date=` |
| Rider directory | GET | `/api/rider-operations/riders?search=&status=&date=` |
| Selected rider | GET | `/api/rider-operations/riders/{id}?date=` |
| Activity | GET | `/api/rider-operations/riders/{id}/activity` |
| Assignments / stops | GET | `/api/rider-operations/riders/{id}/assignments?date=` |
| Exceptions | GET | `/api/rider-operations/exceptions?date=` |
| Location verifications | GET | `/api/rider-operations/location-verifications` → empty until workflow exists |

## Dispatch & Order Management

| UI region | Method | Path |
|---|---|---|
| Directory / KPIs / tabs | GET | `/api/dispatch/orders`, `…/summary`, `…/status-counts` |
| Detail / items / lifecycle / pick-list | GET | `/api/dispatch/orders/{id}` (+ `/items`, `/lifecycle`, `/picklist`) |
| Assign / reassign / cancel / prepare pick-list | POST | `/api/dispatch/orders/{id}/…` |
| Eligible riders / ops summary | GET | `/api/dispatch/eligible-riders`, `/operational-summary` |

## W07 — Day Close & Cash Reconciliation (**planned** — not implemented)

| UI region | Planned path | Existing reuse today |
|---|---|---|
| Date / warehouse context | GET settlements summary | Depot from onboarding/dashboard overview; **no** day-close API |
| Hub Vault Gateway status | Integration status endpoint | **None** → show Not Configured |
| Five KPI cards | `GET /api/settlements/day-close/summary` | Cash partition logic in `CommandDashboardService` only |
| Session tabs + table | `GET /api/settlements/sessions` | Projectable from Shifts/Sales; **no** status store |
| Detail / cash ledger / stock / audit | `GET /api/settlements/sessions/{id}/…` | Partial stock via ShiftStocks/Sales; **no** vault |
| Save draft / verify / resolve / approve | `POST /api/settlements/sessions/{id}/…` | **Missing** |
| Lock / bulk lock / readiness | `POST/GET /api/settlements/days/…` | Rider `POST /api/shifts/end` is **not** day lock |
| Export audit | `GET /api/settlements/audit/export` | **Missing** |

Field inputs that **feed** W07 calculations (already live):

| Concern | Path |
|---|---|
| Start / end shift | `POST /api/shifts/start`, `POST /api/shifts/end` |
| Sales / collections | `POST /api/sales`, `POST /api/sales/{id}/complete`, `POST /api/collections` |

## W09 — Products & Base Pricing (**planned** — not implemented)

| UI region | Planned path | Existing reuse today |
|---|---|---|
| Catalogue / categories / matrix | `GET /api/products/catalogue`, `/categories`, `/base-prices` | `Products` table; **no** admin product API |
| Coverage / unpriced | `GET /api/products/pricing/coverage`, `/unpriced` | **Missing** |
| Customer base-price lookup | `GET /api/customers/{id}/base-price-lookup` | Customer GET exists; prices = all `Products.UnitPrice` |
| Price history | `GET /api/products/{id}/price-history` | **No** audit table → empty/read-only |
| Export | `GET /api/products/pricing/export` | **Missing** |
| Create Price List / tier assign | — | **Excluded** by Locked V1 |

Field POS already stamps base price:

| Concern | Path |
|---|---|
| Sale lines priced from product | `POST /api/sales` (`UnitPrice` from `Products`) |

## Shared

| Concern | Path |
|---|---|
| Auth profile | `GET /api/auth/me` |
| Business profile | Onboarding overview / dashboard overview embeds BusinessProfile |
| Health | `GET /api/health` |
