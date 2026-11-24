# W07 Financial Calculations — Phase 2 Mapping

All money uses `decimal` (SQL `decimal(18,2)`). Server recalculates; Flutter never supplies authoritative totals.  
Order `EstimatedValue` is **never** Expected Cash or collected revenue.

## 1. Scope filters

For business date `D` (server local calendar) and rider `R`:

| Source | Inclusion |
|---|---|
| `Sales` | `Status = Completed`, `RiderId = R`, local date of `CreatedAt` (or `SignedAt` when present) = `D` |
| `Collections` | `RiderId = R`, local date of `CreatedAt` = `D` |
| Excluded channels | BankTransfer, Wallet, Cheque — tracked as `excludedUnsupportedAmount`, not vault cash |

Reuse the same partition rules as `CommandDashboardService.CollectionsSummaryAsync` / `DASHBOARD_METRIC_CALCULATIONS.md`.

## 2. Per-sale classification

`due = SaleAmount + PreviousOutstanding`

| Condition | Class | Cash contribution |
|---|---|---|
| `AmountReceived = 0` | FullCredit | `0` toward Expected Cash |
| `0 < AmountReceived < due` | PartialCash | `AmountReceived` |
| `AmountReceived >= due` and `PaymentChannel = Cash` | Cash | `AmountReceived` |
| `AmountReceived >= due` and channel ≠ Cash | Excluded | `0` toward Expected Cash |

## 3. Per-collection classification

| Condition | Class | Cash contribution |
|---|---|---|
| `Amount < OutstandingBefore` | PartialCash | `Amount` |
| `Channel = Cash` and `Amount >= OutstandingBefore` | Cash | `Amount` |
| Other channel and `Amount >= OutstandingBefore` | Excluded | `0` |

Sales and collections are **never** merged into one row; sums are added after classification.

## 4. Expected Cash (rider / day / fleet)

```
ExpectedCash(R, D) =
    Σ Cash sale AmountReceived
  + Σ PartialCash sale AmountReceived
  + Σ Cash collection Amount
  + Σ PartialCash collection Amount
```

Full credit billed amounts are **not** Expected Cash (no physical cash due that day from those sales).  
Fleet Expected Cash = Σ over eligible riders (or over sessions present for `D`).

Previous-day comparison (KPI): only when previous local day has ≥1 contributing cash/partial transaction; else omit trend.

## 5. Declared Cash

**Authoritative:** `CashDeclaration.DeclaredAmount` for session `(R, D)` when the rider (or approved workflow) has submitted.

**Until a declaration row exists:**

- Session status stays non-submitted for “Riders Submitted” KPI.
- Do **not** silently copy Expected Cash into Declared.
- Optional read-only “system suggested total” may show Expected Cash for manager awareness, labeled as suggestion — not Declared.

Declaration must store: rider, business date, amount, source (`RiderApp` / `AdminAssist`), submittedAtUtc, optional note, link to `ShiftId` when present.

## 6. Physically Received (In Vault)

**Authoritative:** sum of `PhysicalCashVerification.VerifiedAmount` for the session (one or more batches).

Rules:

- Never auto-copy Declared → Vault.
- Manager “Cashier Verified Cash” on approve must match or create a verification record under Admin actor — not overwrite sales.
- BatchesCleared = count of verification rows for the date/session scope used by the KPI.

## 7. Variances (sign convention)

```
DeclarationVariance = DeclaredCash − ExpectedCash
PhysicalVariance    = PhysicallyReceived − DeclaredCash
NetVariance         = PhysicallyReceived − ExpectedCash
```

| Display | Rule |
|---|---|
| Zero net + required checks done | Reconciled |
| Non-zero unresolved | Variance Detected / flag |
| Positive NetVariance | Overage |
| Negative NetVariance | Shortage |

Do not add DeclarationVariance + PhysicalVariance into a third “total deficit” that double-counts; show the three figures separately. UI may show `NetVariance` as the headline deficit/overage.

Unresolved Variance KPI (fleet):

```
UnresolvedNet = Σ NetVariance over sessions where Status ∉ {Reconciled, Locked}
               and (NetVariance ≠ 0 or resolution incomplete)
FlagCount     = count of those sessions
```

## 8. Stock / returnable assets (not cash)

### Full bottles (returnable sellable SKU, e.g. 19L)

| Metric | Source |
|---|---|
| Loaded | `ShiftStocks.CountedQuantity` at shift start (or VehicleStock after start) |
| Sold | Σ `SaleLines.Quantity` for that product on rider/day |
| Returned (full) | Only if a stock movement exists — do not invent; else show “—” / 0 with honest label |
| Verified | Manager stock verification when implemented |

### Empty returns

| Metric | Source |
|---|---|
| Expected empties | Domain rule from sold returnable qty and/or customer holds — **document exact rule at implement time**; do not equate Sold full = Expected empty without product rules |
| Declared empties | Σ `Sales.EmptyBottlesReturned` for rider/day (and future declaration fields if added) |
| Received / verified | Physical stock verification when implemented |
| Discrepancy | Received − Expected (or Declared − Expected per card copy) |

```
NewHeldStock = PreviousHeld + Issued − Returned
```

Use customer/`VehicleStocks` facts; manager comments never adjust stock without a stock movement workflow.

## 9. KPI card formulas

| Card | Formula |
|---|---|
| Riders Submitted | `submitted / eligible`; eligible = active users in Rider role (or riders with route assignment policy); submitted = sessions with declaration (or approved submission event) for `D` |
| Expected Cash | Fleet Σ ExpectedCash |
| Declared Cash | Fleet Σ DeclaredCash; show `submitted/submitted` sync only from real declaration/sync flags |
| Physically Received | Fleet Σ VerifiedAmount; batches = verification count |
| Unresolved Variance | UnresolvedNet + FlagCount |

Empty date: all zeros / empty lists — never screenshot fillers.

## 10. Resolution categories (Locked V1)

Allowed themes (names finalized at implement time; **no IBFT/wallet/bank transfer as payment methods**):

- Cash shortage — rider accountable  
- Cash overage — recorded  
- Counting error — corrected via new verification  
- Timing / pending sync (failed sale recovery)  
- Stock discrepancy (non-cash) — separate from cash approve when needed  
- Other (remarks required)

Disallowed as cash settlement methods: IBFT, Raast, wallet, cheque “as received cash”.

## 11. Immutability

- Posted `Sales`, `SaleLines`, `Collections`, `LedgerEntries` are not updated by approve/lock.
- Adjustments = new verification / resolution / audit rows only.
