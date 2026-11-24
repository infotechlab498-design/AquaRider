# Test Report — Rider Operations + Dispatch & Orders

Executed 2026-11-18 after implementation.

## Backend

```text
dotnet test
```

**22 passed**, 0 failed.

Includes assign / reassign / cancel, pick-list 400 without lines, rider 403 on `/api/dispatch`, empty date windows.

Migration applied additively: `20261118203822_DispatchOrderLifecycle` (`OrderLifecycleEvents` + cancellation columns). Database not dropped.

## Flutter

```text
flutter analyze lib/adminDashboard lib/api/route_api.dart
flutter test
```

Analyze: **No issues found.**  
Tests: **27 passed**, 0 failed.

## Live SQL smoke (Admin JWT → AquaRider)

- `GET /api/dispatch/orders/summary` → total=1, pending=0, assigned=1 (matches one Scheduled order with rider).
- List returns `ORD-OPEN-ALI`, `lineCount=0`.
- Pick-list → **400** (`This order has no lines to pick.`) — no fake lines invented.
- **Reassign live:** `ORD-OPEN-ALI` Ahmed → Infotech persisted on `CustomerOrders.RiderId`; lifecycle Detail includes previous + new rider; `AuditLogs.ReassignRider`; directory riderName refreshed.
- Rider ops summary → 2 registered / 2 available.
- Location verifications → empty with honest message (no GPS fabrications).

## Drawer / reassignment follow-up

- Flutter `dispatch_orders_test.dart`: **8 passed** (open/close, switch stale-guard, reassign UI).
- Backend dispatch filter suite: **4 passed**.
- Docs: `ENTITY_MAPPING_DISPATCH.md`, `DISPATCH_DRAWER_AUDIT.md`.

## Known honest empties

- Existing order has **zero** order lines → pick-list unavailable until lines exist.
- Shift target remains `targetConfigured: false`.
- No `Manifests` / `DeliveryAssignments` tables — assignment is `CustomerOrders.RiderId`; items are `OrderLines`.
