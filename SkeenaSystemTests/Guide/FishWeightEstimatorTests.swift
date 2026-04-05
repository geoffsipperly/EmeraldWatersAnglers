import XCTest
@testable import SkeenaSystem

/// Tests for FishWeightEstimator — the pure-math weight/girth estimator.
///
/// Validates:
/// 1. `lookupDivisor` cascading: river+species override > species-only > default (800).
/// 2. `lookupGirthRatio` returns species-specific ratio or the 0.58 default.
/// 3. `estimate(lengthInches:species:river:)` computes girth and weight correctly.
/// 4. `estimateWeight(lengthInches:girthInches:...)` uses the caller-supplied girth.
/// 5. Species normalization strips lifecycle suffixes and honors aliases.
final class FishWeightEstimatorTests: XCTestCase {

  // MARK: - lookupDivisor

  func testLookupDivisor_babineSteelhead_usesRiverOverride() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "steelhead", river: "Babine River"
    )
    XCTAssertEqual(divisor, 690)
    XCTAssertEqual(source, "Babine River steelhead")
  }

  func testLookupDivisor_skeenaSteelhead_usesSkeenaOverride() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "Steelhead", river: "Upper Skeena"
    )
    XCTAssertEqual(divisor, 690)
    XCTAssertEqual(source, "Skeena/Kispiox steelhead")
  }

  func testLookupDivisor_speciesOnly_usesSpeciesTable() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "chinook", river: nil
    )
    XCTAssertEqual(divisor, 740)
    XCTAssertEqual(source, "Chinook salmon")
  }

  func testLookupDivisor_unknownSpecies_returnsDefault() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "sturgeon", river: "Fraser"
    )
    XCTAssertEqual(divisor, FishWeightEstimator.defaultDivisor)
    XCTAssertEqual(source, "Default")
  }

  func testLookupDivisor_nilSpeciesAndRiver_returnsDefault() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(species: nil, river: nil)
    XCTAssertEqual(divisor, 800)
    XCTAssertEqual(source, "Default")
  }

  func testLookupDivisor_speciesAliasKing_mapsToChinook() {
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "king salmon", river: nil
    )
    XCTAssertEqual(divisor, 740)
    XCTAssertEqual(source, "Chinook salmon")
  }

  func testLookupDivisor_stripsLifecycleSuffix() {
    // "steelhead holding" should normalize to "steelhead".
    let (divisor, source) = FishWeightEstimator.lookupDivisor(
      species: "Steelhead holding", river: nil
    )
    XCTAssertEqual(divisor, 775)
    XCTAssertEqual(source, "General steelhead")
  }

  // MARK: - lookupGirthRatio

  func testLookupGirthRatio_knownSpecies_returnsSpeciesRatio() {
    let (ratio, source) = FishWeightEstimator.lookupGirthRatio(species: "chinook")
    XCTAssertEqual(ratio, 0.60, accuracy: 0.0001)
    XCTAssertTrue(source.lowercased().contains("chinook"))
  }

  func testLookupGirthRatio_nil_returnsDefault() {
    let (ratio, source) = FishWeightEstimator.lookupGirthRatio(species: nil)
    XCTAssertEqual(ratio, FishWeightEstimator.defaultGirthRatio, accuracy: 0.0001)
    XCTAssertTrue(source.lowercased().contains("default"))
  }

  func testLookupGirthRatio_pike_usesElongatedRatio() {
    let (ratio, _) = FishWeightEstimator.lookupGirthRatio(species: "Northern Pike")
    XCTAssertEqual(ratio, 0.46, accuracy: 0.0001)
  }

  // MARK: - estimate(lengthInches:species:river:)

  func testEstimate_babineSteelhead_usesOverrideDivisorAndSpeciesRatio() {
    let estimate = FishWeightEstimator.estimate(
      lengthInches: 36, species: "steelhead", river: "Babine"
    )
    // ratio 0.58, divisor 690
    let expectedGirth = 36.0 * 0.58                 // 20.88
    let expectedWeight = 36.0 * expectedGirth * expectedGirth / 690.0
    XCTAssertEqual(estimate.divisor, 690)
    XCTAssertEqual(estimate.divisorSource, "Babine River steelhead")
    XCTAssertEqual(estimate.girthRatio, 0.58, accuracy: 0.0001)
    XCTAssertEqual(estimate.girthInches, round(expectedGirth * 10) / 10, accuracy: 0.0001)
    XCTAssertEqual(
      estimate.weightLbs,
      round(expectedWeight * 100) / 100,
      accuracy: 0.0001
    )
    XCTAssertTrue(estimate.girthIsEstimated)
  }

  func testEstimate_unknownSpecies_usesDefaults() {
    let estimate = FishWeightEstimator.estimate(
      lengthInches: 20, species: nil, river: nil
    )
    XCTAssertEqual(estimate.divisor, 800)
    XCTAssertEqual(estimate.girthRatio, 0.58, accuracy: 0.0001)
    // Girth = 20 * 0.58 = 11.6, weight = 20 * 11.6^2 / 800 = 3.364
    XCTAssertEqual(estimate.girthInches, 11.6, accuracy: 0.0001)
    XCTAssertEqual(estimate.weightLbs, 3.36, accuracy: 0.01)
  }

  // MARK: - estimateWeight(lengthInches:girthInches:...)

  func testEstimateWeight_usesProvidedGirth() {
    let estimate = FishWeightEstimator.estimateWeight(
      lengthInches: 30, girthInches: 18, species: "coho", river: nil
    )
    // coho divisor = 790; weight = 30 * 18^2 / 790 = 12.303...
    XCTAssertEqual(estimate.divisor, 790)
    XCTAssertEqual(estimate.girthInches, 18.0, accuracy: 0.0001)
    XCTAssertEqual(estimate.weightLbs, round((30.0 * 324.0 / 790.0) * 100) / 100, accuracy: 0.01)
    XCTAssertFalse(estimate.girthIsEstimated)
  }

  func testEstimateWeight_zeroLength_isZero() {
    let estimate = FishWeightEstimator.estimateWeight(
      lengthInches: 0, girthInches: 0, species: "steelhead", river: "Babine"
    )
    XCTAssertEqual(estimate.weightLbs, 0, accuracy: 0.0001)
    XCTAssertEqual(estimate.girthInches, 0, accuracy: 0.0001)
  }
}
