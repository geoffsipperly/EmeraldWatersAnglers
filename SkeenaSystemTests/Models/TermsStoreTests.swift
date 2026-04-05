import XCTest
@testable import SkeenaSystem

/// Tests for `TermsStore` title and body-text loading.
final class TermsStoreTests: XCTestCase {

  func testTitle_guide() {
    XCTAssertEqual(TermsStore.title(for: .guide), "Guide Terms & Conditions")
  }

  func testTitle_angler() {
    XCTAssertEqual(TermsStore.title(for: .angler), "Angler Terms & Conditions")
  }

  func testBodyText_whenBundleMissingResource_returnsDescriptiveFallback() {
    // In the unit test bundle, guide_terms.md / angler_terms.md are not embedded,
    // so bodyText falls through its `Bundle.main.url(...)` guard and returns a
    // "Terms file missing:" placeholder we can assert on without depending on
    // the production app bundle.
    let guideBody = TermsStore.bodyText(for: .guide)
    let anglerBody = TermsStore.bodyText(for: .angler)

    // Accept either the missing-file fallback (test target) or real content
    // (if the file ships in the test bundle via a future copy phase).
    XCTAssertFalse(guideBody.isEmpty)
    XCTAssertFalse(anglerBody.isEmpty)
    if guideBody.hasPrefix("Terms file missing:") {
      XCTAssertTrue(guideBody.contains("guide_terms.md"))
    }
    if anglerBody.hasPrefix("Terms file missing:") {
      XCTAssertTrue(anglerBody.contains("angler_terms.md"))
    }
  }

  func testTermsRole_rawValues() {
    XCTAssertEqual(TermsRole.guide.rawValue, "guide")
    XCTAssertEqual(TermsRole.angler.rawValue, "angler")
  }
}
