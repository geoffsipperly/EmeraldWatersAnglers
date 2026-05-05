# Mad Thinker Platform API Reference

**Version:** 2026-05-01
**Generated:** 2026-05-05T20:30:09.688Z

## Key Concepts

- **member_id**: UUID foreign key reference to a member record
- **member_number**: Human-readable string identifier in MAD Crockford Base32 format — 9 characters: "MAD" prefix + 6 random characters from 0-9 A-H J-N P-T V-Z (e.g., "MAD4ZQ7H9")
- **Entitlements**: Per-community-type feature toggles with E_ prefix (e.g., E_CATCH_CAROUSEL). Note: E_THE_BUZZ has been removed.
- **Add-ons**: Per-community feature toggles (OPS, Sales, Social) stored in the community_addons table. The "Social" add-on replaces the former E_THE_BUZZ entitlement. CRM/member management is a core feature, not an add-on.
- **Roles**: community-scoped roles — angler, guide, admin, public, researcher
- **Units**: community-level setting — "imperial" or "metric"
- All endpoints require `Authorization: Bearer <token>` and `apikey: <anon_key>` headers unless noted.

---

## Sign Up (Invite-Based)

**POST** `/auth/v1/signup`

Register with a community code. Profile is auto-populated from pending invite.

**Auth:** none

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | ✅ | User email |
| password | string | ✅ | User password |
| data.community_code | string | ✅ | 6-char community code from guide/admin |
| data.member_number | string | ✅ | 9-char MAD-format member number from invite email (e.g. MAD4ZQ7H9) |

**Notes:**

- Email must match the invite email exactly.
- member_number must match the value tied to the pending invite for this community + email; signup is rejected otherwise.
- first_name, last_name, role populated from invite.
- member_id (member_number) populated from claimed member record.

---

## Sign Up (Full Registration)

**POST** `/auth/v1/signup`

Register without a community code. All profile fields required.

**Auth:** none

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | ✅ | User email |
| password | string | ✅ | User password |
| data.first_name | string | ✅ | First name |
| data.last_name | string | ✅ | Last name |
| data.user_type | string | ✅ | Role: angler, guide, public, researcher |
| data.member_id | string | ✅ | Auto-generated or provided member identifier |
| data.date_of_birth | string | ✅ | YYYY-MM-DD |
| data.sex | string | ✅ | male, female, or other |
| data.mailing_address | string | ✅ | Full mailing address |
| data.telephone_number | string | ✅ | Phone number |
| data.residency | string | ✅ | US, CA, or other |

**Notes:**

- User is not associated with a community until they join one.

---

## Sign In

**POST** `/auth/v1/token?grant_type=password`

Authenticate and receive access token.

**Auth:** none

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | ✅ | User email |
| password | string | ✅ | User password |

**Response:**

- `access_token`: JWT token for Authorization header

---

## Password Reset Request

**POST** `/auth/v1/recover`

Send a password reset email.

**Auth:** none

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| email | string | ✅ | User email |

---

## My Profile

**GET** `/functions/v1/my-profile`

Returns the authenticated user's profile, communities, and memberships.

**Auth:** required

**Response:**

- `userId`: UUID
- `email`: string
- `memberId`: string (maps to member_number)
- `firstName`: string
- `lastName`: string
- `communities`: array of { id, name, code, role, memberNumber, entitlements, units }

---

## My Profile — Update

**PUT** `/functions/v1/my-profile`

Update the authenticated user's profile fields.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| first_name | string | ❌ | First name |
| last_name | string | ❌ | Last name |
| date_of_birth | string | ❌ | YYYY-MM-DD |
| sex | string | ❌ | male, female, or other |
| mailing_address | string | ❌ | Mailing address |
| telephone_number | string | ❌ | Phone number |

---

## Delete Account

**POST** `/functions/v1/delete-account`

Permanently delete the authenticated user's account, all related records, and storage objects. Implemented for Apple App Store account-deletion compliance.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| confirmationText | string | ✅ | Must be exactly the string 'DELETE' to confirm intent. |

**Response:**

- `success`: boolean
- `message`: string — human-readable status
- `deletedAt`: ISO timestamp of deletion

**Notes:**

