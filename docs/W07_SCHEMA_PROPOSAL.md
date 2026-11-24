# W07 Additive Schema Proposal — Phase 2 (not migrated yet)

**Status:** Design only. No EF migration applied in Phase 2.  
**Rules:** Additive only; no drop; no recreate; no production seed.

## 1. Reuse first

| Need | Reuse |
|---|---|
| Rider, route, vehicle | `AspNetUsers`, `DeliveryRoutes`, `Vehicles` |
| Shift spine | `Shifts`, `ShiftStocks` |
| Cash facts | `Sales`, `Collections` |
| Stock sold / empties | `SaleLines`, `Sales.EmptyBottlesReturned` |
| Facility | `Depots` (single) |
| Generic audit | `AuditLogs` (supplement, not replace settlement timeline) |

## 2. Proposed new tables

### `SettlementSessions`

| Column | Type | Notes |
|---|---|---|
| Id | uniqueidentifier PK | |
| BusinessDate | date | |
| RiderId | nvarchar(450) | FK conceptually to AspNetUsers |
| ShiftId | uniqueidentifier NULL | FK Shifts |
| RouteId | uniqueidentifier NULL | denormalized for filter |
| Status | nvarchar(32) | NotStarted / AwaitingReview / VarianceDetected / Reconciled / Locked |
| RiderAnnotation | nvarchar(500) NULL | settlement-level note |
| DraftVerifiedCash | decimal(18,2) NULL | draft only |
| DraftResolutionCategory | nvarchar(64) NULL | |
| DraftRemarks | nvarchar(1000) NULL | |
| ResolutionCategory | nvarchar(64) NULL | set on approve |
| ResolutionRemarks | nvarchar(1000) NULL | |
| ApprovedByUserId | nvarchar(450) NULL | |
| ApprovedAtUtc | datetime2 NULL | |
| RowVersion | rowversion | concurrency |
| CreatedAtUtc / UpdatedAtUtc | datetime2 | |

Unique: `(BusinessDate, RiderId)`.

### `CashDeclarations`

| Column | Type | Notes |
|---|---|---|
| Id | PK | |
| SettlementSessionId | FK | |
| DeclaredAmount | decimal(18,2) | |
| Source | nvarchar(32) | RiderApp / AdminAssist |
| SubmittedAtUtc | datetime2 | |
| SubmittedByUserId | nvarchar(450) | |
| Note | nvarchar(500) NULL | |

### `PhysicalCashVerifications`

| Column | Type | Notes |
|---|---|---|
| Id | PK | |
| SettlementSessionId | FK | |
| VerifiedAmount | decimal(18,2) | |
| BatchReference | nvarchar(40) NULL | |
| VerifiedAtUtc | datetime2 | |
| VerifiedByUserId | nvarchar(450) | Admin |
| Notes | nvarchar(500) NULL | |

### `SettlementStockVerifications` (optional Phase 5)

Per product / empty-full kind: expected, declared, received, discrepancy, verifiedBy, atUtc.

### `DayLocks`

| Column | Type | Notes |
|---|---|---|
| Id | PK | |
| BusinessDate | date UNIQUE | |
| DepotId | uniqueidentifier NULL | Main warehouse |
| LockedAtUtc | datetime2 | |
| LockedByUserId | nvarchar(450) | |
| AcknowledgementNote | nvarchar(500) NULL | |

### `SettlementAuditEvents`

| Column | Type | Notes |
|---|---|---|
| Id | PK | |
| BusinessDate | date | |
| SettlementSessionId | uniqueidentifier NULL | |
| EventCode | nvarchar(64) | |
| Title | nvarchar(200) | |
| Detail | nvarchar(1000) NULL | |
| ActorUserId | nvarchar(450) NULL | |
| OccurredAtUtc | datetime2 | |
| RelatedEntityName / RelatedEntityId | nvarchar | |

Append-only at application layer (no update/delete APIs).

### `BusinessProfiles` additive column (optional)

| Column | Type | Notes |
|---|---|---|
| SettlementVarianceThreshold | decimal(18,2) NULL | SOP threshold; null = require remarks for any non-zero variance |

## 3. W09 schema note

No PriceList tables. Optional later: `ProductPriceAudits` only if base-price edit is approved. Phase 2/8 keep matrix read-only on `Products.UnitPrice`.

## 4. Migration plan (Phase 4+)

1. Add tables via EF migration.  
2. Apply to AquaRider without EnsureDeleted.  
3. Do not seed settlement rows.  
4. Backfill sessions on-read from shifts/sales when first opened (create row lazily) — document in API.
