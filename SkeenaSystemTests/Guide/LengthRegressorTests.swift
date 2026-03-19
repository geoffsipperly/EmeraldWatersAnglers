import XCTest
@testable import SkeenaSystem

/// Regression tests for Phase 2 ML length estimation pipeline.
///
/// These tests verify the feature vector construction, feature ordering,
/// and integration of the new length regressor with existing structures.
/// The CatchPhotoAnalyzer's internal types (NormalizedBox, DetectionResult,
/// HandMeasurement) are private, so we test through the public-facing
/// LengthFeatureVector struct and CatchPhotoAnalysis.
final class LengthRegressorTests: XCTestCase {

  // MARK: - Feature Column Ordering

  func testFeatureColsCount_is26() {
    XCTAssertEqual(
      CatchPhotoAnalyzer.featureCols.count, 26,
      "FEATURE_COLS must have exactly 26 entries to match the trained model"
    )
  }

  func testFeatureColsOrder_matchesPythonPipeline() {
    // This exact order must match train_length_regressor.py FEATURE_COLS.
    // If this test fails, predictions will be silently wrong.
    let expected = [
      "fish_box_width",
      "fish_box_height",
      "fish_box_area",
      "fish_aspect_ratio",
      "fish_confidence",
      "person_box_height",
      "person_box_width",
      "person_aspect_ratio",
      "fish_to_person_ratio",
      "species_index",
      "species_confidence",
      "diagonal_fraction",
      "hand_detected",
      "finger_width_px",
      "finger_length_px",
      "ppi_from_finger",
      "fish_to_finger_width",
      "fish_to_finger_length",
      "fish_inches_from_finger",
      "fish_pixel_length",
      "pixel_length_to_person",
      "fish_w_to_person_h",
      "fish_h_to_person_h",
      "fish_area_to_person_h_sq",
      "fish_w_to_person_w",
      "fish_area_to_person_w_sq",
    ]

    XCTAssertEqual(
      CatchPhotoAnalyzer.featureCols, expected,
      "Feature column order must exactly match the Python training pipeline"
    )
  }

  func testFeatureColsHaveNoDuplicates() {
    let cols = CatchPhotoAnalyzer.featureCols
    let uniqueCols = Set(cols)
    XCTAssertEqual(
      cols.count, uniqueCols.count,
      "Feature columns must not contain duplicates"
    )
  }

  // MARK: - LengthFeatureVector

  func testFeatureVectorAsArray_has26Elements() {
    let fv = makeFeatureVector()
    XCTAssertEqual(
      fv.asArray.count, 26,
      "asArray must return exactly 26 values matching featureCols"
    )
  }

  func testFeatureVectorAsArray_matchesFeatureColsCount() {
    let fv = makeFeatureVector()
    XCTAssertEqual(
      fv.asArray.count, CatchPhotoAnalyzer.featureCols.count,
      "asArray count must equal featureCols count"
    )
  }

  func testFeatureVectorAsArray_orderMatchesProperties() {
    // Verify the array order by constructing with known values
    let fv = CatchPhotoAnalyzer.LengthFeatureVector(
      fishBoxWidth: 1.0,
      fishBoxHeight: 2.0,
      fishBoxArea: 3.0,
      fishAspectRatio: 4.0,
      fishConfidence: 5.0,
      personBoxHeight: 6.0,
      personBoxWidth: 7.0,
      personAspectRatio: 8.0,
      fishToPersonRatio: 9.0,
      speciesIndex: 10.0,
      speciesConfidence: 11.0,
      diagonalFraction: 12.0,
      handDetected: 13.0,
      fingerWidthPx: 14.0,
      fingerLengthPx: 15.0,
      ppiFromFinger: 16.0,
      fishToFingerWidth: 17.0,
      fishToFingerLength: 18.0,
      fishInchesFromFinger: 19.0,
      fishPixelLength: 20.0,
      pixelLengthToPerson: 21.0,
      fishWToPersonH: 22.0,
      fishHToPersonH: 23.0,
      fishAreaToPersonHSq: 24.0,
      fishWToPersonW: 25.0,
      fishAreaToPersonWSq: 26.0
    )

    let arr = fv.asArray
    for i in 0 ..< 26 {
      XCTAssertEqual(
        arr[i], Double(i + 1),
        "asArray[\(i)] (\(CatchPhotoAnalyzer.featureCols[i])) should be \(i + 1)"
      )
    }
  }

