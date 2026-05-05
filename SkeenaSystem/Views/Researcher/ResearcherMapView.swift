// Bend Fly Shop
//
// ResearcherMapView.swift — Full-page map of the *current researcher's* catch
// reports. Reached from the Researcher bottom toolbar's "Maps" tab. Mirrors the
// Guide landing-page map but server-filters by member_id and drops every
// non-catch report type, so the map only shows pins this researcher logged.

import CoreLocation
import SwiftUI

struct ResearcherMapView: View {
  @StateObject private var loc = LocationManager()

  @State private var mapReports: [MapReportDTO] = []
  @State private var fetchDone = false
  @State private var focusCatchCoordinate: CLLocationCoordinate2D? = nil

  var body: some View {
    DarkPageTemplate(bottomToolbar: {
      RoleAwareToolbar(activeTab: "maps")
    }) {
      content
    }
    .navigationTitle("Member Catch Map")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      loc.request()
      loc.start()
    }
    .task {
      await fetchMapReports()
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var content: some View {
    if !fetchDone {
      ZStack {
        Color.brandBackground
        ProgressView().tint(.white)
      }
    } else {
      ZStack(alignment: .top) {
        GuideLandingMapView(
          reports: mapReports,
          userLocation: loc.lastLocation?.coordinate,
          focusCoordinate: focusCatchCoordinate
        )

        if mapReports.isEmpty {
          Text("No catches recorded yet")
            .font(.brandSubheadline.weight(.semibold))
            .foregroundColor(.brandTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.brandScrim.opacity(0.6), in: Capsule())
            .accessibilityIdentifier("researcherMapEmptyState")
        } else if let nearest = nearestCatch {
          Button {
            focusCatchCoordinate = nearest.coordinate
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
              Text(nearest.label)
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.brandTextPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.brandScrim.opacity(0.6), in: Capsule())
          }
          .buttonStyle(.plain)
          .padding(.top, 12)
          .accessibilityIdentifier("nearestCatchLabel")
        }
      }
    }
  }

  // MARK: - Nearest catch

  private struct NearestCatch {
    let label: String
    let coordinate: CLLocationCoordinate2D
  }

  /// Returns label + coordinate for the nearest catch, or nil when location/catches are unavailable.
  private var nearestCatch: NearestCatch? {
    guard let userLoc = loc.lastLocation else { return nil }
    let validReports = mapReports.compactMap { r -> (CLLocationCoordinate2D, CLLocation)? in
      guard let lat = r.latitude, let lon = r.longitude,
            lat.isFinite, lon.isFinite,
            !(lat == 0 && lon == 0) else { return nil }
      let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
      return (coord, CLLocation(latitude: lat, longitude: lon))
    }
    guard let (catchCoord, catchLoc) = validReports.min(by: {
      $0.1.distance(from: userLoc) < $1.1.distance(from: userLoc)
    }) else { return nil }

    let distanceMiles = catchLoc.distance(from: userLoc) / 1609.344
    let distanceStr = distanceMiles < 10
      ? String(format: "%.1f mi", distanceMiles)
      : String(format: "%.0f mi", distanceMiles)
    let cardinal = Self.cardinalDirection(from: userLoc.coordinate, to: catchCoord)
    return NearestCatch(label: "Nearest catch \(distanceStr) \(cardinal)", coordinate: catchCoord)
  }

  private static func cardinalDirection(
    from: CLLocationCoordinate2D,
    to: CLLocationCoordinate2D
  ) -> String {
    let lat1 = from.latitude  * .pi / 180
    let lat2 = to.latitude    * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let index = Int((bearing + 22.5) / 45) % 8
    return directions[index]
  }

  // MARK: - Fetch

  /// Fetches the catch-only subset of map reports for the active community,
  /// scoped to this researcher's member id. Reports without a memberId or
  /// with a non-`catch` type are dropped client-side as defense in depth in
  /// case the server stops honouring the filter.
  private func fetchMapReports() async {
    defer { Task { @MainActor in fetchDone = true } }

    guard let communityId = CommunityService.shared.activeCommunityId else {
      AppLogging.log("[ResearcherMap] no active community — skipping fetch", level: .debug, category: .map)
      return
    }
    let memberId = (AuthService.shared.currentMemberId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !memberId.isEmpty else {
      AppLogging.log("[ResearcherMap] no current memberId — skipping fetch", level: .debug, category: .map)
      return
    }

    do {
      let all = try await MapReportService.fetch(communityId: communityId, memberId: memberId)
      let catches = all.filter { $0.type == "catch" }
      await MainActor.run { mapReports = catches }
    } catch {
      AppLogging.log("[ResearcherMap] fetch failed: \(error.localizedDescription)", level: .error, category: .map)
    }
  }
}
