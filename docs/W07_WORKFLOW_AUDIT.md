# W07 Workflow Audit — What Exists vs What Must Be Built

## 1. Existing field workflows (reuse)

| Step | Existing API / service | Persists? | W07 reuse |
|---|---|---|---|
| Day started | `POST /api/shifts/start` (`FieldService.StartShiftAsync`) | `Shifts` + `ShiftStocks` + `AuditLogs`/`ActivityLogs` | Session start / stock opening |
| Record sale | `POST /api/sales` + complete | `Sales`/`SaleLines`, customer bottles, ledger | Expected cash components; empty returns |
| Record collection | `POST /api/collections` | `Collections` | Expected/declared cash (cash channel) |
| Day closed (rider) | `POST /api/shifts/end` | Closes shift + odometer photos | **Not** manager settlement; no cash/vault/lock |
| Admin cash categories | `GET /api/dashboard/collections-summary` | Read-only | Approved Cash / FullCredit / PartialCash partition |
| Rider cash total | `GET /api/dashboard` field | Sum cash sales + cash collections for day | Informational only — not vault |

## 2. Screenshot workflow vs reality

| Screenshot step | Status |
|---|---|
| Select settlement date / warehouse | **Partial** — date filters exist on other admin APIs; single depot exists; no day-close API |
| Hub Vault Gateway Sync: Live | **Missing** — no gateway integration → UI must show **Gateway Integration Not Configured** |
| KPI: Riders submitted / eligible | **Missing** — no settlement submission entity; eligible = active Rider role users |
| Expected cash | **Calculable** from Sales/Collections with Locked V1 rules (server recalculation required) |
| Declared cash | **Missing** as first-class declaration; proxying from transactions is incomplete vs spec |
| Physically received / vault batches | **Missing** |
| Unresolved variance | **Missing** (depends on physical − expected) |
| Session tabs (Awaiting / Variance / Reconciled / Locked) | **Missing** statuses |
| Settlement directory table | **Missing** — can *project* candidate rows from riders × date × shifts/sales, but status/received need new data |
| 3-way ledger (Expected / Declared / In Vault) | **Missing** vault + declaration layers |
| Rider shift annotation | **Partial** — `Sales.SignatureNote` / activity detail exist; no dedicated settlement annotation |
| Van stock & empty returns | **Partial** — `ShiftStocks`, `VehicleStocks`, `Sales.EmptyBottlesReturned`, customer bottle fields; no manager verified-return record |
| Manager decision (draft / approve / lock) | **Missing** |
| SOP threshold PKR 1,000 | **Not configured** in DB — must not hardcode |
| Export Audit PDF/XLS | **Missing** for settlements |
| Bulk Lock Days | **Missing** |

## 3. Roles (Locked V1 vs codebase)

| Spec role | Existing Identity role | Disposition |
|---|---|---|
| Rider | `Rider` | Reuse — submit field sales/collections/shift |
| Manager | **None** | Map manager settlement actions to existing **`Admin`** (do **not** invent Manager/Vault Cashier roles) |
| Owner | **None** | Owner policies → existing **`Admin`** until product expands roles |

Do not create custom RBAC or a Vault Cashier role.

## 4. Financial calculation sources (approved today)

Documented in `DASHBOARD_METRIC_CALCULATIONS.md` / `CommandDashboardService`:

- **Cash sales**: completed sale, `AmountReceived > 0`, covers due, `PaymentChannel == Cash`.
- **Full credit**: `AmountReceived == 0`.
- **Partial cash**: `0 < AmountReceived < SaleAmount + PreviousOutstanding`.
- **Cash collections**: `Collections.Channel == Cash`.
- Sales and collections stay separate; do not double-count.
- Order `EstimatedValue` is **never** collected revenue.

W07 Expected Cash must reuse these rules per rider/day, then subtract only what is already cash-received — not billed invoice totals alone.

## 5. Day-lock readiness (all **unimplemented**)

Spec conditions (submissions, reconciliations, vault, stock, sync queue, approvals) have **no** readiness endpoint today.  
`POST /api/shifts/end` is rider day-close only and must not be treated as manager day lock.

## 6. Implementation recommendation (post–Phase 1)

1. Project **candidate sessions** from `AspNetUsers` (Rider) + `Shifts`/`Sales`/`Collections` for a date.  
2. Add additive tables for declaration (if required), physical verification, settlement decision/status, day lock, audit codes.  
3. Admin APIs under `/api/settlements/...` (new) — no duplicate of field shift endpoints.  
4. Flutter admin nav key + screen; reuse KPI/table/drawer patterns from Dispatch/Rider Ops.  
5. Gateway widget: always honest “Not Configured” until a real integration exists.

## 7. Empty-state policy

With 0 settlement sessions for a date: **No settlement sessions found for this date.**  
Never pad with screenshot rows (Ahmed DAY-1042 / Bilal DAY-1043).
