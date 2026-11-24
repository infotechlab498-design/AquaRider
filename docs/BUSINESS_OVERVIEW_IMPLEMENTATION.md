# Business Overview — implementation

Admin sign-in opens the command dashboard. The screen follows the screenshot’s hierarchy (header, six KPI slots, operational panel, attention, sales, collections, activity ledger) and reads only the admin dashboard API. A missing or failing endpoint shows an error and retry. It does not fill screenshot totals.

## Routing

`homeForSession` returns `AdminWorkspace` with `AdminNav.dashboard` for an Admin role. Riders still enter the field flow.

| Sidebar key | Screen |
|---|---|
| `adminDashboard` | Business Overview / Command Dashboard |
| `setupChecklist` | Six-step onboarding checklist |
| `fleetCouriers` | Rider Operations |
| `routeManifests`, `inventoryAudits`, `hqSettings` | Honest “not available on this server yet” page |

The shell is `AdminShell`: sidebar, top bar, scrollable body, and a system footer. The footer prints `Enterprise System Ver 0.1.0 · Build 1` from `AdminBuild` (pubspec `0.1.0+1`). Database latency is shown only when overview JSON includes `databaseLatencyMs`. There is no auto-refresh countdown. Refresh is a button.

## Screen

`lib/adminDashboard/presentation/screens/business_overview_screen.dart`

Widgets under `lib/adminDashboard/presentation/widgets/dashboard/`:

- `DashboardHeader` — greeting from the overview payload, otherwise a time-of-day greeting plus the signed-in first name. Business name comes from the overview. Range chips Today / Yesterday / 7D / 30D. Create Order opens a dialog that POSTs the admin order endpoint or shows validation / API errors.
- `DashboardKpiCard` — one card per figure the KPI payload actually contains.
- `OperationalSummaryCard` — counts and recent activity. No map.
- `AttentionItemsCard`
- `SalesSummaryChart` — column bars from returned buckets.
- `CollectionsSummaryCard` — Cash, Full credit, Partial cash only. Wallet, Raast, IBFT, and bank rows are dropped.
- `ActivityLedgerTable` — search, status (All / Synced / Pending / Failed), previous / next page.

Date query strings are `yyyy-MM-dd`. Today and Yesterday ask for `bucket=hour`. 7D and 30D ask for `bucket=day`.

## API

All calls go through `HttpRouteApi`, which unwraps `ApiResponse.data`. A non-success body, including HTTP 404, throws `ApiException`. The screen shows that message.

| UI | Method | Path |
|---|---|---|
| Header | GET | `/api/dashboard/overview?from=&to=` |
| KPIs | GET | `/api/dashboard/kpis?from=&to=` |
| Operational activity | GET | `/api/dashboard/operational-summary?from=&to=` |
| Attention | GET | `/api/dashboard/attention-items?from=&to=` |
| Sales bars | GET | `/api/dashboard/sales-summary?from=&to=&bucket=` |
| Collections | GET | `/api/dashboard/collections-summary?from=&to=` |
| Ledger | GET | `/api/dashboard/activity-ledger?from=&to=&search=&status=&page=&pageSize=` |
| Create order | POST | `/api/dashboard/orders` |

The rider `GET /api/dashboard` path is unchanged.

### KPI JSON

Either a `cards` / `kpis` / `items` list:

```json
{ "key": "billedSales", "label": "Total billed sales", "value": 1200, "format": "currency", "detail": "4 invoices" }
```

or named fields. A card is emitted only when its amount or count is present. Null and missing fields are omitted. They are not coerced to a screenshot total.

| Field | Label |
|---|---|
| `totalBilledSales` | Total billed sales |
| `collectionsReceived` | Collections received |
| `fleetActive` / `fleetTotal` | Fleet / couriers |
| `deliveriesDone` / `deliveriesTotal` | Deliveries |
| `pendingOrders` | Pending orders |
| `outstandingDues` | Outstanding dues |

Optional companions: `invoiceCount`, `salesDeltaPercent`, `collectionsRecoveredPercent`, `fleetNotStarted`, `deliveriesRemaining`, `unassignedOrders`, `outstandingAccounts`.

Cards whose label or key contains wallet, raast, ibft, radar, geofence, knox, playback, moving speed, device health, stationary, handset, live trackboard, or spot billing are dropped.

### Other payloads

Overview: `greeting`, `businessName` (or `business.displayName`), `facilityName`, `subtitle`, `onDutyRiders`, `databaseLatencyMs`.

Operational summary: `activeRoutes`, `ridersOnDuty`, `stopsCompleted`, `stopsRemaining`, `exceptions`, `recent[]`.

Attention: `items[]` with `title`, `detail`, `severity`, `count`, `actionLabel`. The action opens the returned detail. It does not send a notification.

Sales: `buckets[]` of `{ label, amount }`, optional `peakLabel` and `total`.

Collections: `cash`, `fullCredit`, `partialCash` as numbers or `{ amount, percent, count }`. A `channels` array is accepted and filtered to those three slots.

Ledger rows: `reference`, `customerName`, `riderName`, `transactionType`, `amount`, `occurredAt`, `syncStatus`. Paging reads the envelope `pagination` object (`page`, `pageSize`, `totalRecords`, `totalPages`).

Create order body:

```json
{
  "customerId": "",
  "riderId": "",
  "window": "Morning",
  "deliveryDate": "2026-11-18",
  "note": "",
  "showOnManifest": true,
  "lines": [{ "productId": "", "quantity": 1 }]
}
```

The dialog requires customer, rider, product, a quantity above zero, and a window (Morning / Afternoon / Evening) before it calls the API.

## Screenshot replacements

| Screenshot | What the screen does |
|---|---|
| Live map / moving markers | Operational activity card |
| PKR 185,000 and the other sample KPIs | Values from `/api/dashboard/kpis` only |
| Marcus Sterling, AquaPure, Rawalpindi switcher | Signed-in name and overview business / facility text |
| Handsets live, Knox, 48 agents | Omitted. On-duty count only if `onDutyRiders` is returned |
| Bank Raast / Digital Wallet | Not rendered |
| Auto-refresh 12s, fake server node | Omitted |
