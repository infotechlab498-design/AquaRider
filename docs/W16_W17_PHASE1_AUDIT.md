# W16 Collections & Recovery + W17 Reports & Analytics — Phase 1 Audit

**Date:** 2026-11-19  
**Sources:** Live AquaRider SQL, FieldService collections, CommandDashboard, Day Close, W14/W15 patterns, Locked V1 docs, supplied screenshots.

---

## Executive verdict (Locked V1)

| Module | Disposition |
|---|---|
| **W16** | Admin collections ledger over existing `Collections` + receivables from `Customer.Outstanding`. Tabs: **All / Cash / Pending Sync**. Manual HQ settlement (Cash) on behalf of a rider. |
| **W17** | Analytics hub computed from Sales, Collections, RouteStops, Customers, Users. Report catalog with **CSV export only**. |

**Blocked without separate V2 approval:** Raast health, Bank/Wallet/Cheque product tabs, Knox, WhatsApp/thermal/PDF as shipped features, bulk WhatsApp, geofence accuracy, multi-hub filters, scheduled auto-export engines, XLSX/PDF generation servers.

---

## Live SQL truth

| Metric | Value |
|---|---|
| Collections | **1** (`COL-YDAY-0001`, Cash, **Pending**, PKR 1,000) |
| Customers with debt | **1** |
| Total outstanding | **PKR 1,200** |
| Reminder / Report / Schedule / Export tables | **None** |

---

## Existing (reuse)

- `Collection` entity + `POST /api/collections` (field; Admin blocked without route/vehicle)
- Ledger `Payment` lines; Day Close cash recon
- `GET /api/dashboard/collections-summary`, KPIs, activity-ledger, sales-summary
- Admin customers outstanding + ledger
- Flutter dashboard collections card + sales chart widgets
- W15 admin sales screen pattern to clone for W16

## Missing

- `/api/admin/collections*` HQ directory + manual settlement
- `/api/admin/reports*` catalog + CSV
- Flutter nav/screens for Collections and Reports

## V1 API surface (to implement)

```http
GET  /api/admin/collections/summary?date=
GET  /api/admin/collections?date=&type=&riderId=&search=&page=
GET  /api/admin/collections/{id}
POST /api/admin/collections
GET  /api/admin/receivables/exposure

GET  /api/admin/reports/summary?from=&to=
GET  /api/admin/reports/catalog
GET  /api/admin/reports/{key}
GET  /api/admin/reports/{key}/export.csv
```

No migrations required for V1 (compute-first).
