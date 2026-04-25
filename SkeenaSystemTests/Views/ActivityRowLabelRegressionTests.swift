import XCTest
@testable import SkeenaSystem

/// Locks the user-visible "Member" label that fronts every activity row's
/// `report.guideName` line. Originally rendered as "Guide:" — renamed in
/// commit 3bd04b3 once the same row started being reused by Public and
/// Researcher roles.
///
/// The label is exposed as a `static let` on each containing view and read
/// from there in the body, so a future revert lands as a one-line constant
/// change that this test catches.
final class ActivityRowLabelRegressionTests: XCTestCase {

  func testFarmedReportsListView_activityRowMemberLabel_isMember() {
    XCTAssertEqual(FarmedReportsListView.activityRowMemberLabel, "Member",
                   "Activity row prefix on FarmedReportsListView must be 'Member' — see commit 3bd04b3")
  }

  func testFarmedReportsListView_activityRowMemberLabel_isNotLegacyGuide() {
    XCTAssertNotEqual(FarmedReportsListView.activityRowMemberLabel, "Guide",
                      "Reverting to 'Guide:' breaks role-agnostic row reuse — see commit 3bd04b3")
  }

  func testActivitiesObservationsTab_activityRowMemberLabel_isMember() {
    XCTAssertEqual(ActivitiesObservationsTab.activityRowMemberLabel, "Member",
                   "Activity row prefix on ActivitiesObservationsTab must be 'Member'")
  }

  func testActivityRowMemberLabel_consistentAcrossViews() {
    // The two row sites must agree — they render the same conceptual line in
    // different layouts. Drift would mean Public/Researcher see one label and
    // Guide sees another for the same underlying farmed report.
    XCTAssertEqual(
      FarmedReportsListView.activityRowMemberLabel,
      ActivitiesObservationsTab.activityRowMemberLabel,
      "Both activity-row sites must use the same prefix"
    )
  }
}
