-- Water Body: Upper Copper River (BC, Canada)
-- Also known as: Zymoetz River (official name)
-- Generated: 2026-05-01
-- Skill: water-body-mapping
--
-- WSC gauge: 08EF005 — "Zymoetz River Above O.K. Creek"
--   Confirmed as the primary active gauge on the Zymoetz / Copper River.
--   Located in the remote upper reach, well above the Copper River Road end (~mile 28).
--   Maximum recorded discharge: 3,140 m³/s on 1978-11-01.
--
-- River course: ~90 miles (145 km) from Aldrich Lake headwaters (Bulkley Ranges,
--   Hazelton Mountains) southwest to the Skeena River confluence ~12 km east of
--   downtown Terrace. The lower 28 miles are paralleled by the Copper River Road.
--   Upper reach flows east through the Aldrich-Dennis-McDonell lake chain before
--   turning south/southwest toward the main valley.
--
-- Tidal status: Non-tidal. The Skeena confluence is far inland of any tidal zone;
--   tidal influence on the Skeena ends near Kasiks (~mile 15 on the Skeena, well
--   downstream of the Zymoetz mouth).
--
-- Name note: "Upper Copper River" is the lodge-facing name used by the client.
--   The official BC geographic name is "Zymoetz River." Both names refer to the
--   same water body; use "Upper Copper River" to match the Swift atlas key and
--   any future LODGE_RIVERS xcconfig entry.

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
  'Upper Copper River',
  'river',
  'CA',
  'BC',
  'WSC',
  '08EF005',
  false,
  NULL,
  NULL,
  54.5450,
  -128.4858
);
