import XCTest

// TC-LEARN-001 to TC-LEARN-007
// Requirement: REQ-LEARN-001 to REQ-LEARN-003

final class ExploreTests: PostLoginTestBase {

    private func openLearnTab() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "Landing should be visible")
        app.buttons["Learn"].tap()
    }

    // MARK: - TC-LEARN-001
    // REQ-LEARN-001: masterclassCard visible with expected content

    func testMasterclassCardVisible() {
        openLearnTab()

        let explore = ExplorePage(app: app)
        XCTAssertTrue(explore.isDisplayed,
                      "TC-LEARN-001: Learn/Explore view should be displayed")
        XCTAssertTrue(explore.isMasterclassVisible,
                      "TC-LEARN-001: masterclassCard should be visible")

        // Verify card content text
        XCTAssertTrue(app.staticTexts["Steelhead in the PNW"].exists,
                      "TC-LEARN-001: Masterclass title 'Steelhead in the PNW' should be visible")
        XCTAssertTrue(app.staticTexts["Expert techniques and tactics"].exists,
                      "TC-LEARN-001: Masterclass subtitle should be visible")
    }

    // MARK: - TC-LEARN-002
    // REQ-LEARN-001: tapping masterclassCard opens in-app WebView

    func testMasterclassTapOpensWebView() {
        openLearnTab()

        let explore = ExplorePage(app: app)
        XCTAssertTrue(explore.isMasterclassVisible, "TC-LEARN-002: Masterclass card must be visible")

        explore.tapMasterclass()

        // WebView navigation title should appear
        XCTAssertTrue(app.navigationBars["Masterclasses"].waitForExistence(timeout: 10),
                      "TC-LEARN-002: WebView should open with 'Masterclasses' navigation title")
    }

    // MARK: - TC-LEARN-003
    // REQ-LEARN-002: community recommended video cards displayed in carousel

    func testRecommendedVideoCardsVisible() throws {
        openLearnTab()

        let explore = ExplorePage(app: app)
        XCTAssertTrue(explore.isDisplayed, "TC-LEARN-003: Learn view should be displayed")

        // Community video links section labeled "Recommended"
        // This section only appears if the community has configured custom URLs.
        let recommendedLabel = app.staticTexts["Recommended"]
        if !recommendedLabel.waitForExistence(timeout: 5) {
            throw XCTSkip("TC-LEARN-003: No community recommended videos configured — skip")
        }
        XCTAssertTrue(recommendedLabel.exists,
                      "TC-LEARN-003: 'Recommended' section header should be visible")
    }

    // MARK: - TC-LEARN-005
    // REQ-LEARN-002: tapping a video card opens in-app WebView

    func testVideoCardTapOpensWebView() throws {
        openLearnTab()

        let explore = ExplorePage(app: app)
        XCTAssertTrue(explore.isDisplayed, "TC-LEARN-005: Learn view should be displayed")

        // Find any learnVideo_ button in the carousel
        let videoPredicate = NSPredicate(format: "identifier BEGINSWITH 'learnVideo_'")
        let videoCard = app.buttons.matching(videoPredicate).firstMatch
        guard videoCard.waitForExistence(timeout: 5) else {
            throw XCTSkip("TC-LEARN-005: No community video cards available — skip")
        }

        let videoTitle = videoCard.label
        videoCard.tap()

        // WebView should open; nav title matches the video name
        XCTAssertTrue(
            app.navigationBars[videoTitle].waitForExistence(timeout: 10) ||
            app.navigationBars.firstMatch.waitForExistence(timeout: 10),
            "TC-LEARN-005: WebView should open after tapping a community video card"
        )
    }

    // MARK: - TC-LEARN-007
    // REQ-LEARN-003: WebView nav title matches the video link name

    func testWebViewTitleMatchesLinkName() throws {
        openLearnTab()

        let explore = ExplorePage(app: app)
        XCTAssertTrue(explore.isDisplayed, "TC-LEARN-007: Learn view should be displayed")

        let videoPredicate = NSPredicate(format: "identifier BEGINSWITH 'learnVideo_'")
        let videoCard = app.buttons.matching(videoPredicate).firstMatch
        guard videoCard.waitForExistence(timeout: 5) else {
            throw XCTSkip("TC-LEARN-007: No community video cards available — skip")
        }

        let videoTitle = videoCard.label
        videoCard.tap()

        XCTAssertTrue(
            app.navigationBars[videoTitle].waitForExistence(timeout: 10),
            "TC-LEARN-007: WebView navigation title '\(videoTitle)' should match the tapped video card name"
        )
    }
}
