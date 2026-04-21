# EmeraldWatersAnglers - iOS App

SwiftUI iOS app for fishing guides to log catch reports with AI-powered photo analysis. Built on the SkeenaSystem framework.

Roles: **Angler**, **Guide**, **Researcher**, **Public** — each has its own `Views/<Role>/` and `SkeenaSystemTests/<Role>/` directory.

## Rules (read first)
- Open `SkeenaSystem.xcworkspace`, never the `.xcodeproj` (CocoaPods).
- Scheme: **`SkeenaSystem`** (the only app scheme). Default simulator: **iPhone 17 Pro**.
- `DevTEST` is a **build configuration**, not a scheme. The `SkeenaSystem` scheme's Test action already targets it — don't pass `-scheme SkeenaSystem` to `xcodebuild`, it will fail.
- Swift default actor isolation is set to `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in `project.pbxproj`). Any unannotated `final class` with no stored properties that gets stored inside a SwiftUI View can crash on destroy via `swift_task_deinitOnExecutorMainActorBackDeploy` → `TaskLocal::StopLookupScope` on iOS 26.2 sim. Mark such service classes `nonisolated` (see `UploadObservations.swift` for an example + explanation).
- **Never** add MediaPipe (`MediaPipeTasksVision`) to the `SkeenaSystemTests` target — causes duplicate-symbol crashes. Test target gets headers via search paths only.
- `libz.tbd` must stay linked on **both** SkeenaSystem and SkeenaSystemTests targets.
- When adding a species class, update **all three** in lockstep: the `speciesLabels` array (must match training ImageFolder alphabetical order), `speciesDisplayNames` in `CatchChatViewModel`, and retrain/ship a new `ViTFishSpecies.mlpackage`.
- Below-threshold species detection returns the string `"Species: Unable to confidently detect"`, never `nil`.
- `splitSpecies()` only treats the trailing words `holding` / `traveler` as lifecycle stages — don't add more without updating the parser.
- ⚠️ `UPLOAD_CATCH_V3_URL` in Info.plist currently points at the **v4** endpoint. The key name is legacy; don't rename without a migration.

## Build & Test
```
# Build
xcodebuild -workspace SkeenaSystem.xcworkspace -scheme SkeenaSystem \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Test
xcodebuild -workspace SkeenaSystem.xcworkspace -scheme SkeenaSystem \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```
Test conventions: `*RegressionTests.swift` files guard role-specific UI/flow regressions (see `SkeenaSystemTests/Guide/GuideLandingRegressionTests.swift`). Prefer a regression test when changing role landing views, entitlements, or public-facing UI.

## ML Pipeline — `SkeenaSystem/Managers/CatchPhotoAnalyzer.swift`
Ordered stages:
1. **YOLOv8 detection** (`best.mlpackage`) — fish + person boxes
2. **ViT species** (`ViTFishSpecies.mlpackage`, vit_tiny_patch16_224). Input `"image"` 1×3×224×224, output `"logits"`. Class list: see `speciesLabels` (source of truth).
3. **ViT sex** (`ViTFishSex.mlpackage`)
4. **MediaPipe hand landmarks** (`hand_landmarker.task`) — guarded by `#if canImport(MediaPipeTasksVision)`
5. **26-feature vector** — box ratios, hand measurements, species index, image metadata
6. **CoreML length regressor** (`LengthRegressor.mlmodel`, tree-based) → inches
7. **Heuristic fallback** when regressor unavailable or species bypasses it (e.g. `sea_run_trout`)
8. **Confidence score** from available signals (person, hand, fish)

Species confidence threshold: `SPECIES_DETECTION_THRESHOLD` in Info.plist / `AppEnvironment` (source of truth — do not hardcode in docs).

## Upload API — `SkeenaSystem/Managers/UploadCatchReport.swift`
- Endpoint: `UPLOAD_CATCH_V3_URL` Info.plist key (points at v4 — see Rules).
- v4 `initialAnalysis` adds `mlFeatures` (26-feature JSONB) and `lengthSource` ∈ `"regressor" | "heuristic" | "manual"`.
- `modelVersion` is read from CoreML model metadata and sent in `InitialAnalysisDTO`.

