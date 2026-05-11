# SkeenaSystem (Mad Thinker Mobile App) — Codebase Summary

## 1. Directory Structure

| Folder / File | Contents |
|---|---|
| `SkeenaSystem/` | Main iOS app source — SwiftUI views, CoreData models, ML models, managers/services, authentication, and configuration |
| `SkeenaSystem/Authentication/` | Auth service (Supabase JWT), biometric auth, community service, offline login, app logging |
| `SkeenaSystem/Config/` | xcconfig files (DevTEST, PROD), `Environment.swift` (runtime config singleton), `FeatureFlags.swift` |
| `SkeenaSystem/Managers/` | 22 service files — catch photo analysis, trip sync, upload services, OCR, location, weather, river coordinates |
| `SkeenaSystem/Models/` | Data models (Swift structs + CoreData), ML model packages, view models, persistence stores |
| `SkeenaSystem/Views/` | SwiftUI views organized by role: `Angler/`, `Guide/`, `Public/`, `Map/`, `Components/` |
| `SkeenaSystem/Forum/` | Community forum feature — ForumAPI, thread management, image caching |
| `SkeenaSystem/ViewModels/` | `ReportFormViewModel` for catch report forms |
| `SkeenaSystem/Terms/` | Terms and conditions content |
| `SkeenaSystemTests/` | Unit tests — 47 files across 14 subdirectories (Angler, Auth, Config, Forum, Guide, etc.) |
| `SkeenaSystemUITests/` | UI tests — 3 files (launch tests, guide login, database reset client) |
| `.github/` | CI/CD workflows (currently disabled), Dependabot config |
| `.git-hooks/` | Git hooks for code quality |
| `Scripts/` | Build scripts (`swiftlint.sh`) |
| `SkeenaSystem.xcodeproj/` | Xcode project |
| `SkeenaSystem.xcworkspace/` | Xcode workspace (CocoaPods integration) |
| `Podfile` / `Podfile.lock` | CocoaPods dependencies (MediaPipeTasksVision ~> 0.10.14) |

---

## 2. Data Model

### Swift Struct Models

| Model | File | Key Properties | Supabase Table |
|---|---|---|---|
| `CatchReportPicMemo` | `Models/CatchReportPicMemo.swift` | id, catchDate, status, species, sex, lengthInches, river, lat/lon, photoFilename, voiceNoteId, tripId, communityId, mlFeatureVector, lengthSource, modelVersion | `catch_reports` (via upload) |
| `Observation` | `Models/Observation.swift` | id, clientId (idempotency), status, transcript, voiceNoteId, lat/lon | `observations` (via upload) |
| `FarmedReport` | `Models/FarmedReport.swift` | id, status, eventType (active/farmed/promising/passed), guideName, lat/lon | `farmed_reports` (via upload) |
| `CatchReportDTO` | `Models/CatchModels.swift` | catch_id, latitude, longitude, river, photo_url, notes | `catch_reports` (read) |
| `CommunityMembership` | `Models/CommunityModels.swift` | id, communityId, role (guide/angler/public), nested communities | `user_communities` |
| `CommunityInfo` | `Models/CommunityModels.swift` | id, name, code, isActive, communityTypeId, logoUrl, tagline, geography | `communities` |
| `CommunityTypeInfo` | `Models/CommunityModels.swift` | id, name (Lodge/FlyShop/Conservation/MultiLodge), entitlements | `community_types` |
| `CommunityGeography` | `Models/CommunityModels.swift` | defaultRiver, lodgeRivers, defaultWaterBody, forecastLocation, defaultMapLat/Lon | JSONB in `communities` |
| `CommunityConfig` | `Models/CommunityConfig.swift` | logoUrl, tagline, displayName, entitlements, geography | Local config (merges backend + xcconfig) |
| `ForumCategory` | `Models/ForumModels.swift` | id, name, description, sort_order | `forum_categories` |
| `ForumThread` | `Models/ForumModels.swift` | id, category_id, user_id, title, is_pinned, is_locked, view_count | `forum_threads` |
| `ForumPost` | `Models/ForumModels.swift` | id, thread_id, user_id, content, is_edited, media | `forum_posts` |
| `ForumMedia` | `Models/ForumModels.swift` | id, file_name, file_type, mime_type, publicUrl | `forum_media` |
| `LicenseCountry` | `Models/LicenseRegions.swift` | US/CA enum with subdivisions | Local reference data only |
| `CatchPhotoAnalysis` | `Managers/CatchPhotoAnalyzer.swift` | riverName, species, sex, estimatedLength, featureVector, lengthSource | Transient (not persisted) |
| `LocalVoiceNote` | `Views/Guide/VoiceNoteView.swift` | id, durationSec, language, onDevice, sampleRate, format, transcript | Referenced by PicMemo/Observation |

