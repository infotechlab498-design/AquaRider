# RouteLedger database

Development connection (`ConnectionStrings:Default` in `appsettings.Development.json`):

`Server=localhost\SQLEXPRESS;Database=AquaRider;Trusted_Connection=True;TrustServerCertificate=True;`

The API applies pending EF Core migrations on startup (`Database.MigrateAsync`). It does not drop or recreate `AquaRider`. Schema changes are forward migrations only.

## Migration `20261118191051_AuthAndOnboarding`

Additive only. `Up` adds columns and creates two tables. It does not drop existing tables.

| Change | Object |
|---|---|
| `LastLoginAtUtc` `datetime2` null | `AspNetUsers` |
| `RememberMe` `bit` not null, default 0 | `RefreshTokens` |
| `DeviceInformation` `nvarchar(512)` null | `RefreshTokens` |
| New table | `BusinessProfiles` |
| New table | `OnboardingStepRecords` |

`BusinessProfiles`: `Id`, `LegalName` (200), `DisplayName` (200), `TaxNumber` (64, null), `RegistrationNumber` (64, null), `Status` (40), `CreatedAtUtc`.

`OnboardingStepRecords`: `Id`, `BusinessProfileId` (FK to `BusinessProfiles`, cascade delete), `StepCode` (40), `Status` (32), `CompletedAtUtc` null, `ValidationNotes` (500, null). Unique index on `(BusinessProfileId, StepCode)`. Step code and status are stored as strings.

Earlier migrations, unchanged:

- `20261117145528_InitialCreate`
- `20261117170048_OdometerPhotos`
- `20261117172815_EmptyBottlesOnSale`
- `20261117174104_SignatureImages`
- `20261117175602_CollectionWithholding`
- `20261117175930_OrderNotes`

## What onboarding reads

Step completion is not a flag the client sets. `OnboardingService` recomputes it from these tables and from Identity:

| Step | Source |
|---|---|
| PlantDetails | `Depots` with non-empty `Name` and `Address` |
| ItemsAndOpenings | `Products` where `ShowOnSale = 1` |
| Customers | `Customers` where `IsDeleted = 0` |
| Zones | `DeliveryRoutes` |
| RiderAndLoad | Active `AspNetUsers` in role Rider, and at least one `VehicleStocks` row |
| FirstSyncedSale | `Sales` with `Status = Completed` and `SyncStatus = Synced` |

`CompletedAtUtc` is written when that check first passes and cleared if a later check fails. `POST /api/onboarding/steps/{stepCode}/complete` also writes `AuditLogs` (`Action = OnboardingComplete`, `EntityName = OnboardingStep`). Login still writes `AuditLogs` with `Action = Login` and updates `AspNetUsers.LastLoginAtUtc`.

`RefreshTokens.TokenHash` remains the SHA-256 hex of the refresh token. The raw token is not stored. `PasswordResetRequests` records that a reset was asked for. The Identity reset token itself is not a column.

## Tests

`Application.Tests` points `ConnectionStrings:Default` at `AquaRider_Test_<id>` on the same SQL Express instance. Those test databases are created by `MigrateAsync` and removed with `EnsureDeleted` when the test host disposes. That cleanup does not run against `AquaRider`.
