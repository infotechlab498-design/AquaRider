# W16 / W17 Implementation (Locked V1)

## Backend

| Endpoint | Purpose |
|---|---|
| `GET /api/admin/collections/summary` | Daily/monthly KPIs + receivables + sync counts |
| `GET /api/admin/collections` | Paged ledger (`All` / `Cash` / `PendingSync`) |
| `GET /api/admin/collections/{id}` | Detail + settlement arithmetic |
| `POST /api/admin/collections` | HQ Cash settlement (rider + idempotency) |
| `GET /api/admin/receivables/exposure` | High exposure accounts |
| `GET /api/admin/reports/summary` | Analytics KPIs, series, fulfillment, leaderboard, assets |
| `GET /api/admin/reports/catalog` | Static CSV report templates |
| `GET /api/admin/reports/{key}` | Run report table |
| `GET /api/admin/reports/{key}/export.csv` | CSV download |

Services: `AdminCollectionsService`, `AdminReportsService`  
Tests: `Admin_collections_ledger_is_sql_backed`, `Admin_reports_hub_is_sql_backed`  
Migrations: **none**

## Flutter

- Screens: `collections_management_screen.dart`, `reports_analytics_screen.dart`
- Nav: Collections (Operations), Reports (Administration)
- Models + `route_api` / memory stubs

## Unavailable (honest)

Raast, Bank/Wallet/Cheque tabs, Knox, WhatsApp, thermal, PDF/XLSX, Schedule Auto-Export, Custom Report Builder, bulk WhatsApp.
