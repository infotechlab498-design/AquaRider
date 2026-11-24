# Dispatch order details drawer — functional audit

Scope: right-side order panel on Dispatch & Order Management (`DispatchOrdersScreen` + `DispatchOrderPanel`). No seed data; live checks against AquaRider SQL + widget tests.

## Stale-data controls

| Guard | Behavior |
|---|---|
| `_detailGeneration` | Bumped on open/switch/close/reload; in-flight responses for a prior generation are ignored |
| Loading paint | While `_detailBusy`, drawer shows spinner and **does not** paint prior notes, phone, vehicle, items, events, or pick-list |
| List row identity | Reference / customer / rider from the selected directory row may show during load; hydrated fields wait for the matching detail response |
| After reassign / cancel | `_reload()` refreshes directory then `_loadDetail` for the open id |
| After prepare pick-list | Pick result is kept, then `_loadDetail` reloads lifecycle so events are not stale |

## Checklist

| Scenario | Result | Evidence |
|---|---|---|
| Open drawer from directory row | Pass | Widget: `order drawer opens and closes…` |
| Close drawer | Pass | Close clears open id + detail/items/events/pick |
| Switch between orders | Pass | Prior notes cleared during load; new notes after settle (`drawer drops prior notes…`) |
| Customer information | Pass | Customer block from detail/row; live detail returns customer phone for `ORD-OPEN-ALI` |
| Rider assignment display | Pass | Rider name · code · vehicle; after reassign shows new rider |
| Reassign confirm | Pass | Live API + SQL: `RiderId` → Infotech; lifecycle previous+new; audit `ReassignRider`; directory riderName refreshed |
| Manifest / order items | Pass | Empty list is honest (“No order lines were returned.”); no invented SKUs |
| Pick-list generation | Pass | With 0 lines → API 400; UI shows server error, never fake lines |
| Cancellation | Pass | Backend + MemoryRouteApi cancel path; closed status disables actions |
| Lifecycle history | Pass | `GET …/lifecycle` + drawer section; reassign appends `RiderReassigned` |
| Loading | Pass | Spinner while detail fetch in flight |
| Errors | Pass | Detail/items/events/pick failures surface messages; unreachable uses admin notice |
| Refresh after update | Pass | Reassign/cancel/pick-list trigger reload; generation guards prevent overwrite |

## Live reassignment proof (AquaRider)

- Order: `ORD-OPEN-ALI` (`b4e5d7e2-2f30-44f0-a611-6fe602662c54`)
- Before: `RiderId` = Ahmed Khan (`14c5f345-…`)
- After `POST /api/dispatch/orders/{id}/reassign-rider` → Infotech (`15ea95ac-…`)
- `OrderLifecycleEvents.Detail`: `Previous rider Ahmed Khan (14c5f345-…); new rider Infotech (15ea95ac-…).`
- `AuditLogs`: `ReassignRider` for that entity id
- Directory GET after change: `riderName=Infotech`

## Automated tests

- Backend: dispatch assign/reassign/cancel/pick-list suite — **passed**
- Flutter: `test/dispatch_orders_test.dart` — **8 passed** (open/close, switch stale guard, reassign UI)

## Known honest empty states

- `ORD-OPEN-ALI` has **0** `OrderLines` → pick-list prepare remains 400 until real lines exist
- No `Manifests` / `DeliveryAssignments` tables; do not invent them in the drawer
