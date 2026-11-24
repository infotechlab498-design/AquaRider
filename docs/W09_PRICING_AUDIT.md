# W09 Pricing Audit — Base Product Pricing (Locked V1)

## 1. Screenshot vs Locked V1

| Screenshot feature | Locked V1 disposition |
|---|---|
| Four price tiers (Retail / Wholesale / Subsidized / Corp) | **Excluded** — do not implement |
| Customer assignments to price lists | **Excluded** |
| Volume discounts / thresholds | **Excluded** |
| Zone-specific pricing | **Excluded** |
| Net-30 / institutional contracts | **Excluded** |
| Create Price List | **Excluded** |
| Pricing simulator with customer-specific rate match | **Replace** with Base Price Validation (base × qty) |
| Automatic Rider POS rate match claim | **Only if** true — today POS uses `Products.UnitPrice` at sale line write time |

Compliant screen title: **Products & Base Pricing**.

## 2. Existing pricing source

| Asset | Status |
|---|---|
| `Products` table | **Exists** — `Name`, `Sku`, `UnitPrice` (decimal), `UnitLabel`, `IsReturnable`, `ShowOnSale`, `ShowOnShift` |
| `ProductCategories` table | **Does not exist** |
| `PriceLists` / tiers / assignments | **Do not exist** — do not create |
| `ProductBasePrices` / `ProductPriceAudits` | **Do not exist** |
| Admin catalogue API | **Missing** — no `/api/products/*` controller |
| Field sale pricing | **Functional** — `FieldService` stamps `SaleLine.UnitPrice = product.UnitPrice` at create; receipt amounts stay on the line |

### Live catalogue (AquaRider)

| Name | SKU | UnitPrice | UnitLabel | Returnable | ShowOnSale | ShowOnShift |
|---|---|---:|---|---|---|---|
| 19L Water Bottle | 19L | 180.00 | unit | yes | yes | yes |
| 500ml Water Bottle Pack | 500ML | 250.00 | pack | no | yes | yes |
| 1.5L Water Bottle Pack | 1.5L | 320.00 | pack | no | yes | no |
| Empty 19L Bottle | EMPTY19 | 0.00 | unit | no | no | yes |

Base price = **`Products.UnitPrice`**. Empty bottle at 0.00 is a real stored value (shift/asset SKU), not a fabricated fallback.

## 3. Customer price lookup

- Customers: `Customers` (28 active-capable rows).  
- Locked V1: every customer uses the same approved base prices.  
- Existing: `GET /api/customers/{id}`, sale-context — **no** customer-specific rate matrix.  
- Compliant W09 lookup: show customer identity + “Approved base pricing applies” + product base prices from `Products`.

## 4. KPI replacements (screenshot → compliant)

| Screenshot KPI | Compliant KPI |
|---|---|
| Active Price Lists (4 Tiers) | **Active products** (count where usable / ShowOnSale or all non-deleted) |
| Items with Custom Pricing 42/48 | **Base price coverage** (products with valid approved `UnitPrice` per business rules) |
| Assigned Customers 320 | **Customer accounts** using base model (count `Customers` not deleted) |
| Unpriced / Fallback 3 SKUs | **Unpriced products** — only when rules say price missing/invalid; **never invent** fallback |

Coverage must be computed from SQL, not hardcoding 87.5%.

## 5. Category navigation (left column)

No category entity. Compliant options (reuse only real attributes):

1. Group by `UnitLabel` (unit / pack), and/or  
2. Flags: Sale catalogue (`ShowOnSale`), Shift/asset (`ShowOnShift`), Returnable empties (`IsReturnable` / EMPTY SKU).

Do **not** label groups as Retail / Wholesale / Zone / Corporate price lists.

## 6. Price maintenance & history

| Capability | Status |
|---|---|
| Approved admin base-price editor | **Not found** |
| Price change audit table | **Not found** |
| Historical sale immutability | **Present** — amounts live on `SaleLines.UnitPrice` / `Sales.SaleAmount`; changing `Products.UnitPrice` does not rewrite old sales |

**Phase 1 conclusion:** W09 matrix should ship **read-only** until an explicit approved maintenance workflow is designed. If editing is later allowed: additive audit table + reason + actor + apply only to future sales.

## 7. Gaps to implement (post–Phase 1)

1. Admin APIs: catalogue, coverage, unpriced, customer base-price lookup, export, optional price-history (empty until audit exists).  
2. Flutter screen + nav (not Price Lists).  
3. Validation panel: `UnitPrice × quantity` with `decimal` math.  
4. Immutable ledger banner (honest wording — no Spot Billing, no false POS sync claims).

## 8. Empty / honesty rules

- No products → “No approved base-priced products found.”  
- Do not hardcode 19L @ 180 in UI — read from API.  
- Do not create PriceList / CustomerPriceAssignment / VolumeDiscount / ZonePriceRule tables.
