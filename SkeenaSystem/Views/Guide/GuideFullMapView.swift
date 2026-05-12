// Bend Fly Shop
//
// GuideFullMapView.swift — Full-page version of the guide-landing map. Reached
// from the expand button on the landing tile. Filter bar above the map:
//
//   • Time window — server-side (re-fetches when changed). Defaults to
//     "Last year" so guides see a full season's activity when they enlarge
//     the map; tighter windows are one tap away.
//   • "Catch only" toggle — client-side, off by default. When off the map
//     shows every pin (catches + the four no-catch waypoint types). When
//     on the map narrows to catch pins only. Styled identically to the
//     time-window menu so the filter bar reads as one row of affordances.
//
// Map is always community-wide (member_id = nil); per-member scope was removed.

import CoreLocation
import SwiftUI

// MARK: - Filter enums (local — don't leak into landing tile)

enum GuideMapTimeWindow: String, CaseIterable, Identifiable {
  case today, sevenDays, thirtyDays, oneYear, threeYears

  var id: String { rawValue }

  var label: String {
    switch self {
    case .today:      return "Today"
    case .sevenDays:  return "Last 7 days"
    case .thirtyDays: return "Last 30 days"
    case .oneYear:    return "Last year"
    case .threeYears: return "Last 3 years"
    }
  }

  /// Inclusive lower bound for `from_date`. Anchored at the start of day so
  /// "Today" actually means "today's reports", not "the last 24 hours".
  func fromDate(now: Date = Date()) -> Date {
    let cal = Calendar.current
    switch self {
    case .today:
      return cal.startOfDay(for: now)
    case .sevenDays:
      return cal.date(byAdding: .day, value: -7, to: now) ?? now
    case .thirtyDays:
      return cal.date(byAdding: .day, value: -30, to: now) ?? now
    case .oneYear:
      return cal.date(byAdding: .year, value: -1, to: now) ?? now
    case .threeYears:
      return cal.date(byAdding: .year, value: -3, to: now) ?? now
    }
  }
}

/// Two-bucket categorization of pin types. Powers the client-side filter:
/// the "Catch only" toggle in the filter bar narrows the visible pins to
/// `.catch_.apiTypes`, and the underlying union check is still asserted
/// by `testGuideMapPinCategory_unionCoversAllReportTypes` so a new
/// server-side pin type can't silently disappear.
enum GuideMapPinCategory: String, CaseIterable, Identifiable {
  case catch_ = "catch"
  case noCatch

  var id: String { rawValue }

  var label: String {
    switch self {
    case .catch_:  return "Catch"
    case .noCatch: return "No Catch"
    }
  }

  /// API `type` strings this category covers. Union of `.catch_` and
  /// `.noCatch` MUST equal every `GuideLandingAnnotation.ReportType` raw
  /// value — locked by `testGuideMapPinCategory_unionCoversAllReportTypes`.
  var apiTypes: Set<String> {
    switch self {
    case .catch_:  return ["catch"]
    case .noCatch: return ["active", "farmed", "promising", "passed"]
    }
  }
}

// MARK: - View

struct GuideFullMapView: View {
  @StateObject private var loc = LocationManager()

  @State private var mapReports: [MapReportDTO] = []
  @State private var hasLoaded = false
  @State private var isFetching = false

  // Filter state
  @State private var timeWindow: GuideMapTimeWindow = .oneYear
  /// When true, narrows the visible pins to `GuideMapPinCategory.catch_`
  /// only. Defaults to false so the map opens with both catch and
  /// no-catch activity visible.
  @State private var catchOnly: Bool = false

  // Re-fetch key — only the server-side filter (time window) drives a network
  // call. Map is always community-wide.
  private var fetchKey: String { timeWindow.rawValue }

  // Catch-only is a client-side filter — toggles re-render the map without
  // re-fetching. Off → every pin; On → catch pins only.
  private var filteredReports: [MapReportDTO] {
    guard catchOnly else { return mapReports }
    let allowed = GuideMapPinCategory.catch_.apiTypes
    return mapReports.filter { allowed.contains($0.type) }
  }

