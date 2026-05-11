# SkeenaSystem iOS Codebase Evaluation

**Date:** 2026-04-13
**Total Swift files:** 116 | **Total lines:** ~38,000 | **Test files:** 50 (~11,500 lines)

---

## 1. ARCHITECTURE

**Pattern:** Hybrid MVVM with Service Layer — inconsistently applied.

The app uses SwiftUI views with `@Published` / `ObservableObject` bindings, but only **1 dedicated ViewModel file** exists (`ReportFormViewModel.swift`, 162 lines) for 64+ view files. Most business logic lives in views directly or in "Manager" singletons that double as ViewModels.

### Consistency Issues

| Pattern | Expected (MVVM) | Actual |
|---------|-----------------|--------|
| View → ViewModel binding | All views have a ViewModel | ~5% of views use a dedicated VM |
| API calls | In ViewModel or Service layer | Embedded as private enums inside views (`PicMemoUploadAPI`, `AnglerAboutYouAPI`, `OpsTicketsAPI`, `TripAPI`) |
| Service access | Injected into ViewModels | Singletons called directly from views (`AuthService.shared`, `CommunityService.shared`) |
| Core Data access | Repository/Store abstraction | Direct `@FetchRequest` in views (acceptable SwiftUI convention) |
| State management | ViewModel `@Published` | Mix of `@State`, `@StateObject`, and singleton `.shared` properties |

### Top-Level Directory Structure

```
SkeenaSystem/
├── Authentication/           # 5 files — AuthService, CommunityService, BiometricAuth, logging
├── Config/                   # 2 files — AppEnvironment, FeatureFlags
├── Forum/                    # 10 files — ForumAPI + all forum views/components
├── Managers/                 # 23 files — Upload managers, ML, location, sync, utilities
├── Models/                   # 14 files — DTOs, Core Data extensions, JSON stores, CatchChatViewModel
├── ViewModels/               # 1 file — ReportFormViewModel (only dedicated VM)
├── Views/
│   ├── Angler/               # 16 files — Angler-facing screens
│   ├── Guide/                # 24 files — Guide-facing screens + embedded API files
│   ├── Map/                  # 5 files — MapKit views and callouts
│   ├── Public/               # 2 files — Public role landing
│   └── Components/           # 1 file — CommunityLogoView
├── Terms/                    # 1 file — TermsStore
├── Assets.xcassets/          # Colors, images
├── SkeenaSystem.xcdatamodeld/ # Core Data schema (2 versions)
├── Persistence.swift         # Core Data stack setup
├── SkeenaSystemApp.swift     # App entry point
├── Info.plist
└── SkeenaSystem.entitlements
```

---

## 2. CODE BREAKDOWN BY LINE COUNT

| Layer | Lines | % | Notes |
|-------|------:|--:|-------|
| **UI / View layer (SwiftUI)** | ~23,500 | 62% | 100% SwiftUI — zero UIKit views. UIKit used only for `UIViewControllerRepresentable` wrappers (ImagePicker, SplashVideo). |
| **Networking / API** | ~4,600 | 12% | AuthService (1,207), ForumAPI (520), UploadCatchReport (616), TripAPI (289), OpsTicketsAPI (246), upload managers, weather service |
| **ML pipeline** | ~2,150 | 6% | CatchPhotoAnalyzer (1,304), LicenseTextRecognizer (842), plus 4 CoreML models and 1 MediaPipe model |
| **Business logic / domain models** | ~1,800 | 5% | DTOs, CommunityModels, CatchReportPicMemo, FarmedReport, Observation, LicenseRegions, CatchChatViewModel (827) |
| **Offline storage / sync** | ~2,300 | 6% | Persistence.swift, CatchReportStore, ObservationStore, FarmedReportStore, SynchTrips (719), TripSyncService (187), PhotoStore |
| **Utilities / helpers** | ~2,100 | 5% | RiverCoordinates (595), WaterBodyLocator, RiverLocator, ClassifiedWatersExtractor, DateParsing, ForumImageCache (221) |
| **Config / app lifecycle** | ~700 | 2% | Environment (508), FeatureFlags, AppLogging, entrypoint |
| **Forum (mixed view + API)** | ~2,250 | 6% | Feature module with its own API, views, cache, models |

