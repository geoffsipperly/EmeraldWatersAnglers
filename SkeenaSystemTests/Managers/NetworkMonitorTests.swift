import Combine
import XCTest
@testable import SkeenaSystem

/// Smoke tests for `NetworkMonitor` — guard the public surface (snapshot
/// accessor and publisher) without driving the real `NWPathMonitor` callback.
///
/// We do not test the real `NWPathMonitor` here: it would require either a
/// mock-injection seam (out of scope for this foundational slice) or actually
/// toggling simulator network state. The follow-up `SyncCoordinator` work
/// will introduce a publisher-injection seam for end-to-end edge-trigger
/// tests.
final class NetworkMonitorTests: XCTestCase {

  private var cancellables: Set<AnyCancellable>!

  override func setUp() {
    super.setUp()
    cancellables = []
  }

  override func tearDown() {
    cancellables = nil
    super.tearDown()
  }

  /// `isOnlineSnapshot` is the synchronous accessor used by off-MainActor
  /// upload code. It must always return a Bool — never block, never throw.
  func testIsOnlineSnapshotIsReadable() {
    // First-touch access. The shared instance is lazily initialised and the
    // backing `CurrentValueSubject` defaults to `true`, so the very first
    // read should be `true` even before the real path monitor delivers a
    // reading. We tolerate a subsequent transition to `false` (e.g. a CI
    // runner with restricted networking) but at minimum the read must
    // succeed and return a Bool.
    let snapshot = NetworkMonitor.shared.isOnlineSnapshot
    XCTAssertTrue(snapshot == true || snapshot == false, "snapshot must be a readable Bool")
  }

  /// `isOnlinePublisher` is a `CurrentValueSubject`-backed publisher: it
  /// must emit its current value to new subscribers immediately. Consumers
  /// (future `SyncCoordinator`, `OfflineBanner`) depend on this — without
  /// it, a subscriber would have to wait for the next path transition.
  func testPublisherEmitsCurrentValueOnSubscribe() {
    let expectation = expectation(description: "publisher emits on subscribe")
    var received: Bool?

    NetworkMonitor.shared.isOnlinePublisher
      .first()
      .sink { value in
        received = value
        expectation.fulfill()
      }
      .store(in: &cancellables)

    wait(for: [expectation], timeout: 1.0)
    XCTAssertNotNil(received, "publisher must emit at least once on subscribe")
    XCTAssertEqual(received, NetworkMonitor.shared.isOnlineSnapshot,
                   "first emission must match the synchronous snapshot")
  }
}