### CoreData Entities (`SkeenaSystem.xcdatamodeld`)

| Entity | Key Attributes | Relationships |
|---|---|---|
| `CatchReport` | reportId, river, species, sex, lengthInches, status, photoPath, lat/lon | angler → TripClient, trip → Trip |
| `Trip` | tripId, name, guideName, startDate, endDate, localUpdatedAt | catches → CatchReport, clients → TripClient, lodge → Lodge |
| `TripClient` | id, name, licenseNumber | catches, trip |
| `Lodge` | lodgeId, name | community → Community, trips → Trip |
| `Community` | communityId, name | lodges → Lodge |
| `ClassifiedWaterLicense` | licNumber, water, vendor, validFrom, validTo | angler → TripClient, catchReports |
| `CDVoiceNote` | id, audioPath, transcript, durationSec, format, status | — |

### Persistence Stores (JSON file-based)

| Store | File | Directory | Manages |
|---|---|---|---|
| `CatchReportPicMemoStore` | `Models/CatchReportStore.swift` | `Documents/CatchReportsPicMemo/` | CatchReportPicMemo |
| `ObservationStore` | `Models/ObservationStore.swift` | `Documents/Observations/` | Observation |
| `FarmedReportStore` | `Models/FarmedReportStore.swift` | `Documents/FarmedReports/` | FarmedReport (auto-purges uploaded >14 days) |

---

## 3. Edge Function Inventory

### Actively Called (20 functions)

| Function | Primary Caller(s) |
|---|---|
| `upload-catch-reports-v4` | `Views/Guide/ReportsListView.swift` |
| `manage-trip` | `Views/Guide/TripAPI.swift`, `Managers/SynchTrips.swift` |
| `join-community` | `Authentication/CommunityService.swift` |
| `river-conditions` | `Views/Guide/FishingForecastRequestView.swift` |
| `tactics-recommendations` | `Views/Guide/TacticsRecommendationsView.swift` |
| `download-catch-reports` | `Views/Angler/AnglerLandingView.swift`, `Views/Public/PublicLandingView.swift` |
| `angler-forecast` | `Views/Angler/AnglerForecastView.swift` |
| `classified-licenses` | `Views/Angler/AnglerClassifiedWatersLicenseUpload.swift` |
| `catch-story` | `Views/Angler/CatchStoryService.swift` |
| `notes` | `Views/Guide/VoiceNoteView.swift` |
| `angler-profile` | `Views/Guide/TripFormView.swift` |
| `my-profile` | `Views/Angler/ManageProfileView.swift` |
| `angler-context` | `Views/Angler/AnglerAboutYou.swift` |
| `proficiency` | `Views/Angler/AnglerAboutYou.swift`, `Views/Angler/UploadAnglerContext.swift` |
| `gear` | `Views/Angler/GearChecklist.swift` |
| `observations` | `Managers/UploadObservations.swift` |
| `ops-tickets` | `Views/Guide/OpsTicketsAPI.swift`, `OpsTicketCreateView`, `OpsTicketDetailView`, `OpsTicketsListView` |
| `forum-posts` | `Forum/ForumAPI.swift` |
| `weather-snapshot` | `Managers/WeatherSnapshotService.swift`, `Views/LandingView.swift` |
| `map-reports` | `Managers/MapReportService.swift`, `Views/LandingView.swift` |

