# Rider Operations — implementation

Fleet Couriers opens Rider Operations. The page keeps the screenshot’s split layout (summary cards, overview panel, directory, selected detail) and does not implement the live trackboard.

## Navigation

- Breadcrumb: Field Operations › Rider Operations
- Sidebar label stays **Fleet Couriers** (`fleetCouriers`)
- There is no Live Trackboard item and no LIVE RADAR badge
- No History Playback control

## Screen

`lib/adminDashboard/presentation/screens/rider_operations_screen.dart`

Panels live in `lib/adminDashboard/presentation/widgets/rider_operations/rider_operations_panels.dart`.

- Five summary cards when the summary payload includes the counts. Cards labeled Live Tracking, History Playback, LIVE RADAR, Knox, battery, speed, GPS, or km/h are dropped. The same words are hidden on status, activity, notes, and location-verification lines.
- Left panel: assignment progress, assignment list, last activity, and exceptions. No map, geofence, speed, or device health
- Right panel: search, filters (All, Active, At customer, Idle, Offline), directory cards, and a navy detail card. An empty rider list keeps the search and filters and says that no riders were returned.
- Detail actions: View Profile, View Assignment, Activity. Each opens the rows already returned by the API
- Call is shown only when the rider payload includes a phone, and it uses `url_launcher` with a `tel:` URI. Notify is omitted
- Location verifications sit under the split. An empty `200` shows “No location verifications are recorded.” Coordinates are not stored on the model and are not drawn

The date defaults to today and can be changed with the date button. Refresh reloads every rider-operations call for that date.

## API

| UI | Method | Path |
|---|---|---|
| Summary cards | GET | `/api/rider-operations/summary?date=` |
| Directory | GET | `/api/rider-operations/riders?search=&status=&date=` |
| Selected rider | GET | `/api/rider-operations/riders/{id}?date=` |
| Activity | GET | `/api/rider-operations/riders/{id}/activity` |
| Assignments | GET | `/api/rider-operations/riders/{id}/assignments?date=` |
| Exceptions | GET | `/api/rider-operations/exceptions?date=` |
| Location verifications | GET | `/api/rider-operations/location-verifications` |

`date` is `yyyy-MM-dd`. Status `all` is omitted. Other chip values are sent as `active`, `atCustomer`, `idle`, and `offline`. HTTP 404 and other failures show an error and retry. They do not invent riders.

### Summary fields

| Field | Card label |
|---|---|
| `ridersRegistered` | Riders registered |
| `availableForAssignment` | Available for assignment |
| `activeAssignments` | Active assignments |
| `deliveriesInProgress` | Deliveries in progress |
| `requiringAttention` | Requiring attention |

A `kpis` list is used when it still contains an allowed card after telemetry labels are removed. Moving speed, LIVE RADAR, device health, stationary, Knox, battery, playback, and geofence labels are dropped. If that list contributes nothing, the named counts above are used instead.

### Rider JSON

`id`, `fullName`, `riderCode`, `status`, `routeName`, `vehicleName`, `vehiclePlate`, `phone`, `completedStops`, `totalStops`, `cashInHand`, `salesAmount`, `returnsCount`, `nextStop`, `lastActivity`, `notes`.

Assignments: `customerName`, `status`, `sequence`, `address`, `scheduledTime`.

Activity and exceptions: `title`, `detail`, `occurredAt`, plus `riderName` / `severity` on exceptions.

Location verifications, when a future workflow stores them: `riderName`, `outcome`, `recordedAt`, `note`. Latitude and longitude are ignored.

## Screenshot replacements

| Screenshot | What the screen does |
|---|---|
| Live Fleet Trackboard / LIVE RADAR | Rider Operations title and breadcrumb |
| Moving markers, geofences, playback | Operational overview panel |
| Moving speed, doorstep drop, stationary alert, device health | The five summary fields above |
| Knox / SSL / battery / satellite line | Omitted. The shell shows API reachability and the app version |
| Call and Notify | Call only with a real phone. Notify omitted |
| Selected rider sample names and speeds | Directory and detail fields from the riders API |
