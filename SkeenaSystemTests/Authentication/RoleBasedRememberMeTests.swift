import XCTest
import Security
@testable import SkeenaSystem

@MainActor
final class RoleBasedRememberMeTests: XCTestCase {

  override func setUp() {
    super.setUp()
    URLProtocol.registerClass(MockURLProtocol.self)
    MockURLProtocol.requestHandler = nil
    clearKeychain()
    let d = UserDefaults.standard
    d.removeObject(forKey: "OfflineLastEmail")
    d.removeObject(forKey: "OfflineRememberMeEnabled")
    d.removeObject(forKey: "CachedFirstName")
    d.removeObject(forKey: "CachedUserType")
    d.removeObject(forKey: "CachedMemberId")
    AuthService.resetSharedForTests()
  }

  override func tearDown() {
    URLProtocol.unregisterClass(MockURLProtocol.self)
    MockURLProtocol.requestHandler = nil
    clearKeychain()
    let d = UserDefaults.standard
    d.removeObject(forKey: "OfflineLastEmail")
    d.removeObject(forKey: "OfflineRememberMeEnabled")
    d.removeObject(forKey: "CachedFirstName")
    d.removeObject(forKey: "CachedUserType")
    d.removeObject(forKey: "CachedMemberId")
    super.tearDown()
  }

  private func clearKeychain() {
    let keys = [
      "epicwaters.auth.access_token",
      "epicwaters.auth.refresh_token",
      "epicwaters.auth.access_token_exp",
      "OfflineLastPassword"
    ]
    for account in keys {
      let q: [CFString: Any] = [ kSecClass: kSecClassGenericPassword, kSecAttrAccount: account ]
      SecItemDelete(q as CFDictionary)
    }
  }

  private func mockOnlineSignInAndProfile(email: String, firstName: String, userType: String) throws {
    let tokenJSON: [String: Any] = [
      "access_token": "tok-\(email)",
      "refresh_token": "ref-\(email)",
      "expires_in": 3600,
      "token_type": "bearer"
    ]
    let tokenData = try JSONSerialization.data(withJSONObject: tokenJSON)

    let userJSON: [String: Any] = [
      "id": "u-\(email)",
      "email": email,
      "user_metadata": ["first_name": firstName, "user_type": userType]
    ]
    let userData = try JSONSerialization.data(withJSONObject: userJSON)

    MockURLProtocol.requestHandler = { req in
      guard let url = req.url else { throw URLError(.badURL) }
      if url.path.contains("/auth/v1/token") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, tokenData)
      } else if url.path.contains("/auth/v1/user") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, userData)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }
  }

  func testGuide_autoEnablesRememberMe_afterProfileLoad() async throws {
    let auth = AuthService.shared
    try mockOnlineSignInAndProfile(email: "guide@example.com", firstName: "G", userType: "guide")
    try await auth.signIn(email: "guide@example.com", password: "pw")
    XCTAssertEqual(auth.currentUserType, .guide)
    XCTAssertTrue(auth.rememberMeEnabled, "Remember Me should auto-enable for guides")
  }

  // Policy change locked in by commit `9dd61a5` ("Offline login: enable
  // Remember Me for all roles, not just guides"): Remember Me is auto-ON
  // after profile load for every role — anglers, researchers, public, and
  // guides alike. Before, anglers/researchers/public were locked out of
  // offline sign-in because their post-signOut creds got wiped. These two
  // angler-side tests were updated below to assert the new symmetric
  // behaviour (used to assert auto-disable + creds-cleared).

  func testAngler_autoEnablesRememberMe_afterProfileLoad() async throws {
    let auth = AuthService.shared
    try mockOnlineSignInAndProfile(email: "angler@example.com", firstName: "A", userType: "angler")
    try await auth.signIn(email: "angler@example.com", password: "pw")
    XCTAssertEqual(auth.currentUserType, .angler)
    XCTAssertTrue(auth.rememberMeEnabled,
                  "Remember Me should auto-enable for anglers — every role gets offline access after profile load (commit 9dd61a5)")
  }

  func testGuide_signOut_preservesOfflineCreds() async throws {
    let auth = AuthService.shared
    try mockOnlineSignInAndProfile(email: "guide@example.com", firstName: "G", userType: "guide")
    try await auth.signIn(email: "guide@example.com", password: "pw")
    // sign out -> should preserve offline creds due to rememberMe=true
    await auth.signOut()

    MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
    do {
      try await auth.signIn(email: "guide@example.com", password: "pw")
      XCTAssertTrue(auth.isAuthenticated)
    } catch {
      XCTFail("Expected offline sign-in to succeed for guide with remember me auto-enabled; error=\(error)")
    }
  }

  func testAngler_signOut_preservesOfflineCreds() async throws {
    let auth = AuthService.shared
    try mockOnlineSignInAndProfile(email: "angler@example.com", firstName: "A", userType: "angler")
    try await auth.signIn(email: "angler@example.com", password: "pw")
    // Sign out — credentials should persist because Remember Me is now
    // auto-on for every role (mirrors testGuide_signOut_preservesOfflineCreds).
    await auth.signOut()

    MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
    do {
      try await auth.signIn(email: "angler@example.com", password: "pw")
      XCTAssertTrue(auth.isAuthenticated,
                    "Anglers should successfully sign in offline after sign-out — Remember Me is auto-on for all roles (commit 9dd61a5)")
    } catch {
      XCTFail("Expected offline sign-in to succeed for angler with remember me auto-enabled; error=\(error)")
    }
  }
}

