# Setup and installation

## SQL Server

Instance: `localhost\SQLEXPRESS` (SQL Server 2025 Express, Windows authentication for the Windows user that runs the API).

Connection string, in `Application.Api/appsettings.Development.json`:

```text
Server=localhost\SQLEXPRESS;Database=AquaRider;Trusted_Connection=True;TrustServerCertificate=True;
```

`appsettings.json` leaves the connection string and JWT key empty so they are not committed as production secrets. Design-time migrations use `ROUTELEDGER_CONNECTION` when it is set, otherwise the same SQLEXPRESS string.

Do not point this app at `RouteLedger_Db`.

## Backend

From `E:\AquaRider\backend`:

```text
dotnet restore
dotnet build RouteLedger.slnx
dotnet test RouteLedger.slnx
dotnet ef database update --project Application.Infrastructure --startup-project Application.Api
```

User secrets (project id `routeledger-aquarider-api`):

```text
dotnet user-secrets set "Jwt:Key" "<at least 32 random characters>" --project Application.Api
dotnet user-secrets set "Seed:AdminPassword" "<admin password>" --project Application.Api
```

Run so Development settings and user secrets load:

```text
dotnet run --project Application.Api --launch-profile http
```

That listens on `http://0.0.0.0:5266`. HTTPS redirection is off in Development so the Flutter HTTP client can call it. `--no-launch-profile` without `ASPNETCORE_ENVIRONMENT=Development` fails on purpose, because the connection string and JWT key are then empty.

On first Development start, if `AspNetUsers` is empty, the seeder inserts the depot, van, route, products, 28 customers and stops, opening ledger rows, and the rider. The admin is created only when `Seed:AdminPassword` is set.

## Flutter

From `E:\AquaRider\riderfrontend`:

```text
flutter pub get
flutter test test/rider_flow_test.dart
flutter run
```

Restart a running `flutter run` after asset or font changes. The Android emulator reaches the API at `http://10.0.2.2:5266`. A physical device needs `--dart-define=API_HOST=<this PC's LAN address>` and a firewall rule for TCP 5266.
