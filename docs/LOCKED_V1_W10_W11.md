# Locked V1 — W10 Zones & Routes + W11 Customers & Parties

Companion to `W10_W11_PHASE1_PHASE2_AUDIT.md`.

## Allowed (when implementation is authorized)

- Admin **route directory** backed by `DeliveryRoutes` (+ Sector/City as zone labels)
- Assign rider to route via `AspNetUsers.RouteId`
- Day stop sequence from `RouteStops` (honest empty/zero if none)
- Admin **customer directory** from `Customers` with real filters/KPIs
- Customer edit / deactivate / change route; ledger from existing APIs
- Bottle balances and outstanding from existing columns
- Optional **static** map pin when lat/long exists (reuse `flutter_map`)

## Excluded (screenshot → do not build)

| Feature | Disposition |
|---|---|
| Live Geospatial Manifest / courier speed / geofence | Omit |
| Fabricated 8 zones / 24 routes / 486 stores | Show SQL counts only |
| Unassigned store pool | Only if schema change approved; today RouteId required |
| Multi-branch hub switcher | Single depot |
| Price Lists / Trackboard / custom Roles UI | Keep Locked V1 nav |
| Credit limit / utilization meters | No columns; omit unless approved |
| LIVE SYNC as product claim | Omit badge |

## Nav (target after implementation)

Business Management: **Customers & Parties**, **Zones & Routes** (plus existing Base Pricing).  
No Price Lists, no Live Trackboard.
