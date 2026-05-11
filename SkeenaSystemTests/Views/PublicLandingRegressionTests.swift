import XCTest
@testable import SkeenaSystem

/// Regression tests for `PublicWelcomeView`'s copy and capability tiles
/// (refreshed in commit 0ccaf70) and the public-role greeting personalization.
///
/// PublicRoleRegressionTests already covers auth/routing for the public role.
/// This file locks the *content* of the first-login welcome screen — easy to
/// silently drift since SwiftUI body changes don't break compilation.
final class PublicLandingRegressionTests: XCTestCase {

  // MARK: - Greeting personalization

  func testGreetingTitle_withFirstName_personalizesGreeting() {
    XCTAssertEqual(
      PublicWelcomeView.greetingTitle(firstName: "Alex"),
      "Alex, Welcome to Mad Thinker"
    )
  }

  func testGreetingTitle_withNilFirstName_fallsBackToUnpersonalized() {
    XCTAssertEqual(
      PublicWelcomeView.greetingTitle(firstName: nil),
      "Welcome to Mad Thinker"
    )
  }

  func testGreetingTitle_withEmptyFirstName_fallsBackToUnpersonalized() {
    XCTAssertEqual(
      PublicWelcomeView.greetingTitle(firstName: ""),
      "Welcome to Mad Thinker"
    )
  }

  func testGreetingTitle_withWhitespaceOnlyFirstName_fallsBackToUnpersonalized() {
    XCTAssertEqual(
      PublicWelcomeView.greetingTitle(firstName: "   "),
      "Welcome to Mad Thinker",
      "Whitespace-only names should not produce ', Welcome to Mad Thinker'"
    )
  }

  func testGreetingTitle_trimsLeadingAndTrailingWhitespace() {
    XCTAssertEqual(
      PublicWelcomeView.greetingTitle(firstName: "  Alex  "),
      "Alex, Welcome to Mad Thinker"
    )
  }

  // MARK: - Capability tiles

  func testCapabilities_hasExactlyFiveTiles() {
    XCTAssertEqual(PublicWelcomeView.capabilities.count, 5,
                   "Welcome screen ships with 5 capability tiles. Adding/removing one is a deliberate UX decision — update this assertion in lockstep.")
  }

  func testCapabilities_firstTileIsRecordCatches() {
    let first = PublicWelcomeView.capabilities.first
    XCTAssertEqual(first?.title, "Record catches")
    XCTAssertEqual(first?.icon, "camera.fill")
  }

  func testCapabilities_includesExpectedTitles() {
    let titles = PublicWelcomeView.capabilities.map(\.title)
    XCTAssertEqual(titles, [
      "Record catches",
      "Estimate length, girth & weight",
      "Record environmental observations",
      "Maps & catch journal",
      "Curated videos"
    ], "Tile order is intentional — the most-used capability (Record catches) is first")
  }

  func testCapabilities_iconsAreSFSymbolNames() {
    let icons = PublicWelcomeView.capabilities.map(\.icon)
    XCTAssertEqual(icons, [
      "camera.fill",
      "ruler",
      "leaf.fill",
      "map.fill",
      "play.rectangle.fill"
    ], "Capability icons are rendered via Image(systemName:) — names must match SF Symbols")
  }

  func testCapabilities_subtitlesHaveNoTrailingPeriods() {
    // Commit 0ccaf70 specifically stripped trailing periods from each
    // capability subtitle. Lock this — re-introducing a period silently
    // breaks the visual consistency of the tile group.
    for cap in PublicWelcomeView.capabilities {
      XCTAssertFalse(cap.subtitle.hasSuffix("."),
                     "Capability subtitle '\(cap.subtitle)' must not end with a period (commit 0ccaf70)")
    }
  }

  func testCapabilities_titlesAreUnique() {
    // ForEach in the body uses `title` as the SwiftUI id. Duplicate titles
    // would warn at runtime and fail to render the second tile correctly.
    let titles = PublicWelcomeView.capabilities.map(\.title)
    XCTAssertEqual(titles.count, Set(titles).count, "Capability titles must be unique — used as ForEach id")
  }

  // MARK: - Routing

  /// Mirrors AppRootView's role → landing-view routing.
  private func landingViewName(for userType: AuthService.UserType?, isConservation: Bool = false) -> String {
    guard let t = userType else { return "LoginView" }
    switch t {
    case .guide:      return "GuideLandingView"
    case .angler:     return "AnglerLandingView"
    case .public:     return "PublicLandingView"
    case .researcher: return isConservation ? "ResearcherLandingView" : "PublicLandingView"
    }
  }

  func testRouting_publicUser_routesToPublicLandingView() {
    XCTAssertEqual(landingViewName(for: .public), "PublicLandingView")
  }

  func testRouting_publicUser_isConservationFlagDoesNotMatter() {
    // Public role is community-type-agnostic — it doesn't get the
    // researcher's Conservation branch.
    XCTAssertEqual(landingViewName(for: .public, isConservation: true), "PublicLandingView")
    XCTAssertEqual(landingViewName(for: .public, isConservation: false), "PublicLandingView")
  }
}
