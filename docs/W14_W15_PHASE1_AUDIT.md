# W14 Branches & Warehouses + W15 Sales Management — Phase 1 Audit

**Scope:** Audit only. No entities, migrations, seed data, UI, or API code were modified for this document.  
**Date:** 2026-11-19  
**Sources:** Live AquaRider SQL Server, ASP.NET Core 10 + EF Core, Flutter admin shell, field sales APIs, Sentinel-04 Locked V1 docs, W14/W15 screenshots + full specification.

---

## Executive verdict

| Module | Locked V1 disposition |
|---|---|
| **W14 Branches & Warehouses** | Implement as **Main Warehouse (single Depot) operations console**. Multi-depot network, regional map, Add Branch/Hub, inter-depot transfers = **V2 — do not build without approval**. |
| **W15 Sales Management** | Implement as **Admin sales ledger + summary** over existing `Sales` / `SaleLines` / field post workflow. Separate from Collections. Cash / credit / pending-sync tabs in V1. Bank IBFT / Wallet **tabs off** as new payment products (existing `PaymentChannel` values may appear as tender labels only). |

**Do not begin V2 architecture expansion without explicit approval.**

---

## 1. What already exists

### 1.1 Database (live AquaRider)

| Object | Reality |
|---|---|
| `Depots` | **1** row — `Warehouse Depot Hub 02`, Gate `Zone C - Bay 04`, Address `Satellite Town, Rawalpindi` |
| `Vehicles` | 1 |
| `VehicleStocks` | 4 (per-vehicle product qty + DepotExpected) |
| `Customers` | 28 |
| `CustomerOrders` (today UTC) | 1 |
| `Sales` | 11 Completed (Cash 6, BankTransfer 3, Wallet 2; Synced 10, Failed 1) |
| `Collections` | 1 (separate from sales) |
| Warehouse / Bay / Transfer / Receivable tables | **None** |

**Live KPI truth for UI (must not be fabricated):** Total Depots = **1**, Assigned Fleet = **1**, Linked Stores = **28**, Pending Sync (Failed) = **1**, Completed Sales = **11**.

### 1.2 Domain entities already mapped

**W14-relevant**

- `Depot` — `Name`, `Gate`, `Address` only (no capacity, type, manager, status columns)
- `Vehicle`, `VehicleStock` — fleet stock custody on van, not warehouse bay model
- `DeliveryRoute.DepotId`, `Zone.DepotId`, `ApplicationUser.DepotId` — all point at single depot
- Day-close settlement stock reconciliation (operational, not warehouse bay grid)

**W15-relevant**

- `Sale` — receipt, customer, rider, amounts, `PaymentChannel?`, `SaleStatus` (Draft/Completed), `SyncStatus`, signature/POD fields, empties returned
- `SaleLine` — product, qty, unit price (server-set from `Products.UnitPrice`)
- `Collection` — separate payment entity (correct separation per spec)
- `LedgerEntry` — Opening / Sale / Payment
- `Customer.Outstanding`, bottle fields
- Field flow: `POST /api/sales` (draft) → `POST /api/sales/{id}/complete` (post)
- `GET /api/sales/{id}/receipt`, `GET /api/history` (rider-scoped)
- Command dashboard: billed sales KPIs, sales summary buckets, collections summary

### 1.3 APIs that can be reused

| Need | Existing |
|---|---|
| Depot identity | Query `Depots` (no dedicated admin depot controller yet) |
| Fleet assigned to depot | `Vehicles` + users with `VehicleId` / `DepotId`; Rider Ops / Users APIs |
| Linked stores | `Customers` count (all routes under single depot today) |
| Today’s dispatch | `CustomerOrders` / dispatch APIs (already Admin) |
| Van stock | `VehicleStocks` |
| Create/post sale | `POST /api/sales` → `POST /api/sales/{id}/complete` (`FieldController`, Admin+Rider) |
| Receipt / POD | `GET /api/sales/{id}/receipt`; signature fields on `Sale` |
| Rider history (not HQ ledger) | `GET /api/history` (rider-scoped) |
| Ledger / bottles | Customer ledger + `EmptyBottlesReturned` / `BottlesHeld` |
| Sales aggregates | `GET /api/dashboard/sales-summary`, overview KPIs, Day Close cash ledger |
| Base price validation | Product pricing APIs (`UnitPrice` set server-side on draft) |

