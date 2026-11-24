# RouteLedger backend requirements

Audit of the Flutter app in `riderfrontend` and the existing `backend` folder. The live navigation is the RouteLedger field app. The older AquaRider phone-and-PIN screens are still in the repo and are not opened by `main.dart`.

## What already existed

- `backend/` was the ASP.NET Core 10 weather-forecast template. It had no database, Identity, or business endpoints.
- This machine has two running SQL Server Express instances. Windows authentication works for `DESKTOP-0Q9OHVL\786` on both.
- `localhost\SQLEXPRESS` already contains `RouteLedger_Db` (parties, documents, zones, refresh tokens, and other rows). That schema is not referenced anywhere in this repository. It is left unchanged.
- This application uses a new database, `AquaRider`, on `localhost\SQLEXPRESS`.

## Screen inventory

| Screen | Purpose | Inputs and actions | Backend need |
|---|---|---|---|
| Splash | Brand pause, then login | None | None |
| Login | Rider sign-in | Username, password, remember session, forgot password | `POST /api/auth/login`, `POST /api/auth/forgot-password` |
| Location access | Explain location use, then enter the shell | Allow location | None. The screen does not collect a coordinate |
| Home | Duty status, performance, next stop | Start day, history, route, queue, ledger | `GET /api/dashboard` |
| Start / end day | Opening stock and odometer, close the shift | 19L count, start or end | `GET /api/shifts/current`, `POST /api/shifts/start`, `POST /api/shifts/end` |
| Route queue | Today's stops | Search, All / Missed / Drafts / Orders | `GET /api/stops` |
| Route map | Schematic route and stop list | None beyond the list | `GET /api/stops`. No map-tile SDK exists in the app |
| Customer operations | One stop's customer | New sale, collection, order, ledger, call, map | `GET /api/customers/{id}` |
| New sale | Quantities and van stock | 19L quantity, save draft, continue | `GET /api/customers/{id}/sale-context`, `POST /api/sales` |
| Payment | Method and amount due | Cash, bank transfer, wallet, cheque | Sale draft already stored. Amount due is calculated on the server |
| Signature | Confirm the customer signed | Confirm | `POST /api/sales/{id}/complete` or `POST /api/collections` |
| Receipt | Show the posted document | Print, share, done | Receipt returned by the complete call. `POST /api/receipts/{id}/print` |
| Collection | Recover part of the balance | Amount, channel | `POST /api/collections` after signature |
| New order | Future order, stock not touched | Quantities, delivery window | `POST /api/orders` |
| Ledger | Balance and movements | Share statement | `GET /api/customers/{id}/ledger` |
| New / edit customer | Five-step customer form | Identity, address, bottles, opening balances | `POST /api/customers`, `PUT /api/customers/{id}` |
| History | Sync queue | Search | `GET /api/history` |
| Settings | Preferences, sign out | Toggles, paper size, customer form, printer | `GET/PUT /api/settings`, `POST /api/auth/logout` |
| Printer | Choose a thermal printer | Printer, paper, auto-print | `GET /api/printers`, `PUT /api/settings` |

The login route card ("Sector 4D Route Ready") is static branding. Operational screens use Satellite Town, Route 03, Sector 4B. The API follows the operational screens.

The home "Simulate Offline" control only changes the local status pill. It does not create server data.

Language, PDF download, and Bluetooth printing have no working client implementation. Printing records a server print job. Bluetooth delivery and PDF rendering are documented gaps. Call and map directions use `url_launcher`.

## Roles

| Role | Who | Access |
|---|---|---|
| Rider | Field operative signed in on the phone | Own route, own shifts, own sales, own settings |
| Admin | Fleet admin named by the forgot-password message | Create and manage users, reset passwords. No Flutter admin screen exists |

There is no self-registration screen, so `POST /api/auth/register` is not public. An admin creates riders with `POST /api/users`.

## Entities

- Identity user extended with full name, rider code, route, vehicle, depot, and active flag.
- Refresh token (hash only), password-reset request.
- Delivery route, vehicle, depot.
- Customer, including balance, bottle counts, route, and soft delete.
- Product and per-vehicle stock.
- Shift and counted stock lines.
- Route stop for a service date.
- Sale, sale line, collection, customer order, order line.
- Ledger entry.
- Activity / sync record.
- Rider settings, printer, print job.
- Number sequence for receipt, collection, order, and customer codes.

