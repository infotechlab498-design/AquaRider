# W07 Implementation Notes

## Delivered

- Additive migration `DayCloseAndBasePricing`: `SettlementSessions`, `CashDeclarations`, `PhysicalCashVerifications`, `DayLocks`, `SettlementAuditEvents`, optional `BusinessProfiles.SettlementVarianceThreshold`.
- Admin APIs under `/api/settlements/*` (summary, sessions, detail, draft, verify-cash, resolve, lock readiness, lock, bulk-lock, gateway status).
- Flutter `DayCloseScreen` + nav **Day Close & Recon**.
- Gateway chip always reports **Gateway Integration Not Configured** (no fake Live sync).
- Expected cash from Sales/Collections cash+partial rules; vault only from verification rows; no IBFT resolution categories.

## Not yet

- PDF/XLS export audit endpoint body
- Dedicated stock verification persistence beyond shift/sale projection
- Rider-app cash declaration submit UI (admin assist declaration on resolve)
