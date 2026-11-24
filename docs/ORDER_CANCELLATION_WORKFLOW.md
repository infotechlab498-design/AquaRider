# Order cancellation workflow

`POST /api/dispatch/orders/{id}/cancel` with an optional body `{ "reason": "..." }`. Admin only. One transaction.

## Who can be cancelled

| Stored status | Result |
|---|---|
| `Scheduled` | Cancelled. Rider id is kept. |
| `InProgress` | Cancelled. Rider id is kept. |
| `Delivered` | 409 "A delivered order cannot be cancelled." |
| `Cancelled` | 409 "This order is already cancelled." |

A missing order is 404. A reason longer than 300 characters is 400 "Cancellation reason is too long." A blank reason is stored as null.

## What is written

- `Status` becomes `Cancelled` (directory `status` is `cancelled`).
- `CancelledAtUtc` is the UTC time of the action.
- `CancelledByUserId` is the signed-in admin.
- `CancellationReason` is the trimmed reason, or null.
- `RiderId` is not cleared.
- `Notes` is not rewritten. The customer note stays the customer note.
- `OrderLines` are not added or removed.
- Lifecycle code `Cancelled`, title "Order cancelled". `detail` is the reason, or "Cancelled by dispatch." when no reason was sent.
- Audit action `CancelOrder` on entity `CustomerOrder`.

The detail response returns the cancellation fields and the rider card for the rider who was still assigned.

Cancelling does not delete the order, reverse a sale, or change route stops. A delivered order has to stay delivered; this endpoint will not reopen it.
