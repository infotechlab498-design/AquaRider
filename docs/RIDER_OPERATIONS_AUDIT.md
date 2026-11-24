# Rider Operations — Audit

## Screenshot conflict

The reference is a **Live Fleet Trackboard** (GPS markers, speed, geofences, Knox telemetry). Sentinel-04 Locked V1 **excludes** continuous live GPS tracking.

**Approved equivalent:** Rider Operations / Fleet Couriers screen using the same shell hierarchy (KPIs + overview panel + rider directory + detail card) without maps, fake telemetry, or animated markers.

## Existing assets

| Asset | Reuse |
|---|---|
| `ApplicationUser` + role Rider | Rider directory identity |
| `Shifts` | On-duty / unstarted day |
| `RouteStops` + `Sales` | Assignment progress and delivery counts |
| `Vehicles` | Assigned vehicle name/plate |
| `ActivityLogs` | Last activity (not GPS ping) |
| `Customers.Latitude/Longitude` | Optional action-time context only when tied to a completed sale/stop — **not** live position |
| Admin sidebar “Fleet Couriers” | Navigation target for this screen |

## No existing tables for

- Live GPS pings / heartbeats
- Geofences
- Device battery / Knox channel
- LocationVerification entity

Therefore location-verification API returns empty/unavailable unless/until an approved workflow stores action-time verification rows. Do not fabricate coordinates.

## Planned KPIs (SQL-backed)

1. Riders registered — count users in role Rider  
2. Available for assignment — active riders without open shift (or without incomplete stops), documented rule  
3. Active assignments — riders with open shift today  
4. Deliveries in progress — RouteStops `InProgress` (or Pending on open shifts)  
5. Requiring attention — failed sync sales/activity, idle open shifts with zero progress, inactive flagged  

## Navigation

Sidebar label: **Fleet Couriers** (Locked V1). Do not add **Live Trackboard** as a destination.
