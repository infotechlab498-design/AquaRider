# Existing Entity Mapping — W07 Day Close + W09 Base Pricing

Cross-module map of **logical** screen concepts → **physical** RouteLedger entities.  
Related: `ENTITY_MAPPING_DISPATCH.md`, `DATABASE_ENTITY_MAPPING.md`, `W07_DATABASE_AUDIT.md`, `W09_PRICING_AUDIT.md`.

## Identity & facility

| Concept | Entity / table | Notes |
|---|---|---|
| Rider | `AspNetUsers` + role `Rider` | `RiderCode`, `RouteId`, `VehicleId`, `IsActive` |
| Manager / Owner (spec) | Role `Admin` | No separate Manager/Owner/Vault Cashier roles |
| Main Warehouse | `Depots` (single) | Do not build multibranch switcher |
| Business | `BusinessProfiles` | Display/legal name; no variance threshold column |

## W07 — Day close & cash

| Logical concept | Physical mapping | Exists? |
|---|---|---|
| Settlement session spine | `Shifts` (rider + `ServiceDate`) + activity for the day | Partial |
| Expected cash | Sum of approved cash components from `Sales` + `Collections` | Calculable |
| Declared cash | Dedicated declaration row | **No** |
| Physically received / vault | Physical verification entity | **No** |
| Variance / resolution | Settlement decision entity | **No** |
| Day lock | DayLock entity | **No** |
| Stock loaded / counted | `ShiftStocks`, `VehicleStocks` | Yes (opening-centric) |
| Sold qty | `SaleLines` | Yes |
| Empty returns | `Sales.EmptyBottlesReturned`, `Customers` bottle fields | Yes |
| Verified stock returns | Manager verification entity | **No** |
| Audit trail | `AuditLogs` + `ActivityLogs` (+ future settlement event codes) | Partial |
| Hub Vault Gateway | Integration + sync log | **No** → Not Configured |
| DeliveryAssignments / Manifests | Not used for cash close | N/A (see dispatch docs) |

## W09 — Base pricing

| Logical concept | Physical mapping | Exists? |
|---|---|---|
| Product catalogue | `Products` | Yes |
| Base system price | `Products.UnitPrice` | Yes |
| Effective base price (V1) | Same `UnitPrice` | Yes |
| Product category | No table — derive from flags/`UnitLabel` | Partial |
| Price list / tier | — | **Must not create** |
| Customer price assignment | — | **Must not create** |
| Price change history | — | **No** (read-only matrix until approved) |
| Customer lookup | `Customers` | Yes |
| Posted sale price | `SaleLines.UnitPrice` (immutable history) | Yes |

## Sales & collections (shared financial truth)

| Concept | Table | Rule |
|---|---|---|
| Invoice / sale | `Sales` | Completed only for revenue views |
| Line price snapshot | `SaleLines` | Written from `Products.UnitPrice` at sale time |
| Collection | `Collections` | Separate from sales |
| Customer ledger | `LedgerEntries` | Do not rewrite from W07/W09 |
| Order estimate | `CustomerOrders.EstimatedValue` | **Never** collected cash |

## Do not duplicate

`Riders`, `DeliveryAssignments`, `Manifests`, `PriceLists`, `VaultCashiers`, GPS telemetry, Spot Billing ledgers.
