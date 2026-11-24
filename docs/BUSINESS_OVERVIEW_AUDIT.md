# Business Overview / Command Dashboard — Audit

## Existing assets to reuse

| Asset | Location | Notes |
|---|---|---|
| Admin shell pieces | `lib/adminDashboard/presentation/widgets/admin_sidebar.dart`, `admin_topbar.dart` | Extract shared nav; currently Setup Checklist is hard-active |
| Tokens | `lib/adminDashboard/theme/admin_tokens.dart` | Locked V1 colors already match |
| Auth session | `HttpRouteApi` / `AuthSession` | FullName, role, depot |
| Rider field dashboard | `GET /api/dashboard` via `FieldService.DashboardAsync` | Rider-scoped only; not admin command KPIs |
| Sales / collections / stops / orders | Domain + FieldService | Source tables for admin aggregations |
| ActivityLogs | SQL + `GET /api/history` | Rider history; admin needs period ledger |
| BusinessProfile | Onboarding | Display business name |

## Gaps

- No admin command-dashboard Flutter screen.
- No `/api/dashboard/overview` (or equivalent) admin aggregation API.
- Sidebar Admin Dashboard is a stub (`onUnavailable`).
- Screenshot “live map” is excluded by Locked V1 → replace with Operational Activity Overview.
- Screenshot collection channels (Raast/wallet) excluded → Cash / Full credit / Partial cash only.

## Calculation sources (planned)

| KPI | Source |
|---|---|
| Total billed sales | `Sales` where `Status=Completed` in range, sum `SaleAmount`, count invoices |
| Collections received | `Collections` in range, sum `Amount` |
| Fleet / couriers | Identity role `Rider`; “on duty” = open `Shifts` for service date |
| Deliveries | `RouteStops` for service date(s): Completed vs total |
| Pending orders | `CustomerOrders` where `Status=Scheduled` |
| Outstanding dues | Sum `Customers.Outstanding` where `IsDeleted=0` |

## Screenshot → Locked V1 replacements

| Screenshot element | Decision |
|---|---|
| Live Field Operations Trackboard / map | Operational Activity Overview (counts + recent activity) |
| Create Order | Real admin order create against `CustomerOrders` when customer+rider supplied; otherwise clear unavailable |
| Bank/wallet collection mix | Not shown; approved categories only |
| Hardcoded “Marcus Sterling” / AquaPure | Authenticated user + `BusinessProfiles.DisplayName` |