**Gap:** There is **no** Admin HQ sales directory (`GET /api/admin/sales`) and **no** Admin depot summary controller. Dashboard sales charts are aggregates only.

### 1.4 Flutter

- Admin shell + Locked V1 nav (`AdminNav`) exists; keys today: dashboard, fleet, dispatch, dayClose, basePricing, zonesRoutes, customersParties, usersStaff, plus unavailable stubs (manifests, audits, settings)
- **No** `branchesWarehouses` or `salesManagement` nav keys / screens
- Field app already posts sales and shows history/receipts
- `Inventory Audits` nav → unavailable stub (related theme, not W14 depot console)

---

## 2. Missing functionality (V1-scoped)

### W14 — Main Warehouse console (allowed)

1. Admin read API for the single depot + operational summary  
2. KPIs from SQL: 1 depot, active flag (implicit), fleet count, today’s dispatch count, linked customers  
3. Directory showing **one** Main Warehouse card (honest — not 8 hubs)  
4. Detail panel: address/gate, assigned vehicles/riders, vehicle stock summary, today’s order/sales counts  
5. Optional: edit Name/Gate/Address (additive; audit)  
6. Flutter screen under Team Management or System  

### W15 — Admin sales ledger (allowed)

1. `GET /api/admin/sales/summary?date=` — billed, cash component, credit outstanding from sales, completed count, average, pending/failed sync counts  
2. `GET /api/admin/sales` — paged/filter by date, tender class (Cash / Credit / Partial), rider, sync status, search  
3. `GET /api/admin/sales/{id}` — full detail: lines, customer, rider/vehicle, financials, empties, signature meta  
4. Manual invoice for Admin: reuse draft+complete with Admin auth (or thin admin wrapper) — server price validation already exists  
5. Flutter Sales screen: KPIs, tabs (All / Cash / Credit / Pending Sync), table, detail panel  

### Explicitly not in V1 missing list

- Multi-warehouse CRUD, bays, transfers, regional telemetry  
- New Bank/Wallet payment products / IBFT tabs as first-class filters  
- WhatsApp / thermal / PDF export as working features  
- Sale reversal engine (may be Phase-later additive; not in current schema)  
- Separate `ClientTransactionId` offline admin sync service (field uses `SyncStatus`; expand only if needed)

---

## 3. Required modifications vs new work

| Area | Modification of existing | New (V1) | New (V2 only — blocked) |
|---|---|---|---|
| Depot | Possibly add optional capacity/status columns **or** compute capacity from `VehicleStocks`/`Products` without schema | Admin depot summary API + Flutter | Warehouses, bays, transfers, multi-hub |
| Sales | Extend read models; Admin controllers; optional enrich Sale DTO | Admin sales list/summary/detail UI | Full `/api/v1/sales` rewrite, new receivable tables if duplicating `Customer.Outstanding` |
| Payments | Map Cash vs Credit from `AmountReceived`/`SaleAmount`; existing enum labels for Bank/Wallet as display-only | Tab set per Locked V1 | New payment rails |
| Auth | Keep Admin / Rider only | — | Custom RBAC |

**Migration preference for V1:** Prefer **no migration** for W14/W15 if KPIs can be computed from `Depots`, `Vehicles`, `VehicleStocks`, `Customers`, `CustomerOrders`, `Sales`. Add columns only if product requires editable warehouse capacity/status.

---

## 4. Outside approved V1 scope (do not implement)

### W14 screenshot / V2

- Total Depots = 8, satellite hubs, Add Branch / Add Hub  
- Regional corridor map / GPS latency / fake telemetry  
- Loading bay grid B1–B8 as live dock system  
- Inter-depot stock transfer pipeline  
- WarehouseStaffAssignment / WarehouseBay / WarehouseTransfer entities  
- RO bottling line / GPH industrial telemetry  

### W15 screenshot / out of Locked V1 product claims

