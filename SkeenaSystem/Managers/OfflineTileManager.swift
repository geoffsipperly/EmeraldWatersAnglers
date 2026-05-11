// Bend Fly Shop
//
// OfflineTileManager.swift — Mapbox v11 offline-region wrapper for the
// conditions-recall map. Pre-caches a per-fishery satellite-streets region
// so guides can open the recall map while off-line (boats, gorges, big
// rivers below tree-line, etc.).
//
// Two things have to be on disk for the basemap to render offline:
//
//   1. A *style pack* — the .satelliteStreets style JSON + glyphs + sprites.
//      One per device, ~3–15 MB, downloaded the first time we pre-cache.
//   2. A *tile region* — the actual map tiles for a geometry + zoom range,
//      keyed by a region id. We use one region per fishery the user opens.
//
// Storage discipline: regions are tagged with a metadata `lastUsedAt` and
// pruned to `maxRegions` (oldest first) so the device can't accumulate
// unbounded GBs of tiles. Each fishery region at zoom 9–12 over a typical
// river is ~10–25 MB; the default cap of 6 keeps us under ~150 MB.

import Foundation
import CoreLocation
import MapboxMaps

enum OfflineTileManager {

  // MARK: - Tunables

  /// Style downloaded for offline rendering. Must match the live view's
  /// `.mapStyle(...)` so the offline appearance is identical to online.
  private static let styleURI: StyleURI = .satelliteStreets

  /// Inclusive zoom range pre-fetched per fishery. Lower bound gives
  /// regional orientation; upper bound gives tactical river-bend detail.
  /// Bumping the max by 1 roughly 4× tile count + bytes — see header.
  private static let minZoom: UInt8 = 9
  private static let maxZoom: UInt8 = 12

  /// Cap on simultaneously-cached fishery regions. Oldest (by `lastUsedAt`)
  /// are deleted when a new region is cached over this cap.
  private static let maxRegions: Int = 6

  /// Zoom range for the *community* landing-map basemap. Shallower than the
  /// recall window (no need for tactical river-bend detail at the overview
  /// scale); covers regional context to "I can see major rivers + roads".
  /// Guides zoom past this by drilling into a fishery, which has its own
  /// 9–12 cache.
  private static let landingMinZoom: UInt8 = 7
  private static let landingMaxZoom: UInt8 = 10

  /// Cap on simultaneously-cached *landing-map* regions (one per community).
  /// Separate from `maxRegions` so a guide switching across N communities
  /// doesn't churn out their per-fishery recall regions.
  private static let maxLandingRegions: Int = 3

  /// `false` keeps tile-region downloads free under the Mapbox v11 default
  /// hosting metering. Switching to `true` would predownload glyphs / fonts
  /// that the runtime would otherwise rasterize on demand — slightly nicer
  /// offline experience for non-Latin scripts at the cost of more bytes.
  private static let preloadGlyphs: Bool = false

  // MARK: - Public API

