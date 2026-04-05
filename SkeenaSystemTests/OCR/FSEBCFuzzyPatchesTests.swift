import XCTest
import CoreGraphics
@testable import SkeenaSystem

/// Tests for `FSEBCFuzzyPatches` — the OCR post-processing helpers that
/// tolerate small recognition errors and clean up parsed license rows.
final class FSEBCFuzzyPatchesTests: XCTestCase {

  // MARK: - Helpers

  private func line(_ text: String, y: CGFloat = 0.5, minX: CGFloat = 0.05) -> OCRLine {
    OCRLine(
      text: text,
      bbox: CGRect(x: minX, y: y, width: 0.5, height: 0.02),
      confidence: 1.0
    )
  }

  // MARK: - indexOfLabelFuzzy

  func testIndexOfLabelFuzzy_exactMatch() {
    let lines = [
      line("Licencee"),
      line("date of birth"),
      line("Sex"),
    ]
    XCTAssertEqual(FSEBCFuzzyPatches.indexOfLabelFuzzy("date of birth", in: lines), 1)
  }

  func testIndexOfLabelFuzzy_withinEditDistance_matches() {
    // "date 0f birth" has 1 substitution vs "date of birth" → within maxDistance.
    let lines = [
      line("Licencee"),
      line("date 0f birth"),
      line("Sex"),
    ]
    XCTAssertEqual(FSEBCFuzzyPatches.indexOfLabelFuzzy("date of birth", in: lines), 1)
  }

  func testIndexOfLabelFuzzy_noCandidate_returnsNil() {
    let lines = [
      line("Completely unrelated"),
      line("Another irrelevant line"),
    ]
    XCTAssertNil(FSEBCFuzzyPatches.indexOfLabelFuzzy("date of birth", in: lines))
  }

  func testIndexOfLabelFuzzy_stripsPunctuationNoise() {
    // "Date: of. birth;" normalizes to "date of birth".
    let lines = [line("Date: of. birth;")]
    XCTAssertEqual(FSEBCFuzzyPatches.indexOfLabelFuzzy("date of birth", in: lines), 0)
  }

  func testIndexOfLabelFuzzy_picksBestAmongCandidates() {
    let lines = [
      line("date of birh"),   // 1 edit
      line("date of birth"),  // 0 edits — should win
      line("date 0f birtl"),  // 2 edits
    ]
    XCTAssertEqual(FSEBCFuzzyPatches.indexOfLabelFuzzy("date of birth", in: lines), 1)
  }

  func testIndexOfLabelFuzzy_emptyLines_returnsNil() {
    XCTAssertNil(FSEBCFuzzyPatches.indexOfLabelFuzzy("anything", in: []))
  }

  // MARK: - cleanupClassifiedRows

  func testCleanupClassifiedRows_removesEmbeddedLicenseTokenFromWater() {
    let row = ClassifiedLicenceParse(
      licNumber: "NA123456",
      water: "Nehalem River NA987654 Section 3",
      validFrom: nil,
      validTo: nil,
      guideName: "",
      vendor: ""
    )
    let cleaned = FSEBCFuzzyPatches.cleanupClassifiedRows([row])
    XCTAssertEqual(cleaned.count, 1)
    XCTAssertFalse(cleaned[0].water.contains("NA987654"))
    XCTAssertTrue(cleaned[0].water.contains("Nehalem"))
    XCTAssertTrue(cleaned[0].water.contains("Section"))
  }

  func testCleanupClassifiedRows_removesLicKeyword() {
    let row = ClassifiedLicenceParse(
      licNumber: "NA123456",
      water: "Wilson River Lic Vend",
      validFrom: nil,
      validTo: nil,
      guideName: "",
      vendor: ""
    )
    let cleaned = FSEBCFuzzyPatches.cleanupClassifiedRows([row])
    XCTAssertFalse(cleaned[0].water.contains("Lic"))
    XCTAssertFalse(cleaned[0].water.contains("Vend"))
    XCTAssertTrue(cleaned[0].water.contains("Wilson"))
  }

  func testCleanupClassifiedRows_preservesCleanInput() {
    let row = ClassifiedLicenceParse(
      licNumber: "NA123456",
      water: "Babine River",
      validFrom: nil,
      validTo: nil,
      guideName: "",
      vendor: ""
    )
    let cleaned = FSEBCFuzzyPatches.cleanupClassifiedRows([row])
    XCTAssertEqual(cleaned[0].water, "Babine River")
  }

  func testCleanupClassifiedRows_preservesOtherFields() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let row = ClassifiedLicenceParse(
      licNumber: "NA111111",
      water: "Skeena NA222222",
      validFrom: date,
      validTo: date.addingTimeInterval(86_400),
      guideName: "Derek",
      vendor: "BCFS"
    )
    let cleaned = FSEBCFuzzyPatches.cleanupClassifiedRows([row])[0]
    XCTAssertEqual(cleaned.licNumber, "NA111111")
    XCTAssertEqual(cleaned.validFrom, date)
    XCTAssertEqual(cleaned.validTo, date.addingTimeInterval(86_400))
    XCTAssertEqual(cleaned.guideName, "Derek")
    XCTAssertEqual(cleaned.vendor, "BCFS")
  }

  func testCleanupClassifiedRows_emptyArray_returnsEmpty() {
    XCTAssertTrue(FSEBCFuzzyPatches.cleanupClassifiedRows([]).isEmpty)
  }
}
