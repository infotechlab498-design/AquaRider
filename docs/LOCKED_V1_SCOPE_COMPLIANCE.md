# Locked V1 Scope Compliance

Applies to Business Overview, Rider Operations, Dispatch, and the **planned** W07 / W09 modules.

## Allowed

- Admin Command Dashboard with SQL-backed KPIs  
- Operational activity overview (non-map)  
- Attention items from failed sync / unstarted shifts / pending orders  
- Sales and collections summaries with approved collection semantics  
- Activity / transaction ledger from Sales, Collections, ActivityLogs  
- Rider Operations directory, assignments, activity  
- Dispatch order directory, assignment/reassignment, cancel, pick-list from `OrderLines`  
- Shared shell with Locked V1 navigation registry  
- Cash / Full credit / Partial cash reporting categories  
- **W07:** Day close using real Sales/Collections/Shifts/stock + additive settlement/vault/lock when implemented  
- **W09:** Products & Base Pricing from `Products.UnitPrice` for all customers  

## Roles

| Spec wording | Implementation |
|---|---|
| Rider | Identity role `Rider` |
| Manager / Owner | Identity role `Admin` (no new Manager/Owner/Vault Cashier roles) |

## Excluded (screenshot present → not implemented)

| Screenshot feature | Locked V1 disposition |
|---|---|
| Live Trackboard / LIVE RADAR | Not a nav destination; Rider Operations is the approved equivalent |
| Continuous GPS / moving markers | Not implemented |
| Geofencing / route playback | Not implemented |
| Spot Billing Ledger | Not in sidebar |
| Bank Raast / IBFT / Digital Wallet as approved collection/recon types | Not displayed; W07 resolution must not introduce IBFT/wallet categories |
| Multibranch depot switcher | Single-facility / Main Warehouse only |
| Knox / SSL telemetry badges as live claims | Not claimed; connectivity = API reachability only |
| Fabricated fleet/order KPIs | Show actual counts or empty |
| Hub Vault Gateway “Live” without integration | Show **Gateway Integration Not Configured** |
| Multi-tier Price Lists (Retail/Wholesale/Zone/Corp) | **Excluded** — W09 is base pricing only |
| Customer-specific / volume / Net-30 pricing | **Excluded** |
| Create Price List | **Excluded** |
| Price Lists sidebar destination | Use **Products & Base Pricing** (or unavailable until built) |
| DeliveryAssignments / Manifests tables | Not created; dispatch uses `CustomerOrders.RiderId` + `OrderLines` |

## W07 conflict log (screenshot → compliant)

1. **Vault Sync Live** → Not Configured until a real gateway exists.  
2. **IBFT / WhatsApp bank note as resolution category** → cash-only / approved variance categories only; rider notes may be displayed as text without creating a non-cash payment method.  
3. **Declared = vault auto-fill** → forbidden; physical verification is a separate persisted amount.  
4. **SOP threshold PKR 1,000** → read from configuration when present; do not hardcode.  
5. **Bulk Lock / Approve** → Admin-only; transactional; no silent success.  
6. **Estimated order value** → never Expected Cash.

## W09 conflict log (screenshot → compliant)

1. **Price Lists & Customer Pricing** title → **Products & Base Pricing**.  
2. **Four tier cards** → category/catalogue groups from real product attributes.  
3. **Custom pricing coverage KPIs** → active products, base-price coverage, customer accounts, unpriced SKUs.  
4. **Pricing simulator / POS rate match** → Base Price Validation (`UnitPrice × qty`); no customer-specific rate.  
5. **Matrix Difference / Gross Margin / Cost** → omit unless cost data exists (it does not).  
6. **Immutable ledger banner** → required; historical `SaleLines` unchanged when base price changes later.

## Prior conflict log (dashboard / rider ops)

1. **Live map → Operational overview panels** documented in BUSINESS_OVERVIEW_IMPLEMENTATION.md and RIDER_OPERATIONS_IMPLEMENTATION.md.  
2. **Collections by channel UI → approved three categories** (Cash, Full credit, Partial cash).  
3. **Create Order** posts `/api/dashboard/orders` after required fields validate.  
4. **Admin home** is the command dashboard. Setup Checklist stays on the sidebar. See LOCKED_V1_COMPLIANCE.md.