- Gated by the 'tca-phase1-mvp-account-lifecycle' feature flag — returns 403 when disabled.
- Rate limited to 5 attempts per hour per user (tracked in account_lifecycle_audit). Returns 429 when exceeded.
- Cascading deletion: catch_reports, no_catch_reports, archived_catch_reports, enriched_catch_reports, anglers, trips, trip_roster, user_communities, user_roles, angler_licenses, flight_details, ops_tickets, forum_posts, profiles, then auth.users.
- Storage cleanup: recursively deletes the user's prefix in catch-media, forum-media, and voice-notes buckets.
- All attempts (success and failure) are written to account_lifecycle_audit for compliance.
- JWT identity is the only acceptable user identifier — users can only delete their own account.
- Common errors: 400 (missing/invalid confirmationText), 401 (no/invalid JWT), 403 (feature flag off), 429 (rate limited), 500 (deletion failure — partial state recorded in audit log).

---

## Angler Profile

**GET** `/functions/v1/angler-profile`

Get profile info for a specific member by member_id.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID (also accepts legacy angler_id) |

---

## Member Details

**GET** `/functions/v1/member-details`

Returns member profile with preferences, proficiencies, and gear. Sources from community_field_definitions + member_field_values with legacy fallback.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID (also accepts legacy angler_id) |
| community_id | uuid | ❌ | Community UUID (auto-detected if omitted) |

**Response:**

- `member_id`: uuid
- `member_number`: string
- `first_name`: string
- `last_name`: string
- `preferences`: array of field objects or legacy format
- `proficiencies`: array of field objects or legacy format
- `gear`: array of field objects or legacy format

---

## Member Profile Fields — GET

**GET** `/functions/v1/member-profile-fields`

Returns community field definitions with the current member's saved values merged in.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |
| category | string | ❌ | Filter: gear, preference, or proficiency |

---

## Member Profile Fields — POST

**POST** `/functions/v1/member-profile-fields`

Upsert member field values. Accepts array of objects with field_name or field_definition_id.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |
| fields | array | ✅ | Array of { field_name|field_definition_id, value } |

---

## Upload Catch Reports v5

**POST** `/functions/v1/upload-catch-reports-v5`

Upload catch reports with conservation research fields. Writes to catch_reports table. Supports dual photos (full fish + back of head), research identifiers (Floy ID, PIT ID, sample envelope barcode + declared contents), initial and actual girth/weight, and conservation opt-in.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| reportId | uuid | ✅ | Client-generated report UUID |
| createdAt | iso8601 | ✅ | Catch timestamp |
| tripId | uuid | ✅ | Trip UUID (auto-creates solo trip if not found) |
| tripName | string | ❌ | Trip name (fallback lookup / solo trip name) |
| communityId | uuid | ❌ | Community UUID (inferred if guide has one community) |
| catch.memberId | string | ✅ | Member number (human-readable) |
| catch.species | string | ✅ | Species name |
| catch.lengthInches | number | ✅ | Fish length in inches |
| catch.sex | string | ❌ | Fish sex |
| catch.river | string | ❌ | River name |
| catch.lifecycleStage | string | ❌ | e.g. Adult, Juvenile |
| catch.girthInches | number | ❌ | Final confirmed girth (inches) |
| catch.weightLbs | number | ❌ | Final confirmed weight (lbs) |
| catch.initialGirthInches | number | ❌ | Initial girth estimate before correction |
| catch.initialWeightLbs | number | ❌ | Initial weight estimate before correction |
| catch.floyId | string | ❌ | Floy tag alphanumeric ID |
| catch.pitId | string | ❌ | PIT tag alphanumeric ID |
| catch.scaleEnvelopeId | string | ❌ | Scanned barcode of the Scale sample envelope |
| catch.finEnvelopeId | string | ❌ | Scanned barcode of the Fin sample envelope |
| catch.conservationOptIn | boolean | ❌ | Conservation data sharing opt-in (default false) |
| catch.mlTrainingOptOut | boolean | ❌ | Set true to opt this report OUT of being used to train ML models. Default false (data CAN be used). |
| catch.location.lat | number | ❌ | Latitude |
| catch.location.lon | number | ❌ | Longitude |
| catch.photo | object | ❌ | Full fish photo: { filename, mimeType, data_base64 } or { url } |
| catch.headPhoto | object | ❌ | Back-of-head photo: { filename, mimeType, data_base64 } or { url } |
| catch.voiceMemo | object | ❌ | Voice memo: { filename, mimeType, data_base64, transcript?, language? } |
| weightEstimation | object | ❌ | Weight estimation metadata blob (stored as JSONB) |
| initialAnalysis | object | ❌ | ML analysis: { riverName, species, lifecycleStage, sex, lengthInches, mlFeatures, lengthSource, modelVersion } |
| meta.appVersion | string | ✅ | App version string |
| meta.device | string | ❌ | Device model |
| meta.platform | string | ❌ | OS platform |