**UI framework:** 100% SwiftUI. No storyboards, no xibs, no UIKit view controllers (only UIKit bridging for camera picker and video player).

---

## 3. SUPABASE INTEGRATION

### Communication Method

**Raw URLSession — no Supabase Swift SDK.** Every API call constructs `URLRequest` manually with `URLSession.shared.data(for:)`. There is no centralized API client.

### API Pattern

The app uses a **decentralized, per-domain API enum pattern**:

```
Feature → Private API Enum → URLSession → Supabase Edge Function or PostgREST
```

Each feature defines its own enum with static methods for endpoint construction and response parsing. Several of these are **embedded directly inside view files**.

### Configuration

| Key | Source | Value |
|-----|--------|-------|
| `API_BASE_URL` | Info.plist (from xcconfig) | `koyegehcwcrvxpfthkxq.supabase.co` |
| `SUPABASE_ANON_KEY` | Info.plist (from xcconfig) | Anonymous key (not committed — Secrets.xcconfig in .gitignore) |
| Base URL | `AppEnvironment.shared.projectURL` | `https://{API_BASE_URL}` |

### Authentication Flow

1. Login: `POST /auth/v1/token` (grant_type=password)
2. JWT stored in Keychain (`epicwaters.auth.access_token`, `epicwaters.auth.refresh_token`, `epicwaters.auth.access_token_exp`)
3. Refresh: `POST /auth/v1/token` (grant_type=refresh_token), with concurrency-safe single-flight refresh
4. All requests include: `apikey: {SUPABASE_ANON_KEY}` + `Authorization: Bearer {JWT}`
5. Retry on transient errors (429, 5xx) with 1s delay; clear tokens on 400/401

### All Endpoints (32 total)

**Auth (6):** signup, token (password + refresh), recover, logout, user (GET + PATCH)

**Edge Functions (16):**
upload-catch-reports-v4, manage-trip, river-conditions, tactics-recommendations, download-catch-reports, angler-forecast, classified-licenses (CRUD), catch-story, notes, angler-profile, my-profile, angler-context, proficiency, gear, observations, ops-tickets

**PostgREST (10):**
forum_categories, forum_threads_with_authors, forum_posts_with_authors, profiles, user_communities (with nested joins), forum_threads (POST), forum_posts (POST/PATCH/DELETE), forum-posts (edge function)

### Is There an Abstraction Layer?

**No.** Views and ViewModels call Supabase directly. There is no shared `APIClient`, no request middleware, no response interceptor. Each domain re-implements JWT header attachment, error mapping, and response decoding independently.

---

## 4. OFFLINE / SYNC

### Storage Technologies

| Store | Technology | Purpose |
|-------|-----------|---------|
| Trips, Clients, Lodges, Communities | **Core Data** (NSPersistentContainer) | Relational master data with relationships |
| Catch reports (PicMemo) | **JSON files** (`Documents/CatchReportsPicMemo/*.json`) | Append-only catch reports |
| Farmed reports | **JSON files** (`Documents/FarmedReports/*.json`) | No-catch event reports |
| Observations | **JSON files** (`Documents/Observations/*.json`) | Voice-based observations |
| Photos | **JPEG files** (`Documents/CatchPhotos/*.jpg`) | Compressed catch photos |
| Voice notes | **M4A + JSON** (`Documents/VoiceNotes/`) | Audio recordings + metadata |
| Forum images | **Disk cache** (`Caches/ForumMedia/`) | LRU 200MB disk + 50MB memory |
| Auth tokens | **Keychain** | JWT access + refresh tokens |
| Active community | **UserDefaults** | Current community selection |

### Sync Architecture

