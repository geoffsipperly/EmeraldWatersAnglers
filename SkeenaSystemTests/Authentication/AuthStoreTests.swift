import XCTest
@testable import SkeenaSystem

/// Tests for `AuthStore` — the synchronous JWT cache used by upload flows.
///
/// Relies on `#if DEBUG` test helper `setJWTForTesting(_:)` to stage values
/// without requiring a live Supabase session.
final class AuthStoreTests: XCTestCase {

  override func tearDown() {
    AuthStore.shared.clear()
    super.tearDown()
  }

  func testShared_isSingleton() {
    XCTAssertTrue(AuthStore.shared === AuthStore.shared)
  }

  func testInitialState_jwtIsNil() {
    AuthStore.shared.clear()
    XCTAssertNil(AuthStore.shared.jwt)
  }

  func testSetJWTForTesting_storesValue() {
    AuthStore.shared.setJWTForTesting("test-token-abc")
    XCTAssertEqual(AuthStore.shared.jwt, "test-token-abc")
  }

  func testClear_removesJWT() {
    AuthStore.shared.setJWTForTesting("stale")
    AuthStore.shared.clear()
    XCTAssertNil(AuthStore.shared.jwt)
  }

  func testSetJWTForTesting_withNil_clearsValue() {
    AuthStore.shared.setJWTForTesting("something")
    AuthStore.shared.setJWTForTesting(nil)
    XCTAssertNil(AuthStore.shared.jwt)
  }
}