- Fabricated KPIs (185,000 / 146 txns) — show SQL truth (today: 11 sales)  
- Bank IBFT/Raast and Mobile Wallet **tabs as active payment products**  
- “Synced & Crypto-Locked”, geofence accuracy badges  
- WhatsApp slip / PDF / thermal as shipped features  
- Merging collections into the sales row as if one document  

---

## 5. Entity / relationship map (authoritative V1)

```
Depots (1)
  ├── DeliveryRoutes / Zones
  ├── AspNetUsers.DepotId
  └── (indirect) Vehicles via riders

Vehicles 1──* VehicleStocks *── Products

Customers 1──* Sales 1──* SaleLines
          1──* Collections
          1──* LedgerEntries

Sale.RiderId → AspNetUsers
Sale.Status: Draft | Completed
Sale.SyncStatus: Pending | Synced | Failed
Sale.PaymentChannel: Cash | BankTransfer | Wallet | Cheque  (enum exists; V1 UI emphasizes Cash/Credit)
```

Sales vs Collections vs Orders already separated — **preserve**.

---

## 6. Authorization (Locked V1)

- Admin: warehouse console, sales directory, manual invoice  
- Rider: existing field sale create/complete only  
- No new roles  

---

## 7. Flutter files that would change (after approval)

| File | Change |
|---|---|
| `admin_nav.dart` / `admin_sidebar.dart` / `admin_workspace.dart` | Add `branchesWarehouses`, `salesManagement` |
| New screens + models | Main warehouse screen; sales ledger screen |
| `route_api.dart` + memory stub | Depot summary + admin sales endpoints |
| Tests | Honest empty/small-data tests |

Reuse `AdminTokens` / shell; do not invent parallel apps.

---

## 8. Proposed V1 API surface (not implemented yet)

### W14

```http
GET  /api/depot                 # single main warehouse
GET  /api/depot/summary         # KPIs from SQL
PUT  /api/depot                 # optional edit name/gate/address
GET  /api/depot/fleet           # vehicles + assigned riders
GET  /api/depot/stock           # vehicle stocks rollup / product expected
```

Reject `POST` multi-warehouse create in V1.

### W15

```http
GET  /api/admin/sales/summary?date=
GET  /api/admin/sales?date=&type=&syncStatus=&riderId=&search=&page=
GET  /api/admin/sales/{id}
POST /api/admin/sales/drafts          # or reuse POST /api/sales as Admin
POST /api/admin/sales/{id}/complete   # or reuse complete
GET  /api/admin/sales/{id}/receipt
```

Types for V1 tabs: `All | Cash | Credit | PendingSync`  
where Credit = posted sales with `AmountReceived < SaleAmount` (or 0), Cash = full cash receipt classification used by Day Close.

---

## 9. Business-rule conflicts to preserve

1. Server sets `UnitPrice` from catalogue — never trust client price.  
2. Posted `Completed` sales are not edited in place today — keep immutable; reversal = future additive.  
3. Day Close cash recon remains cash-focused; do not expand screenshot wallet/IBFT into settlement.  
4. Single `Depots` row — UI must not invent satellite hubs.  
5. Offline: field `SyncStatus` exists; do not fake “Pending Sync = 4” without rows.

---

## 10. Implementation sequence (after approval)

| Phase | Work |
|---|---|
| 1 | **This audit** — complete |
| 2 | Confirm V1 scope: single-depot W14 + admin sales W15; V2 deferred |
| 3 | Backend: depot summary APIs (no multi-warehouse schema) |
| 4 | Backend: admin sales summary/list/detail (+ tests) |
| 5 | Flutter W14 Main Warehouse screen |
| 6 | Flutter W15 Sales ledger + detail panel |
| 7 | E2E Flutter → API → SQL; document known unavailable buttons (PDF/WhatsApp/Add Hub) |

---

## 11. Approval ask

Please confirm before coding:

1. **W14 V1** = single Main Warehouse console over `Depots` (no multi-hub / bays / transfers).  
2. **W15 V1** = Admin sales ledger over existing `Sales` with Cash / Credit / Pending Sync tabs; Bank/Wallet tabs not activated as products.  
3. Prefer **compute-first, migration only if capacity/status fields are mandated**.  
4. **V2 warehouse network remains blocked** until separate approval.  

No implementation starts until you approve this audit.
