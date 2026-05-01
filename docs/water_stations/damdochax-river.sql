-- Water Body: Damdochax River (BC, Canada)
-- Generated: 2026-05-01
-- Skill: water-body-mapping
--
-- Caveats:
--   * Small (~12 mi) wilderness river ~140 km NE of Hazelton, accessible only
--     by air. Drains Damdochax Lake into the upper Nass River.
--   * **Watershed mismatch (intentional):** Damdochax is geographically a
--     Nass tributary, but the user-specified proxy gauge is WSC 08EB005
--     "Skeena River above Babine River" rather than a Nass-watershed gauge.
--     Recorded as-specified; revisit if a Nass-watershed proxy is preferred.
--   * No dedicated gauge on Damdochax itself; 08EB005 is a regional fallback.
--   * Non-tidal — entirely inland; tide_* fields NULL.
--   * Mouth coordinate (56.5316, -128.3206) and Lake outlet (56.5078,
--     -128.1011) come from BC GeoNames / Wikidata. Mid-river points (Mile 5,
--     Mile 10) in RiverCoordinates.swift are linear-interpolated.

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
  'Damdochax River',
  'river',
  'CA',
  'BC',
  'WSC',
  '08EB005',
  false,
  NULL,
  NULL,
  56.5316,
  -128.3206
);
