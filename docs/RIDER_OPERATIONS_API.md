# Rider operations API

Admin fleet screen. Route prefix: `api/rider-operations`. Role: **Admin**. Riders receive 403.

There is no live GPS, geofence, speed, or device telemetry. Location verification is not stored.

## Date

`date` is `yyyy-MM-dd`. Omitted means the server's local today (`DateOnly.FromDateTime(DateTime.Today)`). Stop progress uses `RouteStops.ServiceDate`. Sales, collections, and failed-sync checks use that local day's UTC window, the same conversion as the command dashboard.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/rider-operations/summary?date=` | Registered, available, on-duty, in-progress stops, attention |
| GET | `/api/rider-operations/riders?search=&status=&date=` | Directory |
| GET | `/api/rider-operations/riders/{id}?date=` | One rider card |
| GET | `/api/rider-operations/riders/{id}/activity` | Latest 100 activity rows for that rider |
| GET | `/api/rider-operations/riders/{id}/assignments?date=` | Route stops for the rider's route on that service date |
| GET | `/api/rider-operations/exceptions?date=` | Real rider exceptions |
| GET | `/api/rider-operations/location-verifications` | Empty list |

Unknown id, or a user who is not in the Rider role, is 404 "Rider not found."

## Status

A rider is in exactly one status. The directory filter uses the same tokens: `all`, `available`, `onDuty`, `attention`, `inactive`.

| Status | Rule |
|---|---|
| `inactive` | `IsActive` is false. This wins over an open shift. |
| `available` | Active, and no shift with `Status = Open` on the requested `ServiceDate`. |
| `onDuty` | Active, with an open shift that day, and not in attention. |
| `attention` | On duty, and any of the following is true. |

Attention while on duty:

1. A sale that day (`CreatedAt` in the local day) has `SyncStatus = Failed`.
2. An activity log that day has `SyncStatus = Failed`.
3. The open shift started at least **2 hours** ago (`RiderOperationsService.OpenShiftIdleThreshold`), the route has at least one stop that day, and none of those stops are `Completed`.

A failed sale or failed activity does not by itself change an active rider with no open shift. That rider stays `available`. The failed row still appears under exceptions and on the command dashboard.

Inactive is the account's current flag. The API does not store whether the rider was inactive on a past date.

## Summary

| Field | Meaning |
|---|---|
| `ridersRegistered` | Users in the Rider role, including inactive |
| `availableForAssignment` | Status `available` |
| `activeAssignments` | Status `onDuty` or `attention` (an open shift that day) |
| `deliveriesInProgress` | `RouteStops` on that `ServiceDate` with status `InProgress`, across routes |
| `requiringAttention` | Status `attention` or `inactive` |

`activeAssignments` counts riders with an open shift. The `onDuty` filter does not include `attention` riders, because those are a separate directory bucket.

## Rider card

`id`, `fullName`, `riderCode`, `vehicleName`, `plate`, `routeName`, `status`, `stopsCompleted`, `stopsTotal`, `billedSalesToday`, `cashCollectedToday`, `lastActivityAt`, `lastActivityTitle`.

`billedSalesToday` and `cashCollectedToday` are for the requested date, not only the calendar today. The property names match the card contract.

- Stops: `RouteStops` for the rider's `RouteId` and `ServiceDate`. No route means 0 and 0.
- Billed: sum of `SaleAmount` for completed sales by that rider in the day.
- Cash: sum of `AmountReceived` on completed sales with `PaymentChannel = Cash`, plus `Collections.Amount` with `Channel = Cash`, for that rider and day.
- Last activity: the latest `ActivityLogs` row for the user, any date. Null when none exist.

`search` matches full name, rider code, vehicle name, plate, or route name. An invalid `status` is 400.

## Assignments

Stops for the rider's route on the service date, ordered by sequence: `stopId`, `sequence`, `customerId`, `customerName`, `customerCode`, `status`, `scheduledTime`, `distanceMeters`.

No route returns an empty list and says the rider has no route. A route with no stops that day returns an empty list. Coordinates are not added.

## Activity

Up to 100 newest `ActivityLogs` for the rider: `id`, `title`, `reference`, `amount`, `syncStatus`, `detail`, `occurredAtUtc`.

## Exceptions

Only stored conditions:

- Inactive rider (`rider-inactive:{id}`), severity `warning`.
- On-duty idle shift past 2 hours with zero completed stops (`shift-idle:{id}:{date}`), severity `warning`.
- Each failed sale that day (`sale-sync:{saleId}`), severity `high`.
- Each failed activity log that day (`activity-sync:{logId}`), severity `high`.

`status` is `Open`. An empty list means none of these rows exist for that date.

## Location verifications

`data.items` is always an empty array. `data.message` is: "Action-time location verification is not persisted yet."

No latitude, longitude, speed, or device row is created.
