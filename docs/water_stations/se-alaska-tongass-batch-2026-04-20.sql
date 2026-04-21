-- Water Stations: SE Alaska / Tongass NF batch
-- Generated: 2026-04-20
-- Skill: water-body-mapping
--
-- Rivers included:
--   1. Kadake Creek (NE Kuiu Island)
--   2. Farragut River (mainland, east of Frederick Sound)
--
-- Caveats:
--   * Neither river has a dedicated USGS or NOAA NWPS hydrometric gauge.
--     `source` is set to 'USGS' (regional agency for AK) with `station_id = NULL`
--     so the app falls back to regional agency proxy data.
--   * Both are tidal at the mouth. Nearest NOAA CO-OPS tide stations:
--       - Kadake Creek  -> Kake Harbor, Keku Strait (9451528)
--       - Farragut River -> Petersburg, Wrangell Narrows (9451204)
--   * Kadake Creek: official GNIS name is "Kadake Creek"; locally also called
--     "Kadake River". Swift dictionary key and LODGE_RIVERS entry must match
--     the `name` column below exactly.
--   * Farragut River mouth lat/lon is interpolated from NOAA Chart 17367 and
--     Farragut Bay geometry; the source (Glory Lake) coord is GNIS-verified.

INSERT INTO water_stations (
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
  'Kadake Creek',
  'river',
  'US',
  'AK',
  'USGS',
  NULL,
  true,
  '9451528',
  'NOAA',
  56.7831,
  -133.9822
);

INSERT INTO water_stations (
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
  'Farragut River',
  'river',
  'US',
  'AK',
  'USGS',
  NULL,
  true,
  '9451204',
  'NOAA',
  57.1200,
  -133.0800
);
