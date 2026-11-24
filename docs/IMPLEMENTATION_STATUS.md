# Implementation status

## Done

- [x] Flutter screens audited. Mapping is in `BACKEND_REQUIREMENTS_ANALYSIS.md`.
- [x] ASP.NET Core Web API on .NET 10 builds (`backend/RouteLedger.slnx`).
- [x] ASP.NET Core Identity, JWT access tokens, refresh rotation and revocation, Rider and Admin roles.
- [x] SQL Server database `AquaRider` on `localhost\SQLEXPRESS`. Migration `20261117145528_InitialCreate` applied.
- [x] Tables checked with `sqlcmd` after the Development host seeded them.
- [x] Field workflows: dashboard aggregates, stops with search and paging, customer read/create/update, sales with server prices, stock check, ledger, collections, future orders, shifts, history, settings, print queue.
- [x] Flutter login, home, queue, customer, sale, collection, receipt, order, ledger, history, map stops, settings, printer selection, and shift screens call the API.
- [x] Enterprise admin login (desktop/web ≥900px) under `lib/adminDashboard/` wired to real Identity login + secure token storage.
- [x] Auth deltas: remember-me refresh lifetime, `LastLoginAtUtc`, SSO status endpoint, Identity reset-password confirm endpoint.
- [x] W03 onboarding API + Flutter checklist (exactly six Locked V1 steps; progress from SQL).
- [x] Migration `20261118191051_AuthAndOnboarding` applied additively.
- [x] Admin Command Dashboard (`/api/dashboard/*`) + Flutter Business Overview with SQL-backed KPIs (no live map).
- [x] Rider Operations (`/api/rider-operations/*`) + Flutter Fleet Couriers screen (no GPS / Live Trackboard). Telemetry labels such as Live Tracking, History Playback, Knox, battery, speed, and GPS are dropped from the cards and the directory.
- [x] Flutter Dispatch & Orders (`dispatchOrders`) calls `/api/dispatch/*` for summary, status counts, paged orders, detail, reassign, cancel, pick-list, and a text operational summary. Missing or failed calls stay empty or show the server message. The screen does not invent 248/18/64 or draw a zone map. Sidebar has no Live Trackboard, Spot Billing, or Price Lists.
- [x] Flutter tests: 27 passed (`flutter test` in `riderfrontend`). `flutter analyze lib/adminDashboard lib/api/route_api.dart` reported no issues.
- [x] Backend integration tests: 18 passed.
- [x] Documents in `docs/` including login/onboarding/dashboard/rider-ops audits, APIs, metric calculations, Locked V1 compliance, test reports.
- [x] **Phase 1 — W07/W09 audit only** (no feature code): live SQL inventory, Flutter/admin nav gaps, backend reuse map. Docs: `W07_DATABASE_AUDIT.md`, `W07_WORKFLOW_AUDIT.md`, `W09_PRICING_AUDIT.md`, `EXISTING_ENTITY_MAPPING.md`, `SCREEN_TO_API_MAPPING.md`, `LOCKED_V1_SCOPE_COMPLIANCE.md`.
- [x] **Phase 2 — W07 financial/session mapping + wireframes** (no migration applied): `W07_FINANCIAL_CALCULATIONS.md`, `W07_DAY_LOCK_WORKFLOW.md`, `W07_SCHEMA_PROPOSAL.md`, `W07_W09_WIREFRAMES.md`.
- [x] **W07/W09 implementation (core):** migration `DayCloseAndBasePricing` applied; `/api/settlements/*` + `/api/products/*` pricing APIs; Flutter Day Close + Base Pricing screens wired; gateway Not Configured; base `UnitPrice` only.

## Not done, and why

- **W07 export audit PDF/XLS** — endpoint not implemented yet.
- **W07 rider-app declaration UI** — resolve can admin-assist declare; dedicated rider declaration screen not built.
- **W09 price edit + history table** — matrix is read-only; history API returns empty until an approved maintenance workflow exists.
- Multi-tier Price Lists remain excluded.

- No email or SMS password reset. The app only tells the rider to ask the fleet admin. The API records the request and does not pretend a message was sent.
- No Bluetooth printing and no PDF. Print queues a `PrintJob` row. Share, PDF, and WhatsApp on the receipt stay as labels.
- No map tiles. The route drawing is the existing painter. Stop names and the next stop come from the API.
- No admin UI in Flutter. User administration is the `/api/users` API.
- Language is stored as English (US). The language row does not switch locale.
- The Windows firewall was not opened. A physical Android phone cannot reach the PC until TCP 5266 is allowed and the app is started with `API_HOST` set to the PC's LAN address.
- Swagger UI has no Authorize button. Tokens are sent by the Flutter client and by the tests.
- Older AquaRider screens that are not on the RouteLedger navigation still use the on-device store.
- `System.Security.Cryptography.Pkcs` 9.0.11 vulnerability warnings come from the EF and Identity packages.
- Widget tests use an in-memory API so they stay green without SQL Server. Production `HttpRouteApi` is the SQL-backed client. The live login and dashboard call against `AquaRider` succeeded; the phone itself was not exercised.

`RouteLedger_Db` was not modified.