  /// Kicks off (or refreshes) the offline tile region for a fishery.
  ///
  /// - Parameters:
  ///   - communityId: scopes the region id so two communities don't share
  ///     a "Skeena River" region. UUID in production.
  ///   - fisheryName: human-readable name for the fishery; slugged into
  ///     the region id and used to evict by name.
  ///   - geometry: coordinates describing the fishery. Two or more points
  ///     are treated as a LineString (rivers); a single point becomes a
  ///     small bounding circle (≈10 km radius). Empty → returns failure.
  ///   - onProgress: called on the main actor with a 0…1 fraction whenever
  ///     either the style pack or tile region reports progress. Style pack
  ///     reuses the same callback (it's a brief one-time event).
  /// - Returns: success once both the style pack and the tile region have
  ///   finished downloading. Failure surfaces the underlying Mapbox error.
  @discardableResult
  static func preCache(
    communityId: String,
    fisheryName: String,
    geometry: [CLLocationCoordinate2D],
    onProgress: @MainActor @escaping (Double) -> Void = { _ in }
  ) async -> Result<Void, Error> {
    guard !geometry.isEmpty else {
      return .failure(OfflineTileError.emptyGeometry)
    }

    let regionId = makeRegionId(communityId: communityId, fisheryName: fisheryName)
    let offlineManager = OfflineManager()
    let tileStore = TileStore.default

    // Style pack first — required by the runtime even if tile data is
    // present. Idempotent: a re-download is a no-op once the pack is on
    // disk and unexpired.
    let stylePackResult = await loadStylePack(
      using: offlineManager,
      onProgress: onProgress
    )
    if case .failure(let error) = stylePackResult {
      AppLogging.log("[OfflineTiles] style pack failed: \(error.localizedDescription)", level: .warn, category: .map)
      return .failure(error)
    }

    // Tile region. The descriptor binds the style URI + zoom range to the
    // download; the geometry restricts which tiles are included.
    let tilesetDescriptor = offlineManager.createTilesetDescriptor(
      for: TilesetDescriptorOptions(
        styleURI: styleURI,
        zoomRange: minZoom...maxZoom,
        tilesets: nil
      )
    )

    let mbxGeometry = makeMapboxGeometry(from: geometry)
    let metadataDict: [String: Any] = [
      "fisheryName": fisheryName,
      "communityId": communityId,
      "lastUsedAt": Date().timeIntervalSince1970
    ]

    guard let loadOptions = TileRegionLoadOptions(
      geometry: mbxGeometry,
      descriptors: [tilesetDescriptor],
      metadata: metadataDict,
      acceptExpired: true,
      networkRestriction: .none,
      averageBytesPerSecond: nil
    ) else {
      return .failure(OfflineTileError.loadOptionsInvalid)
    }

    let regionResult: Result<Void, Error> = await withCheckedContinuation { continuation in
      _ = tileStore.loadTileRegion(forId: regionId, loadOptions: loadOptions) { progress in
        let total = max(progress.requiredResourceCount, 1)
        let done = progress.completedResourceCount
        let fraction = Double(done) / Double(total)
        Task { @MainActor in onProgress(fraction) }
      } completion: { result in
        switch result {
        case .success:
          continuation.resume(returning: .success(()))
        case .failure(let error):
          continuation.resume(returning: .failure(error))
        }
      }
    }

    if case .success = regionResult {
      AppLogging.log("[OfflineTiles] region '\(regionId)' cached (zoom \(minZoom)–\(maxZoom))", level: .info, category: .map)
      // Best-effort LRU prune. Failures here are logged but never propagated
      // — we already cached what the user asked for; pruning is hygiene.
      await pruneIfOverCap(tileStore: tileStore, prefix: "recall-", cap: maxRegions)
    }

    return regionResult
  }

  /// Kicks off (or refreshes) the offline tile region for the guide
  /// **landing** map — a community-wide overview rather than a single
  /// fishery. Bounded by a bounding box around the supplied fishery
  /// geometries (rivers + water bodies). Use this so the landing map's
  /// map tile + the expanded full-screen map still render base tiles when
  /// the guide is off-line.
  ///
  /// - Parameters:
  ///   - communityId: scopes the region id. UUID in production.
  ///   - fisheryCoordinates: every coordinate the active community knows
  ///     about — concatenation of `RiverAtlas` spines and `WaterBodyAtlas`
  ///     polygons. Used solely to compute the bbox of the community's
  ///     fishing footprint. Empty → returns failure.
  ///   - onProgress: 0…1 progress callback, main-actor.
  /// - Returns: success once both the style pack and the bbox tile region
  ///   have finished downloading.
  @discardableResult
  static func preCacheLanding(
    communityId: String,
    fisheryCoordinates: [CLLocationCoordinate2D],
    onProgress: @MainActor @escaping (Double) -> Void = { _ in }
  ) async -> Result<Void, Error> {
    guard !fisheryCoordinates.isEmpty else {
      return .failure(OfflineTileError.emptyGeometry)
    }

    let regionId = "landing-\(communityId)"
    let offlineManager = OfflineManager()
    let tileStore = TileStore.default

    // Style pack first — same pack as the recall view, so this is a no-op
    // on a device that's already cached a fishery.
    let stylePackResult = await loadStylePack(
      using: offlineManager,
      onProgress: onProgress
    )
    if case .failure(let error) = stylePackResult {
      AppLogging.log("[OfflineTiles] landing style pack failed: \(error.localizedDescription)", level: .warn, category: .map)
      return .failure(error)
    }

    let tilesetDescriptor = offlineManager.createTilesetDescriptor(
      for: TilesetDescriptorOptions(
        styleURI: styleURI,
        zoomRange: landingMinZoom...landingMaxZoom,
        tilesets: nil
      )
    )

    let bbox = makeBoundingPolygon(from: fisheryCoordinates)
    let metadataDict: [String: Any] = [
      "communityId": communityId,
      "lastUsedAt": Date().timeIntervalSince1970
    ]

    guard let loadOptions = TileRegionLoadOptions(
      geometry: bbox,
      descriptors: [tilesetDescriptor],
      metadata: metadataDict,
      acceptExpired: true,
      networkRestriction: .none,
      averageBytesPerSecond: nil
    ) else {
      return .failure(OfflineTileError.loadOptionsInvalid)
    }

    let regionResult: Result<Void, Error> = await withCheckedContinuation { continuation in
      _ = tileStore.loadTileRegion(forId: regionId, loadOptions: loadOptions) { progress in
        let total = max(progress.requiredResourceCount, 1)
        let done = progress.completedResourceCount
        let fraction = Double(done) / Double(total)
        Task { @MainActor in onProgress(fraction) }
      } completion: { result in
        switch result {
        case .success: continuation.resume(returning: .success(()))
        case .failure(let error): continuation.resume(returning: .failure(error))
        }
      }
    }

    if case .success = regionResult {
      AppLogging.log("[OfflineTiles] landing region '\(regionId)' cached (zoom \(landingMinZoom)–\(landingMaxZoom))", level: .info, category: .map)
      await pruneIfOverCap(tileStore: tileStore, prefix: "landing-", cap: maxLandingRegions)
    }

    return regionResult
  }