## Backend API Reference — source of truth
The Supabase backend is managed by a separate Loveable agent and can change independently of this repo. **Before implementing or modifying any API call, re-sync the reference by running `/sync-api`** (or the curl below). The `Version` field at the top of the fetched file shows when the backend was last updated.

```bash
curl -sf "https://koyegehcwcrvxpfthkxq.supabase.co/functions/v1/api-reference?format=markdown" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtveWVnZWhjd2NydnhwZnRoa3hxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3NjE3MzMsImV4cCI6MjA4OTMzNzczM30.XVjI2BRX0-XdHQFK_Vas2jc7zZN32DCXRVKtnsbQQGk" \
  > docs/api-reference.md
```

Snapshots live at `docs/api-reference.md` (human-readable) and `docs/api-reference.json` (programmatic). These are the source of truth for endpoint contracts, parameter names, and response shapes — not any DTOs or URL constants inside this repo. If a DTO in Swift contradicts the reference, **trust the reference** and update the DTO.

## Project Structure
```
SkeenaSystem/
├── Authentication/     # AuthService, AuthStore, BiometricAuth, CommunityService, AppLogging
├── Config/             # Environment, DateFormatting, FeatureFlags, xcconfigs
├── Location/           # RiverLocator, WaterBodyLocator, coordinate data, LocationManager
├── Managers/           # Upload managers (Catch/Farmed/Observations), SynchTrips, TripSync,
│                       #   CatchPhotoAnalyzer, ImagePicker, FishWeightEstimator, SplashVideo
├── Models/             # Pure data models (CatchModels, CommunityModels, CatchReport,
│                       #   Observation, FarmedReport, LiveWeather) + CoreData extensions + ML models
├── Services/           # API clients: TripAPI, OpsTicketsAPI, MapReportService, WeatherSnapshot,
│                       #   CatchStoryService, MemberProfileFieldsAPI, APIURLUtilities
├── Stores/             # Observable state: CatchReportStore, ObservationStore, FarmedReportStore,
│                       #   PhotoStore
├── ViewModels/         # CatchChatViewModel, CatchCaptureContext, ResearcherCatchFlowManager
├── Views/
│   ├── Auth/           # LoginView, CommunityPicker, CommunitySwitcher, JoinCommunity
│   ├── Shared/         # DarkPageTemplate, SectionChrome, Toast, SplashVideoView
│   ├── Components/     # CommunityLogoView, SocialFeed
│   ├── Map/            # Map views + callout views
│   ├── Angler/         # Angler role views (landing, onboarding, trips, forecasts, catches)
│   ├── Guide/          # Guide role views (landing, trips, reports, chat, observations, ops)
│   ├── Public/         # Public role views (landing, explore, record activity)
│   └── Researcher/     # Researcher role views (landing, conservation, catch confirmation)
├── Persistence.swift   # Core Data stack + community seed
└── SkeenaSystemApp.swift
```

## Key Files
- `SkeenaSystem/Managers/CatchPhotoAnalyzer.swift` — all ML inference, `speciesLabels`, length re-estimation
- `SkeenaSystem/ViewModels/CatchChatViewModel.swift` — species parsing (`splitSpecies`), `speciesDisplayNames`, chat/report building
- `SkeenaSystem/Config/Environment.swift` — feature flags, thresholds, endpoint URLs
- `SkeenaSystem/Managers/UploadCatchReport.swift` — Supabase upload
- `SkeenaSystem/Views/Guide/ReportsListView.swift` — report list + upload trigger
- `SkeenaSystem/Views/Shared/DarkPageTemplate.swift` — shared dark-theme page chrome used across role landing views

## Logging
`AppLogging` with categories `.ml`, `.catch`, `.upload`, etc. ML pipeline logs at `.debug` on `.ml`.