### Defined but Usage Unclear (6 functions)

| Function | Caller |
|---|---|
| `flight-details` | `Views/Angler/AnglerFlights.swift` |
| `flight-status` | `Views/Angler/AnglerFlights.swift` |
| `staff-bios` | `Views/Angler/MeetStaff.swift` |
| `staff-bio-detail` | `Views/Angler/StaffDetailView.swift` |
| `trip-roster` | `Views/Guide/AnglerProfilesView.swift` |
| `angler-details` | `Views/Guide/AnglerProfilesView.swift` |

### Test-Only (1 function)

| Function | Caller |
|---|---|
| `reset-database` | `SkeenaSystemUITests/ResetDatabaseClient.swift` |

All endpoints are configured in `Config/Environment.swift` and overridable via Info.plist keys. Authentication uses `SUPABASE_ANON_KEY` plus bearer tokens from `AuthService`.

---

## 4. Feature Flags

### Entitlement Flags (E_*)

Resolution chain: backend `community_types.entitlements` JSONB → xcconfig fallback via `readEntitlement()` → `false`.

| Flag | DevTEST Default | PROD Default | Used In |
|---|---|---|---|
| `E_FLIGHT_INFO` | false | true | `AnglerTripPrepView` — shows "Add flights" link |
| `E_MEET_STAFF` | true | true | `AnglerTripPrepView` — shows staff directory |
| `E_GEAR_CHECKLIST` | false | true | `AnglerTripPrepView` — shows gear checklist |
| `E_MANAGE_LICENSES` | false | true | `AnglerTripPrepView` — shows license management |
| `E_SELF_ASSESSMENT` | true | true | `AnglerTripPrepView` — shows self-assessment |
| `E_CATCH_CAROUSEL` | true | true | `AnglerLandingView`, `PublicLandingView` — recent catches carousel |
| `E_THE_BUZZ` | true | true | `AnglerLandingView` — forum threads section |
| `E_CATCH_MAP` | true | true | `AnglerLandingView`, `PublicLandingView` — map button in header |
| `E_MANAGE_OPS` | false | true | `LandingView` (guide) — ops tickets toolbar item |

### Compile-Time Flags

| Flag | Usage |
|---|---|
| `#if DEBUG` | 41+ locations — extra logging, preview canvases, diagnostic output |
| `#if canImport(MediaPipeTasksVision)` | `CatchPhotoAnalyzer.swift` — hand landmark detection (falls back silently) |
| `#if canImport(UIKit)` | `CatchChatViewModel.swift`, `CatchChatView.swift` — clipboard operations |
| `if #available(iOS 16.0, *)` | `CatchPhotoAnalyzer.swift`, `ScrollContentBackgroundCompat.swift` |

### Other Runtime Config

| Key | Purpose |
|---|---|
| `BETA_RELEASE` (DevTEST: true, PROD: not defined) | Shows beta badge on `LoginView` |
| `@AppStorage("hasSeenGuideCameraLocationOnboarding")` | One-time onboarding gate |

---

## 5. CoreML Models

| Model | Type | Location | Purpose | Invoked In |
|---|---|---|---|---|
| `best.mlpackage` | YOLOv8 Object Detection | `Models/best.mlpackage` | Detects fish and person bounding boxes (640x640 input, ~8400 anchors) | `CatchPhotoAnalyzer.runDetector(on:)` (line 941) |
| `ViTFishSpecies.mlpackage` | Vision Transformer Classification | `Models/ViTFishSpecies.mlpackage` | Classifies species: sea_run_trout, steelhead_holding, steelhead_traveler (confidence threshold 0.3) | `CatchPhotoAnalyzer.runViT(on:)` (line 274) |
| `ViTFishSex.mlpackage` | Vision Transformer Classification | `Models/ViTFishSex.mlpackage` | Classifies sex: male, female (iOS 16+) | `CatchPhotoAnalyzer.runSexClassifier(on:)` (line 345) |
| `LengthRegressor.mlmodel` | Regression | `Models/LengthRegressor.mlmodel` | Predicts fish length in inches from 26-feature vector (fish box, person ratio, hand measurements, species) | `CatchPhotoAnalyzer.predictLength(from:)` (line 786) |
| `hand_landmarker.task` | MediaPipe Hand Landmarks | Root directory | Detects hand landmarks for finger-based scale reference (conditional on MediaPipeTasksVision) | `CatchPhotoAnalyzer.detectHand(on:)` (line 383) |

