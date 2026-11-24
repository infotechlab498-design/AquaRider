# Pick list workflow

A pick list is a read of `OrderLines` plus the order and customer header. There is no manifest table and no generated placeholder lines.

`ShowOnManifest` on the order is unchanged by these endpoints. An order with zero lines still has no pick list, even when `EstimatedValue` or `ShowOnManifest` is set.

## Read

`GET /api/dispatch/orders/{id}/picklist`

When the order has at least one line, the body is:

| Field | Source |
|---|---|
| `orderId`, `referenceNumber`, `deliveryDate`, `window`, `orderStatus`, `estimatedValue`, `notes` | `CustomerOrders` |
| `customer` | Customer card (name, code, phone, address) |
| `lines` | Each `OrderLine` joined to `Products` |
| `linesTotal` | Sum of line subtotals |

Each line: `lineId`, `productId`, `productName`, `sku`, `quantity`, `unitLabel`, `unitPrice`, `subtotal` (`quantity * unitPrice`).

`linesTotal` can differ from `estimatedValue` if the header was stored without lines or the prices were captured separately. Both numbers are returned. Neither is rewritten to match the other.

When the order exists and has no lines, the response is 400 "This order has no lines to pick." `GET /api/dispatch/orders/{id}/items` is the empty-safe list: it returns 200 and `data: []` for the same order.

## Prepare

`POST /api/dispatch/orders/{id}/prepare-picklist`

The order must already have lines. The handler counts those lines, writes lifecycle code `PickListPrepared` (detail `Prepared {n} line(s).`), writes audit action `PreparePickList`, and returns the same pick-list shape as the GET.

It does not insert `OrderLines`, copy products, or fill quantities from `EstimatedValue`. Calling it again appends another `PickListPrepared` event and still does not add lines.

No lines: 400, and no lifecycle event is written. Unknown order: 404.

## How lines get onto an order

Only the existing create paths add lines, from the request:

- Rider `POST /api/orders`
- Admin `POST /api/dashboard/orders`

Both require at least one positive quantity and a real product. Both write lifecycle `OrderCreated` in the same save as the order. The actor is the signed-in user (the rider, or the admin).

An order inserted without lines, including older rows such as a scheduled order whose `OrderLines` count is 0, stays without lines until a create path that accepts lines is used. Prepare will not repair it.