**Trips — Bidirectional, Last-Write-Wins:**
- `SynchTrips.swift` (719 lines) compares `serverUpdatedAt` vs `localUpdatedAt`
- Server newer → overwrite local; Local newer → POST to server
- Fallback to `createdAt` if server lacks `updatedAt`
- Core Data merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`
- Triggered from `LandingView` at app launch

**Reports / Observations / Farmed Reports — One-Way Upload:**
- Status enum: `.savedLocally` → `.uploaded`
- Upload managers filter pending items, validate, batch POST, mark uploaded
- `purgeOldUploaded(olderThanDays: 14)` auto-cleans farmed reports
- Binary data (photos, audio) base64-encoded into JSON payload

### Conflict Resolution

- **Trips:** Last-write-wins with timestamp comparison
- **Reports:** No conflicts possible — append-only, one-way upload
- **No retry queue:** Failed uploads are not automatically retried. They remain `.savedLocally` until the next manual or launch-triggered sync attempt.

### Gaps

- No explicit retry queue or exponential backoff for failed uploads
- Hybrid persistence (Core Data for some entities, JSON files for others) adds complexity
- No offline indicator or user-facing sync status
- No data migration strategy between JSON schema versions

---

## 5. DEPENDENCIES

### CocoaPods (Podfile)

| Pod | Version | Purpose |
|-----|---------|---------|
| `MediaPipeTasksVision` | ~> 0.10.14 (resolved: 0.10.21) | Hand pose detection for fish length estimation via hand landmarks |
| `MediaPipeTasksCommon` | 0.10.21 (transitive) | Shared MediaPipe runtime |

### Native Frameworks (no SPM, no Carthage)

| Framework | Purpose |
|-----------|---------|
| **CoreML** | Species classification (ViT), sex classification (ViT), fish detection (YOLOv8), length regression (XGBoost) |
| **Vision** | OCR for license text recognition (VNRecognizeTextRequest) |
| **CoreLocation** | GPS for river/water body detection |
| **MapKit** | Guide landing map, catch map views |
| **AVFoundation** | Voice note recording (AVAudioRecorder, 16kHz PCM), video playback |
| **CoreData** | Offline trip/client/community persistence |
| **LocalAuthentication** | Biometric login (Face ID / Touch ID) |
| **Combine** | Reactive state management (@Published, ObservableObject) |
| **SwiftUI** | Entire UI layer |
| **UIKit** | Bridging only (UIViewControllerRepresentable for camera picker, video player) |

**Total third-party dependencies: 1 (MediaPipe).** Everything else is Apple-native.

---

## 6. TEST COVERAGE

### Test Files

| Directory | Files | Lines | What's Tested |
|-----------|------:|------:|---------------|
| `SkeenaSystemTests/Guide/` | ~10 | ~3,000 | LengthRegressor features, length estimation parsing, CatchChatViewModel, trip sync, upload reports |
| `SkeenaSystemTests/OCR/` | 1 | 173 | License text recognizer (DOB, phone, name regex) |
| `SkeenaSystemTests/Location/` | 2 | 476 | RiverLocator, WaterBodyLocator |
| `SkeenaSystemTests/` (root) | ~34 | ~7,500 | Community, auth, forum, environment, various model tests |
| `SkeenaSystemUITests/` | 3 | 243 | Launch tests, database reset helper |

### Coverage Estimate by Area

| Area | Estimated Coverage | Notes |
|------|-------------------|-------|
| ML feature engineering (26-feature vector) | **~95%** | LengthRegressorTests thoroughly covers all features and ordering |
| Length estimation parsing | **~80%** | Range parsing, high-end extraction, edge cases |
| OCR regex patterns | **~60%** | DOB, phone, name extraction tested; Vision integration untested |
| CatchChatViewModel flow | **~50%** | Photo analysis workflow, user corrections, confidence levels |
| Location detection | **~50%** | RiverLocator and WaterBodyLocator coordinate matching |
| Upload / networking | **~30%** | Serialization tested; actual HTTP calls untested |
| Species / sex classification | **~10%** | Only through integration tests via CatchChatViewModel |
| Fish detection (YOLO) | **~10%** | YOLO output parsing untested directly |
| Hand detection (MediaPipe) | **~0%** | No tests |
| UI views | **~0%** | UI tests are scaffold only (launch tests) |
| **Overall estimate** | **~25-30%** | Strong on ML feature engineering, weak on UI and integration |

---

## 7. BUILD CONFIG

### Targets

| Target | Type |
|--------|------|
| SkeenaSystem | iOS Application |
| SkeenaSystemTests | Unit Test Bundle |
| SkeenaSystemUITests | UI Test Bundle |

### Build Configurations (4)

| Config | Purpose | Key Differences |
|--------|---------|-----------------|
| Debug | Local development | Standard debug settings |
| DevTest | Development/Test environment | `SPECIES_DETECTION_THRESHOLD=0.5`, `LOG_LEVEL=debug`, app name "Epic Waters" |
| Release | Release build | Standard optimization |
| Prod | Production | `SPECIES_DETECTION_THRESHOLD=0.80`, `LOG_LEVEL=error`, app name "Bend Fly Shop" |

### XCConfig Files

- `Config/DevTEST.xcconfig` — Dev/test API URL, ML calibration constants, community rivers, splash video settings
- `Config/PROD.xcconfig` — Prod ML thresholds (stricter species detection), different community rivers, Mapbox token placeholder
- `Config/Secrets.xcconfig` — **gitignored** — Contains `SUPABASE_ANON_KEY`

### CI/CD

- **GitHub Actions:** `.github/workflows/ci.yml.disabled` — currently disabled
  - Jobs: lint (SwiftLint), format (SwiftFormat), build, test (with coverage), UI test (commented out), security (CodeQL, disabled)
  - Coverage: xcresult → xccov report
- **Dependabot:** `.github/dependabot.yml` — dependency update monitoring
- **No Fastlane, no TestFlight automation** found in repo

### Code Quality

- `.swiftlint.yml` — SwiftLint rules configured
- `.swiftformat` — SwiftFormat configuration present
- `Scripts/swiftlint.sh` — Lint runner script

---

## 8. PORTABILITY ASSESSMENT

### iOS-Coupled vs. Framework-Agnostic Code

| Category | Lines | % of Total | iOS Coupling | Portability |
|----------|------:|:----------:|:------------:|:-----------:|
| SwiftUI views | ~23,500 | 62% | **Hard-coupled** | Must be fully rewritten |
| CoreML inference pipeline | ~2,150 | 6% | **Hard-coupled** | Requires TFLite/ONNX equivalents |
| Core Data persistence | ~2,300 | 6% | **Hard-coupled** | Replace with SQLite/Realm/WatermelonDB |
| CoreLocation / MapKit | ~1,200 | 3% | **Hard-coupled** | Replace with react-native-maps + expo-location |
| AVFoundation (audio/video) | ~1,000 | 3% | **Hard-coupled** | Replace with expo-av or react-native-audio |
| Vision (OCR) | ~850 | 2% | **Hard-coupled** | Replace with ML Kit or Tesseract |
| Keychain / BiometricAuth | ~110 | <1% | **Hard-coupled** | Replace with expo-secure-store + expo-local-authentication |
| Networking (URLSession) | ~4,600 | 12% | **Moderate** | Rewrite with fetch/axios — logic is portable, API contracts preserved |
| Domain models / DTOs | ~1,800 | 5% | **Portable** | TypeScript interfaces from existing Swift structs |
| Business logic / utilities | ~2,100 | 5% | **Mostly portable** | River coordinates, date parsing, label matching — logic translates |

**Summary: ~82% hard-coupled to iOS, ~12% moderately coupled, ~6% portable.**

### Hardest Parts to Port to React Native

1. **ML Pipeline (CatchPhotoAnalyzer — 1,304 lines)**
   - 4 CoreML models (ViT species, ViT sex, YOLOv8 fish detection, XGBoost length regressor)
   - 1 MediaPipe model (hand landmark detection)
   - Custom 26-feature vector construction with precise column ordering matching a Python training pipeline
   - Dual-path length estimation (regressor + heuristic fallback)
   - **Why it's hard:** CoreML models need conversion to TFLite or ONNX. MediaPipe has a React Native wrapper but it's less mature. The feature vector construction and calibration constants are tightly coupled to specific model architectures. Model versioning flows through to the backend.

2. **Offline-First Architecture (Hybrid Core Data + JSON files)**
   - Core Data relationships (Trip → TripClient → ClassifiedWaterLicense)
   - JSON file stores with status-based sync
   - Bidirectional trip sync with last-write-wins conflict resolution
   - **Why it's hard:** No direct Core Data equivalent in RN. WatermelonDB or Realm would require schema redesign. The hybrid storage approach (Core Data for some entities, JSON files for others) would need unification.

3. **OCR Pipeline (LicenseTextRecognizer — 842 lines)**
   - Apple Vision framework for text recognition with spatial bounding box analysis
   - Complex regex parsing for license fields (DOB, phone, name, license number)
   - Layout-aware text extraction (not just OCR but spatial relationship reasoning)
   - **Why it's hard:** Google ML Kit's text recognition has different spatial APIs. The bounding-box layout logic assumes Vision framework's coordinate system.

4. **Voice Note System (VoiceNoteView — 931 lines)**
   - AVAudioRecorder at 16kHz PCM
   - On-device speech recognition (SFSpeechRecognizer)
   - Real-time waveform visualization
   - M4A encoding + metadata JSON
   - **Why it's hard:** React Native audio libraries (expo-av, react-native-audio-recorder-player) have different APIs and encoding options. On-device speech recognition would need a separate library.

5. **Multi-tenant Community Theming**
   - Dynamic branding per community (logo, colors, tagline, splash video)
   - Entitlements-based feature gating per community type
   - Community-specific river/water body datasets
   - **Why it's moderate:** Logic is portable but the SwiftUI environment-based theming would need a React Context/Provider equivalent.

### What Ports Easily

- All Supabase API contracts (endpoints, payloads, auth flow) — use `@supabase/supabase-js`
- Domain models → TypeScript interfaces
- Business logic (river coordinate lookup, date parsing, label matching)
- Forum features — standard CRUD
- Navigation structure (tab-based with role switching)

### Estimated Effort Distribution for RN Port

| Work Area | Effort % | Notes |
|-----------|:--------:|-------|
| UI rewrite (SwiftUI → React Native) | 40% | Every screen rewritten; design system from scratch |
| ML pipeline port | 20% | Model conversion, inference runtime, feature engineering |
| Offline/sync rebuild | 15% | New persistence layer, sync engine |
| Networking layer | 10% | Supabase JS SDK replaces raw URLSession |
| OCR + voice | 10% | Platform-specific native modules |
| Testing | 5% | New test infrastructure |

---

## Appendix: Largest Files (Maintenance Risk)

| File | Lines | Concern |
|------|------:|---------|
| `Views/Guide/ReportsListView.swift` | 1,458 | View + embedded API + filtering logic |
| `Managers/CatchPhotoAnalyzer.swift` | 1,304 | ML orchestrator — 5 models, detection, classification, measurement |
| `Views/Angler/AnglerFlights.swift` | 1,220 | Monolithic view |
| `Authentication/AuthService.swift` | 1,207 | Auth + state + caching + offline — multiple responsibilities |
| `Views/Angler/AnglerClassifiedWatersLicenseUpload.swift` | 1,064 | View + photo capture + OCR integration |
| `Views/Guide/ReportChatView.swift` | 958 | Complex chat-based reporting UI |
| `Views/Guide/GuideRegistrationView.swift` | 944 | Registration form |
| `Views/Guide/VoiceNoteView.swift` | 931 | Audio recording + transcription + file management |
| `Managers/LicenseTextRecognizer.swift` | 842 | OCR pipeline with spatial analysis |
| `Models/CatchChatViewModel.swift` | 827 | Orchestrator masquerading as ViewModel |
