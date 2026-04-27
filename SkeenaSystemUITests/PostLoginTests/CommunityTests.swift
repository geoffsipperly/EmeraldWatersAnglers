import XCTest

// TC-COMM-001, 004
// Requirement: REQ-COMM-001 to REQ-COMM-004
// Note: TC-COMM-002/003 (auto-select behavior) require specific account configurations
// and are tested via API tests. TC-COMM-005 requires a real community code.

final class CommunityTests: PostLoginTestBase {

    // MARK: - TC-COMM-004
    // REQ-COMM-003: Join Community tile visible in community picker with dashed border

    func testJoinCommunityButtonVisible() throws {
        // The community picker appears when the user has multiple communities or
        // navigates to it via the community switcher on the home screen.
        // For a standard single-community user, this screen may not be reachable
        // without navigating explicitly.

        // Check if the community switcher button is accessible from the landing screen
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "TC-COMM-004: Landing should be visible")

        // Community picker is shown at login for multi-community users.
        // If we're already past it, verify the Join Community tile can be found
        // by navigating to it if there's a switcher.
        // For the standard test account with one community, skip if picker is not accessible.
        let picker = CommunityPickerPage(app: app)
        guard picker.isDisplayed else {
            throw XCTSkip("TC-COMM-004: Community picker not shown for single-community test account. Verify manually.")
        }

        XCTAssertTrue(picker.joinCommunityButton.exists,
                      "TC-COMM-004: joinCommunityButton should be visible in community picker")
    }

    // MARK: - TC-COMM-001
    // REQ-COMM-001: community picker shows 2-column grid with tiles

    func testCommunityPickerGridLayout() throws {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()

        let picker = CommunityPickerPage(app: app)
        guard picker.isDisplayed else {
            throw XCTSkip("TC-COMM-001: Community picker not shown — test account may have only one community")
        }

        XCTAssertTrue(app.staticTexts["Select Your Community"].exists,
                      "TC-COMM-001: 'Select Your Community' heading should be visible")
        XCTAssertTrue(picker.joinCommunityButton.exists,
                      "TC-COMM-001: Join Community tile should be visible in the grid")
    }
}
