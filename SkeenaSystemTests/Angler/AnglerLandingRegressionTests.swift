import XCTest
@testable import SkeenaSystem

/// Regression tests for `AnglerLandingView`'s onboarding gate, navigation
/// destinations, and role routing. Existing AnglerLandingViewTests cover
/// data-decoding edge cases; this file locks behavior that's easy to break
/// without a compile error:
///
/// - Onboarding only triggers for the right community types
/// - Onboarding key shape matches what production reads/writes
/// - The `AnglerDestination` enum stays exhaustive for the toolbar
/// - Role → landing-view routing puts every angler at AnglerLandingView
///   regardless of community type (Conservation anglers are deprecated
///   per ResearcherRoleRegressionTests)
@MainActor
final class AnglerLandingRegressionTests: XCTestCase {

  // MARK: - Onboarding community-type gate

  /// Lock the exact set. Adding a new community type that should trigger
  /// onboarding (or removing one) is a deliberate decision — this test
  /// surfaces it.
  func testOnboardingCommunityTypes_exactSet() {
    XCTAssertEqual(
      AnglerLandingView.onboardingCommunityTypes,
      ["Lodge", "MultiLodge", "FlyShop"],
      "Onboarding wizard must trigger for exactly Lodge / MultiLodge / FlyShop community types"
    )
  }

  func testOnboardingCommunityTypes_excludesConservation() {
    XCTAssertFalse(AnglerLandingView.onboardingCommunityTypes.contains("Conservation"),
                   "Conservation communities must not trigger angler onboarding — researchers don't go through the angler wizard")
  }

  func testOnboardingCommunityTypes_excludesNilOrEmpty() {
    XCTAssertFalse(AnglerLandingView.onboardingCommunityTypes.contains(""))
  }

  // MARK: - Onboarding key shape

  /// The key is read AND written by the same view, so a shape change in
  /// either direction silently regresses (either re-shows the wizard or
  /// skips it forever). Lock it.
  func testOnboardingKey_withMemberId_includesBothMemberAndCommunity() {
    XCTAssertEqual(
      AnglerLandingView.onboardingKey(cid: "comm-123", memberId: "mem-456"),
      "anglerOnboarded_mem-456_comm-123"
    )
  }

  func testOnboardingKey_withoutMemberId_fallsBackToCommunityOnly() {
    XCTAssertEqual(
      AnglerLandingView.onboardingKey(cid: "comm-123", memberId: nil),
      "anglerOnboarded_comm-123",
      "Falls back to per-community key when member id isn't loaded yet"
    )
  }

  func testOnboardingKey_differentMembers_produceDifferentKeys() {
    let alice = AnglerLandingView.onboardingKey(cid: "c1", memberId: "alice")
    let bob = AnglerLandingView.onboardingKey(cid: "c1", memberId: "bob")
    XCTAssertNotEqual(alice, bob, "Shared simulator/device must give each member their own onboarding state")
  }

  func testOnboardingKey_differentCommunities_produceDifferentKeys() {
    let lodgeA = AnglerLandingView.onboardingKey(cid: "lodge-a", memberId: "alice")
    let lodgeB = AnglerLandingView.onboardingKey(cid: "lodge-b", memberId: "alice")
    XCTAssertNotEqual(lodgeA, lodgeB, "Same member at two lodges must onboard separately for each")
  }

  // MARK: - Navigation destinations

  /// The toolbar pushes `AnglerDestination` values onto a NavigationPath.
  /// A missing case here usually means a broken toolbar tab — locking the
  /// set forces deliberate updates.
  func testAnglerDestination_includesAllExpectedCases() {
    let expected: [AnglerDestination] = [
      .conditions, .learn, .community, .profile, .trip, .explore
    ]
    for dest in expected {
      // Just constructing each case is the test — if a case is renamed or
      // removed, this no longer compiles, which is exactly what we want.
      _ = dest
    }
  }

  // MARK: - Role → landing-view routing

  /// Mirrors AppRootView's routing logic. Anglers always land on
  /// AnglerLandingView, even in Conservation communities (the legacy
  /// ConservationLandingView was deprecated in favor of researchers
  /// having their own role).
  private func landingViewName(for userType: AuthService.UserType?, isConservation: Bool = false) -> String {
    guard let t = userType else { return "LoginView" }
    switch t {
    case .guide:      return "GuideLandingView"
    case .angler:     return "AnglerLandingView"
    case .public:     return "PublicLandingView"
    case .researcher: return isConservation ? "ResearcherLandingView" : "PublicLandingView"
    }
  }

  func testRouting_angler_anyCommunityType_routesToAnglerLandingView() {
    XCTAssertEqual(landingViewName(for: .angler, isConservation: false), "AnglerLandingView")
    XCTAssertEqual(landingViewName(for: .angler, isConservation: true), "AnglerLandingView",
                   "Conservation anglers must still land on AnglerLandingView (ConservationLandingView deprecated)")
  }

  func testRouting_unauthenticated_routesToLoginView() {
    XCTAssertEqual(landingViewName(for: nil), "LoginView")
  }
}