  func testFeatureVector_isCodable() throws {
    let fv = makeFeatureVector(fishBoxWidth: 123.4, speciesIndex: 3)
    let data = try JSONEncoder().encode(fv)
    let decoded = try JSONDecoder().decode(CatchPhotoAnalyzer.LengthFeatureVector.self, from: data)

    XCTAssertEqual(decoded.fishBoxWidth, 123.4, accuracy: 0.001)
    XCTAssertEqual(decoded.speciesIndex, 3.0, accuracy: 0.001)
    XCTAssertEqual(decoded.asArray.count, 26)
  }

  func testFeatureVector_noPersonZerosPersonFields() {
    let fv = makeFeatureVector(personBoxHeight: 0, personBoxWidth: 0)
    XCTAssertEqual(fv.personBoxHeight, 0.0)
    XCTAssertEqual(fv.personBoxWidth, 0.0)
    XCTAssertEqual(fv.personAspectRatio, 0.0)
    XCTAssertEqual(fv.fishToPersonRatio, 0.0)
  }

  func testFeatureVector_noHandZerosHandFields() {
    let fv = makeFeatureVector(handDetected: 0)
    XCTAssertEqual(fv.handDetected, 0.0)
    XCTAssertEqual(fv.fingerWidthPx, 0.0)
    XCTAssertEqual(fv.fingerLengthPx, 0.0)
    XCTAssertEqual(fv.ppiFromFinger, 0.0)
    XCTAssertEqual(fv.fishToFingerWidth, 0.0)
    XCTAssertEqual(fv.fishToFingerLength, 0.0)
    XCTAssertEqual(fv.fishInchesFromFinger, 0.0)
  }

  // MARK: - LengthEstimateSource

  func testLengthEstimateSource_allCases() {
    // Verify the enum has the expected raw values for Codable serialization
    XCTAssertEqual(LengthEstimateSource.regressor.rawValue, "regressor")
    XCTAssertEqual(LengthEstimateSource.heuristic.rawValue, "heuristic")
    XCTAssertEqual(LengthEstimateSource.manual.rawValue, "manual")
  }

  func testLengthEstimateSource_isCodable() throws {
    let source = LengthEstimateSource.regressor
    let data = try JSONEncoder().encode(source)
    let decoded = try JSONDecoder().decode(LengthEstimateSource.self, from: data)
    XCTAssertEqual(decoded, source)
  }

  // MARK: - CatchPhotoAnalysis struct defaults

  func testCatchPhotoAnalysis_newFieldsDefaultToNil() {
    // Existing construction pattern must still compile and default new fields to nil
    let analysis = CatchPhotoAnalysis(
      riverName: "Test River",
      species: "rainbow holding",
      sex: "male",
      estimatedLength: "32 inches"
    )

    XCTAssertNil(analysis.featureVector, "featureVector should default to nil")
    XCTAssertNil(analysis.lengthSource, "lengthSource should default to nil")
    XCTAssertNil(analysis.lifecycleStage, "lifecycleStage should default to nil")
  }

  func testCatchPhotoAnalysis_canSetNewFields() {
    let fv = makeFeatureVector()
    let analysis = CatchPhotoAnalysis(
      riverName: nil,
      species: nil,
      sex: nil,
      estimatedLength: "28 inches (ML estimate)",
      featureVector: fv,
      lengthSource: .regressor
    )

    XCTAssertNotNil(analysis.featureVector)
    XCTAssertEqual(analysis.lengthSource, .regressor)
    XCTAssertEqual(analysis.featureVector?.asArray.count, 26)
  }

  func testCatchPhotoAnalysis_manualCorrection_preservesSource() {
    let analysis = CatchPhotoAnalysis(
      riverName: "Skeena",
      species: "steelhead",
      sex: "female",
      estimatedLength: "38 inches",
      lengthSource: .manual
    )

    XCTAssertEqual(analysis.lengthSource, .manual)
    XCTAssertNil(analysis.featureVector, "Manual corrections should not have a feature vector")
  }

  // MARK: - Engineered feature consistency

