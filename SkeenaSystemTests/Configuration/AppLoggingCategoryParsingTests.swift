import XCTest
@testable import SkeenaSystem

/// Regression tests for `AppLogging.parseCategories` — the pure parser behind the
/// `LOG_CATEGORIES` xcconfig/Info.plist key. Locks in the contract:
/// empty/whitespace → all, whitespace-tolerant, case-insensitive, unknowns dropped,
/// all-unknown → all (fail-open so logging can't be silently disabled by a typo).
final class AppLoggingCategoryParsingTests: XCTestCase {

  private var allCategories: Set<LogCategory> { Set(LogCategory.allCases) }

  // MARK: - Empty / missing → all

  func testEmptyString_returnsAllCategories() {
    XCTAssertEqual(AppLogging.parseCategories(""), allCategories)
  }

  func testWhitespaceOnly_returnsAllCategories() {
    XCTAssertEqual(AppLogging.parseCategories("   "), allCategories)
    XCTAssertEqual(AppLogging.parseCategories("\t\n "), allCategories)
  }

  // MARK: - Happy path

  func testSingleCategory_resolves() {
    XCTAssertEqual(AppLogging.parseCategories("ml"), [.ml])
  }

  func testMultipleCategories_resolveAll() {
    XCTAssertEqual(AppLogging.parseCategories("ml,catch,angler"),
                   [.ml, .catch, .angler])
  }

  // MARK: - Whitespace tolerance

  func testWhitespaceAroundCommas_isTolerated() {
    XCTAssertEqual(AppLogging.parseCategories("ml, catch , angler"),
                   [.ml, .catch, .angler])
  }

  func testLeadingAndTrailingWhitespace_isTolerated() {
    XCTAssertEqual(AppLogging.parseCategories("  ml,catch  "),
                   [.ml, .catch])
  }

  // MARK: - Case insensitivity

  func testMixedCase_isNormalized() {
    XCTAssertEqual(AppLogging.parseCategories("ML,Catch,ANGLER"),
                   [.ml, .catch, .angler])
  }

  // MARK: - Unknown tokens

  func testUnknownTokens_areDropped() {
    XCTAssertEqual(AppLogging.parseCategories("ml,bogus,catch"),
                   [.ml, .catch])
  }

  func testAllUnknownTokens_failsOpenToAll() {
    // Fail-open: a fat-fingered xcconfig value must NOT silently disable all logging.
    XCTAssertEqual(AppLogging.parseCategories("bogus,alsobogus"),
                   allCategories)
  }

  // MARK: - Edge cases

  func testDuplicateTokens_areDeduplicated() {
    XCTAssertEqual(AppLogging.parseCategories("ml,ml,catch"),
                   [.ml, .catch])
  }

  func testEmptyTokensBetweenCommas_areIgnored() {
    // Stray commas (e.g. trailing comma) shouldn't break parsing.
    XCTAssertEqual(AppLogging.parseCategories("ml,,catch,"),
                   [.ml, .catch])
  }
}
