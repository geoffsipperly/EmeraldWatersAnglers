// Bend Fly Shop
//
// MapRecallCache.swift — per-community disk snapshot of the conditions-recall
// map's pin list. One file per community at:
//
//   Documents/MapRecallCache/<communityId>.json
//
// Written on every successful `MapReportService.fetch` call; read by
// `GuideFisheryMapView` when a fetch fails so guides see the most recent
// recall map they had instead of an empty pane when off-line.
//
// Bounded storage: a successful fetch overwrites the file, so a community
// uses at most one snapshot's worth of disk. The cached snapshot's age is
// surfaced in the filter bar so the guide knows it isn't live.

import Foundation

enum MapRecallCache {

  /// Snapshot persisted to disk. `cachedAt` lets the UI surface staleness
  /// ("Cached 2d ago") so an off-line guide never confuses old pins for live.
  struct Snapshot: Codable {
    let cachedAt: Date
    let reports: [MapReportDTO]
  }

  // MARK: - Public API

  /// Write the latest fetched pin list for `communityId`. Atomic so a
  /// mid-write crash can't leave a half-decoded file behind. Failures are
  /// logged but never thrown — caching is a best-effort enhancement, not a
  /// correctness requirement of the fetch path.
  ///
  /// `scope` lets callers partition the cache further (e.g. by `memberId`)
  /// so two views serving different filtered slices of the same community
  /// don't overwrite each other. Pass `nil` for the community-wide slice.
  static func save(reports: [MapReportDTO], communityId: String, scope: String? = nil) {
    do {
      let url = try fileURL(for: communityId, scope: scope)
      let snapshot = Snapshot(cachedAt: Date(), reports: reports)
      let data = try JSONEncoder().encode(snapshot)
      try data.write(to: url, options: .atomic)
      AppLogging.log("[MapRecallCache] saved \(reports.count) pins for community=\(communityId) scope=\(scope ?? "—")", level: .debug, category: .map)
    } catch {
      AppLogging.log("[MapRecallCache] save failed for community=\(communityId) scope=\(scope ?? "—"): \(error.localizedDescription)", level: .warn, category: .map)
    }
  }

  /// Read the most recent snapshot for `communityId` (optionally scoped),
  /// or nil if missing / unreadable. A corrupt file returns nil (the caller
  /// falls back to "empty" rather than crashing); the corrupt file is
  /// removed so the next successful fetch can rewrite cleanly.
  static func load(communityId: String, scope: String? = nil) -> Snapshot? {
    let url: URL
    do { url = try fileURL(for: communityId, scope: scope) } catch {
      AppLogging.log("[MapRecallCache] load: bad path: \(error.localizedDescription)", level: .warn, category: .map)
      return nil
    }
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
      let data = try Data(contentsOf: url)
      let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
      AppLogging.log("[MapRecallCache] loaded \(snapshot.reports.count) pins from \(snapshot.cachedAt) for community=\(communityId) scope=\(scope ?? "—")", level: .debug, category: .map)
      return snapshot
    } catch {
      AppLogging.log("[MapRecallCache] load failed (will delete corrupt file): \(error.localizedDescription)", level: .warn, category: .map)
      try? FileManager.default.removeItem(at: url)
      return nil
    }
  }

  /// Remove a community's cached snapshot. Used by tests; production code
  /// just lets fresh fetches overwrite the file.
  static func clear(communityId: String, scope: String? = nil) {
    guard let url = try? fileURL(for: communityId, scope: scope) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Internals

  /// `Documents/MapRecallCache/<communityId>.json` (no scope) or
  /// `<communityId>__<scope>.json` (scoped). The directory is created on
  /// demand so a fresh install or a wiped Documents folder doesn't need
  /// a one-time bootstrap step elsewhere.
  private static func fileURL(for communityId: String, scope: String?) throws -> URL {
    let fm = FileManager.default
    let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let dir = docs.appendingPathComponent("MapRecallCache", isDirectory: true)
    if !fm.fileExists(atPath: dir.path) {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    // Sanitize both ids so an unexpected separator can't write outside
    // the cache directory. Real ids are UUIDs / MAD-prefixed shortcodes,
    // so this is belt + suspenders.
    let safeCommunity = communityId.replacingOccurrences(of: "/", with: "_")
    let basename: String
    if let scope, !scope.isEmpty {
      let safeScope = scope.replacingOccurrences(of: "/", with: "_")
      basename = "\(safeCommunity)__\(safeScope)"
    } else {
      basename = safeCommunity
    }
    return dir.appendingPathComponent("\(basename).json", isDirectory: false)
  }
}
