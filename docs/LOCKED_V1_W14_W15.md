# Locked V1 — W14 Branches & Warehouses + W15 Sales Management

**Approved scope (2026-11-19)**

| Decision | Locked V1 |
|---|---|
| W14 | Single Main Warehouse console over `Depots` (no multi-hub) |
| W15 | Admin sales ledger; tabs All / Cash / Credit / Pending Sync only |
| Schema | Compute-first; migration only if required |
| V2 warehouse network | Blocked until separate approval |

## Excluded

- Add Branch / Add Hub / multi-depot CRUD
- Regional corridor map / fake GPS telemetry
- Loading bay assignment engine
- Inter-depot transfers
- Bank IBFT / Mobile Wallet tabs as payment products
- WhatsApp / thermal / PDF as shipped actions
- Custom RBAC / new Identity roles
- Fabricated KPIs

## Unavailable UI (honest)

Buttons that appear in design but are out of scope must open an unavailable/disabled state with a clear reason, not a fake success.