**Response:**

- `version`: v5
- `processed`: number
- `successful`: number
- `skipped`: number
- `failed`: number
- `results`: array of { reportId, id, status, tripId, anglerId }
- `errors`: array of { reportId, error }

**Notes:**

- Writes to catch_reports table (legacy v1 table has been removed).
- Removed fields from v4: origin, tactic, quality, tag_id, notes, classified_waters_license.
- New dual-photo support: photo (full fish) + headPhoto (back of head). Head photo is stored but not displayed to users.
- If tripId doesn't exist, a 'Solo Fishing Trip' is auto-created.
- Enrichment (weather, tides, moon phase) is triggered automatically after insert.

---

## Download Catch Reports

**GET** `/functions/v1/download-catch-reports`

Download catch reports as JSON for a community or member.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ❌ | Filter by community |
| member_id | uuid | ❌ | Filter by member |
| from_date | string | ❌ | Start date YYYY-MM-DD |
| to_date | string | ❌ | End date YYYY-MM-DD |

---

## Catch Report Media

**POST** `/functions/v1/catch-report-media`

Upload additional media to an existing catch report.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| catch_report_id | uuid | ✅ | Catch report UUID |
| files[] | array | ✅ | Array of { filename, mimeType, data_base64 } |

---

## Catch Story

**POST** `/functions/v1/catch-story`

Generate an AI narrative for a catch report. Uses community-specific prompt if configured.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| catch_report_id | uuid | ✅ | Catch report UUID |

**Response:**

- `title`: string
- `summary`: string (AI-generated narrative)

**Notes:**

- Uses community-specific custom prompt if one exists for the 'catch_story' prompt_type.

---

## Upload No-Catch Reports

**POST** `/functions/v1/upload-no-catch-reports`

Report non-catch events (active fishing, farmed out, promising water, passed water).

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| reportId | uuid | ✅ | Client-generated report UUID |
| createdAt | iso8601 | ✅ | Event timestamp |
| eventType | string | ✅ | active, farmed, promising, or passed |
| communityId | uuid | ✅ | Community UUID |
| memberId | string | ✅ | Member number |
| river | string | ❌ | River name |
| guideName | string | ❌ | Guide name |
| location.lat | number | ✅ | Latitude |
| location.lon | number | ✅ | Longitude |
| meta.appVersion | string | ✅ | App version |
| mlTrainingOptOut | boolean | ❌ | Set true to opt this report OUT of being used to train ML models. Default false (data CAN be used). |

---

## Map Reports

**GET** `/functions/v1/map-reports`

Unified catch and no-catch map pin data. Role-based: members see own data, guides/admins/researchers see all community data.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |
| member_id | uuid | ❌ | Filter by member |
| from_date | string | ❌ | Start date YYYY-MM-DD |
| to_date | string | ❌ | End date YYYY-MM-DD |

**Response:**

- `reports`: array of { type, lat, lon, river, created_at, water_temp_c, water_level_ft, species?, lengthInches?, eventType? }

**Notes:**

- type is one of: catch, active, farmed, promising, passed
- water_temp_c (Celsius) and water_level_ft (feet) come from server-side enrichment; null if the report has not been enriched or the value was unavailable.

---

## Manage Trip

**GET | POST | PUT | DELETE** `/functions/v1/manage-trip`

CRUD operations for trips scoped to a community.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID (GET) |
| trip_id | uuid | ❌ | Trip UUID (GET single, PUT, DELETE) |

