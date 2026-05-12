// Bend Fly Shop
//
// BatchConditionsCache.swift — per-community disk snapshot of the river/water
// body batch conditions list shown on the "Conditions" landing screen. One
// file per community at:
//
//   Documents/FisheriesConditionsCache/<communityId>/batch.json
//
// Written on every successful `/river-conditions-batch` fetch by
// `FishingForecastRequestView.fetchBatchConditions()`. Read on view appear
// (before the network call fires) so the list paints instantly and works
// offline. The cached snapshot's age is rendered as "Last updated: …" so
// users always know how stale the data is.
//
// Bounded storage: a successful fetch overwrites the file, so a community
// uses at most one snapshot's worth of disk. Mirrors the contract and
// failure-tolerant logging of `MapRecallCache`.

import Foundation

enum BatchConditionsCache {

  /// Snapshot persisted to disk. `cachedAt` lets the UI surface staleness
  /// to the user (the "Last updated: …" row above the rivers list).
  struct Snapshot: Codable {
    let cachedAt: Date
    let response: BatchResponse
  }

  // MARK: - Public API

  /// Write the latest batch response for `communityId`. Atomic so a
  /// mid-write crash can't leave a half-decoded file behind. Failures are
  /// logged but never thrown — caching is a best-effort enhancement, not a
  /// correctness requirement of the fetch path.
  static func save(response: BatchResponse, communityId: String) {
    do {
      let url = try fileURL(for: communityId)
      let snapshot = Snapshot(cachedAt: Date(), response: response)
      let data = try encoder.encode(snapshot)
      try ensureDirectory(at: url.deletingLastPathComponent())
      try data.write(to: url, options: [.atomic])
      AppLogging.log("[BatchConditionsCache] saved snapshot for community=\(communityId) (\(response.conditions.count) rows)", level: .debug, category: .trip)
    } catch {
      AppLogging.log("[BatchConditionsCache] save failed for community=\(communityId): \(error.localizedDescription)", level: .warn, category: .trip)
    }
  }

  /// Read the cached snapshot for `communityId`. Returns nil when no file
  /// exists or when the file fails to decode (e.g. older schema).
  static func load(communityId: String) -> Snapshot? {
    do {
      let url = try fileURL(for: communityId)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      let data = try Data(contentsOf: url)
      return try decoder.decode(Snapshot.self, from: data)
    } catch {
      AppLogging.log("[BatchConditionsCache] load failed for community=\(communityId): \(error.localizedDescription)", level: .warn, category: .trip)
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

  private static func fileURL(for communityId: String) throws -> URL {
    let docs = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return docs
      .appendingPathComponent("FisheriesConditionsCache", isDirectory: true)
      .appendingPathComponent(communityId, isDirectory: true)
      .appendingPathComponent("batch.json")
  }

  private static func ensureDirectory(at url: URL) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }
}
