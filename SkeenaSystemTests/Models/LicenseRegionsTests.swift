import XCTest
@testable import SkeenaSystem

/// Tests for `LicenseCountry` country/subdivision catalog used in registration forms.
final class LicenseRegionsTests: XCTestCase {

  func testAllCases_containsUSAndCA() {
    XCTAssertEqual(Set(LicenseCountry.allCases), [.US, .CA])
  }

  func testIdentifier_matchesRawValue() {
    XCTAssertEqual(LicenseCountry.US.id, "US")
    XCTAssertEqual(LicenseCountry.CA.id, "CA")
  }

  func testDisplayNames() {
    XCTAssertEqual(LicenseCountry.US.displayName, "United States")
    XCTAssertEqual(LicenseCountry.CA.displayName, "Canada")
  }

  func testSubdivisionLabels() {
    XCTAssertEqual(LicenseCountry.US.subdivisionLabel, "State")
    XCTAssertEqual(LicenseCountry.CA.subdivisionLabel, "Province")
  }

  func testUSSubdivisions_contains50Unique() {
    let states = LicenseCountry.US.subdivisions
    XCTAssertEqual(states.count, 50)
    XCTAssertEqual(Set(states).count, 50, "State list must be unique")
    XCTAssertTrue(states.contains("California"))
    XCTAssertTrue(states.contains("New York"))
    XCTAssertTrue(states.contains("Wyoming"))
  }

  func testCASubdivisions_contains13Unique() {
    let provinces = LicenseCountry.CA.subdivisions
    XCTAssertEqual(provinces.count, 13)
    XCTAssertEqual(Set(provinces).count, 13, "Province list must be unique")
    XCTAssertTrue(provinces.contains("British Columbia"))
    XCTAssertTrue(provinces.contains("Ontario"))
    XCTAssertTrue(provinces.contains("Yukon"))
  }

  func testUSAndCASubdivisions_doNotOverlap() {
    let states = Set(LicenseCountry.US.subdivisions)
    let provinces = Set(LicenseCountry.CA.subdivisions)
    XCTAssertTrue(states.isDisjoint(with: provinces))
  }
}
