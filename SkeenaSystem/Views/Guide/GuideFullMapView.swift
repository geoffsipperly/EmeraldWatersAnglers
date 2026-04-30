// Bend Fly Shop
//
// GuideFullMapView.swift — Full-page version of the guide-landing map. Reached
// from the expand button on the landing tile. Adds a filter bar above the map
// with three controls:
//
//   • Time window — server-side (re-fetches when changed). Defaults to
//     "Last 30 days" so a busy community doesn't dump 3 years of pins on open.
//   • Mine / All — server-side (member_id). Defaults to "All" to mirror the
//     landing tile's behavior on first open.
//   • Pin type chips — client-side, multi-select, all on by default. Acts as
//     the legend, so the static GuideLandingMapLegend is intentionally dropped
//     here.

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

enum GuideMapScope: String, CaseIterable, Identifiable {
  case community, personal
  var id: String { rawValue }
  var label: String {
    switch self {
    case .community: return "Community"
    case .personal:  return "Personal"
    }
  }
}

/// Two-bucket categorization of pin types. Chips control which buckets are
/// visible; the footer legend still shows the underlying 5-color breakdown.
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

  /// Indicator dot color shown on the chip. Catch uses the catch pin color;
  /// "No Catch" uses a neutral grey because it spans 4 colors — the footer
  /// legend decodes them.
  var chipDotColor: UIColor {
    switch self {
    case .catch_:  return .systemBlue
    case .noCatch: return .systemGray3
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
  @State private var timeWindow: GuideMapTimeWindow = .thirtyDays
  @State private var scope: GuideMapScope = .community
  @State private var enabledCategories: Set<GuideMapPinCategory> = Set(GuideMapPinCategory.allCases)

  // Re-fetch key — only the server-side filters drive a network call.
  private var fetchKey: String { "\(timeWindow.rawValue)|\(scope.rawValue)" }

  // Union of every enabled category's underlying API types, then filter
  // the in-memory pin list. Done as a computed property so chip toggles
  // re-render the map without re-fetching.
  private var filteredReports: [MapReportDTO] {
    let allowed = enabledCategories.reduce(into: Set<String>()) { acc, cat in
      acc.formUnion(cat.apiTypes)
    }
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
    VStack(spacing: 8) {
      HStack(spacing: 10) {
        timeMenu
        Spacer(minLength: 8)
        scopeToggle
      }
      typeChipRow
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 10)
    .background(Color.white.opacity(0.04))
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
          .font(.caption.weight(.semibold))
        Image(systemName: "chevron.down")
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundColor(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color.white.opacity(0.10), in: Capsule())
    }
    .accessibilityIdentifier("mapTimeWindowMenu")
  }

  private var scopeToggle: some View {
    HStack(spacing: 0) {
      ForEach(GuideMapScope.allCases) { option in
        Button {
          scope = option
        } label: {
          Text(option.label)
            .font(.caption.weight(.semibold))
            .foregroundColor(scope == option ? .black : .white.opacity(0.85))
            .frame(minWidth: 78) // wide enough for "Community"
            .padding(.vertical, 6)
            .background(
              Capsule().fill(scope == option ? Color.white : Color.clear)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(2)
    .background(Color.white.opacity(0.10), in: Capsule())
    .accessibilityIdentifier("mapScopeToggle")
  }

  private var typeChipRow: some View {
    HStack(spacing: 8) {
      ForEach(GuideMapPinCategory.allCases) { category in
        categoryChip(category)
      }
      Spacer(minLength: 0)
    }
  }

  private func categoryChip(_ category: GuideMapPinCategory) -> some View {
    let isOn = enabledCategories.contains(category)
    let dot = Color(category.chipDotColor)
    return Button {
      if isOn {
        // Don't allow deselecting the last category — an empty filter set
        // would hide every pin with no obvious way back. Bounce the tap.
        if enabledCategories.count > 1 { enabledCategories.remove(category) }
      } else {
        enabledCategories.insert(category)
      }
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(dot)
          .frame(width: 8, height: 8)
        Text(category.label)
          .font(.caption.weight(.semibold))
          .foregroundColor(isOn ? .white : .white.opacity(0.45))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        Capsule()
          .fill(isOn ? dot.opacity(0.22) : Color.white.opacity(0.05))
      )
      .overlay(
        Capsule()
          .stroke(isOn ? dot.opacity(0.7) : Color.white.opacity(0.12),
                  lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("mapCategoryChip_\(category.rawValue)")
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
    .background(Color.white.opacity(0.04))
  }

  // MARK: - Map pane

  @ViewBuilder
  private var mapPane: some View {
    if !hasLoaded {
      ZStack {
        Color.black
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
            .background(Color.black.opacity(0.55), in: Circle())
            .padding(10)
        }

        if filteredReports.isEmpty {
          VStack {
            Spacer()
            Text("No reports for this filter")
              .font(.subheadline.weight(.semibold))
              .foregroundColor(.white)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(Color.black.opacity(0.6), in: Capsule())
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

    let memberId: String? = {
      switch scope {
      case .community: return nil
      case .personal:
        let id = (AuthService.shared.currentMemberId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
      }
    }()

    do {
      let reports = try await MapReportService.fetch(
        communityId: communityId,
        memberId: memberId,
        fromDate: timeWindow.fromDate()
      )
      await MainActor.run { mapReports = reports }
    } catch {
      AppLogging.log("[GuideFullMap] fetch failed: \(error.localizedDescription)", level: .error, category: .map)
    }
  }
}

