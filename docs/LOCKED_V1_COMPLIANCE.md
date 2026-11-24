# Locked V1 Compliance — Rider Operations + Dispatch

## Allowed

- Rider Operations (Fleet Couriers) with SQL KPIs, directory, assignments, activity
- Dispatch & Order Management with real CustomerOrders
- Assign / reassign / cancel with server validation + audit
- Pick-list as projection of OrderLines
- Operational zone/shift summaries from routes/stops/orders

## Excluded (screenshot → not built)

| Feature | Disposition |
|---|---|
| Live Trackboard / LIVE RADAR / GPS / geofence / Knox telemetry | Rider Operations operational panels only |
| Spot Billing / Price Lists | Not in sidebar |
| Fabricated order KPIs (248/18/64) | Empty/zero until SQL has rows |
| Fake Call/Notify/Audit | Call only via `tel:` when phone exists |
| Live zone density map | Textual Operational Zone Summary |
| Unconfigured shift targets as fake % | Show Not Configured |

Nav: Admin Dashboard, Route Manifests, Inventory Audits, Setup Checklist, Fleet Couriers (Rider Ops), Dispatch & Orders, HQ Settings. No Live Trackboard destination.