**ML Pipeline** (`CatchPhotoAnalyzer.analyze(image:location:)`):
1. Location → river name lookup
2. YOLOv8 → fish & person bounding boxes
3. ViT Species → species classification
4. ViT Sex → sex classification
5. MediaPipe → hand finger measurements (optional)
6. Length Regressor → predicted length (fallback: heuristic pixel-based estimation)

**OCR** (not CoreML but Vision framework):
- `VNRecognizeTextRequest` in `LicenseTextRecognizer.swift` — OCR on fishing license images, recognition level `.accurate`, languages en-CA/en-US.

---

## 6. Offline/Sync Architecture

### Storage Layers

| Layer | Mechanism | Data |
|---|---|---|
| CoreData (SQLite) | `PersistenceController` with `NSMergeByPropertyObjectTrumpMergePolicy` | Trips, TripClients, CatchReports, Lodges, Communities, ClassifiedWaterLicenses, VoiceNotes |
| JSON File Stores | Per-entity directories in Documents/ | CatchReportPicMemo, Observation, FarmedReport |
| UserDefaults | Key-value | Community state, onboarding flags, offline login email |
| Keychain | Secure storage | JWT access/refresh tokens, token expiry, offline password |

### Sync Mechanisms

| Data Type | Direction | Trigger | Service |
|---|---|---|---|
| Trips | Bidirectional | Manual on `LandingView.onAppear` | `TripSyncService.syncTripsIfNeeded()` |
| Catch Reports (PicMemo) | Local → Server | User taps upload button | `UploadCatchReport` |
| Observations | Local → Server | User taps upload button | `UploadObservations` |
| Farmed Reports | Local → Server | User taps upload button | `UploadFarmedReports` |
| Catch Reports (download) | Server → Local | On landing view load | `download-catch-reports` edge function |

### Conflict Resolution

| Layer | Strategy | Field |
|---|---|---|
| Trips | Last-Write-Wins (timestamp) | `Trip.localUpdatedAt` — server timestamp > local → server wins, else local wins |
| Catch/Observation/Farmed | None (unidirectional) | `status` field — uploaded once, treated as immutable |
| CoreData merge | Property-object trump | `NSMergeByPropertyObjectTrumpMergePolicy` |

### Offline Authentication

- On network failure, `AuthService.signIn()` checks cached credentials in Keychain (`OfflineLastEmail`, `OfflineLastPassword`)
- Restores cached profile from UserDefaults (`CachedFirstName`, `CachedUserType`, `CachedMemberId`)
- Remember Me default: guides ON, anglers OFF

### Limitations

- No persistent upload queue — retries depend on manual user action
- No background sync — foreground-only, manual trigger
- No Supabase Realtime subscriptions
- No NWPathMonitor — passive error handling on URLError
- No differential sync — full trip data fetched each time

---

## 7. Role-Based Routing

### Role Definition

```swift
// AuthService.swift, line 84
enum UserType: String, Codable { case angler, guide, `public` }
```

### Role Determination Flow

1. User logs in → `AuthService.signIn()`
2. `CommunityService.fetchMemberships()` fetches from `user_communities` table (each membership has a `role` field)
3. `CommunityService.setActiveCommunity(id:)` extracts role and syncs to `AuthService.currentUserType`
4. Users can belong to multiple communities with different roles; switching communities changes the active role

### Routing (`AppRootView.swift`, lines 44-51)

| Condition | View |
|---|---|
| Not authenticated | `LoginView` |
| Authenticated, no community selected | `CommunityPickerView` |
| `currentUserType == .guide` | `LandingView` |
| `currentUserType == .angler` | `AnglerLandingView` |
| `currentUserType == .public` | `PublicLandingView` |

