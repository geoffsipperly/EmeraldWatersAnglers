import XCTest
import CoreLocation
@testable import SkeenaSystem

/// Tests for the FarmedReport model.
///
/// Validates:
/// 1. Default values and initialization
/// 2. Status enum raw values and Codable conformance
/// 3. Coordinate computation and boundary validation
/// 4. JSON encode/decode round-trip
/// 5. Equatable conformance
final class FarmedReportTests: XCTestCase {

  // MARK: - Helpers

  private func createReport(
    id: UUID = UUID(),
    createdAt: Date = Date(),
    status: FarmedReportStatus = .savedLocally,
    guideName: String = "Test Guide",
    lat: Double? = 54.5,
    lon: Double? = -128.6,
    memberId: String? = nil
  ) -> FarmedReport {
    FarmedReport(
      id: id,
      createdAt: createdAt,
      status: status,
      guideName: guideName,
      lat: lat,
      lon: lon,
      memberId: memberId
    )
  }

  private let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
  }()

  private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()

  // MARK: - Initialization Tests

  func testInit_setsAllFields() {
    let id = UUID()
    let now = Date()
    let report = createReport(
      id: id,
      createdAt: now,
      status: .savedLocally,
      guideName: "Alice",
      lat: 54.0,
      lon: -128.0,
      memberId: "A-12345"
    )

    XCTAssertEqual(report.id, id)
    XCTAssertEqual(report.createdAt, now)
    XCTAssertEqual(report.status, .savedLocally)
    XCTAssertEqual(report.guideName, "Alice")
    XCTAssertEqual(report.lat, 54.0)
    XCTAssertEqual(report.lon, -128.0)
    XCTAssertEqual(report.memberId, "A-12345")
  }

  func testInit_memberIdIsOptional() {
    let report = createReport(memberId: nil)
    XCTAssertNil(report.memberId, "memberId should default to nil")
  }

  func testInit_locationIsOptional() {
    let report = createReport(lat: nil, lon: nil)
    XCTAssertNil(report.lat)
    XCTAssertNil(report.lon)
  }

  // MARK: - Status Tests

  func testStatus_savedLocally_rawValue() {
    XCTAssertEqual(FarmedReportStatus.savedLocally.rawValue, "Saved locally")
  }

  func testStatus_uploaded_rawValue() {
    XCTAssertEqual(FarmedReportStatus.uploaded.rawValue, "Uploaded")
  }

  func testIsUploaded_falseWhenSavedLocally() {
    let report = createReport(status: .savedLocally)
    XCTAssertFalse(report.isUploaded)
  }

  func testIsUploaded_trueWhenUploaded() {
    let report = createReport(status: .uploaded)
    XCTAssertTrue(report.isUploaded)
  }

  // MARK: - Coordinate Tests

  func testCoordinate_returnsValidCoordinate() {
    let report = createReport(lat: 54.5, lon: -128.6)
    let coord = report.coordinate

    XCTAssertNotNil(coord)
    XCTAssertEqual(coord?.latitude, 54.5)
    XCTAssertEqual(coord?.longitude, -128.6)
  }

  func testCoordinate_nilWhenLatMissing() {
    let report = createReport(lat: nil, lon: -128.6)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lat is missing")
  }

  func testCoordinate_nilWhenLonMissing() {
    let report = createReport(lat: 54.5, lon: nil)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lon is missing")
  }

  func testCoordinate_nilWhenBothMissing() {
    let report = createReport(lat: nil, lon: nil)
    XCTAssertNil(report.coordinate)
  }

  func testCoordinate_nilWhenLatOutOfRange() {
    let report = createReport(lat: 91.0, lon: -128.6)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lat > 90")
  }

  func testCoordinate_nilWhenLatNegativeOutOfRange() {
    let report = createReport(lat: -91.0, lon: -128.6)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lat < -90")
  }

  func testCoordinate_nilWhenLonOutOfRange() {
    let report = createReport(lat: 54.5, lon: 181.0)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lon > 180")
  }

  func testCoordinate_nilWhenLonNegativeOutOfRange() {
    let report = createReport(lat: 54.5, lon: -181.0)
    XCTAssertNil(report.coordinate, "Coordinate should be nil when lon < -180")
  }

  func testCoordinate_validAtBoundary_90_180() {
    let report = createReport(lat: 90.0, lon: 180.0)
    XCTAssertNotNil(report.coordinate, "Coordinate should be valid at boundary lat=90, lon=180")
  }

  func testCoordinate_validAtBoundary_negative90_negative180() {
    let report = createReport(lat: -90.0, lon: -180.0)
    XCTAssertNotNil(report.coordinate, "Coordinate should be valid at boundary lat=-90, lon=-180")
  }

  // MARK: - JSON Round-Trip Tests

  func testEncodeDecode_roundTrip_allFields() throws {
    let report = createReport(
      guideName: "Bob",
      lat: 54.123,
      lon: -128.456,
      memberId: "X-999"
    )

    let data = try encoder.encode(report)
    let decoded = try decoder.decode(FarmedReport.self, from: data)

    XCTAssertEqual(decoded.id, report.id)
    XCTAssertEqual(decoded.guideName, "Bob")
    XCTAssertEqual(decoded.lat, 54.123)
    XCTAssertEqual(decoded.lon, -128.456)
    XCTAssertEqual(decoded.memberId, "X-999")
    XCTAssertEqual(decoded.status, .savedLocally)
    // ISO 8601 may truncate subsecond precision
    XCTAssertEqual(
      decoded.createdAt.timeIntervalSince1970,
      report.createdAt.timeIntervalSince1970,
      accuracy: 1.0
    )
  }

  func testEncodeDecode_roundTrip_nilOptionals() throws {
    let report = createReport(lat: nil, lon: nil, memberId: nil)

    let data = try encoder.encode(report)
    let decoded = try decoder.decode(FarmedReport.self, from: data)

    XCTAssertEqual(decoded.id, report.id)
    XCTAssertEqual(decoded.guideName, report.guideName)
    XCTAssertNil(decoded.lat)
    XCTAssertNil(decoded.lon)
    XCTAssertNil(decoded.memberId)
  }

  func testEncodeDecode_statusPreserved() throws {
    let uploaded = createReport(status: .uploaded)
    let data = try encoder.encode(uploaded)
    let decoded = try decoder.decode(FarmedReport.self, from: data)

    XCTAssertEqual(decoded.status, .uploaded, "Status should survive round-trip")
  }

  func testEncodeDecode_datePreserved() throws {
    let now = Date()
    let report = createReport(createdAt: now)

    let data = try encoder.encode(report)
    let decoded = try decoder.decode(FarmedReport.self, from: data)

    // ISO 8601 truncates to seconds
    XCTAssertEqual(
      decoded.createdAt.timeIntervalSince1970,
      now.timeIntervalSince1970,
      accuracy: 1.0,
      "Date should survive round-trip within 1 second accuracy"
    )
  }

  // MARK: - Equatable Tests

  func testEquatable_sameValues_areEqual() {
    let id = UUID()
    let now = Date()
    let a = FarmedReport(id: id, createdAt: now, status: .savedLocally, guideName: "G", lat: 1.0, lon: 2.0, memberId: nil)
    let b = FarmedReport(id: id, createdAt: now, status: .savedLocally, guideName: "G", lat: 1.0, lon: 2.0, memberId: nil)

    XCTAssertEqual(a, b)
  }

  func testEquatable_differentIds_areNotEqual() {
    let now = Date()
    let a = FarmedReport(id: UUID(), createdAt: now, status: .savedLocally, guideName: "G", lat: 1.0, lon: 2.0, memberId: nil)
    let b = FarmedReport(id: UUID(), createdAt: now, status: .savedLocally, guideName: "G", lat: 1.0, lon: 2.0, memberId: nil)

    XCTAssertNotEqual(a, b)
  }

  func testEquatable_differentStatus_areNotEqual() {
    let id = UUID()
    let now = Date()
    let a = FarmedReport(id: id, createdAt: now, status: .savedLocally, guideName: "G")
    let b = FarmedReport(id: id, createdAt: now, status: .uploaded, guideName: "G")

    XCTAssertNotEqual(a, b)
  }

  // MARK: - NoCatchEventType Tests

  func testNoCatchEventType_allCases() {
    XCTAssertEqual(NoCatchEventType.allCases.count, 4)
    XCTAssertTrue(NoCatchEventType.allCases.contains(.active))
    XCTAssertTrue(NoCatchEventType.allCases.contains(.farmed))
    XCTAssertTrue(NoCatchEventType.allCases.contains(.promising))
    XCTAssertTrue(NoCatchEventType.allCases.contains(.passed))
  }

  func testNoCatchEventType_rawValues() {
    XCTAssertEqual(NoCatchEventType.active.rawValue, "active")
    XCTAssertEqual(NoCatchEventType.farmed.rawValue, "farmed")
    XCTAssertEqual(NoCatchEventType.promising.rawValue, "promising")
    XCTAssertEqual(NoCatchEventType.passed.rawValue, "passed")
  }

  func testNoCatchEventType_displayNames() {
    XCTAssertEqual(NoCatchEventType.active.displayName, "Active")
    XCTAssertEqual(NoCatchEventType.farmed.displayName, "Farmed")
    XCTAssertEqual(NoCatchEventType.promising.displayName, "Promising")
    XCTAssertEqual(NoCatchEventType.passed.displayName, "Passed")
  }

  func testNoCatchEventType_codableRoundTrip() throws {
    for eventType in NoCatchEventType.allCases {
      let data = try JSONEncoder().encode(eventType)
      let decoded = try JSONDecoder().decode(NoCatchEventType.self, from: data)
      XCTAssertEqual(decoded, eventType, "Round-trip failed for \(eventType.rawValue)")
    }
  }

  // MARK: - eventType on FarmedReport

  func testInit_eventTypeDefaultsToFarmed() {
    let report = createReport()
    XCTAssertEqual(report.eventType, .farmed, "eventType should default to .farmed")
  }

  func testInit_eventTypeCanBeSet() {
    let report = FarmedReport(
      id: UUID(), createdAt: Date(), status: .savedLocally,
      eventType: .promising, guideName: "Guide"
    )
    XCTAssertEqual(report.eventType, .promising)
  }

  func testEncodeDecode_eventTypePreserved() throws {
    for eventType in NoCatchEventType.allCases {
      let report = FarmedReport(
        id: UUID(), createdAt: Date(), status: .savedLocally,
        eventType: eventType, guideName: "Guide", lat: 54.0, lon: -128.0
      )
      let data = try encoder.encode(report)
      let decoded = try decoder.decode(FarmedReport.self, from: data)
      XCTAssertEqual(decoded.eventType, eventType,
                     "eventType \(eventType.rawValue) should survive round-trip")
    }
  }

  func testDecode_missingEventType_defaultsToFarmed() throws {
    // Simulate legacy JSON without eventType field
    let json = """
    {
      "id": "\(UUID().uuidString)",
      "createdAt": "2026-03-30T10:00:00Z",
      "status": "Saved locally",
      "guideName": "Legacy Guide",
      "lat": 54.5,
      "lon": -128.6
    }
    """.data(using: .utf8)!

    let decoded = try decoder.decode(FarmedReport.self, from: json)
    XCTAssertEqual(decoded.eventType, .farmed,
                   "Missing eventType should default to .farmed for backward compatibility")
  }

  func testEquatable_differentEventType_areNotEqual() {
    let id = UUID()
    let now = Date()
    let a = FarmedReport(id: id, createdAt: now, status: .savedLocally, eventType: .farmed, guideName: "G")
    let b = FarmedReport(id: id, createdAt: now, status: .savedLocally, eventType: .active, guideName: "G")
    XCTAssertNotEqual(a, b)
  }
}