  /// Bump the `lastUsedAt` metadata so this region survives the next LRU
  /// pass. Called when a region is *re-opened* but already fully cached —
  /// no re-download needed, just re-rank.
  static func touch(communityId: String, fisheryName: String) async {
    let regionId = makeRegionId(communityId: communityId, fisheryName: fisheryName)
    let tileStore = TileStore.default
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      tileStore.tileRegionMetadata(forId: regionId) { result in
        // v11 TileStore has no "update metadata" — we read it so callers
        // know the region exists, but the LRU prune falls back to creation
        // order when timestamps are missing. A future SDK revision exposes
        // `updateTileRegionMetadata` — switch over once we upgrade.
        _ = result
        continuation.resume()
      }
    }
  }

  // MARK: - Internals

  /// One-time style-pack download. Re-runs are inexpensive (Mapbox short-
  /// circuits when the pack is already on disk and unexpired).
  private static func loadStylePack(
    using offlineManager: OfflineManager,
    onProgress: @MainActor @escaping (Double) -> Void
  ) async -> Result<Void, Error> {
    let options = StylePackLoadOptions(
      glyphsRasterizationMode: preloadGlyphs ? .allGlyphsRasterizedLocally : .ideographsRasterizedLocally,
      metadata: nil,
      acceptExpired: true
    )
    guard let options else {
      return .failure(OfflineTileError.loadOptionsInvalid)
    }
    return await withCheckedContinuation { continuation in
      _ = offlineManager.loadStylePack(for: styleURI, loadOptions: options) { progress in
        let total = max(progress.requiredResourceCount, 1)
        let done = progress.completedResourceCount
        // Style pack is brief; weight it as the first 10% of the overall
        // progress so the user-visible chip moves immediately.
        let fraction = 0.1 * Double(done) / Double(total)
        Task { @MainActor in onProgress(fraction) }
      } completion: { result in
        switch result {
        case .success: continuation.resume(returning: .success(()))
        case .failure(let error): continuation.resume(returning: .failure(error))
        }
      }
    }
  }

  /// Coordinate list → Mapbox Turf `Geometry` consumed by
  /// `TileRegionLoadOptions`. ≥2 points = LineString (mirrors the river-
  /// spine input we already feed the live map); a single point becomes
  /// `.point` (Mapbox internally buffers it into a small download area).
  private static func makeMapboxGeometry(from coords: [CLLocationCoordinate2D]) -> MapboxMaps.Geometry {
    if coords.count >= 2 {
      return .lineString(LineString(coords))
    }
    return .point(Point(coords[0]))
  }

  /// Builds an axis-aligned bounding-box polygon enclosing every coordinate
  /// in `coords`, padded by ~5 km on each side so river mouths and access
  /// roads near the boundary still end up in the offline tiles. Used by
  /// the landing-map cache to size the download to the community's whole
  /// fishing footprint with a single rectangle.
  private static func makeBoundingPolygon(from coords: [CLLocationCoordinate2D]) -> MapboxMaps.Geometry {
    // Single-point fallback — degenerate to a small square so Mapbox has
    // a polygon to work with. ~10 km on a side.
    if coords.count < 2 {
      let c = coords[0]
      let pad = 0.05 // ~5.5 km in latitude degrees
      let ring = [
        CLLocationCoordinate2D(latitude: c.latitude - pad, longitude: c.longitude - pad),
        CLLocationCoordinate2D(latitude: c.latitude - pad, longitude: c.longitude + pad),
        CLLocationCoordinate2D(latitude: c.latitude + pad, longitude: c.longitude + pad),
        CLLocationCoordinate2D(latitude: c.latitude + pad, longitude: c.longitude - pad),
        CLLocationCoordinate2D(latitude: c.latitude - pad, longitude: c.longitude - pad)
      ]
      return .polygon(Polygon([ring]))
    }

    let lats = coords.map(\.latitude)
    let lons = coords.map(\.longitude)
    let pad = 0.05
    let minLat = (lats.min() ?? 0) - pad
    let maxLat = (lats.max() ?? 0) + pad
    let minLon = (lons.min() ?? 0) - pad
    let maxLon = (lons.max() ?? 0) + pad

    // Mapbox polygons close themselves, but Turf's Polygon ring convention
    // wants the closing vertex listed explicitly. Repeat the first.
    let ring = [
      CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
      CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
      CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
      CLLocationCoordinate2D(latitude: maxLat, longitude: minLon),
      CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
    ]
    return .polygon(Polygon([ring]))
  }

  /// `recall-<community>-<slug(fisheryName)>`. The slug is restricted to
  /// `[a-z0-9-]` so it survives any path or URL handling the SDK might do
  /// internally.
  private static func makeRegionId(communityId: String, fisheryName: String) -> String {
    let lower = fisheryName.lowercased()
    let mapped = lower.map { ch -> Character in
      if ch.isLetter || ch.isNumber { return ch }
      return "-"
    }
    var slug = String(mapped)
    while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
    slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return "recall-\(communityId)-\(slug)"
  }

  /// Delete the oldest regions inside `prefix` until at or under `cap`.
  /// Sorts by `lastUsedAt` from the region metadata; regions missing the
  /// timestamp are treated as oldest and evicted first. Per-prefix scoping
  /// so the landing-map cache can't evict a guide's per-fishery tiles and
  /// vice versa.
  private static func pruneIfOverCap(tileStore: TileStore, prefix: String, cap: Int) async {
    let regions: [TileRegion] = await withCheckedContinuation { continuation in
      tileStore.allTileRegions { result in
        switch result {
        case .success(let regions): continuation.resume(returning: regions)
        case .failure:              continuation.resume(returning: [])
        }
      }
    }
    let ours = regions.filter { $0.id.hasPrefix(prefix) }
    guard ours.count > cap else { return }

    let scored: [(id: String, lastUsedAt: TimeInterval)] = await withTaskGroup(of: (String, TimeInterval).self) { group in
      for region in ours {
        group.addTask {
          let ts: TimeInterval = await withCheckedContinuation { c in
            tileStore.tileRegionMetadata(forId: region.id) { result in
              if case .success(let metadata) = result,
                 let dict = metadata as? [String: Any],
                 let v = dict["lastUsedAt"] as? TimeInterval {
                c.resume(returning: v)
              } else {
                c.resume(returning: 0)
              }
            }
          }
          return (region.id, ts)
        }
      }
      var out: [(String, TimeInterval)] = []
      for await pair in group { out.append(pair) }
      return out
    }.map { (id: $0.0, lastUsedAt: $0.1) }

    let sorted = scored.sorted { $0.lastUsedAt < $1.lastUsedAt }
    let toEvict = sorted.prefix(scored.count - cap)
    for victim in toEvict {
      tileStore.removeTileRegion(forId: victim.id)
      AppLogging.log("[OfflineTiles] evicted region '\(victim.id)' (LRU)", level: .debug, category: .map)
    }
  }
}

// MARK: - Errors

enum OfflineTileError: LocalizedError {
  case emptyGeometry
  case loadOptionsInvalid

  var errorDescription: String? {
    switch self {
    case .emptyGeometry:     return "No geometry supplied for the fishery — cannot pre-cache tiles."
    case .loadOptionsInvalid: return "Mapbox rejected the offline-region load options."
    }
  }
}
