# W07 Database Audit — Day Close & Cash Reconciliation

Inspected: AquaRider on `localhost\SQLEXPRESS` via `sqlcmd` (2026-11-18).  
Policy: **no seed**, **no drop**, **no destructive migration**.

## 1. Tables that do **not** exist

| Logical W07 concept | Table present? |
|---|---|
| DailySettlement / DayLock | **No** |
| RiderSettlementSession | **No** |
| CashDeclaration | **No** |
| PhysicalCashVerification / Vault batch | **No** |
| SettlementVariance / SettlementResolution | **No** |
| SettlementAuditEvent (dedicated) | **No** |
| Hub Vault Gateway sync log | **No** |
| Supervisor variance threshold config | **No** (not on `BusinessProfiles`) |

Do **not** invent screenshot amounts (245,800 / 14/18 / −5,800). Empty settlement dates must show honest empty states.

## 2. Existing tables that **can be reused**

| Table | Live rows | Relevance to W07 |
|---|---:|---|
| `Sales` | 11 | Cash expected/declared inputs: `SaleAmount`, `AmountReceived`, `PaymentChannel`, `EmptyBottlesReturned`, `RiderId`, `ShiftId`, `CreatedAt`, `Status`, `SyncStatus` |
| `SaleLines` | 13 | Product qty sold (stock sold side) |
| `Collections` | 1 | Separate cash collections (`Amount`, `Channel`, `RiderId`, `CreatedAt`) |
| `Shifts` | 1 | Per-rider service day (`ServiceDate`, `Status` Open/Closed, `StartedAt`/`EndedAt`, vehicle/route) — closest “session” spine |
| `ShiftStocks` | 3 | Opening stock count vs depot expected (`ExpectedQuantity`, `CountedQuantity`) |
| `VehicleStocks` | 4 | Van on-hand after shift start adjustments |
| `Products` | 4 | Returnable vs pack units for asset cards |
| `Customers` | 28 | Bottle hold (`BottlesHeld` / issued / returned) for empty-return expectations |
| `AspNetUsers` + roles | 3 users / 2 riders | Rider identity (`RiderCode`, `RouteId`, `VehicleId`, `IsActive`) |
| `DeliveryRoutes` / `Depots` | 1 / 1 | Route label + **single** Main Warehouse context |
| `AuditLogs` | 36 | Append-style admin/rider actions (`StartShift`, `EndShift`, sale/collection audits) |
| `ActivityLogs` | 13 | Rider-visible timeline (“Shift — Day started/closed”, sales) |
| `BusinessProfiles` | 1 | Legal/display name only — **no** variance threshold column |
| `LedgerEntries` | 7 | Posted customer ledger (immutable for W07 UI) |

## 3. Column notes (financial)

### `Sales` (decimal 18,2)

- `AmountReceived` = cash/credit received at sale completion (not order `EstimatedValue`).
- `PaymentChannel`: `Cash`, `BankTransfer`, `Wallet`, `Cheque` (enum). Locked V1 **cash-only** reconciliation must filter to Cash (+ approved credit/partial rules), not IBFT/wallet rows as vault cash.
- `EmptyBottlesReturned` = per-sale empty returns (not interchangeable with full bottles sold).

### `Collections`

- Separate from sales. `Channel` required. Live: 1 Cash / Pending / PKR 1,000.

### `Shifts` / `ShiftStocks`

- Shift end (`EndShift`) records odometer/photos and closes the shift — **does not** persist declared cash, vault cash, manager resolution, or day lock.
- `ShiftStocks` captured at **start** (expected vs counted). No dedicated end-of-day return verification table.

## 4. Live sample (do not treat as demo seed)

| Status | Channel | Sync | Count | SaleAmount | AmountReceived |
|---|---|---|---:|---:|---:|
| Completed | Cash | Synced | 5 | 6,880 | 9,380 |
| Completed | Cash | Failed | 1 | 1,500 | 1,500 |
| Completed | BankTransfer | Synced | 3 | 6,800 | 6,800 |
| Completed | Wallet | Synced | 2 | 4,500 | 4,500 |

Open shift: Infotech, `ServiceDate` 2026-11-17, Status `Open`.  
Eligible riders: **2**. Depots: **1** (`Warehouse Depot Hub 02` pattern).

## 5. Gaps that genuinely need schema (Phase 2+)

Only after documenting reuse, additive migrations may introduce (names illustrative):

1. **Settlement session** status + manager draft/approval fields keyed by rider + business date (+ optional `ShiftId`).
2. **Physical cash verification** amount, actor, timestamp, batch reference (never auto-copy from declared).
3. **Optional cash declaration** if rider-declared total must differ from sum of cash `AmountReceived` + cash collections.
4. **Day lock** per business date (+ readiness flags).
5. **Settlement audit events** *or* strict conventions on `AuditLogs` for W07 event codes (append-only at app layer).
6. **Variance threshold** on `BusinessProfiles` or settings — currently absent; SOP must not hardcode PKR 1,000 until configured.

## 6. What must **not** be created

- Parallel `Sales`/`Collections` mirrors  
- Multi-branch vault tables  
- IBFT / wallet settlement categories as Locked V1 resolution types  
- Seeded “14/18 riders submitted” rows  
