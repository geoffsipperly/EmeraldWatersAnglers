// Bend Fly Shop
//
// FisheryConditionsCache.swift — per-(community, fishery) disk snapshot of
// the single-river conditions response (weather tiles, tides, water-level /
// temperature series). One file per fishery at:
//
//   Documents/FisheriesConditionsCache/<communityId>/<sanitizedName>.json
//
// Written on every successful `/river-conditions` fetch when a user taps a
// fishery on the Conditions screen. Read by the tap handler when the network
// call fails — if a cache exists we navigate to the detail view with the
// stale data (and a visible "Last updated: …" timestamp); if not, the detail
// view shows a friendly "you need to be connected" empty state.
//
// Bounded storage per fishery: one file per (community, fishery) pair, each
// successful fetch overwrites. Snapshot is a `RiverConditionsResponse` plus
// `cachedAt`, encoded as JSON.

import Foundation

enum FisheryConditionsCache {

  /// Snapshot persisted to disk. `cachedAt` flows through to the detail
  /// view's "Last updated: …" row so users always know how stale the cached
  /// payload is.
  struct Snapshot: Codable {
    let cachedAt: Date
    let response: RiverConditionsResponse
  }

  // MARK: - Public API

  /// Write the latest fetched response for `(communityId, fisheryName)`.
  /// Atomic so a mid-write crash can't leave a half-decoded file behind.
  /// Failures are logged but never thrown — caching is a best-effort
  /// enhancement, not a correctness requirement of the fetch path.
  static func save(response: RiverConditionsResponse, communityId: String, fisheryName: String) {
    do {
      let url = try fileURL(for: communityId, fisheryName: fisheryName)
      let snapshot = Snapshot(cachedAt: Date(), response: response)
      let data = try encoder.encode(snapshot)
      try ensureDirectory(at: url.deletingLastPathComponent())
      try data.write(to: url, options: [.atomic])
      AppLogging.log("[FisheryConditionsCache] saved snapshot for community=\(communityId) fishery=\(fisheryName)", level: .debug, category: .trip)
    } catch {
      AppLogging.log("[FisheryConditionsCache] save failed for community=\(communityId) fishery=\(fisheryName): \(error.localizedDescription)", level: .warn, category: .trip)
    }
  }

  /// Read the cached snapshot for `(communityId, fisheryName)`. Returns nil
  /// when no file exists or when the file fails to decode.
  static func load(communityId: String, fisheryName: String) -> Snapshot? {
    do {
      let url = try fileURL(for: communityId, fisheryName: fisheryName)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      let data = try Data(contentsOf: url)
      return try decoder.decode(Snapshot.self, from: data)
    } catch {
      AppLogging.log("[FisheryConditionsCache] load failed for community=\(communityId) fishery=\(fisheryName): \(error.localizedDescription)", level: .warn, category: .trip)
      return nil
    }
  }

  // MARK: - Internals

  private static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
  }()

  private static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  private static func fileURL(for communityId: String, fisheryName: String) throws -> URL {
    let docs = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return docs
      .appendingPathComponent("FisheriesConditionsCache", isDirectory: true)
      .appendingPathComponent(communityId, isDirectory: true)
      .appendingPathComponent("\(sanitize(fisheryName)).json")
  }

  private static func ensureDirectory(at url: URL) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }

  /// Make a fishery display name safe to use as a filename.
  /// Replaces path separators, control characters, and a few other
  /// filesystem-hostile characters with `_`. Preserves Unicode otherwise
  /// (the cache files live in our sandbox; we don't need ASCII-only).
  private static func sanitize(_ name: String) -> String {
    let badChars = CharacterSet(charactersIn: "/\\:?*\"<>|")
      .union(.controlCharacters)
      .union(.newlines)
    return name
      .components(separatedBy: badChars)
      .joined(separator: "_")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
