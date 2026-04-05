import XCTest
@testable import SkeenaSystem

/// Tests for `CatchReportDTO` decoding and the `displayLocation` fallback chain.
final class CatchReportDTOTests: XCTestCase {

  // MARK: - JSON decoding

  func testDecode_fullPayload_populatesAllFields() throws {
    let json = """
    {
      "catch_id": "abc-123",
      "created_at": "2025-01-15T12:34:56Z",
      "latitude": 49.1234,
      "longitude": -122.5678,
      "river": "Babine River",
      "photo_url": "https://example.com/photo.jpg",
      "notes": "Big fish",
      "species": "Steelhead",
      "sex": "M",
      "length_inches": 36,
      "girth_inches": 18.5,
      "weight_lbs": 14.2
    }
    """.data(using: .utf8)!

    let dto = try JSONDecoder().decode(CatchReportDTO.self, from: json)
    XCTAssertEqual(dto.id, "abc-123")
    XCTAssertEqual(dto.createdAt, "2025-01-15T12:34:56Z")
    XCTAssertEqual(dto.river, "Babine River")
    XCTAssertEqual(dto.species, "Steelhead")
    XCTAssertEqual(dto.length_inches, 36)
    XCTAssertEqual(dto.girth_inches, 18.5)
    XCTAssertEqual(dto.weight_lbs, 14.2)
    XCTAssertEqual(dto.photoURL?.absoluteString, "https://example.com/photo.jpg")
  }

  func testDecode_minimalPayload_allowsNilOptionals() throws {
    let json = """
    { "catch_id": "x", "created_at": "t", "river": "Babine" }
    """.data(using: .utf8)!
    let dto = try JSONDecoder().decode(CatchReportDTO.self, from: json)
    XCTAssertNil(dto.latitude)
    XCTAssertNil(dto.photo_url)
    XCTAssertNil(dto.photoURL)
    XCTAssertNil(dto.species)
  }

  // MARK: - displayLocation

  private func makeDTO(
    river: String,
    latitude: Double? = nil,
    longitude: Double? = nil
  ) -> CatchReportDTO {
    CatchReportDTO(
      catch_id: "id",
      created_at: "t",
      latitude: latitude,
      longitude: longitude,
      river: river,
      photo_url: nil,
      notes: nil,
      species: nil,
      sex: nil,
      length_inches: nil,
      girth_inches: nil,
      weight_lbs: nil
    )
  }

  func testDisplayLocation_knownRiver_returnsRiverName() {
    let dto = makeDTO(river: "Babine River", latitude: 1, longitude: 2)
    XCTAssertEqual(dto.displayLocation, "Babine River")
  }

  func testDisplayLocation_unableToDetect_withCoordinates_returnsFormattedGPS() {
    let dto = makeDTO(
      river: "Unable to detect via GPS",
      latitude: 49.1234,
      longitude: -122.5678
    )
    XCTAssertEqual(dto.displayLocation, "49.1234, -122.5678")
  }

  func testDisplayLocation_unknownRiver_withCoordinates_returnsFormattedGPS() {
    let dto = makeDTO(river: "Unknown", latitude: 1.0, longitude: 2.0)
    XCTAssertEqual(dto.displayLocation, "1.0000, 2.0000")
  }

  func testDisplayLocation_unknownRiver_withoutCoordinates_returnsDash() {
    let dto = makeDTO(river: "unknown")
    XCTAssertEqual(dto.displayLocation, "-")
  }

  func testDisplayLocation_unableToDetect_caseInsensitive() {
    let dto = makeDTO(river: "UNABLE TO DETECT location")
    XCTAssertEqual(dto.displayLocation, "-")
  }
}
