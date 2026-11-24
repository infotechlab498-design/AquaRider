# API documentation

Base URL in development: `http://localhost:5266` (all interfaces). Android emulator: `http://10.0.2.2:5266`.

Every JSON body uses this envelope:

```json
{
  "success": true,
  "message": "Record retrieved successfully",
  "data": {},
  "errors": null
}
```

List endpoints that page also include:

```json
"pagination": { "page": 1, "pageSize": 20, "totalRecords": 28, "totalPages": 2 }
```

Status codes: 200 success, 201 created, 400 validation, 401 missing or invalid token, 403 wrong role or no assigned route, 404 missing row, 409 conflict (duplicate customer code, or not enough van stock, or a collection larger than the balance), 500 unexpected failure. Internal exceptions, SQL, passwords, and tokens are not returned.

OpenAPI is at `GET /openapi/v1.json`. Swagger UI reads that document. It does not have an Authorize button; send `Authorization: Bearer {accessToken}` yourself.

## Authentication

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | /api/auth/login | Anonymous | Username and password. Returns access token, refresh token, and the user |
| POST | /api/auth/refresh-token | Anonymous | Rotates the refresh token. Reuse of a revoked token revokes every active token for that user |
| POST | /api/auth/logout | Bearer | Revokes the presented refresh token |
| POST | /api/auth/forgot-password | Anonymous | Records a request. Always returns the same message. No email or SMS |
| GET | /api/auth/me | Bearer | Current user |
| POST | /api/auth/change-password | Bearer | Current password plus the new password |

There is no public registration endpoint. The login screen has no sign-up flow.

Login body: `{ "username": "ahmed.khan", "password": "routeledger1" }`.

## Users (Admin only)

| Method | Path | Purpose |
|---|---|---|
| GET | /api/users | Directory |
| GET | /api/users/{id} | One user |
| POST | /api/users | Create a rider or admin |
| PUT | /api/users/{id} | Update name, route, vehicle, depot |
| POST | /api/users/{id}/status | Activate or deactivate |
| POST | /api/users/{id}/reset-password | Set a new password |

The Flutter app has no admin screens. These endpoints are for fleet administration through the API.

## Field (Rider or Admin who has a route)

| Method | Path | Purpose |
|---|---|---|
| GET | /api/dashboard | Today's billed sales, cash collected, stop counts, next stop name, coordinates, and greeting |
| GET | /api/stops | Today's stops. Query: search, filter (`all`, `missed`, `drafts`, `orders`), page, pageSize (1–100, default 20) |
| GET | /api/customers/{id} | Customer detail |
| POST | /api/customers | Create a customer on the rider's route |
| PUT | /api/customers/{id} | Update permitted fields |
| POST | /api/customers/{id}/visit | Log a visit without a sale. Body `{ "outcome": "NoNeed" }` or `"NoResponse"`. NoResponse marks today's stop Missed. |
| GET | /api/customers/{id}/sale-context | Products, prices, van stock |
| GET | /api/customers/{id}/ledger | Outstanding, credit cycle, today's collections, open orders, today's stop sequence, ledger rows (`kind`, `reference`, `detail`), and recent bottle movements from completed sales |
| POST | /api/sales | Create a draft. Client prices are ignored. Optional `emptyBottlesReturned` is stored and applied when the sale is completed. |
| POST | /api/sales/{id}/complete | Take payment. `amountReceived` defaults to the full due. `closeStop` defaults to true and marks the route stop completed. Optional `signatureImage` is a PNG, stored with the signer name, role, and customer. |
| GET | /api/sales/{id}/receipt | Receipt. Includes the customer address, phone, depot, empty-bottle counts, and signature note. |
| GET | /verify/{receiptNumber} | Public page for the QR code. No login. Shows that receipt only. |
| POST | /api/receipts/{id}/print | Queue a print job. Does not talk to Bluetooth |
| POST | /api/collections | Collect part or all of the outstanding balance. Optional `withholdingTax` is stored separately and also reduces the balance. Optional `note` is the rider's reference. |
| POST | /api/orders | Schedule a future order. Van stock is unchanged. Optional `deliveryDate`, `note`, and `showOnManifest`. |
| GET | /api/shifts/current | Open shift, or the depot expectation when none is open |
| POST | /api/shifts/start | Counted stock, the odometer digits read from a photo, and that photo as base64 JPEG or PNG (`odometerPhoto`). Optional `inspectionPhoto`. |
| POST | /api/shifts/end | Closing odometer digits read from a photo, and that photo as base64 JPEG or PNG. |
| GET | /api/history | One local day's original work for the signed-in rider only (`RiderId` / `UserId`). Query: `search`, `date` (`yyyy-MM-dd`, default today). Rows come from that rider's completed sales, collections, orders, visits, and shift start/end. Counts are synced, pending, and failed for the day before search. The payload also returns `riderUserId`, `riderName`, and `riderCode`. |
| GET | /api/settings | Rider settings and selected printer |
| PUT | /api/settings | Save toggles, paper size, printer |
| GET | /api/printers | Printer catalog |
| GET | /api/health | Anonymous. Reports whether SQL Server accepts a connection |

Prices used by the server: 19L bottle 180, 500ml pack 250, 1.5L pack 320. A sale's amount due is the sale total plus the customer's current outstanding. Received cash must be between 0 and that due amount. A collection cannot exceed the outstanding balance.

Returnable 19L bottles: empties returned on a sale are `min(held, quantity)`; issued increases by the quantity sold; held decreases by the empties returned.
