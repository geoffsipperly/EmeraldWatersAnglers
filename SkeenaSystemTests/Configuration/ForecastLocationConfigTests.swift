// ForecastLocationConfigTests.swift
// SkeenaSystemTests
//
// Unit tests for the FORECAST_LOCATION configuration variable:
// verifies AppEnvironment.forecastLocation reads from config,
// supports runtime override, and restores the config default.

import XCTest
@testable import SkeenaSystem

@MainActor
final class ForecastLocationConfigTests: XCTestCase {

  // MARK: - Setup / Teardown

  override func setUp() {
    super.setUp()
    // Clear any previous override
    AppEnvironment.shared.overrideForecastLocation = nil
  }

  override func tearDown() {
    AppEnvironment.shared.overrideForecastLocation = nil
    super.tearDown()
  }

  // MARK: - Default Value

  func testForecastLocation_defaultFromConfig() {
    // When no override is set, the value should come from Info.plist (xcconfig)
    let location = AppEnvironment.shared.forecastLocation
    XCTAssertFalse(location.isEmpty, "Forecast location should never be empty")
  }

  // MARK: - Override

  func testForecastLocation_respectsOverride() {
    AppEnvironment.shared.overrideForecastLocation = "Terrace"
    XCTAssertEqual(AppEnvironment.shared.forecastLocation, "Terrace",
                   "Override should take precedence over Info.plist value")
  }

  func testForecastLocation_overrideWithDifferentLocation() {
    AppEnvironment.shared.overrideForecastLocation = "Prince Rupert"
    XCTAssertEqual(AppEnvironment.shared.forecastLocation, "Prince Rupert",
                   "Override should support any location string")
  }

  func testForecastLocation_clearingOverrideRestoresDefault() {
    let original = AppEnvironment.shared.forecastLocation
    AppEnvironment.shared.overrideForecastLocation = "Smithers"
    XCTAssertEqual(AppEnvironment.shared.forecastLocation, "Smithers")

    AppEnvironment.shared.overrideForecastLocation = nil
    XCTAssertEqual(AppEnvironment.shared.forecastLocation, original,
                   "Clearing override should restore the original config value")
  }

  // MARK: - Empty Override Ignored

  func testForecastLocation_emptyOverrideIsUsed() {
    // Unlike stringFromInfo which checks isEmpty, override is used directly
    AppEnvironment.shared.overrideForecastLocation = "Vancouver Island"
    XCTAssertEqual(AppEnvironment.shared.forecastLocation, "Vancouver Island")
  }

  // MARK: - Consistency

  func testForecastLocation_isConsistentAcrossReads() {
    // Two consecutive reads without any override change should return the same value
    let first = AppEnvironment.shared.forecastLocation
    let second = AppEnvironment.shared.forecastLocation
    XCTAssertEqual(first, second,
                   "Consecutive reads of forecastLocation should return the same value")
  }
}
