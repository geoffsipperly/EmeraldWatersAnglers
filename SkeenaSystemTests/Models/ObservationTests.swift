import XCTest
import CoreLocation
@testable import SkeenaSystem

/// Tests for the `Observation` model: Codable round-trip, `isUploaded`, and
/// the `coordinate` computed property.
final class ObservationTests: XCTestCase {

  private func makeObservation(
    lat: Double? = nil,
    lon: Double? = nil,
    status: ObservationStatus = .savedLocally
  ) -> Observation {
    Observation(
      id: UUID(),
      clientId: UUID(),
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      uploadedAt: nil,
      status: status,
      voiceNoteId: nil,
      transcript: "hello",
      voiceLanguage: "en",
      voiceOnDevice: true,
      voiceSampleRate: 16_000,
      voiceFormat: "wav",
      lat: lat,
      lon: lon,
      horizontalAccuracy: nil
    )
  }

  // MARK: - isUploaded

  func testIsUploaded_falseWhenSavedLocally() {
    let obs = makeObservation(status: .savedLocally)
    XCTAssertFalse(obs.isUploaded)
  }

  func testIsUploaded_trueWhenUploaded() {
    let obs = makeObservation(status: .uploaded)
    XCTAssertTrue(obs.isUploaded)
  }

  // MARK: - coordinate

  func testCoordinate_nilWhenLatMissing() {
    let obs = makeObservation(lat: nil, lon: -122.3)
    XCTAssertNil(obs.coordinate)
  }

  func testCoordinate_nilWhenLonMissing() {
    let obs = makeObservation(lat: 47.6, lon: nil)
    XCTAssertNil(obs.coordinate)
  }

  func testCoordinate_returnsValueWhenBothPresent() {
    let obs = makeObservation(lat: 47.6062, lon: -122.3321)
    let coord = obs.coordinate
    XCTAssertNotNil(coord)
    XCTAssertEqual(coord?.latitude ?? 0, 47.6062, accuracy: 0.0001)
    XCTAssertEqual(coord?.longitude ?? 0, -122.3321, accuracy: 0.0001)
  }

  // MARK: - Codable round-trip

  func testCodable_roundTrip_preservesFields() throws {
    let original = makeObservation(lat: 1.23, lon: 4.56, status: .uploaded)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Observation.self, from: data)
    XCTAssertEqual(decoded, original)
    XCTAssertEqual(decoded.transcript, "hello")
    XCTAssertEqual(decoded.status, .uploaded)
    XCTAssertEqual(decoded.lat, 1.23)
    XCTAssertEqual(decoded.lon, 4.56)
  }

  // MARK: - ObservationStatus

  func testObservationStatus_rawValues() {
    XCTAssertEqual(ObservationStatus.savedLocally.rawValue, "Saved locally")
    XCTAssertEqual(ObservationStatus.uploaded.rawValue, "Uploaded")
  }
}
