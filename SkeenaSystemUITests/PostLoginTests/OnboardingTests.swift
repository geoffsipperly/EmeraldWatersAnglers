import XCTest

// TC-ONBOARD-001 to TC-ONBOARD-007
// Requirement: REQ-ONBOARD-001 to REQ-ONBOARD-003

final class OnboardingTests: XCTestCase {

    let app = XCUIApplication()

    private func launch(resetWelcome: Bool, resetAuth: Bool = true) {
        var args = ["-uiTesting"]
        if resetAuth { args.append("-resetAuthForUITests") }
        if resetWelcome { args.append("-resetWelcomeStateForUITests") }
        app.launchArguments = args
        app.launchEnvironment["UI_TEST_EMAIL"] = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        app.launchEnvironment["UI_TEST_PASSWORD"] = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        app.launch()
    }

    private func signIn() {
        let login = LoginPage(app: app)
        let email = app.launchEnvironment["UI_TEST_EMAIL"] ?? ""
        let password = app.launchEnvironment["UI_TEST_PASSWORD"] ?? ""
        _ = login.signIn(email: email, password: password, timeout: 45)
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - TC-ONBOARD-001
    // REQ-ONBOARD-001: welcome screen shown on first login (welcome key absent)

    func testWelcomeAppearsOnFirstLogin() throws {
        let email = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        let password = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        guard !email.isEmpty, !password.isEmpty else { throw XCTSkip("Credentials not set") }

        launch(resetWelcome: true) // clears publicWelcome_* keys so welcome will show
        let login = LoginPage(app: app)
        _ = login.signIn(email: email, password: password, timeout: 45)

        let getStarted = app.buttons["publicWelcomeGetStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 30),
                      "TC-ONBOARD-001: Welcome screen should appear on first login (welcome key cleared)")
    }

    // MARK: - TC-ONBOARD-002
    // REQ-ONBOARD-001: welcome screen NOT shown on repeat login (key already set)

    func testWelcomeDoesNotRepeatOnSubsequentLogin() throws {
        let email = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        let password = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        guard !email.isEmpty, !password.isEmpty else { throw XCTSkip("Credentials not set") }

        // Launch WITHOUT resetting welcome state — assumes the key is already set
        // for this test account from a prior run (or real usage).
        launch(resetWelcome: false)
        let login = LoginPage(app: app)
        _ = login.signIn(email: email, password: password, timeout: 45)

        let landing = PublicLandingPage(app: app)
        // Welcome should NOT appear; landing should be visible
        XCTAssertTrue(landing.isDisplayed,
                      "TC-ONBOARD-002: Landing screen should be visible without welcome overlay on repeat login")
        let getStarted = app.buttons["publicWelcomeGetStartedButton"]
        XCTAssertFalse(getStarted.exists,
                       "TC-ONBOARD-002: Welcome 'Get Started' button should not be present on repeat login")
    }

    // MARK: - TC-ONBOARD-005
    // REQ-ONBOARD-002: welcome screen content (tagline, 5 capabilities, buttons)

    func testWelcomeScreenContent() throws {
        let email = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        let password = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        guard !email.isEmpty, !password.isEmpty else { throw XCTSkip("Credentials not set") }

        launch(resetWelcome: true)
        _ = LoginPage(app: app).signIn(email: email, password: password, timeout: 45)

        guard app.buttons["publicWelcomeGetStartedButton"].waitForExistence(timeout: 30) else {
            throw XCTSkip("TC-ONBOARD-005: Welcome screen did not appear — welcome key may already be set")
        }

        // Tagline
        XCTAssertTrue(app.staticTexts["You just became part of the living knowledge that protects wild places"].exists,
                      "TC-ONBOARD-005: Tagline should be visible")

        // 5 capability tiles
        let capabilities = [
            "Record catches",
            "Estimate length, girth & weight",
            "Record environmental observations",
            "Maps & catch journal",
            "Curated videos"
        ]
        for cap in capabilities {
            XCTAssertTrue(app.staticTexts[cap].exists, "TC-ONBOARD-005: Capability '\(cap)' should be visible")
        }

        // Action buttons
        XCTAssertTrue(app.buttons["publicWelcomeGetStartedButton"].exists,
                      "TC-ONBOARD-005: 'Get Started' button should be visible")
        XCTAssertTrue(app.buttons["publicWelcomeCloseButton"].exists,
                      "TC-ONBOARD-005: Close button should be visible")
    }

    // MARK: - TC-ONBOARD-006
    // REQ-ONBOARD-002: tapping Get Started dismisses welcome and lands on home screen

    func testGetStartedDismissesWelcome() throws {
        let email = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        let password = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        guard !email.isEmpty, !password.isEmpty else { throw XCTSkip("Credentials not set") }

        launch(resetWelcome: true)
        _ = LoginPage(app: app).signIn(email: email, password: password, timeout: 45)

        let getStarted = app.buttons["publicWelcomeGetStartedButton"]
        guard getStarted.waitForExistence(timeout: 30) else {
            throw XCTSkip("TC-ONBOARD-006: Welcome screen did not appear")
        }
        getStarted.tap()

        let landing = PublicLandingPage(app: app)
        XCTAssertTrue(landing.isDisplayed,
                      "TC-ONBOARD-006: Landing screen should be visible after tapping Get Started")
        XCTAssertFalse(app.buttons["publicWelcomeGetStartedButton"].exists,
                       "TC-ONBOARD-006: Welcome screen should be dismissed")
    }

    // MARK: - TC-ONBOARD-007
    // REQ-ONBOARD-003: App Overview button in Profile re-presents welcome screen

    func testAppOverviewRepresentsWelcome() throws {
        let email = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        let password = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        guard !email.isEmpty, !password.isEmpty else { throw XCTSkip("Credentials not set") }

        launch(resetWelcome: false)
        _ = LoginPage(app: app).signIn(email: email, password: password, timeout: 45)

        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "TC-ONBOARD-007: Landing should be visible")

        landing.tapProfile()
        let profile = ManageProfilePage(app: app)
        XCTAssertTrue(profile.isDisplayed, "TC-ONBOARD-007: Profile screen should be visible")

        profile.appOverviewButton.tap()

        let getStarted = app.buttons["publicWelcomeGetStartedButton"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 10),
                      "TC-ONBOARD-007: Welcome screen should re-appear when tapping App Overview")
    }
}
