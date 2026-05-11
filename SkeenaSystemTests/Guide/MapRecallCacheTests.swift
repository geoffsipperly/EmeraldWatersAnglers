import XCTest
@testable import SkeenaSystem

/// Tests for `MapRecallCache` — the per-community on-disk snapshot that
/// powers off-line fallback on the conditions-recall map.
///
/// Coverage:
///   1. Save → load roundtrip preserves the pin list and the `cachedAt` stamp.
///   2. Loading an unknown community returns nil (no crash, no surprise data).
///   3. A corrupt cache file is treated as missing and removed so the next
///      successful fetch can rewrite cleanly.
///   4. Re-saving overwrites the previous snapshot in place (bounded storage).
///   5. Two communities don't collide on disk.
@MainActor
final class MapRecallCacheTests: XCTestCase {

  // MARK: - Helpers

  private func makeReport(id: String, type: String = "catch") -> MapReportDTO {
    // MapReportDTO has no public init — round-trip through JSON to construct
    // a fixture. Same path the API uses, so anything that decodes in prod
    // works here too.
    let json = """
    {
      "id": "\(id)",
      "type": "\(type)",
      "date": "2026-05-01T12:00:00Z",
      "latitude": 49.5,
      "longitude": -127.5,
      "species": "Steelhead",
      "lengthInches": 32,
      "memberId": "MAD123ABC",
      "river": "Skeena River",
      "water_temp_c": 8.5,
      "water_level_ft": 4.2
    }
    """.data(using: .utf8)!
    return try! JSONDecoder().decode(MapReportDTO.self, from: json)
  }

  override func tearDown() {
    // Best-effort: scrub any caches the tests wrote so other suites or
    // re-runs start clean. Keys are test-only sentinel ids.
    for id in ["test-community-A", "test-community-B", "corrupt-community"] {
      MapRecallCache.clear(communityId: id)
      MapRecallCache.clear(communityId: id, scope: "MAD000A")
      MapRecallCache.clear(communityId: id, scope: "MAD000B")
    }
    super.tearDown()
  }

  // MARK: - Tests

  func testSaveAndLoad_roundtripsPinsAndTimestamp() {
    let community = "test-community-A"
    let reports = [makeReport(id: "pin-1"), makeReport(id: "pin-2", type: "active")]
    let before = Date()
    MapRecallCache.save(reports: reports, communityId: community)
    let after = Date()

    let loaded = MapRecallCache.load(communityId: community)
    XCTAssertNotNil(loaded, "Saved snapshot must be loadable")
    XCTAssertEqual(loaded?.reports.count, 2)
    XCTAssertEqual(loaded?.reports.map(\.id), ["pin-1", "pin-2"])
    XCTAssertEqual(loaded?.reports.map(\.type), ["catch", "active"])
    if let cachedAt = loaded?.cachedAt {
      XCTAssertGreaterThanOrEqual(cachedAt, before.addingTimeInterval(-1))
      XCTAssertLessThanOrEqual(cachedAt, after.addingTimeInterval(1))
    }
  }

  func testLoad_unknownCommunity_returnsNil() {
    MapRecallCache.clear(communityId: "test-community-A")
    XCTAssertNil(
      MapRecallCache.load(communityId: "test-community-A"),
      "Loading a community with no snapshot must return nil, not crash"
    )
  }

  func testLoad_corruptFile_returnsNilAndRemovesFile() throws {
    let community = "corrupt-community"
    // Reach into the cache directory through the public save() to make
    // sure the directory exists, then overwrite with garbage.
    MapRecallCache.save(reports: [makeReport(id: "scratch")], communityId: community)
    let fm = FileManager.default
    let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let url = docs.appendingPathComponent("MapRecallCache/\(community).json")
    try "not json".data(using: .utf8)!.write(to: url, options: .atomic)
    XCTAssertTrue(fm.fileExists(atPath: url.path), "Setup precondition")

    XCTAssertNil(
      MapRecallCache.load(communityId: community),
      "A corrupt snapshot must surface as nil instead of crashing the decoder"
    )
    XCTAssertFalse(
      fm.fileExists(atPath: url.path),
      "Corrupt file must be cleaned up so the next fresh fetch can rewrite cleanly"
    )
  }

  func testSave_overwritesPreviousSnapshot() {
    let community = "test-community-A"
    MapRecallCache.save(reports: [makeReport(id: "old-1"), makeReport(id: "old-2")], communityId: community)
    MapRecallCache.save(reports: [makeReport(id: "new-1")], communityId: community)

    let loaded = MapRecallCache.load(communityId: community)
    XCTAssertEqual(loaded?.reports.map(\.id), ["new-1"],
                   "A subsequent save must replace prior pins (bounded storage)")
  }

  func testSave_twoCommunities_doNotCollide() {
    MapRecallCache.save(reports: [makeReport(id: "a-1")], communityId: "test-community-A")
    MapRecallCache.save(reports: [makeReport(id: "b-1"), makeReport(id: "b-2")], communityId: "test-community-B")

    let a = MapRecallCache.load(communityId: "test-community-A")
    let b = MapRecallCache.load(communityId: "test-community-B")
    XCTAssertEqual(a?.reports.map(\.id), ["a-1"])
    XCTAssertEqual(b?.reports.map(\.id), ["b-1", "b-2"])
  }

  /// Researcher's per-member slice must not overwrite or be overwritten by
  /// the community-wide cache, even when scoped to the same community.
  /// This is what keeps `ResearcherMapView` (filtered by memberId) and any
  /// future community-wide cache (e.g. guide landing pin cache) separate
  /// on disk.
  func testSave_scopePartitionsByMember_doesNotCollideWithUnscoped() {
    let community = "test-community-A"
    MapRecallCache.save(reports: [makeReport(id: "community-wide-1")], communityId: community)
    MapRecallCache.save(reports: [makeReport(id: "member-A-1")], communityId: community, scope: "MAD000A")
    MapRecallCache.save(reports: [makeReport(id: "member-B-1"), makeReport(id: "member-B-2")], communityId: community, scope: "MAD000B")

    let unscoped = MapRecallCache.load(communityId: community)
    let memberA = MapRecallCache.load(communityId: community, scope: "MAD000A")
    let memberB = MapRecallCache.load(communityId: community, scope: "MAD000B")
    let bogus = MapRecallCache.load(communityId: community, scope: "MAD-DOES-NOT-EXIST")

    XCTAssertEqual(unscoped?.reports.map(\.id), ["community-wide-1"])
    XCTAssertEqual(memberA?.reports.map(\.id), ["member-A-1"])
    XCTAssertEqual(memberB?.reports.map(\.id), ["member-B-1", "member-B-2"])
    XCTAssertNil(bogus, "Loading an unwritten scope must return nil even when the community-wide cache exists")
  }
}