  var body: some View {
    DarkPageTemplate(bottomToolbar: {
      RoleAwareToolbar(activeTab: "map")
    }) {
      VStack(spacing: 0) {
        filterBar
        mapPane
        legendFooter
      }
    }
    .navigationTitle("Map")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      loc.request()
      loc.start()
    }
    .task(id: fetchKey) {
      await fetchMapReports()
    }
  }

  // MARK: - Filter bar

  private var filterBar: some View {
    HStack(spacing: 8) {
      timeMenu
      Spacer(minLength: 8)
      catchOnlyToggle
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 10)
    .background(Color.brandSurfaceMuted)
  }

  private var timeMenu: some View {
    Menu {
      ForEach(GuideMapTimeWindow.allCases) { option in
        Button {
          timeWindow = option
        } label: {
          if option == timeWindow {
            Label(option.label, systemImage: "checkmark")
          } else {
            Text(option.label)
          }
        }
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "calendar")
          .font(.system(size: 12, weight: .semibold))
        Text(timeWindow.label)
          .font(.brandCaption.weight(.semibold))
        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundColor(.brandTextPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color.brandTextPrimary.opacity(0.10), in: Capsule())
    }
    .accessibilityIdentifier("mapTimeWindowMenu")
  }

  /// "Catch only" toggle button. Matches the time-window menu's font,
  /// foreground, padding, and capsule background exactly — only the
  /// leading icon flips between `square` (off) and `checkmark.square.fill`
  /// (on) to indicate state. Keeping the color scheme constant means the
  /// filter bar reads as one row of equivalent affordances rather than
  /// a primary/secondary pair.
  private var catchOnlyToggle: some View {
    Button { catchOnly.toggle() } label: {
      HStack(spacing: 6) {
        Image(systemName: catchOnly ? "checkmark.square.fill" : "square")
          .font(.system(size: 12, weight: .semibold))
        Text("Catch only")
          .font(.brandCaption.weight(.semibold))
      }
      .foregroundColor(.brandTextPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color.brandTextPrimary.opacity(0.10), in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("mapCatchOnlyToggle")
  }

  // MARK: - Legend footer

  /// Static color → label legend pinned below the map. The chips above
  /// only have two buckets (Catch / No Catch); this row decodes the four
  /// "No Catch" pin colors so a guide can tell green vs orange vs yellow
  /// vs grey at a glance.
  private var legendFooter: some View {
    HStack {
      Spacer()
      GuideLandingMapLegend()
      Spacer()
    }
    .padding(.vertical, 8)
    .background(Color.brandSurfaceMuted)
  }

  // MARK: - Map pane

  @ViewBuilder
  private var mapPane: some View {
    if !hasLoaded {
      ZStack {
        Color.brandBackground
        ProgressView().tint(.white)
      }
    } else {
      ZStack(alignment: .topTrailing) {
        // No `.id(...)` here on purpose — re-instantiating the Mapbox view
        // on every chip toggle would tear down the GL surface AND reset the
        // camera to initialViewport, yanking the user away from whatever
        // they'd zoomed into. Annotations update in place; the camera stays.
        GuideLandingMapView(
          reports: filteredReports,
          userLocation: loc.lastLocation?.coordinate
        )

        if isFetching {
          ProgressView()
            .tint(.white)
            .padding(8)
            .background(Color.brandScrim.opacity(0.55), in: Circle())
            .padding(10)
        }

        if filteredReports.isEmpty {
          VStack {
            Spacer()
            Text("No reports for this filter")
              .font(.brandSubheadline.weight(.semibold))
              .foregroundColor(.brandTextPrimary)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(Color.brandScrim.opacity(0.6), in: Capsule())
              .accessibilityIdentifier("guideMapEmptyState")
            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
  }

  // MARK: - Fetch

  private func fetchMapReports() async {
    await MainActor.run { isFetching = true }
    defer {
      Task { @MainActor in
        isFetching = false
        hasLoaded = true
      }
    }

    guard let communityId = CommunityService.shared.activeCommunityId else {
      AppLogging.log("[GuideFullMap] no active community — skipping fetch", level: .debug, category: .map)
      return
    }

    do {
      let reports = try await MapReportService.fetch(
        communityId: communityId,
        memberId: nil,
        fromDate: timeWindow.fromDate()
      )
      await MainActor.run { mapReports = reports }
    } catch {
      AppLogging.log("[GuideFullMap] fetch failed: \(error.localizedDescription)", level: .error, category: .map)
    }
  }
}

