# CEHQ Integration Plan — Quebec Hydrometric Source

**Status:** Proposed (not yet implemented)
**Author:** Claude / Geoff (2026-05-08)
**Trigger:** Petite Cascapédia River onboarding revealed that Quebec inland rivers are primarily monitored by **CEHQ** (Centre d'expertise hydrique du Québec), not WSC. The skill, app, and backend all currently assume USGS / WSC / NOAA only.

---

## Background

When we onboarded the Petite Cascapédia River the SQL row used `source='WSC'`, `station_id='01BG010'`. Both were wrong:

- **01BG010 returns no data** on `wateroffice.ec.gc.ca` — likely a discontinued or never-operational station.
- The **active gauge** at the same physical location (Saint-Edgar covered bridge) is **CEHQ station 010902**. CEHQ's record cross-references it to WSC federal station `01BG008`, but the live data feed lives on the provincial CEHQ system at `cehq.gouv.qc.ca/suivihydro/`.
- Quebec operates ~280 hydrometric stations through CEHQ (under MELCCFP), independent of the federal WSC network.

Until we add CEHQ as a first-class source, every Quebec inland fishery we onboard will either be misattributed to WSC (returning empty data) or have to be force-fitted with the legacy federal cross-listing.

---

## The five changes

### 1. Add `CEHQ` as a valid source for new fisheries

**Surface area:**
- `fisheries_configuration.source` enum/values (Supabase, controlled by Loveable)
- Backend Edge Functions (see #2 and #3)
- Skill methodology + `source` field documentation (see #5)

**Action:** Loveable agent should add `'CEHQ'` to whatever validation/enum gates the `source` column in `fisheries_configuration`. If the column is plain `text` with no constraint, this is a no-op at the schema layer — the gate is whether the Edge Functions route on it.

---

### 2. `river-conditions-batch` — add CEHQ fetcher

The current Edge Function (`/functions/v1/river-conditions-batch`) appears to recognise USGS, WSC, NOAA. It needs a new branch for `source='CEHQ'`.

#### CEHQ data API (researched 2026-05-08)

**There is no JSON REST API.** CEHQ exposes a tab-separated text export per station:

```
URL:    https://www.cehq.gouv.qc.ca/suivihydro/fichier_donnees.asp?NoStation={STATION_ID}
Method: GET
Auth:   None (public)
```

**Response format** (tab-separated, French locale):

```
Date      	Heure	Débit

2026-05-08	16:45	313,8
2026-05-08	16:30	314,0
2026-05-08	16:15	317,3
…
```

**Parsing rules:**
- Skip the header row (`Date\tHeure\tDébit`) and the blank line after it.
- Each data row is `YYYY-MM-DD\tHH:MM\tFLOAT`.
- **Decimal separator is comma**, not period — replace `,` with `.` before `parseFloat`.
- Timestamp is in **America/Toronto** local time (Eastern, with DST). Convert to UTC if you store ISO timestamps.
- The first data line is the most recent reading — emit that as "current" for batch responses.
- Readings arrive every 15 minutes; lag is typically <1 hour.

**What columns are returned:**
- The default export is **flow / débit** in m³/s. The endpoint does **not** seem to expose water level or temperature via the same parameter set (probed `&Type=N`, `&Type=Q`, `&Type=T`, `&Date=Niveau` — all returned the same flow data).
- **Water level (niveau)** is rendered on the `tableau.asp` HTML view but is not in the export. Either parse from the HTML (fragile) or accept that level is missing for CEHQ stations.
- **Water temperature** is **not measured** by CEHQ for most stations. Quebec river temperatures are aggregated by [RivTemp](https://rivtemp.ca/) (a separate research-network database). RivTemp coverage is thin and sourced from independent sensors. **Recommendation:** for CEHQ stations, leave `water_temp_c = null` for now.

#### Edge-function pseudocode

```ts
async function fetchCEHQ(stationId: string): Promise<Reading> {
  const url = `https://www.cehq.gouv.qc.ca/suivihydro/fichier_donnees.asp?NoStation=${encodeURIComponent(stationId)}`;
  const resp = await fetch(url, {
    headers: { "User-Agent": "EmeraldWatersAnglers/1.0 (loveable-edge-fn)" },
    signal: AbortSignal.timeout(15_000),
  });
  if (!resp.ok) throw new Error(`CEHQ ${stationId} HTTP ${resp.status}`);
  const text = await resp.text();
  const lines = text.split(/\r?\n/).filter(l => l.trim().length > 0);
  // Drop header row "Date\tHeure\tDébit"
  const dataLines = lines.slice(1);
  if (dataLines.length === 0) {
    return { water_level_ft: null, water_temp_c: null, flow_cms: null };
  }
  const [date, time, flowStr] = dataLines[0].split("\t");
  const flow_cms = parseFloat(flowStr.replace(",", "."));   // m³/s
  return {
    water_level_ft: null,           // not exposed via this endpoint
    water_temp_c: null,             // not measured
    flow_cms,                        // primary CEHQ reading
    reading_at_local: `${date}T${time}:00-04:00`,  // EDT/EST — adjust for DST
  };
}
```

**Open question for Loveable:** the current `river-conditions-batch` response shape returns `water_level_ft` and `water_temp_c`. CEHQ gives us flow (m³/s), not level (ft). Three options:

- **A.** Add a new field `flow_cms` to the response shape; clients show flow when level is null.
- **B.** Convert flow to a synthetic "level" — bad idea, station-specific rating curve required.
- **C.** Leave both `water_level_ft` and `water_temp_c` null for CEHQ stations, and rely on the upcoming UI hint that data is partial.

I'd lean **A** (additive, semantically correct).

---

### 3. `fisheries-readings-collector` — same CEHQ fetcher

Whatever long-running collector job pre-fetches readings into the readings table needs the same CEHQ branch as #2. Re-use the same `fetchCEHQ()` helper.

**Schedule consideration:** CEHQ updates every 15 minutes; a 30-minute collector cadence is plenty. Be considerate — they're a small provincial agency with a public ASP page, not a CDN-backed API. Add a per-station throttle and respect the 15s timeout above.

---

### 4. App — Conditions view source attribution

**File:** `SkeenaSystem/Config/DevTEST.xcconfig:89`
**Current text:**

```
FORECAST_NOTES =  Water height and temperature data sourced from USGS, WSC, and NOAA as available. Tide data provided by NOAAs CO-OPS Tides & Currents API
```

**Proposed text:**

```
FORECAST_NOTES =  Water height, flow, and temperature data sourced from USGS, WSC, NOAA, and CEHQ (Quebec) as available. Tide data provided by NOAA's CO-OPS Tides & Currents API and the Canadian Hydrographic Service (CHS).
```

Notes on the change:
- Added "flow" since CEHQ primarily provides flow, not height.
- Added CEHQ with a parenthetical "(Quebec)" so users know what the acronym means.
- Added CHS for the Canadian-side tide story (we already use it for `tide_source`, just hadn't surfaced it in copy).
- Added the missing apostrophe in "NOAA's" while we're here.

**Also update:** `PROD.xcconfig:81` if/when production communities ship with non-USGS sources. Currently it's Tillamook-only, USGS-only — leave as-is until a non-PNW community ships in PROD.

**Optional:** if any view renders the source list dynamically (e.g., from the actual rows in `fisheries_configuration`), prefer that over hardcoded copy. Worth a 5-minute audit before editing the xcconfig string.

---

### 5. `water-body-mapping` skill — add CEHQ to methodology + SKILL.md

**Files:**
- `.claude/skills/water-body-mapping/references/methodology.md`
- `.claude/skills/water-body-mapping/SKILL.md`

#### `methodology.md` — replace the "Canadian rivers (BC, AB, etc.)" block

Currently:

```
#### Canadian rivers (BC, AB, etc.)

1. **Water Survey of Canada (WSC)** hydrometric stations …
2. **No WSC?** Use the nearest monitored river as a proxy …
```

Replace with:

```
#### Canadian rivers

The right agency depends on the province.

**Quebec inland rivers — use CEHQ first:**
- The Centre d'expertise hydrique du Québec (now under MELCCFP) operates ~280
  stations across Quebec, primarily for flow (débit, m³/s).
- Atlas: https://www.cehq.gouv.qc.ca/atlas-hydroclimatique/stations-hydrometriques/
- Station search by hydro region:
  https://www.cehq.gouv.qc.ca/hydrometrie/historique_donnees/ListeStation.asp?regionhydro={NN}
  (Region 01 = Baie des Chaleurs / Percé; 02 = Saguenay; 04 = Saint-Laurent
  Sud; etc. The region code is the first two digits of the station ID.)
- Station ID format: 6-digit numeric (e.g. `010902`).
- Many CEHQ stations cross-reference a federal WSC ID — the `fiche signalétique`
  page shows it under "Federal Station Number". Prefer the CEHQ ID; the federal
  feed often has no live data for Quebec inland sites.
- Real-time data is published at:
  `https://www.cehq.gouv.qc.ca/suivihydro/fichier_donnees.asp?NoStation={ID}`
  Tab-separated text, comma-decimal, America/Toronto local time, flow only.

**British Columbia, Alberta, Atlantic provinces, Yukon, NWT — use WSC:**
- Water Survey of Canada — wateroffice.ec.gc.ca
- Station IDs: `01BG008`, `08EF001`, etc.
- Operator: Water Survey of Canada / Environment and Climate Change Canada (ECCC).

**No CEHQ or WSC station on the river?** Use the nearest monitored river as a
proxy and document the substitution in the SQL header comment.
```

#### `SKILL.md` — agency-code list

Add `CEHQ` to the value rules under the SQL section. Currently:

```
- **`source` is NOT NULL.** Always populate it with the regional agency in
  **uppercase**: `'USGS'` for US (including Alaska), `'WSC'` for Canada,
  `'NOAA'` only when the primary data feed is a NOAA NWPS gauge …
```

Replace with:

```
- **`source` is NOT NULL.** Always populate it with the regional agency in
  **uppercase**:
    - `'USGS'` for US rivers (including Alaska)
    - `'NOAA'` only when the primary data feed is a NOAA NWPS gauge rather than USGS
    - `'CEHQ'` for Quebec inland rivers (provincial hydrometric network)
    - `'WSC'` for everywhere else in Canada (BC, AB, SK, MB, ON, Atlantic, Yukon, NWT)
  …
```

Also add a Quebec note under the Canadian agency-codes paragraph at the bottom of SKILL.md:

```
**Quebec uses CEHQ, not WSC.** Quebec inland rivers are monitored by the
provincial Centre d'expertise hydrique du Québec network (now MELCCFP).
WSC has cross-listings for some sites but the live feed is on the CEHQ
side (`cehq.gouv.qc.ca/suivihydro/`). Default to `source='CEHQ'` for any
Quebec river unless the only available station is on the federal feed.
```

---

## Concrete one-shot fixes for the Petite Cascapédia (when ready to implement)

```sql
-- fisheries_configuration: switch to CEHQ
UPDATE fisheries_configuration
SET source = 'CEHQ',
    station_id = '010902'
WHERE name = 'Petite Cascapedia River';
```

```swift
// SkeenaSystem/Location/RiverCoordinates.swift — comment update
// Old: "WSC station 01BG010 at Saint-Edgar (0.9 km downstream of the road bridge)"
// New: "CEHQ station 010902 at Saint-Edgar (0.9 km left bank downstream of the
//       covered road bridge); WSC cross-listing 01BG008. CEHQ provides flow only."
```

```diff
# .claude/skills/water-body-mapping/outputs/petite-cascapedia-river.sql
- 'WSC',
- '01BG010',
+ 'CEHQ',
+ '010902',
```

---

## Sequencing

The five items have different owners and can ship out of order. Suggested order:

1. **Skill update (#5)** — zero risk, unblocks future onboardings doing the right thing from the start. Can do today.
2. **Backend Edge Function CEHQ fetcher (#2 and #3)** — the long pole. Needs Loveable agent. The pseudocode + parsing rules above should be the full handoff.
3. **fisheries_configuration row patch + Swift comment** — trivial, do once #2 is live so we don't have a "broken" CEHQ row sitting in PROD.
4. **`source` enum/validation (#1)** — this is implicit in #2 (the function dispatches on `source`), so probably no separate work unless there's a CHECK constraint.
5. **Conditions-view copy (#4)** — purely cosmetic, do anytime after #2 ships so the claim matches reality.

---

## Open questions

1. **Flow vs level in the response shape.** Pick A/B/C above. (Recommendation: A — add `flow_cms` field.)
2. **Temperature for Quebec rivers.** Do nothing for now (CEHQ doesn't measure it), or integrate RivTemp.ca? RivTemp is a separate research-aggregation database with thin coverage; probably not worth integrating for one river. Revisit if we onboard 5+ Quebec rivers.
3. **DST handling.** CEHQ timestamps are local (Eastern). Confirm the Edge Function converts correctly across the spring-forward / fall-back boundary.
4. **HTML scraping for water level.** CEHQ's `tableau.asp` view shows level alongside flow. If level is important, we'd need to parse the HTML — not done in the proposed implementation. Re-evaluate if a community owner asks specifically for it.
5. **Federal WSC fallback for Quebec.** Some Quebec stations *do* have live federal data. If we ever want belt-and-suspenders, we could fetch both CEHQ and WSC and prefer whichever returned a fresher reading. Probably overkill.