### Role-Specific Toolbars (`DarkPageTemplate.swift`)

| Role | Toolbar Tabs |
|---|---|
| Guide | Home, Trips, Catches, Social, Observations |
| Angler | Home, My Trip, Conditions, Learn, Social |
| Public | Home, Catches, Conditions, Social, Learn |

Shared views use `@Environment(\.userRole)` (custom `AppUserRole` environment key, default `.angler`) to render the correct toolbar via `RoleAwareToolbar`.

### Role-Specific Features

- **Guide**: Record activity, manage trips, observations, ops tickets (E_MANAGE_OPS), trip sync, guide onboarding
- **Angler**: Trip prep (slide-in panel), catch carousel, The Buzz forum, profile management, learn tactics
- **Public**: Record activity (alwaysSolo mode), catch reporting without trip context, no trip sync

---

## 8. Dead Code Candidates

| Item | File(s) | Evidence |
|---|---|---|
| **SynchTrips** (duplicate trip sync) | `Managers/SynchTrips.swift` (28 KB) | Only `TripSyncService` is called (`LandingView.swift:157`). `SynchTrips` is never referenced. |
| **TripNotifications** | `Managers/TripNotifications.swift` | Defines `Notification.Name.tripDidChange` — never posted or observed anywhere. |
| **MediaPipe hand detection** | `Managers/CatchPhotoAnalyzer.swift` (conditional), `hand_landmarker.task` (7.8 MB), `Podfile` | Wrapped in `#if canImport(MediaPipeTasksVision)`. Falls back silently when unavailable. Called out as likely removal. |
| **Forum feature** | `Forum/` directory (11 files), `Models/ForumModels.swift`, `AuthService+ForumSupport.swift` | Called out as likely removal. `AuthService+ForumSupport.swift` has no direct references from forum views. |
| **Classified Waters Extractor** | `Managers/ClassifiedWatersExtractor.swift` | Called out as likely removal. Used only in `LicenseTextRecognizer.swift` and `AnglerClassifiedWatersLicenseUpload.swift`. |
| **Fuzzy label matching** | `Managers/FSELicense_BCFuzzyLabels.swift` (if present) | Called out as likely removal. |
| **Trip sync (legacy)** | `Managers/SynchTrips.swift` | Called out as likely removal. Replaced by `TripSyncService`. |
| **WaterBodyCoordinates** | `Managers/WaterBodyCoordinates.swift` | No references found. Likely superseded by `WaterBodyLocator`. |
| **Commented-out preview code** | `Views/DarkPageTemplate.swift` (lines 271-326) | Large block of commented-out SwiftUI preview examples. |

---

## 9. Test Coverage

### Summary

| Category | Count |
|---|---|
| Unit test files | 47 |
| Unit test classes | 45 |
| Unit test functions | **685** |
| UI test files | 3 |
| UI test functions | **3** |
| Total test functions | **688** |
| Test infrastructure files | 3 (MockURLProtocol, TestGeographySetup, ResetDatabaseClient) |

### Unit Tests by Module

| Module | Files | Tests | Key Files |
|---|---|---|---|
| Guide | 10 | 230 | CatchChatViewModelTests (60), FarmedReportTests (33), ReportFormViewModelTests (26) |
| Authentication | 10 | 116 | CommunityServiceTests (31), LoginAuthRegressionTests (25), AuthServiceRegressionTests (21) |
| Views | 4 | 59 | DarkPageTemplateTests (20), CatchFlowRegressionTests (15), PublicRoleViewTests (14) |
| Configuration | 6 | 51 | ConfigurationSnapshotTests (13), ExternalizedConfigTests (11), APIURLUtilitiesTests (10) |
| Upload | 2 | 49 | UploadCatchReportTests (26), UploadFarmedReportsTests (23) |
| Location | 2 | 36 | RiverLocatorTests (18), WaterBodyLocatorTests (18) |
| Angler | 2 | 35 | AnglerLandingViewTests (20), CatchStoryServiceTests (15) |
| Forum | 3 | 27 | CreateThreadViewTests (11), ForumAPITests (8), ForumImageCacheTests (8) |
| Models | 1 | 26 | CommunityConfigTests (26) |
| Sync | 2 | 24 | TripSyncServiceTests (17), TripOrphanRemovalTests (7) |
| Persistence | 1 | 17 | PersistenceTests (17) |
| OCR | 1 | 9 | LicenseTextRecognizerTests (9) |
| Map | 1 | 6 | MapPinImageTests (6) |

