# W09 Base Pricing Implementation

## Delivered

- Admin APIs: `/api/products/catalogue`, `/categories`, `/base-prices`, `/pricing/coverage`, `/pricing/unpriced`, `/pricing/validate`, `/{id}/base-price`, `/{id}/price-history` (empty history), `/api/customers/{id}/base-price-lookup`.
- Flutter **Products & Base Pricing** screen (not Price Lists).
- Base price = `Products.UnitPrice`; categories derived from catalogue flags/`UnitLabel`.
- Validation = `UnitPrice × quantity` (decimal); read-only; no order create.
- No PriceList / tier / customer discount tables.

## Locked V1 exclusions honored

Create Price List, wholesale/zone/corp tiers, Net-30, volume discounts, POS custom rate match claims.
