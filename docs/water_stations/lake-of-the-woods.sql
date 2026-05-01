-- Water Body: Lake of the Woods (ON / MB / CA + MN / US)
-- Generated: 2026-05-01
-- Skill: water-body-mapping
--
-- Caveats:
--   * International freshwater lake spanning Ontario, Manitoba, and Minnesota.
--     Per skill convention for cross-jurisdiction water bodies, three INSERT
--     rows are emitted with identical `name` and per-jurisdiction centroids.
--   * **Schema requirement:** `fisheries_configuration` must have a composite
--     uniqueness constraint on `(name, country, state_province)` for these
--     three rows to coexist. If today's constraint is on `name` alone, please
--     widen it before applying. The mobile app derives country/state from the
--     angler's lat/lon and joins on all three columns at lookup time.
--   * Canadian gauge: WSC 05PE016 "Lake of the Woods at Kenora" — used for
--     both ON and MB rows (no separate WSC station on the Manitoba shore).
--   * US gauge: USGS 05140520 "Lake of the Woods at Warroad, MN".
--   * Non-tidal — large freshwater lake; tide_* fields NULL on all rows.
--   * Polygon (WaterBodyCoordinates.swift) does not cut out the Northwest
--     Angle peninsula (MN exclave); same simplification used for Mercer
--     Island in Lake Washington.
--   * Centroids are approximate (eyeballed from outline + jurisdiction
--     boundaries inside the lake); they exist mainly so the row has a
--     reasonable lat/lon for display, not as a geofence anchor.

-- Ontario (NE half of the lake, includes Kenora)
INSERT INTO fisheries_configuration (
  name,
  water_type,
  country,
  state_province,
  source,
  station_id,
  is_tidal,
  tide_station_id,
  tide_source,
  latitude,
  longitude
) VALUES (
  'Lake of the Woods',
  'lake',
  'CA',
  'ON',
  'WSC',
  '05PE016',
  false,
  NULL,
  NULL,
  49.450,
  -94.400
);

-- Manitoba (narrow western strip, includes Buffalo Point)
INSERT INTO fisheries_configuration (
  name,
  water_type,
  country,
  state_province,
  source,
  station_id,
  is_tidal,
  tide_station_id,
  tide_source,
  latitude,
  longitude
) VALUES (
  'Lake of the Woods',
  'lake',
  'CA',
  'MB',
  'WSC',
  '05PE016',
  false,
  NULL,
  NULL,
  49.200,
  -95.200
);

-- Minnesota (south half + Northwest Angle exclave)
INSERT INTO fisheries_configuration (
  name,
  water_type,
  country,
  state_province,
  source,
  station_id,
  is_tidal,
  tide_station_id,
  tide_source,
  latitude,
  longitude
) VALUES (
  'Lake of the Woods',
  'lake',
  'US',
  'MN',
  'USGS',
  '05140520',
  false,
  NULL,
  NULL,
  48.900,
  -94.900
);
