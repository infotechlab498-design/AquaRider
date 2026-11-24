# W03 Business Onboarding Checklist — Analysis

## Locked V1 authority

Screenshot geometry and visual hierarchy are the layout reference. **Locked V1 / Sentinel-04** is the functional authority:

- Exactly **six** onboarding steps (not the seven sample tasks in the marketing screenshot).
- Design tokens: Primary `#1565C0`, Secondary `#37474F`, Background `#F4F7FA`, Surface `#FFFFFF`, Primary Text `#17212B`, Secondary Text `#475569`, Border `#64748B`, Success `#2E7D32`, Warning `#8A4B00` / `#FFF4D6`, Error `#C62828` / `#FFF1F0`.
- Navigation excludes Live Trackboard, Spot Billing Ledger, multibranch, and unsupported modules.

## Existing domain mapping

| Locked V1 step | Existing SQL-backed source | Completion rule |
|---|---|---|
| 01 Plant Details | `Depots` | At least one depot with non-empty Name + Address |
| 02 Items & Openings | `Products` (+ optional `VehicleStocks`) | At least one sellable product (`ShowOnSale`) |
| 03 Customers | `Customers` (`IsDeleted = false`) | At least one active customer |
| 04 Zones | `DeliveryRoutes` | At least one route (sector/zone) |
| 05 Rider & Load | Identity users in role Rider + `VehicleStocks` | ≥1 active rider and ≥1 stock row |
| 06 First Synced Sale | `Sales` | ≥1 sale with `Status = Completed` and `SyncStatus = Synced` |

Progress = `CompletedSteps / 6 * 100` calculated on the server from those rules. UI never invents percentages.

## Missing before this work

- No onboarding entities, controllers, or Flutter admin shell.
- No business profile row for legal name / tax display (will add `BusinessProfiles`).
- Step completion audit timestamps (will add `OnboardingStepRecords` for verified completions + audit).

## Screen-to-API map

| UI region | API |
|---|---|
| Business context, welcome title | `GET /api/onboarding/overview` |
| Checklist cards + filters | `GET /api/onboarding/steps` |
| Pace card / % | overview / `GET /api/onboarding/progress` |
| Continue Setup | `GET /api/onboarding/next-step` |
| Validate / complete | `POST .../validate`, `POST .../complete` |
| Readiness banner | `GET /api/onboarding/readiness` |
| Facility / compliance / device cards | overview supporting DTOs |
| Activity | `GET /api/onboarding/activity` |

## Implementation decisions

1. Admin-only endpoints (`[Authorize(Roles = Admin)]`).
2. Single-facility Locked V1 scope: one primary depot summary (no multibranch UI).
3. Promo stats on the login left panel stay static marketing copy, not dashboard aggregates.
4. Support chat / scheduling show unavailable unless configured.
5. Skip-to-dashboard allowed only when readiness is true (or Admin explicitly acknowledged incomplete — readiness gate enforced server-side for operational flag).

## Navigation registry (Locked V1)

**Operations:** Admin Dashboard, Route Manifests, Inventory Audits  
**Administration:** Setup Checklist (active), Fleet Couriers, HQ Settings  

Excluded from screenshot: Live Trackboard, Spot Billing Ledger.
