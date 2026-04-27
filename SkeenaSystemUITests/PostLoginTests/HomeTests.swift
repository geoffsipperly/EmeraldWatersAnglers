import XCTest

// TC-HOME-001, 006, 010, 011, 012, 013, 014, 015, 016
// Requirement: REQ-HOME-001 to REQ-HOME-010

final class HomeTests: PostLoginTestBase {

    override var additionalLaunchArgs: [String] { [] }

    // MARK: - TC-HOME-001
    // REQ-HOME-001: user's full name displayed at top-left

    func testUserNameDisplayedOnHomeScreen() {
        let userNameLabel = app.staticTexts["userNameLabel"]
        XCTAssertTrue(userNameLabel.waitForExistence(timeout: 10),
                      "TC-HOME-001: User name label should be visible at top-left of home screen")
        let displayedName = userNameLabel.label
        XCTAssertFalse(displayedName.trimmingCharacters(in: .whitespaces).isEmpty,
                       "TC-HOME-001: Displayed name should not be empty")
    }

    // MARK: - TC-HOME-006
    // REQ-HOME-004: tapping fishingForecastTile navigates to conditions view

    func testFishingForecastTileNavigatesToConditions() {
        let landing = PublicLandingPage(app: app)
        landing.tapFishingForecast()

        let forecast = ForecastPage(app: app)
        XCTAssertTrue(forecast.isDisplayed,
                      "TC-HOME-006: Tapping fishingForecastTile should navigate to fisheries conditions view")
    }

    // MARK: - TC-HOME-010
    // REQ-HOME-006: Record button visible and navigates to RecordActivityView

    func testRecordButtonNavigatesToRecordActivity() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()

        let recordButton = app.buttons["recordActivityButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 10),
                      "TC-HOME-010: Record button should be visible at top-right of home screen")
        recordButton.tap()

        let recordActivity = RecordActivityPage(app: app)
        XCTAssertTrue(recordActivity.isDisplayed,
                      "TC-HOME-010: Tapping Record button should open RecordActivityView")
    }

    // MARK: - TC-HOME-011
    // REQ-HOME-007: toolbar tabs present (no Social add-on)

    func testToolbarTabsPresentWithoutSocialAddon() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "TC-HOME-011: Landing screen should be visible")

        // Standard tabs should be present
        for tab in ["Home", "Conditions", "Activities", "Learn", "Explore"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 5),
                          "TC-HOME-011: '\(tab)' tab should be visible in toolbar")
        }
    }

    // MARK: - TC-HOME-013
    // REQ-HOME-007: no Trips tab for public users

    func testNoTripsTabForPublicUser() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "TC-HOME-013: Landing screen should be visible")

        XCTAssertFalse(app.buttons["Trips"].exists,
                       "TC-HOME-013: Trips tab should not be present for public users")
    }

    // MARK: - TC-HOME-014
    // REQ-HOME-008: tapping profileButton opens ManageProfileView

    func testProfileButtonOpensProfile() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        landing.tapProfile()

        let profile = ManageProfilePage(app: app)
        XCTAssertTrue(profile.isDisplayed,
                      "TC-HOME-014: Tapping profileButton should open ManageProfileView")
    }

    // MARK: - TC-HOME-016
    // REQ-HOME-010: tapping logoutCapsule signs out and returns to sign-in screen

    func testLogoutReturnsToSignIn() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "TC-HOME-016: Landing should be visible before logout")

        landing.logoutButton.tap()

        let login = LoginPage(app: app)
        XCTAssertTrue(login.isDisplayed,
                      "TC-HOME-016: After logout user should be returned to sign-in screen")
    }
}