---

## Trip Roster

**GET | POST | DELETE** `/functions/v1/trip-roster`

Manage trip roster assignments. Returns member_id (UUID) without legacy angler_id aliases.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| trip_id | uuid | ✅ | Trip UUID |

---

## Join Community

**POST** `/functions/v1/join-community`

Join a community using its code. Requires a valid member_number tied to the pending invite for this community + email.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| community_code | string | ✅ | 6-char community code |
| member_number | string | ✅ | 9-char MAD-format member number from the invite email |
| role | string | ❌ | Optional; ignored if invite has a role |

**Notes:**

- Returns 400 if member_number is missing.
- Returns 403 'Invalid member number for this community' if member_number does not match the pending invite.

---

## Manage Community

**POST** `/functions/v1/manage-community`

Create or update a community. Admin-only (or community admin for update).

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | ✅ | 'create' or 'update' |
| community_id | uuid | ❌ | Required for update |
| name | string | ❌ | Community name |
| community_type_id | uuid | ❌ | Community type |
| is_active | boolean | ❌ | Active status |
| logo_url | string | ❌ | Logo image URL |
| logo_asset_name | string | ❌ | Bundled asset fallback |
| tagline | string | ❌ | Short tagline |
| display_name | string | ❌ | Display name |
| geography | object | ❌ | Geography config (rivers/water bodies) |
| learn_url | string | ❌ | DEPRECATED — use custom_urls. Mirrors first custom_urls entry for legacy clients. |
| custom_urls | array | ❌ | Up to 5 named links: [{ name: string (≤100), url: string (≤2048) }, ...]. Empty array clears. |
| units | string | ❌ | 'imperial' or 'metric' |
| donation_url | string | ❌ | Optional single donation URL (≤2048 chars). Pair with donation_description. Send empty string or null to clear. |
| donation_description | string | ❌ | Optional description for the donation link (≤500 chars). When donation_url is set, this should be populated to describe the cause/purpose. |

**Notes:**

- Response includes is_active: false for inactive communities; app must handle this state.
- custom_urls replaces the single learn_url. Mobile apps should render the array as a list of named links (e.g. on a community profile/learn screen). learn_url remains populated with the first entry's URL for backward compatibility but will be removed in a future release.
- Validation: max 5 entries, each entry requires non-empty name (≤100 chars) and url (≤2048 chars). Violations return 400.
- donation_url and donation_description are optional. When donation_url is populated, the configuration package returned to clients will include both fields so apps can render a 'Donate' link with a description. If donation_url is empty/null, both fields will be null.

---

## Community Members

**GET | POST | PUT | DELETE** `/functions/v1/community-members`

Manage community membership. Uses 'members' table with member_number identifier.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |

---

## Angler Context

**GET** `/functions/v1/angler-context`

Get contextual information for AI-powered features.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID |
| community_id | uuid | ❌ | Community UUID |

---

## Angler Forecast

**GET** `/functions/v1/angler-forecast`

Get AI-powered fishing forecast.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID |

---

## Data Enrichment (Catch)

**POST** `/functions/v1/enrich-catch-report`

Enrich a catch report with weather, tide, moon phase, and environmental data.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| catch_report_id | uuid | ✅ | Catch report UUID |

**Response:**

- `air_temperature`: number | null
- `water_temperature`: number | null
- `wind_speed`: number | null
- `humidity`: number | null
- `atmospheric_pressure`: number | null
- `cloud_cover`: number | null
- `precipitation_24h`: number | null
- `moon_phase`: string | null
- `flow_rate_cfs`: number | null
- `water_level`: number | null
- `is_tidal_river`: boolean | null
- `sunrise_time`: string | null
- `sunset_time`: string | null
- `sunshine_hours`: number | null
- `dew_point`: number | null
- `uv_index`: number | null
- `tidal_data`: object | null (next/previous high/low tide times and heights)

---

## Data Enrichment (No-Catch)

**POST** `/functions/v1/enrich-no-catch-report`

Enrich a no-catch report with environmental data.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| no_catch_report_id | uuid | ✅ | No-catch report UUID |

---

## Weather Snapshot