  func testEngineeredFeatures_fishPixelLength_isMax() {
    let fv = makeFeatureVector(fishBoxWidth: 200, fishBoxHeight: 100)
    XCTAssertEqual(fv.fishPixelLength, 200.0, "fishPixelLength should be max(width, height)")

    let fv2 = makeFeatureVector(fishBoxWidth: 100, fishBoxHeight: 300)
    XCTAssertEqual(fv2.fishPixelLength, 300.0, "fishPixelLength should be max(width, height)")
  }

  func testEngineeredFeatures_ratiosUseClampedDenominator() {
    // When person box is 0, denominators should be clamped to 1.0 (not divide by zero)
    let fv = makeFeatureVector(fishBoxWidth: 200, fishBoxHeight: 100, personBoxHeight: 0, personBoxWidth: 0)

    // With clamped denominator of 1.0, ratios should equal the numerator
    XCTAssertEqual(fv.pixelLengthToPerson, 200.0, accuracy: 0.001,
                   "With no person, clamped denominator should be 1.0")
    XCTAssertEqual(fv.fishWToPersonH, 200.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishHToPersonH, 100.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishWToPersonW, 200.0, accuracy: 0.001)
  }

  func testEngineeredFeatures_withPerson_computesRatios() {
    let fv = makeFeatureVector(fishBoxWidth: 200, fishBoxHeight: 100, personBoxHeight: 400, personBoxWidth: 150)

    XCTAssertEqual(fv.fishPixelLength, 200.0, accuracy: 0.001)
    XCTAssertEqual(fv.pixelLengthToPerson, 200.0 / 400.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishWToPersonH, 200.0 / 400.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishHToPersonH, 100.0 / 400.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishAreaToPersonHSq, (200.0 * 100.0) / (400.0 * 400.0), accuracy: 0.001)
    XCTAssertEqual(fv.fishWToPersonW, 200.0 / 150.0, accuracy: 0.001)
    XCTAssertEqual(fv.fishAreaToPersonWSq, (200.0 * 100.0) / (150.0 * 150.0), accuracy: 0.001)
  }

  // MARK: - Helpers

  /// Creates a LengthFeatureVector with configurable values and sensible defaults.
  private func makeFeatureVector(
    fishBoxWidth: Double = 200,
    fishBoxHeight: Double = 100,
    personBoxHeight: Double = 400,
    personBoxWidth: Double = 150,
    speciesIndex: Double = 0,
    handDetected: Double = 0
  ) -> CatchPhotoAnalyzer.LengthFeatureVector {
    let fw = fishBoxWidth
    let fh = fishBoxHeight
    let fishArea = fw * fh
    let pH = personBoxHeight
    let pW = personBoxWidth
    let clampedPH = max(pH, 1.0)
    let clampedPW = max(pW, 1.0)
    let fishPixelLength = max(fw, fh)

    return CatchPhotoAnalyzer.LengthFeatureVector(
      fishBoxWidth: fw,
      fishBoxHeight: fh,
      fishBoxArea: fishArea,
      fishAspectRatio: fw / max(fh, 1.0),
      fishConfidence: 0.85,
      personBoxHeight: pH,
      personBoxWidth: pW,
      personAspectRatio: pH > 0 ? pW / pH : 0.0,
      fishToPersonRatio: pH > 0 ? max(fw, fh) / pH : 0.0,
      speciesIndex: speciesIndex,
      speciesConfidence: 0.9,
      diagonalFraction: 0.3,
      handDetected: handDetected,
      fingerWidthPx: 0.0,
      fingerLengthPx: 0.0,
      ppiFromFinger: 0.0,
      fishToFingerWidth: 0.0,
      fishToFingerLength: 0.0,
      fishInchesFromFinger: 0.0,
      fishPixelLength: fishPixelLength,
      pixelLengthToPerson: fishPixelLength / clampedPH,
      fishWToPersonH: fw / clampedPH,
      fishHToPersonH: fh / clampedPH,
      fishAreaToPersonHSq: fishArea / (clampedPH * clampedPH),
      fishWToPersonW: fw / clampedPW,
      fishAreaToPersonWSq: fishArea / (clampedPW * clampedPW)
    )
  }
}
