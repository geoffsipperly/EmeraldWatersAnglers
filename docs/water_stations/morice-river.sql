-- Water Body: Morice River (BC, Canada)
-- Generated: 2026-05-01
-- Skill: water-body-mapping
--
-- Caveats:
--   * The active WSC gauge "Morice River near Houston" (08ED002) is actually
--     located at the outlet of Morice Lake (54.1168, -127.4266) — i.e., at
--     the SOURCE of the river, not near Houston town. The historical gauge
--     08ED003 is closer to the mouth but has only 1971 data, so 08ED002 is
--     the only viable active choice.
--   * Non-tidal — entirely inland in the BC interior; tide_* fields NULL.
--   * Mouth coordinate (54.3998, -126.6701) is Houston/Bulkley confluence and
--     matches the Bulkley River Mile 70 entry in RiverCoordinates.swift for
--     atlas consistency.

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
  'Morice River',
  'river',
  'CA',
  'BC',
  'WSC',
  '08ED002',
  false,
  NULL,
  NULL,
  54.3998,
  -126.6701
);