### Not Directly Tested

- **Views**: CommunityForumView, ThreadDetailView, ThreadsListView, AnglerAboutYou, CachedAsyncImage, ForumMediaGrid
- **Managers**: LocationManager, MapReportService, ImagePicker, SplashVideoManager, WeatherSnapshotService, UploadObservations, WaterBodyCoordinates
- **Models**: CatchModels, ForumModels, LicenseRegions, ObservationStore
- **App-level**: SkeenaSystemApp, AuthService+ForumSupport, AppLogging

### UI Tests

- `testLaunchPerformance()` — app launch time
- `testGuideLogin()` — guide login flow
- `testLaunch()` — basic launch
- Uses `ResetDatabaseClient` to reset database state before tests

---

## 10. Config & Secrets

### Configuration Files

| File | Purpose |
|---|---|
| `Config/DevTEST.xcconfig` | Development environment defaults |
| `Config/PROD.xcconfig` | Production environment defaults |
| `Config/Secrets.xcconfig` | Mapbox token (gitignored) |
| `Config/Environment.swift` | `AppEnvironment` singleton — reads Info.plist at runtime, supports overrides |
| `Config/FeatureFlags.swift` | `readEntitlement()` — reads E_* flags from Info.plist |
| `Info.plist` | Receives substituted xcconfig values at build time |

### Dev vs Prod Switching

Build configuration selects the xcconfig file:
```
Debug / DevTEST build → DevTEST.xcconfig → Info.plist → AppEnvironment
Release / PROD build → PROD.xcconfig → Info.plist → AppEnvironment
```

Key differences:

| Setting | DevTEST | PROD |
|---|---|---|
| `LOG_LEVEL` | debug | error |
| `UPLOAD_CATCH_URL` | upload-catch-reports-v4 | upload-catch-reports-v3 |
| `SPECIES_DETECTION_THRESHOLD` | 0.5 | 0.80 |
| `SPLASH_VIDEO_FREQUENCY` | FIRST_LOGIN | ALWAYS |
| `APP_DISPLAY_NAME` | Epic Waters | Bend Fly Shop |
| `DEFAULT_RIVER` | Hoh River | Nehalem |
| `FORECAST_LOCATION` | Western Washington | Oregon Coast |
| Feature flags (E_FLIGHT_INFO, E_GEAR_CHECKLIST, E_MANAGE_LICENSES, E_MANAGE_OPS) | false | true |

### Secret References

| Secret | Storage | Location |
|---|---|---|
| `SUPABASE_PROJECT_URL` | xcconfig (committed) | Both xcconfig files |
| `SUPABASE_ANON_KEY` | xcconfig (committed — comment says "Use CI to inject real anon key") | Both xcconfig files |
| `MAPBOX_ACCESS_TOKEN` | `Secrets.xcconfig` (gitignored) | Included via `#include?` in DevTEST.xcconfig |
| JWT access token | Keychain (`epicwaters.auth.access_token`) | Runtime |
| JWT refresh token | Keychain (`epicwaters.auth.refresh_token`) | Runtime |
| Token expiry | Keychain (`epicwaters.auth.access_token_exp`) | Runtime |
| Offline password | Keychain (`OfflineLastPassword`) | Runtime, only if Remember Me enabled |

### CI/CD

| File | Status | Notes |
|---|---|---|
| `.github/workflows/ci.yml.disabled` | Disabled | SwiftLint, SwiftFormat, Build, Unit Tests |
| `.github/workflows/release.yml.disabled` | Disabled | PROD build, TestFlight upload. References GitHub Secrets for certificates, App Store Connect API keys |
| `.github/dependabot.yml` | Active | Weekly SPM and GitHub Actions updates |