**GET** `/functions/v1/weather-snapshot`

Current conditions and 8-hour hourly forecast based on GPS coordinates.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| lat | number | ✅ | Latitude |
| lon | number | ✅ | Longitude |

---

## Water Conditions

**POST** `/functions/v1/river-conditions`

Get river/water conditions (weather, tides, hourly water levels for the past 4 days, and optional hourly water temperatures) for a configured water body. Hourly readings are served from a backend cache populated every hour by an automated collector; if the cache is empty or stale (e.g. station was just added), the function falls back to a live upstream fetch.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| date | string (YYYY-MM-DD) | ✅ | Target date |
| river | string | ✅ | Water body name (must be active for the community) |
| community_id | uuid | ❌ | Community UUID. Inferred from JWT if user has a single membership. |
| include_water_temperature | boolean | ❌ | Include hourly water temperatures when the gauge supports it. |

**Response:**

- `name`: string — water body name
- `water_type`: string — e.g. river, lake, ocean
- `station_id`: string — gauge station ID (empty if no gauge)
- `source`: string — data source (USGS, NOAA, WSC, CHS, ...)
- `isTidal`: boolean — true when the water body is tidal; tides[] is populated only when true
- `date`: string — echoed target date (YYYY-MM-DD)
- `weather`: object — { previous_day, target_day, next_day } each with high/low temp °C and precipitation mm
- `tides`: object — { previous_high, next_high, previous_low, next_low } (all null when isTidal is false)
- `water_levels`: array — hourly water level for the past 4 days (~96 entries). Each entry: { recorded_at: ISO timestamp (hour-aligned, UTC), level_ft: number | null }. Empty when the fishery has no gauge.
- `water_temperatures`: array (optional) — hourly water temperature for the past 4 days (~96 entries). Each entry: { recorded_at: ISO timestamp (hour-aligned, UTC), temp_c: number | null }. Returned only when include_water_temperature=true.

---

## Water Conditions Batch

**GET** `/functions/v1/river-conditions-batch`

Get conditions for multiple stations at once.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |

---

## Gear

**GET | POST | PUT** `/functions/v1/gear`

Manage member gear preferences. Accepts angler_id as legacy input alias.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID (also accepts angler_id) |

---

## Proficiency

**GET | POST | PUT** `/functions/v1/proficiency`

Manage member proficiency ratings. Accepts angler_id as legacy input alias.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID (also accepts angler_id) |

---

## Observations

**GET | POST** `/functions/v1/observations`

Voice memo observations with transcripts.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ❌ | Filter by community |

---

## Transcript Insights

**POST** `/functions/v1/transcript-insights`

AI-powered analysis of observation transcripts.

**Auth:** required

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| observation_id | uuid | ✅ | Observation UUID |

---

## Flight Details

**GET | POST** `/functions/v1/flight-details`

Manage flight itineraries and segments.

**Auth:** required

---

## Flight Status

**GET** `/functions/v1/flight-status`

Check real-time flight status.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| flight_number | string | ✅ | Flight number |
| date | string | ✅ | Flight date YYYY-MM-DD |

---

## Staff Bios

**GET** `/functions/v1/staff-bios`

List staff bios for a community.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |

---

## Staff Bio Detail

**GET** `/functions/v1/staff-bio-detail`

Get detailed staff bio.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| staff_id | uuid | ✅ | Staff UUID |

---

## Tactics Recommendations

**GET** `/functions/v1/tactics-recommendations`

AI-powered tactics recommendations based on conditions.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |
| member_id | uuid | ❌ | Member UUID for personalization |

---

## Classified Licenses

**GET | POST | PUT | DELETE** `/functions/v1/classified-licenses`

Manage classified waters fishing licenses.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| member_id | uuid | ✅ | Member UUID |

---

## Forum Posts

**GET | POST | PUT | DELETE** `/functions/v1/forum-posts`

Community forum threads and posts.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |
| thread_id | uuid | ❌ | Thread UUID |

---

## Ops Tickets

**GET | POST | PUT | DELETE** `/functions/v1/ops-tickets`

Kanban-based operations task management.

**Auth:** required

**Query Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| community_id | uuid | ✅ | Community UUID |

---

