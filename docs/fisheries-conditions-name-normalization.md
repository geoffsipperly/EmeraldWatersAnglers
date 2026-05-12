# Fisheries Conditions — Name Normalization (Loveable Handoff)

**Status:** Proposed (not yet implemented)
**Author:** Claude / Geoff (2026-05-12)
**Trigger:** Researcher community on `rkbonlzjyemhypvrdriy` returned `null` for half its rivers in the `/river-conditions-batch` response despite every river having a row in `fisheries_configuration`. Diagnosis traced it to a name-shape mismatch between `communities.geography.lodge_rivers` (sometimes bare names like `"Babine"`) and `fisheries_configuration.name` (always `"Babine River"`).

We've data-fixed the affected community for now. This document is for the durable fix on the backend.

---

## Symptom (from device logs)

```
[Forecast] batch — Babine:                   type=,      level=nil,  temp=nil
[Forecast] batch — Bogachiel:                type=,      level=nil,  temp=nil
[Forecast] batch — Hoh:                      type=,      level=nil,  temp=nil
[Forecast] batch — Sol Duc:                  type=,      level=nil,  temp=nil
[Forecast] batch — King Salmon River:        type=river, level=nil,  temp=nil
[Forecast] batch — Klamath River (California): type=,    level=nil,  temp=nil
[Forecast] batch — Klamath River (Oregon):   type=,      level=nil,  temp=nil
[Forecast] batch — Situk River:              type=river, level=66.84, temp=3.9
[Forecast] batch — Williamson River:         type=river, level=3.56, temp=13.8
[Forecast] batch — Sprague River:            type=river, level=1.77, temp=19.4
[Forecast] batch — Wood River:               type=river, level=2.96, temp=12.2
[Forecast] batch — Klamath River (CA):       type=river, level=2.60, temp=nil
```

The first row's error field made the failure mode explicit:

```json
"error": "Unknown water body. Valid names: Nehalem River, Wilson River, Trask River, …, Bogachiel River, Sol Duc River, …, Hoh River, … Skykomish River, …"
```

Note that Bogachiel / Sol Duc / Hoh all appear in the "Valid names" list — the backend *knows* them, it just can't match the bare form the client sent.

---

## Root cause

Three coordinated layers each have their own idea of how to name a river:

| Layer | Names look like | Example |
|---|---|---|
| Community config (`communities.geography.lodge_rivers`) | Inconsistent — sometimes bare, sometimes with " River", sometimes with regional disambiguators | `"Babine"`, `"Hoh"`, `"Klamath River (California)"` |
| Mobile client (request payload) | Strips the trailing ` River` suffix before sending | `"Babine"`, `"Hoh"`, `"Klamath River (California)"` |
| Backend DB (`fisheries_configuration.name`) | Canonical full form | `"Babine River"`, `"Hoh River"`, `"Klamath River (CA)"` |
| Backend hardcoded fallback list | Mostly full form, missing some Canadian rivers entirely | `"Bogachiel River"`, `"Wood River"`, **no `"Babine River"`** |

When the request comes in as `"Babine"`:

1. Edge function looks up `"Babine"` in `fisheries_configuration` — exact match miss (row is `"Babine River"`).
2. Falls through to the hardcoded valid-names list — `"Babine"` not in it, `"Babine River"` not in it either.
3. Returns the row with empty `water_type`, nil readings, and the "Unknown water body" error.

For rivers like `"Wood"` / `"Sprague"` / `"Williamson"` / `"Situk"`, the bare forms apparently *do* match the hardcoded fallback list, so they slip through despite the same shape mismatch with `fisheries_configuration`.

---

## What the mobile client sends

[`SkeenaSystem/Views/Guide/FishingForecastRequestView.swift:408`](../SkeenaSystem/Views/Guide/FishingForecastRequestView.swift)

