import XCTest
@testable import SkeenaSystem

/// Tests for the feature flag system.
///
/// Validates:
/// 1. readFeatureFlag correctly reads Bool values from Info.plist
/// 2. readFeatureFlag returns false for absent or empty keys
/// 3. Consecutive reads return consistent values
/// 4. Non-boolean Info.plist keys are not misinterpreted as true
final class FeatureFlagTests: XCTestCase {

  // MARK: - readFeatureFlag helper behaviour

  func testReadFeatureFlag_returnsFalseForAbsentKey() {
    // A key that is not in Info.plist should default to false
    let result = readFeatureFlag("FF_NONEXISTENT_FLAG_12345")
    XCTAssertFalse(result, "readFeatureFlag should return false for keys not present in Info.plist")
  }

  func testReadFeatureFlag_returnsFalseForEmptyKey() {
    let result = readFeatureFlag("")
    XCTAssertFalse(result, "readFeatureFlag should return false for an empty key string")
  }

  // MARK: - Consistency: consecutive reads return the same value

  func testReadFeatureFlag_isConsistentAcrossReads() {
    // Pick a flag that exists in Info.plist and verify two reads agree
    let flagsToCheck = [
      "FF_FLIGHT_INFO",
      "FF_MEET_STAFF",
      "FF_GEAR_CHECKLIST",
      "FF_MANAGE_LICENSES",
      "FF_SELF_ASSESSMENT",
      "FF_CATCH_CAROUSEL",
      "FF_THE_BUZZ",
      "FF_CATCH_MAP",
    ]

    for flag in flagsToCheck {
      let first = readFeatureFlag(flag)
      let second = readFeatureFlag(flag)
      XCTAssertEqual(first, second,
                     "readFeatureFlag(\"\(flag)\") should return the same value on consecutive reads")
    }
  }

  // MARK: - Exhaustiveness: all expected flags exist in Info.plist

  func testAllFeatureFlags_presentInInfoPlist() {
    let expectedFlags = [
      "FF_FLIGHT_INFO",
      "FF_MEET_STAFF",
      "FF_GEAR_CHECKLIST",
      "FF_MANAGE_LICENSES",
      "FF_SELF_ASSESSMENT",
      "FF_CATCH_CAROUSEL",
      "FF_THE_BUZZ",
      "FF_CATCH_MAP",
    ]

    for flag in expectedFlags {
      let value = Bundle.main.object(forInfoDictionaryKey: flag)
      XCTAssertNotNil(value, "\(flag) should be present in Info.plist (check xcconfig and Info.plist entries)")
    }
  }

  // MARK: - Consistency: non-FF keys are not treated as feature flags

  func testNonFeatureFlag_keyReturnsExpectedValue() {
    // API_BASE_URL is a string config key, not a boolean flag.
    // readFeatureFlag should return false since it's not "true"/"YES"/1.
    let value = readFeatureFlag("API_BASE_URL")
    XCTAssertFalse(value, "Non-boolean Info.plist values should not be interpreted as true")
  }
}