## Business rules taken from the screens

- Sign-in is username and password. The current client expects `ahmed.khan`. Empty fields are rejected on the phone. An unknown user and a wrong password return the same message.
- Forgot password does not collect an email address. The server stores a reset request and tells the rider to ask a fleet admin. No SMS or email provider is configured.
- A 19L bottle is PKR 180, a 500ml pack is PKR 250, and a 1.5L pack is PKR 320. Prices come from the product row, not from the phone.
- Amount due on a sale is today's sale plus the customer's current outstanding. The receipt flow pays that full amount. A smaller amount is accepted and leaves the remainder on the ledger.
- Completing a sale reduces van stock, posts the ledger, updates bottle counts, and marks the stop completed. The phone cannot choose the price or the resulting balance.
- A collection cannot exceed the outstanding balance.
- A future order does not change van stock.
- Empty bottles shown as "remaining" follow the sale screen: returned empties are capped at the number the customer holds and at the number of returnable bottles delivered.
- Starting a day records the odometer and counted stock. The existing sale button is reachable without starting the day, so a sale is still accepted and the shift is attached only when one is open.
- Customers are soft-deleted. Sales and ledger rows are not hard-deleted.
- Dashboard figures are aggregates of stored sales, collections, and stops for the rider's route on the service date.

## Screen-to-API map

| Screen | Functionality | Required API |
|---|---|---|
| Login | Authenticate | `POST /api/auth/login` |
| Login | Remember session | Phone stores the username only |
| Login | Forgot password | `POST /api/auth/forgot-password` |
| Home | Real statistics and next stop | `GET /api/dashboard` |
| Start / end day | Open or close a shift | `POST /api/shifts/start`, `POST /api/shifts/end` |
| Queue | List, search, filter stops | `GET /api/stops` |
| Map | Same stops | `GET /api/stops` |
| Customer | Customer detail | `GET /api/customers/{id}` |
| New sale | Price, stock, draft | `GET /api/customers/{id}/sale-context`, `POST /api/sales` |
| Payment and signature | Post the sale | `POST /api/sales/{id}/complete` |
| Receipt | Print intent | `POST /api/receipts/{id}/print` |
| Collection | Recover debt | `POST /api/collections` |
| New order | Schedule | `POST /api/orders` |
| Ledger | Statement | `GET /api/customers/{id}/ledger` |
| Customer form | Create or update | `POST /api/customers`, `PUT /api/customers/{id}` |
| History | Activity and sync counts | `GET /api/history` |
| Settings | Load and save preferences, sign out | `GET /api/settings`, `PUT /api/settings`, `POST /api/auth/logout` |
| Printer | Catalog and selection | `GET /api/printers`, `PUT /api/settings` |
| Session | Current rider, refresh, password | `GET /api/auth/me`, `POST /api/auth/refresh-token`, `POST /api/auth/change-password` |
| Admin | User directory and status | `GET /api/users`, `POST /api/users`, `GET /api/users/{id}`, `PUT /api/users/{id}`, `POST /api/users/{id}/status`, `POST /api/users/{id}/reset-password` |

## Validation

- Username and password required. Password at least 8 characters with a letter and a digit, so the existing rider password can be stored by Identity.
- Customer name, mobile, street, area, and city required. Customer codes are unique.
- Sale lines require a known product and a quantity above zero. Stock is checked again when the sale is completed.
- Collection amount is greater than zero and no higher than the outstanding balance.
- Order quantities cannot all be zero.
- Riders can read and change records on their own route only.

## Unclear items, and the choice made

- Two van identifiers appear in the design (LEA-8841 and PK-RAW-4482). Both are stored: plate and fleet code.
- The sample ledger lines on the design do not reconcile with the PKR 2,500 header. The database keeps a running balance and the screen shows that balance.
- No email service is configured. Password reset is an admin request, matching the snackbar already in the app.
- `RouteLedger_Db` was not reused because its tables and rows belong to a different schema and this repository does not reference them.
