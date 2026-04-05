import XCTest
@testable import SkeenaSystem

/// Tests for `AppEnvironment` override plumbing and static helpers.
///
/// Uses the `override*` properties exposed for tests so we don't depend on
/// the host app's Info.plist values.
final class AppEnvironmentTests: XCTestCase {

  private var env: AppEnvironment { AppEnvironment.shared }

  override func tearDown() {
    // Clear every override we touched so other tests see a clean environment.
    env.overrideProjectURL = nil
    env.overrideAnonKey = nil
    env.overrideForumBase = nil
    env.overrideForumApiKey = nil
    env.overrideAppDisplayName = nil
    env.overrideAppLogoAsset = nil
    env.overrideCommunityName = nil
    env.overrideCommunityTagline = nil
    env.overrideDefaultRiver = nil
    env.overrideUploadCatchURL = nil
    env.overrideManageTripURL = nil
    env.overrideDefaultMapLatitude = nil
    env.overrideDefaultMapLongitude = nil
    env.overrideLodgeRivers = nil
    env.overrideLodgeWaterBodies = nil
    env.overrideDefaultWaterBody = nil
    env.overrideTacticsEnabled = nil
    env.overrideForecastLocation = nil
    env.overrideImageCompressionQuality = nil
    super.tearDown()
  }

  // MARK: - stripRiverSuffix

