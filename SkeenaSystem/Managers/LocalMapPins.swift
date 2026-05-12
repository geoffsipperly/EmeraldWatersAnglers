// Bend Fly Shop
//
// LocalMapPins.swift — bridges the on-device `savedLocally` reports into the
// same `MapReportDTO` shape the map views consume from the server. Lets the
// maps show pins for catches and marks the user has recorded today even
// before those reports have been uploaded.
//
// Scope:
//   • Catches      — `CatchReportStore.reports` filtered to `.savedLocally`
//   • Marks        — `FarmedReportStore.reports` filtered to `.savedLocally`
//   • Observations — intentionally NOT included. They're available to replay
//                    in the Activities view before upload, but they don't get
//                    a map pin (matches the existing server-side behavior —
//                    observation pins aren't surfaced on the map either).
//
// Each synthesized DTO carries `isPendingUpload = true` so the rendering
// layer can pick the hollow pin variant.
//
// Dedup: server pins always win. If a freshly-uploaded report briefly exists
// in both stores (locally with `.savedLocally`, server-side after upload but
// before the local status flips to `.uploaded`), the server pin is kept and
// the local one is dropped.

import Foundation

enum LocalMapPins {

  // MARK: - Public API

  /// Convert the user's `savedLocally` catches and marks into a `MapReportDTO`
  /// list ready to merge with server pins. Empty when the user has no
  /// pending reports with valid coordinates.
  static func localPendingPins() -> [MapReportDTO] {
    let catches = CatchReportStore.shared.reports
      .filter { $0.status == .savedLocally }
      .compactMap(makeCatchDTO)

    let marks = FarmedReportStore.shared.reports
      .filter { $0.status == .savedLocally }
      .compactMap(makeMarkDTO)

    return catches + marks
  }

  /// Merge `serverReports` with the user's local-pending pins. Server pins
  /// win on `id` collision — a report that briefly exists in both lists
  /// during the upload-→-status-flip race window shows up once, as the
  /// freshly-uploaded server pin (not the hollow pending one).
  ///
  /// Local pins are otherwise appended verbatim so they participate in
  /// downstream filtering (time window, river scope, catch-only toggles)
  /// alongside the server pins. Callers don't need to do their own dedup.
  static func mergeWithServer(_ serverReports: [MapReportDTO]) -> [MapReportDTO] {
    let serverIds = Set(serverReports.map(\.id))
    let pending = localPendingPins().filter { !serverIds.contains($0.id) }
    return serverReports + pending
  }

  // MARK: - Conversion

  /// Build a catch-flavoured DTO from a local report. Returns nil when the
  /// report has no usable coordinate (the map can't pin it anywhere) — same
  /// gate the existing map views apply to server pins.
  private static func makeCatchDTO(_ r: CatchReport) -> MapReportDTO? {
    guard let lat = r.lat, let lon = r.lon,
          lat.isFinite, lon.isFinite,
          abs(lat) <= 90, abs(lon) <= 180,
          !(lat == 0 && lon == 0) else { return nil }
    return MapReportDTO(
      id: r.id.uuidString,
      type: "catch",
      date: isoString(r.createdAt),
      latitude: lat,
      longitude: lon,
      species: r.species,
      lengthInches: r.lengthInches,
      memberId: r.memberId,
      river: r.river,
      waterTempC: nil,             // server enriches these post-upload — local pins don't have them yet
      waterLevelFt: nil,
      isPendingUpload: true
    )
  }

  /// Build a mark-flavoured DTO. `FarmedReport.eventType.rawValue` already
  /// matches the wire enum the server uses for `type` ("active" | "farmed" |
  /// "promising" | "passed"), so it's a direct pass-through.
  private static func makeMarkDTO(_ r: FarmedReport) -> MapReportDTO? {
    guard let lat = r.lat, let lon = r.lon,
          lat.isFinite, lon.isFinite,
          abs(lat) <= 90, abs(lon) <= 180,
          !(lat == 0 && lon == 0) else { return nil }
    return MapReportDTO(
      id: r.id.uuidString,
      type: r.eventType.rawValue,
      date: isoString(r.createdAt),
      latitude: lat,
      longitude: lon,
      species: nil,
      lengthInches: nil,
      memberId: r.memberId,
      river: nil,                  // FarmedReport doesn't carry a river name today
      waterTempC: nil,
      waterLevelFt: nil,
      isPendingUpload: true
    )
  }

  // MARK: - Utilities

  /// Match the wire format the server uses for `MapReportDTO.date`
  /// (ISO-8601 with fractional seconds + Z). The map views parse it back
  /// the same way regardless of which side produced it, so the formatter
  /// has to round-trip cleanly.
  private static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static func isoString(_ date: Date) -> String {
    isoFormatter.string(from: date)
  }
}
