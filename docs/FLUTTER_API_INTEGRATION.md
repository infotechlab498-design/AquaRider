# Flutter API integration

Package: `riderfrontend`. The UI layout, colors, and navigation are unchanged: Splash, Login, Location access, then the shell (Home, To-Do, Map, Profile).

## Client

- `lib/api/route_api.dart` — models, `RouteApi`, and `HttpRouteApi`.
- `lib/api/field_store.dart` — `FieldStore` and `FieldScope`, held above `MaterialApp` so pushed screens can see it.
- `lib/screens/session_nav.dart` — sign-out returns to login without an import cycle.

Base URL:

- Android emulator: `http://10.0.2.2:5266`
- Windows and desktop: `http://localhost:5266`
- Override the host with `--dart-define=API_HOST=192.168.x.x` for a physical phone. Do not use `localhost` from a physical device. The Windows firewall must allow inbound TCP 5266; it was not changed.

Widget tests use `test/memory_route_api.dart`. That client is not in the production graph.

## What each screen calls

| Screen | API |
|---|---|
| Login | POST /api/auth/login. Forgot password also POSTs /api/auth/forgot-password, then shows the existing fleet-admin message |
| Home | GET /api/dashboard |
| To-Do queue | GET /api/stops with search and filter |
| Customer operations | GET /api/customers/{id} |
| New sale and payment | GET sale-context, POST /api/sales, POST /api/sales/{id}/complete |
| Collection | POST /api/collections. The slider uses the customer's outstanding balance |
| Receipt | GET receipt data already returned by complete. Print queues POST /api/receipts/{id}/print |
| New order | POST /api/orders |
| Ledger | GET /api/customers/{id}/ledger |
| Customer form | POST or PUT /api/customers |
| History | GET /api/history |
| Map | Stop list and next stop from the dashboard and stops already loaded |
| Settings | GET/PUT /api/settings. Sign out calls logout |
| Printer | GET /api/printers, then PUT /api/settings |
| Start / end day | GET /api/shifts/current, POST start or end |

## Still local

- Share, PDF, and WhatsApp on the receipt. No PDF library and no share plugin call.
- Bluetooth radio. The server only queues a print job.
- Map tiles. The painted route graphic is unchanged; the stop names come from the API.
- Language stays English (US).
- "Simulate offline" is a local control.
- Older AquaRider screens that are not on this navigation still use the on-device store.
