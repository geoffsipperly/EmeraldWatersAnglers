---
description: Map a river's GPS coordinates and identify USGS/WSC water + NOAA/CHS tidal stations
---

Map one or more rivers end-to-end: GPS waypoints from mouth to headwaters at 5-mile intervals, the best water-monitoring gauge (USGS for US, WSC for Canada, NOAA NWPS as fallback), and the nearest tidal station if the mouth is tidal.

The full methodology lives in `SkeenaSystem/rivermappingprompt.md` (Version 3) — that file is the source of truth. Read it now and follow Phase 1 (research) and Phase 2 (output format) exactly. Do not paraphrase or shortcut the steps.

Inputs from the user (passed via `$ARGUMENTS` or asked for if missing):
- River name(s)
- Country / state / province
- Ending point (town, landmark, or "as far upstream as possible")

Produce two files at the repo root unless the user specifies otherwise:
1. `water-stations-import.md` — one table row per river/state, matching the column schema in the prompt (`name, water_type, country, state_province, source, station_id, is_tidal, tide_station_id, tide_source, latitude, longitude`).
2. `river-gps-coordinates.md` — one block per river, 4-decimal coordinates, Point 1 labeled `(mouth)`, final point `(headwaters)`.

Where this lands in the app:
- River course coordinates feed `SkeenaSystem/Location/RiverCoordinates.swift` and are consumed by `RiverLocator.swift` (covered by `SkeenaSystemTests/Location/RiverLocatorTests.swift`).
- Lodge ↔ river configuration is validated by `SkeenaSystemTests/Configuration/LodgeRiversConfigTests.swift` — if you add a river that a lodge references, run that test.

Rules:
- Never invent station IDs. If no USGS/WSC gauge exists on the river, leave `station_id` blank and note the nearest proxy gauge in prose, per the prompt.
- USGS site numbers are 8 or 15 digits; WSC station IDs follow `08EF001`-style; NOAA tide stations are 7 digits; CHS tide stations are 5 digits. Reject any value that doesn't match.
- Interpolated waypoints between verified anchors are approximations — say so explicitly in the output.
- Do not commit the generated files automatically. Show the user the two outputs and let them decide where to file them.

Scope note: the prompt's `water_type` enum is `river | canal | sound | other` — there is no lake-specific methodology yet. If the user asks to map a lake, stop and ask whether to (a) treat its outlet/inlet as a river segment, or (b) extend `rivermappingprompt.md` first.

$ARGUMENTS
