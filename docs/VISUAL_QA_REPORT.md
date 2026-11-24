# Visual QA Report — Rider Operations + Dispatch

Compared Flutter structure to screenshots with Locked V1 replacements.

## Screen 01 (Trackboard screenshot → Rider Operations)

| Reference | Implementation |
|---|---|
| LIVE RADAR / Live Tracking / Playback | Removed |
| Map + geofences + Knox telemetry | Operational overview panels (assignments/activity/exceptions) |
| Moving/Idle/Offline GPS filters | Persisted statuses: all / available / onDuty / attention / inactive |
| Battery / speed | Not shown |
| Fleet Couriers nav | Active for this screen |

Widget tests assert absence of Live Trackboard / LIVE RADAR / Knox / GPS claims.

## Screen 02 (Dispatch screenshot)

| Reference | Implementation |
|---|---|
| KPI 248/18/64 | API summary only (live DB may show 1/0/1…) |
| Order table + drawer | Implemented; mobile uses full-screen detail |
| Price Lists / Live GPS density map | Not present; text Operational Zone + Shift Progress |
| Pick-list | Server projection; 400 when OrderLines empty |

## Remaining visual polish (non-blocking)

- Desktop drawer width ~40% — verify on 1440px browser session
- Table column density vs screenshot — functional columns present; amount/payment may be estimated-value only until collection linkage exists
