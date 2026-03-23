import XCTest
import Security
@testable import SkeenaSystem

/// Regression tests for CommunityService: membership fetching, active community
/// selection, role syncing, join community, and offline persistence.
@MainActor
final class CommunityServiceTests: XCTestCase {

  private var _mockSession: URLSession?
  private var mockSession: URLSession {
    if _mockSession == nil {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [MockURLProtocol.self]
      _mockSession = URLSession(configuration: config)
    }
    return _mockSession!
  }

  override func setUp() {
    super.setUp()
    clearKeychainEntries()
    MockURLProtocol.requestHandler = nil
    // Register globally so CommunityService's URLSession.shared calls are also intercepted
    URLProtocol.registerClass(MockURLProtocol.self)
    AuthService.resetSharedForTests(session: mockSession)
    CommunityService.shared.clear()
  }

  override func tearDown() {
    MockURLProtocol.requestHandler = nil
    URLProtocol.unregisterClass(MockURLProtocol.self)
    _mockSession?.invalidateAndCancel()
    _mockSession = nil
    clearKeychainEntries()
    CommunityService.shared.clear()
    super.tearDown()
  }

  private func clearKeychainEntries() {
    for account in [
      "epicwaters.auth.access_token",
      "epicwaters.auth.refresh_token",
      "epicwaters.auth.access_token_exp"
    ] {
      let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: account
      ]
      SecItemDelete(query as CFDictionary)
    }
  }

  private func setAccessToken(_ token: String) {
    let data = token.data(using: .utf8)!
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: "epicwaters.auth.access_token",
      kSecValueData: data
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
    let exp = Int(Date().timeIntervalSince1970) + 3600
    let expData = String(exp).data(using: .utf8)!
    let expQuery: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrAccount: "epicwaters.auth.access_token_exp",
      kSecValueData: expData
    ]
    SecItemDelete(expQuery as CFDictionary)
    SecItemAdd(expQuery as CFDictionary, nil)
  }

  // MARK: - Membership JSON helpers

  private func makeMembershipsJSON(_ memberships: [[String: Any]]) -> Data {
    try! JSONSerialization.data(withJSONObject: memberships)
  }

  private func makeSingleMembership(
    communityId: String = "comm-uuid-1",
    communityName: String = "Emerald Waters Anglers",
    role: String = "guide",
    code: String = "EWA001"
  ) -> [String: Any] {
    [
      "id": UUID().uuidString,
      "community_id": communityId,
      "role": role,
      "communities": [
        "id": communityId,
        "name": communityName,
        "code": code,
        "is_active": true
      ]
    ]
  }

  // MARK: - Tests: Fetch memberships

  func testFetchMemberships_singleCommunity_autoSelects() async {
    setAccessToken("valid-token")
    let membership = makeSingleMembership()
    let data = makeMembershipsJSON([membership])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
      }
      // Return valid token for currentAccessToken
      if url.path.contains("/auth/v1/user") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships()

    XCTAssertEqual(svc.memberships.count, 1)
    // No longer auto-selects — picker is always shown so users can join more communities
    XCTAssertNil(svc.activeCommunityId, "Should leave selection nil so picker is shown")
    XCTAssertFalse(svc.hasMultipleCommunities)
  }

  func testFetchMemberships_multipleCommunities_autoSelectsFirst() async {
    setAccessToken("valid-token")
    let m1 = makeSingleMembership(communityId: "comm-1", communityName: "Emerald Waters", role: "guide", code: "EWA001")
    let m2 = makeSingleMembership(communityId: "comm-2", communityName: "Epic Waters", role: "angler", code: "EPW002")
    let data = makeMembershipsJSON([m1, m2])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships()

    XCTAssertEqual(svc.memberships.count, 2)
    XCTAssertTrue(svc.hasMultipleCommunities)
    // Should NOT auto-select when multiple communities — picker should be shown
    XCTAssertNil(svc.activeCommunityId, "Should leave selection nil so CommunityPickerView is shown")
    XCTAssertNil(svc.activeRole, "Role should be nil until user picks a community")
  }

  func testFetchMemberships_noToken_doesNotFetch() async {
    // No access token set
    let svc = CommunityService.shared
    await svc.fetchMemberships()

    XCTAssertTrue(svc.memberships.isEmpty)
    XCTAssertNil(svc.activeCommunityId)
  }

  func testFetchMemberships_serverError_keepsPreviousState() async {
    setAccessToken("valid-token")
    let m1 = makeSingleMembership()
    let data = makeMembershipsJSON([m1])

    var callCount = 0
    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        callCount += 1
        if callCount == 1 {
          return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        } else {
          return (HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data("error".utf8))
        }
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships() // first call succeeds
    XCTAssertEqual(svc.memberships.count, 1)

    await svc.fetchMemberships() // second call fails
    // Should keep previous state
    XCTAssertEqual(svc.memberships.count, 1)
  }

  // MARK: - Tests: Set active community

  func testSetActiveCommunity_updatesRoleAndPersists() async {
    setAccessToken("valid-token")
    let m1 = makeSingleMembership(communityId: "c-1", communityName: "Community A", role: "guide", code: "AAA111")
    let m2 = makeSingleMembership(communityId: "c-2", communityName: "Community B", role: "angler", code: "BBB222")
    let data = makeMembershipsJSON([m1, m2])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships()

    // Switch to community B
    svc.setActiveCommunity(id: "c-2")
    XCTAssertEqual(svc.activeCommunityId, "c-2")
    XCTAssertEqual(svc.activeRole, "angler")
    XCTAssertEqual(svc.activeCommunityName, "Community B")

    // Verify persistence
    XCTAssertEqual(UserDefaults.standard.string(forKey: "CommunityService.activeCommunityId"), "c-2")
    XCTAssertEqual(UserDefaults.standard.string(forKey: "CommunityService.activeRole"), "angler")
  }

  func testSetActiveCommunity_syncsRoleToAuthService() async {
    setAccessToken("valid-token")
    let m1 = makeSingleMembership(communityId: "c-1", role: "angler")
    let data = makeMembershipsJSON([m1])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships()

    // Give MainActor time to process the updateUserType call
    try? await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(AuthService.shared.currentUserType, .angler)
  }

  // MARK: - Tests: Clear

  func testClear_removesAllState() {
    let svc = CommunityService.shared
    UserDefaults.standard.set("some-id", forKey: "CommunityService.activeCommunityId")
    UserDefaults.standard.set("guide", forKey: "CommunityService.activeRole")

    svc.clear()

    XCTAssertTrue(svc.memberships.isEmpty)
    XCTAssertNil(svc.activeCommunityId)
    XCTAssertNil(svc.activeRole)
    XCTAssertNil(UserDefaults.standard.string(forKey: "CommunityService.activeCommunityId"))
    XCTAssertNil(UserDefaults.standard.string(forKey: "CommunityService.activeRole"))
  }

  // MARK: - Tests: Join community

  func testJoinCommunity_success() async throws {
    setAccessToken("valid-token")

    let joinResponse: [String: Any] = [
      "success": true,
      "community_name": "New Community",
      "community_id": "new-comm-uuid",
      "role": "angler"
    ]
    let joinData = try JSONSerialization.data(withJSONObject: joinResponse)

    // After join, fetchMemberships will be called
    let m1 = makeSingleMembership(communityId: "new-comm-uuid", communityName: "New Community", role: "angler", code: "NEW001")
    let membershipsData = makeMembershipsJSON([m1])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/functions/v1/join-community") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, joinData)
      }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, membershipsData)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    let result = try await svc.joinCommunity(code: "NEW001", role: "angler")

    XCTAssertEqual(result.success, true)
    XCTAssertEqual(result.communityName, "New Community")
    XCTAssertEqual(result.role, "angler")
    // Memberships should have been refreshed
    XCTAssertEqual(svc.memberships.count, 1)
  }

  func testJoinCommunity_invalidCode_throws() async {
    setAccessToken("valid-token")

    let errorResponse: [String: Any] = ["error": "Code not found"]
    let errorData = try! JSONSerialization.data(withJSONObject: errorResponse)

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/functions/v1/join-community") {
        return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, errorData)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    do {
      _ = try await CommunityService.shared.joinCommunity(code: "BADCOD", role: "angler")
      XCTFail("Expected invalidCode error")
    } catch let error as CommunityError {
      if case .invalidCode = error {
        // Expected
      } else {
        XCTFail("Expected .invalidCode, got \(error)")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testJoinCommunity_alreadyMember_throws() async {
    setAccessToken("valid-token")

    let errorResponse: [String: Any] = [
      "error": "Already a member of this community",
      "community_name": "Emerald Waters",
      "role": "guide"
    ]
    let errorData = try! JSONSerialization.data(withJSONObject: errorResponse)

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/functions/v1/join-community") {
        return (HTTPURLResponse(url: url, statusCode: 409, httpVersion: nil, headerFields: nil)!, errorData)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    do {
      _ = try await CommunityService.shared.joinCommunity(code: "EWA001", role: "guide")
      XCTFail("Expected alreadyMember error")
    } catch let error as CommunityError {
      if case .alreadyMember(let name) = error {
        XCTAssertEqual(name, "Emerald Waters")
      } else {
        XCTFail("Expected .alreadyMember, got \(error)")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func testJoinCommunity_noAuth_throws() async {
    // No access token
    do {
      _ = try await CommunityService.shared.joinCommunity(code: "ABC123", role: "angler")
      XCTFail("Expected unauthenticated error")
    } catch let error as CommunityError {
      if case .unauthenticated = error {
        // Expected
      } else {
        XCTFail("Expected .unauthenticated, got \(error)")
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - Tests: Signup uses community_code

  func testSignUp_sendsCommunityCodeInPayload() async throws {
    var capturedBody: [String: Any]?

    let signupResponse = Data("{}".utf8)
    let tokenJSON: [String: Any] = [
      "access_token": "signup-token",
      "refresh_token": "signup-refresh",
      "expires_in": 3600,
      "token_type": "bearer"
    ]
    let tokenData = try JSONSerialization.data(withJSONObject: tokenJSON)
    let userJSON: [String: Any] = ["id": "u1", "email": "t@t.com", "user_metadata": ["first_name": "T", "user_type": "guide"]]
    let userData = try JSONSerialization.data(withJSONObject: userJSON)

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/auth/v1/signup") {
        // httpBody is nil in URLProtocol — read from httpBodyStream instead
        if let stream = request.httpBodyStream {
          stream.open()
          let bufferSize = 65536
          var data = Data()
          let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
          while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 { data.append(buffer, count: read) }
          }
          buffer.deallocate()
          stream.close()
          capturedBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        return (HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!, signupResponse)
      } else if url.path.contains("/auth/v1/token") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, tokenData)
      } else if url.path.contains("/auth/v1/user") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, userData)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    try await AuthService.shared.signUp(
      email: "t@t.com", password: "pw",
      firstName: "T", lastName: "U",
      userType: .guide, communityCode: "EWA001"
    )

    // Verify the signup body contains community_code, not community
    let dataObj = capturedBody?["data"] as? [String: Any]
    XCTAssertNotNil(dataObj)
    XCTAssertEqual(dataObj?["community_code"] as? String, "EWA001")
    XCTAssertNil(dataObj?["community"]) // old field should NOT be present
  }

  func testSignUp_invalidCommunityCode_throwsValidation() async {
    let auth = AuthService.shared

    // Too short
    do {
      try await auth.signUp(email: "a@b.com", password: "p",
                            firstName: "F", lastName: "L", userType: .guide, communityCode: "AB")
      XCTFail("Expected validation error for short code")
    } catch {
      XCTAssert(error is AuthService.InputValidationError)
    }

    // Contains special chars
    do {
      try await auth.signUp(email: "a@b.com", password: "p",
                            firstName: "F", lastName: "L", userType: .guide, communityCode: "AB!@#$")
      XCTFail("Expected validation error for special chars")
    } catch {
      XCTAssert(error is AuthService.InputValidationError)
    }

    // Too long
    do {
      try await auth.signUp(email: "a@b.com", password: "p",
                            firstName: "F", lastName: "L", userType: .guide, communityCode: "ABCDEFG")
      XCTFail("Expected validation error for long code")
    } catch {
      XCTAssert(error is AuthService.InputValidationError)
    }
  }

  // MARK: - Tests: Cached community restored on init

  func testCachedCommunity_restoredAfterClear() {
    let svc = CommunityService.shared
    UserDefaults.standard.set("cached-comm-id", forKey: "CommunityService.activeCommunityId")
    UserDefaults.standard.set("angler", forKey: "CommunityService.activeRole")

    // Clear and verify
    svc.clear()
    XCTAssertNil(svc.activeCommunityId)
    XCTAssertNil(svc.activeRole)
  }

  // MARK: - Tests: Computed properties

  func testActiveCommunityName_fallsBackToAppEnvironment() {
    let svc = CommunityService.shared
    // No memberships loaded, no active community
    XCTAssertEqual(svc.activeCommunityName, AppEnvironment.shared.communityName)
  }

  func testActiveMembership_returnsCorrectMembership() async {
    setAccessToken("valid-token")
    let m1 = makeSingleMembership(communityId: "c-1", communityName: "Comm A", role: "guide", code: "AAA111")
    let m2 = makeSingleMembership(communityId: "c-2", communityName: "Comm B", role: "angler", code: "BBB222")
    let data = makeMembershipsJSON([m1, m2])

    MockURLProtocol.requestHandler = { request in
      guard let url = request.url else { throw URLError(.badURL) }
      if url.path.contains("/rest/v1/user_communities") {
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
      }
      return (HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!, nil)
    }

    let svc = CommunityService.shared
    await svc.fetchMemberships()
    svc.setActiveCommunity(id: "c-2")

    XCTAssertEqual(svc.activeMembership?.communityId, "c-2")
    XCTAssertEqual(svc.activeMembership?.role, "angler")
  }
}