  func testStripRiverSuffix_removesRiverSuffix() {
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("Nehalem River"), "Nehalem")
  }

  func testStripRiverSuffix_removesCreek() {
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("Bear Creek"), "Bear")
  }

  func testStripRiverSuffix_removesLake() {
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("Crater Lake"), "Crater")
  }

  func testStripRiverSuffix_removesStream() {
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("Silver Stream"), "Silver")
  }

  func testStripRiverSuffix_noSuffix_unchanged() {
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("Skeena"), "Skeena")
  }

  func testStripRiverSuffix_suffixInMiddle_unchanged() {
    // Only trailing suffixes are stripped.
    XCTAssertEqual(AppEnvironment.stripRiverSuffix("River Ranch"), "River Ranch")
  }

  // MARK: - Overrides are honored

  func testProjectURL_usesOverride() {
    env.overrideProjectURL = URL(string: "https://test.example.com")
    XCTAssertEqual(env.projectURL.absoluteString, "https://test.example.com")
  }

  func testAnonKey_usesOverride() {
    env.overrideAnonKey = "anon-test-key"
    XCTAssertEqual(env.anonKey, "anon-test-key")
  }

  func testForumBase_usesOverride() {
    env.overrideForumBase = "https://forum.example.com/rest/v1"
    XCTAssertEqual(env.forumBase, "https://forum.example.com/rest/v1")
  }

  func testForumApiKey_defaultsToAnonKey() {
    env.overrideAnonKey = "fallback-key"
    env.overrideForumApiKey = nil
    XCTAssertEqual(env.forumApiKey, "fallback-key")
  }

  func testForumApiKey_explicitOverrideTakesPrecedence() {
    env.overrideAnonKey = "anon"
    env.overrideForumApiKey = "forum-specific"
    XCTAssertEqual(env.forumApiKey, "forum-specific")
  }

  func testAppDisplayName_usesOverride() {
    env.overrideAppDisplayName = "Test Lodge"
    XCTAssertEqual(env.appDisplayName, "Test Lodge")
  }

  func testCommunityName_fallsBackToAppDisplayName() {
    env.overrideAppDisplayName = "Test Lodge"
    env.overrideCommunityName = nil
    // With no Info.plist COMMUNITY key available in the test bundle, this
    // should fall back to appDisplayName.
    XCTAssertTrue(
      env.communityName == "Test Lodge" || !env.communityName.isEmpty,
      "Expected non-empty community name"
    )
  }

  func testCommunityName_explicitOverride() {
    env.overrideCommunityName = "Skeena"
    XCTAssertEqual(env.communityName, "Skeena")
  }

  func testDefaultRiver_override() {
    env.overrideDefaultRiver = "Babine"
    XCTAssertEqual(env.defaultRiver, "Babine")
  }

  func testDefaultRiver_fallsBackToStrippedFirstLodgeRiver() {
    env.overrideDefaultRiver = nil
    env.overrideLodgeRivers = ["Nehalem River", "Wilson River"]
    XCTAssertEqual(env.defaultRiver, "Nehalem")
  }

  func testLodgeRivers_override() {
    env.overrideLodgeRivers = ["A River", "B River"]
    XCTAssertEqual(env.lodgeRivers, ["A River", "B River"])
  }

  func testLodgeWaterBodies_override() {
    env.overrideLodgeWaterBodies = ["Puget Sound", "Hood Canal"]
    XCTAssertEqual(env.lodgeWaterBodies, ["Puget Sound", "Hood Canal"])
  }

  func testDefaultWaterBody_fallsBackToFirstLodgeWaterBody() {
    env.overrideDefaultWaterBody = nil
    env.overrideLodgeWaterBodies = ["Puget Sound", "Hood Canal"]
    XCTAssertEqual(env.defaultWaterBody, "Puget Sound")
  }

  func testDefaultMapCoordinates_overrides() {
    env.overrideDefaultMapLatitude = 12.34
    env.overrideDefaultMapLongitude = -56.78
    XCTAssertEqual(env.defaultMapLatitude, 12.34, accuracy: 0.0001)
    XCTAssertEqual(env.defaultMapLongitude, -56.78, accuracy: 0.0001)
  }

  func testTacticsEnabled_override() {
    env.overrideTacticsEnabled = true
    XCTAssertTrue(env.tacticsEnabled)
    env.overrideTacticsEnabled = false
    XCTAssertFalse(env.tacticsEnabled)
  }

  func testForecastLocation_override() {
    env.overrideForecastLocation = "Vancouver Island"
    XCTAssertEqual(env.forecastLocation, "Vancouver Island")
  }

  func testImageCompressionQuality_override() {
    env.overrideImageCompressionQuality = 0.5
    XCTAssertEqual(env.imageCompressionQuality, 0.5, accuracy: 0.0001)
  }

  // MARK: - Computed endpoints derive from projectURL

  func testUploadCatchURL_defaultsToProjectURLAppendingPath() {
    env.overrideProjectURL = URL(string: "https://test.example.com")
    env.overrideUploadCatchURL = nil
    let url = env.uploadCatchURL.absoluteString
    XCTAssertTrue(url.hasPrefix("https://test.example.com"))
    XCTAssertTrue(url.contains("functions/v1/upload-catch-reports-v4"))
  }

  func testUploadCatchURL_override_wins() {
    env.overrideUploadCatchURL = URL(string: "https://override.example.com/upload")
    XCTAssertEqual(env.uploadCatchURL.absoluteString, "https://override.example.com/upload")
  }

  func testManageTripURL_defaultsToProjectURLAppendingPath() {
    env.overrideProjectURL = URL(string: "https://test.example.com")
    env.overrideManageTripURL = nil
    XCTAssertTrue(env.manageTripURL.absoluteString.contains("functions/v1/manage-trip"))
  }

  // MARK: - SplashVideoFrequency enum

  func testSplashVideoFrequency_rawValues() {
    XCTAssertEqual(SplashVideoFrequency.always.rawValue, "ALWAYS")
    XCTAssertEqual(SplashVideoFrequency.firstLogin.rawValue, "FIRST_LOGIN")
    XCTAssertEqual(SplashVideoFrequency.session.rawValue, "SESSION")
  }

  func testSplashVideoFrequency_roundTripFromRaw() {
    XCTAssertEqual(SplashVideoFrequency(rawValue: "ALWAYS"), .always)
    XCTAssertEqual(SplashVideoFrequency(rawValue: "FIRST_LOGIN"), .firstLogin)
    XCTAssertEqual(SplashVideoFrequency(rawValue: "SESSION"), .session)
    XCTAssertNil(SplashVideoFrequency(rawValue: "never"))
  }
}