```swift
// Strip river suffixes for rivers; water bodies pass through as-is
let apiNames = rivers.map { AppEnvironment.stripRiverSuffix($0) } + waterBodies
let payload = BatchPayload(rivers: apiNames, communityId: communityId)
```

`AppEnvironment.stripRiverSuffix` removes a trailing ` River` token only. It does not normalize case, doesn't touch parenthetical state disambiguators, and doesn't add anything that isn't already there.

So the client guarantees one thing: the trailing ` River` will be absent. Beyond that, whatever shape sits in `lodge_rivers` is what the backend sees.

---

## Why we don't want to fix this purely on the mobile side

We considered telling the client to send the full canonical names instead of stripped forms. We rejected it because:

- The backend's *legacy fallback list* recognizes some rivers (`"Wood"`, `"Sprague"`, `"Williamson"`, `"Hood Canal"`) by bare name. Sending the suffixed form might silently break those.
- Community admins enter `lodge_rivers` by hand. Whatever convention the mobile client enforces, the next admin will type the other one.
- The `fisheries_configuration` row IS the source of truth — the backend should be the side that owns the matching policy.

---

## Proposed backend behavior

Make name lookup in `/river-conditions-batch` (and `/river-conditions`, and `fisheries-readings-collector`) **normalize-then-match** instead of exact-match.

### Normalization rule

For both the incoming name *and* each candidate `fisheries_configuration.name`:

1. Trim whitespace.
2. Lowercase.
3. Strip a trailing ` river` if present.
4. Collapse the regional disambiguator: `(california)` → `(ca)`, `(oregon)` → `(or)`, `(washington)` → `(wa)`, `(british columbia)` → `(bc)`. (Keep these as canonical short codes — they match the DB's existing convention.)
5. Collapse runs of whitespace to a single space.

Two names are a match when their normalized forms are equal.

### Pseudocode

```ts
function normalize(name: string): string {
  let n = name.trim().toLowerCase();

  // Spelled-out → ISO short forms. Extend this map as new regions appear.
  const regionMap: Record<string, string> = {
    "(california)": "(ca)",
    "(oregon)":     "(or)",
    "(washington)": "(wa)",
    "(british columbia)": "(bc)",
    "(quebec)":     "(qc)",
    "(alaska)":     "(ak)",
  };
  for (const [full, abbr] of Object.entries(regionMap)) {
    n = n.replace(full, abbr);
  }

  // Trim trailing " river" (word boundary).
  n = n.replace(/\s+river$/i, "");

  // Collapse whitespace.
  n = n.replace(/\s+/g, " ");
  return n;
}

async function resolveStation(rawName: string): Promise<Row | null> {
  const target = normalize(rawName);
  const { data: rows } = await supabase
    .from("fisheries_configuration")
    .select("*");
  return rows?.find(r => normalize(r.name) === target) ?? null;
}
```

In production, prefer building a normalized → row map once per request (or once per cold start with cache invalidation) rather than re-normalizing for every lookup.

### Behaviour after the change

Given the current DB rows (`"Babine River"`, `"Hoh River"`, `"Klamath River (CA)"`, …), every request below resolves correctly:

| Client sends | Normalizes to | Matches DB row |
|---|---|---|
| `Babine` | `babine` | `Babine River` (also `babine`) ✓ |
| `Babine River` | `babine` | same ✓ |
| `Hoh` | `hoh` | `Hoh River` ✓ |
| `Klamath River (California)` | `klamath (ca)` | `Klamath River (CA)` ✓ |
| `Klamath River (CA)` | `klamath (ca)` | same ✓ |
| `Petite Cascapédia` | `petite cascapédia` | `Petite Cascapedia River`? **No — accent.** |

That last one's a real gotcha. Two options:

- **Strip diacritics** in `normalize()`. Recommended — `é → e`, `ó → o`, etc. Use Unicode NFD + filter out combining marks.
- **Store normalized form in the DB** as a generated column and index it.

We'd lean toward stripping diacritics in the normalizer — keeps the DB schema unchanged and matches what users typically type on iOS keyboards.

### What to do with the legacy fallback list

The hardcoded list inside the Edge Function ("Valid names: Nehalem River, …") should be retired once `fisheries_configuration` is the only source of truth. Migration:

1. Audit each name in the fallback list — confirm a `fisheries_configuration` row exists for it.
2. Backfill any that are missing (with placeholder `source_id = NULL` if no real station).
3. Remove the fallback list from the Edge Function.
4. The error message can now say `"Unknown water body 'X'. Configure it via the admin UI or contact support."` — no static "Valid names: …" enumeration.

---

## Affected Edge Functions

Per the iOS xcconfig:

- `/functions/v1/river-conditions` — single-river fetch. Used by the tap-on-river flow.
- `/functions/v1/river-conditions-batch` — batch fetch used on the Conditions landing screen.
- `fisheries-readings-collector` — the back-end harvester that pre-fetches readings (presumed; the iOS side doesn't call it directly but it presumably hits the same matching logic).

All three should share a single normalization helper.

---

## Migration / rollout

This is a behavior-compatible change for the happy paths that already match exactly. The only ways it could break something:

- Two `fisheries_configuration` rows with the same normalized name in different communities. The DB has unique-ish `(name)` constraints today (verified during the Petite Cascapédia onboarding), so a single global normalize-and-match works.
- A community config that intentionally has a row named differently from what users type. We haven't seen this; if it ever happens we'd add an alias table rather than disabling the normalizer.

Suggested order:

1. Ship the normalizer behind a feature flag (`USE_NAME_NORMALIZATION=true` env var on the Edge Functions). Default off.
2. Verify on the Researcher and Gaspe Coastal communities — should be a no-op since data is already clean.
3. Re-introduce a "sloppy" entry to one of the dev communities (e.g. `"Babine"` instead of `"Babine River"`) and confirm it still resolves.
4. Flip the flag on. Watch error logs for new unknown-water-body misses.
5. Once stable, remove the hardcoded fallback list and the feature flag.

---

## Data fix we already applied (for context)

We PATCHed `communities.geography.lodge_rivers` for the Researcher community (id `7ec7db20-8e27-4d6f-b4ef-dcf89578d5d1`) on 2026-05-12 to use the canonical DB names:

```json
[
  "Babine River", "Bogachiel River", "Hoh River", "Sol Duc River",
  "King Salmon River", "Sandy River", "Ocean River", "Situk River",
  "Klamath River (CA)", "Klamath River (OR)",
  "Williamson River", "Sprague River", "Wood River"
]
```

Dropped: `"Klamath River (California)"`, `"Klamath River (Oregon)"`, and the duplicate `"Klamath River (CA)"` that was effectively the dedup target. Verified the patched list with a SELECT after the PATCH.

This data fix unblocks the affected community. The backend normalizer is the durable fix so the same drift doesn't bite us when the next community gets configured.

---

## Open questions for Loveable

1. Should normalization match against accents/diacritics? (We'd argue yes — `"Petite Cascapédia"` and `"Petite Cascapedia"` should resolve identically.)
2. Is `fisheries_configuration.name` intended to be globally unique, or scoped per-community? The current rows look global (one row per water body) but there's no constraint enforcing it.
3. What happens for water bodies (`Hood Canal`, `Puget Sound`)? They live in `fisheries_configuration` too with `water_type` = `canal` / `sound`. Confirm normalization applies uniformly across all `water_type` values, not just rivers.
4. Confirm CEHQ-style provincial sources (`source = 'CEHQ'`) will be wired in eventually — see [cehq-integration-plan.md](./cehq-integration-plan.md). The normalizer change is independent of CEHQ but lands in the same Edge Function.

---

## TL;DR

Mobile sends stripped names. Backend has a hardcoded fallback list and an exact-match-against-DB. They drift. Make the backend normalize both sides before matching, and the drift stops mattering.
