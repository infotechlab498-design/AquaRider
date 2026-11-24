# Dispatch & Order Management — implementation

Dispatch & Orders opens the dispatch directory. Counts, rows, lines, and the shift target come from `/api/dispatch/*`. The screen does not fill in the screenshot totals 248 / 18 / 64, and it does not draw a zone map.

## Navigation

- Sidebar label: **Dispatch & Orders** (`dispatchOrders`), under Operations
- Fleet Couriers still opens Rider Operations
- There is no Live Trackboard, Spot Billing, or Price Lists item

## Screen

`lib/adminDashboard/presentation/screens/dispatch_orders_screen.dart`

Widgets live in `lib/adminDashboard/presentation/widgets/dispatch/`.

- Breadcrumb: Field Operations › Dispatch & Orders
- Summary cards from `GET /api/dispatch/orders/summary`: Total, Pending dispatch, Assigned, In progress. A missing count is omitted. A failed call shows an error.
- Status tabs use `GET /api/dispatch/orders/status-counts`. A missing count is left off the label.
- Search, date, and Clear reload the directory. The date is sent as `from` and `to`.
- The orders table pages `GET /api/dispatch/orders`. An empty page says “No orders were returned.”
- Selecting rows shows how many are selected and the sum of `estimatedValue` on those rows only. Clear selection is the only bulk action. There is no bulk cancel endpoint.
- A row opens the order. Wide layouts use a right-hand panel at about 40% of the content width. Narrow layouts replace the directory with the detail.
- Detail calls `GET /api/dispatch/orders/{id}`, items, lifecycle, and pick-list.
- Cancel asks for a reason and posts `/cancel`.
- Reassign loads `GET /api/dispatch/eligible-riders` and posts `/reassign-rider`.
- Prepare pick-list posts `/prepare-picklist`. A 400 shows the server message and does not add lines.
- The bottom of the directory is an operational zone summary and shift progress from `GET /api/dispatch/operational-summary`. Text only. A shift with no target says “Not configured” and does not show a percent.

## API

| UI | Method | Path |
|---|---|---|
| Summary cards | GET | `/api/dispatch/orders/summary` |
| Status tabs | GET | `/api/dispatch/orders/status-counts` |
| Directory | GET | `/api/dispatch/orders` |
| Detail | GET | `/api/dispatch/orders/{id}` |
| Lines | GET | `/api/dispatch/orders/{id}/items` |
| Lifecycle | GET | `/api/dispatch/orders/{id}/lifecycle` |
| Pick-list | GET | `/api/dispatch/orders/{id}/picklist` |
| Prepare pick-list | POST | `/api/dispatch/orders/{id}/prepare-picklist` |
| Eligible riders | GET | `/api/dispatch/eligible-riders` |
| Assign | POST | `/api/dispatch/orders/{id}/assign-rider` |
| Reassign | POST | `/api/dispatch/orders/{id}/reassign-rider` |
| Cancel | POST | `/api/dispatch/orders/{id}/cancel` |
| Zone and shift | GET | `/api/dispatch/operational-summary` |

Query fields on the directory: `page`, `pageSize`, `search`, `status`, `from`, `to`, `riderId`, `unassignedOnly`. Status `all` is omitted. Other tab values are `pendingAssignment`, `assigned`, `inProgress`, `completed`, and `cancelled`.

`HttpRouteApi` throws `ApiException` when the envelope is not successful. The screen shows that message. `MemoryRouteApi` throws the same way unless a test passes a fixture.

## Screenshot replacements

| Screenshot | What the screen does |
|---|---|
| 248 / 18 / 64 | Cards and tabs from the summary and status-count payloads |
| Zone density map | Operational zone summary text |
| 62% shift ring | Shift progress, or “Not configured” when no target was returned |
| Sample manifest lines | Order lines and pick-list lines from the API only |
