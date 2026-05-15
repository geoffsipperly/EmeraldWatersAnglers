// Bend Fly Shop
//
// Persistent on-device cache for community logo images.
//
// Why: `CommunityLogoView` previously rendered logos via `AsyncImage`, which
// relies on `URLCache.shared` (4 MB memory / 20 MB disk by default and prone
// to eviction). On offline cold launch this caused the bundled-asset fallback
// (`AppLogo`) to render — and that asset historically contained the EWA logo,
// so any community whose remote logo wasn't currently in URLCache rendered
// as EWA regardless of who the user actually belonged to.
//
// This cache is **content-addressed** by URL hash, so:
//   1. Two communities sharing a logo URL dedupe automatically.
//   2. We don't need to plumb `communityId` through `CommunityLogoView`'s
//      signature (it has 10+ call sites) — the existing `CommunityConfig.logoUrl`
//      is enough.
//   3. Backend can swap a community's logo by changing the URL — the new URL
//      hashes to a different slot and the cache repopulates on next online
//      `fetchMemberships`. Old slots are orphaned; periodic cleanup can be
//      added later if disk usage becomes a concern (currently bounded by
//      community count × logo size, both small).
//
// Cache fill is initiated from `CommunityService.fetchMemberships()` on each
// successful online refresh, as a fire-and-forget `Task.detached` per
// membership. The synchronous `loadData(for:)` read is microseconds for a
// small image and is layered with an `NSCache` so repeat renders during a
// session don't re-hit disk.
//
// `nonisolated` because path is read by SwiftUI views (MainActor) and
// written from detached background tasks; both `FileManager` and `NSCache`
// are thread-safe. Mirrors the isolation discipline of `NetworkMonitor`.

import CryptoKit
import Foundation

nonisolated final class CommunityLogoCache: @unchecked Sendable {

  nonisolated(unsafe) static let shared = CommunityLogoCache()

  private let directory: URL
  private let memoryCache = NSCache<NSString, NSData>()

  private init() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    directory = docs.appendingPathComponent("CommunityLogos", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  // MARK: - Public API

  /// Synchronous read. Returns nil on cache miss. Safe to call from
  /// SwiftUI view bodies — first call reads from disk, subsequent calls in
  /// the same session hit the `NSCache` in-memory layer.
  func loadData(for url: URL) -> Data? {
    let key = cacheKey(for: url) as NSString
    if let cached = memoryCache.object(forKey: key) {
      return cached as Data
    }
    let path = fileURL(for: url)
    guard let data = try? Data(contentsOf: path) else { return nil }
    memoryCache.setObject(data as NSData, forKey: key)
    return data
  }

  /// Background download + write. No-op if the file already exists on disk
  /// (existing slot is trusted — backend cache-busts by changing the URL,
  /// which produces a new hash). Errors are logged at warn and swallowed:
  /// a missing logo is non-critical, the bundled-asset fallback handles it.
  func cache(_ url: URL) async {
    let path = fileURL(for: url)
    if FileManager.default.fileExists(atPath: path.path) {
      return
    }
    do {
      var req = URLRequest(url: url)
      req.timeoutInterval = 15
      let (data, response) = try await URLSession.shared.data(for: req)
      guard let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode) else {
        AppLogging.log("[CommunityLogoCache] non-2xx for \(url.absoluteString)", level: .warn, category: .community)
        return
      }
      try data.write(to: path, options: .atomic)
      memoryCache.setObject(data as NSData, forKey: cacheKey(for: url) as NSString)
      AppLogging.log("[CommunityLogoCache] cached \(data.count) bytes for \(url.absoluteString)", level: .debug, category: .community)
    } catch {
      AppLogging.log("[CommunityLogoCache] cache failed for \(url.absoluteString): \(error)", level: .warn, category: .community)
    }
  }

  /// Clears all cached logos. Called from `CommunityService.clear()` on
  /// logout so a user signing in to a different account doesn't briefly see
  /// the previous user's community logos before the new fetch lands.
  func clear() {
    memoryCache.removeAllObjects()
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  // MARK: - Internals

  /// SHA256(absoluteString) hex — filesystem-safe and stable across launches.
  private func cacheKey(for url: URL) -> String {
    let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
    return hash.map { String(format: "%02x", $0) }.joined()
  }

  private func fileURL(for url: URL) -> URL {
    directory.appendingPathComponent(cacheKey(for: url) + ".img")
  }
}
