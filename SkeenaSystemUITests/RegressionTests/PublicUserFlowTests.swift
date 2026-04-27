import XCTest

/// Regression test: full public-user lifecycle.
///
/// Steps:
///   1.  Open app — login screen is displayed
///   2.  Create account — tap Create Account to open the registration sheet
///   3.  Choose No Community Code — tap "No, continue without one"
///   4.  Enter fake user email + password — fill the registration form
///   5.  Verify landing on the public landing view
///   6.  Open Fisheries Conditions
///   7.  Click on Babine
///   8.  View Babine Results
///   9.  Click Home icon to return to the public landing view
///   10. Click on Profile
///   11. Click on Delete Account (and confirm)
///
/// Registration credentials:
///   The test generates a unique email each run so it is fully self-contained and
///   does not collide with other test runs.  The account is deleted in step 11,
///   leaving no orphan records.
///
/// Supabase prerequisite:
///   Account creation auto-signs the user in only when email confirmation is
///   disabled (GOTRUE_MAILER_AUTOCONFIRM=true in the Supabase project or
///   "Confirm email" turned off in the Auth settings).  Set the env var
///   PUBLIC_FLOW_SKIP_REGISTRATION=1 in the test plan to skip steps 2–4 and
///   sign in with UI_TEST_EMAIL / UI_TEST_PASSWORD instead.
///
/// Run with:
///   xcodebuild test -workspace SkeenaSystem.xcworkspace \
///     -scheme SkeenaSystem \
///     -destination 'platform=iOS Simulator,...' \
///     -testPlan RegressionTests \
///     -only-testing:SkeenaSystemUITests/PublicUserFlowTests
final class PublicUserFlowTests: XCTestCase {

    private var app: XCUIApplication!
    private var loginPage: LoginPage!
    private var registrationPage: RegistrationPage!
    private var publicLandingPage: PublicLandingPage!
    private var forecastPage: ForecastPage!
    private var forecastResultPage: ForecastResultPage!
    private var manageProfilePage: ManageProfilePage!

    // MARK: - Test credentials

    private let testFirstName = "TestUser"
    private let testLastName = "Public"
    private let testPassword = "Testuser1"

    private var testEmail: String {
        let override = ProcessInfo.processInfo.environment["UI_REGISTER_EMAIL"]
        guard override == nil || override!.isEmpty else { return override! }
        let short = UUID().uuidString.prefix(8).lowercased()
        return "uitest_\(short)@test.invalid"
    }

    private var skipRegistration: Bool {
        ProcessInfo.processInfo.environment["PUBLIC_FLOW_SKIP_REGISTRATION"] == "1"
    }

    private var existingEmail: String {
        ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? ""
    }

    private var existingPassword: String {
        ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? ""
    }

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-resetAuthForUITests"]
        app.launchEnvironment["UITestingDisableAnimations"] = "1"
        app.launch()

        loginPage = LoginPage(app: app)
        registrationPage = RegistrationPage(app: app)
        publicLandingPage = PublicLandingPage(app: app)
        forecastPage = ForecastPage(app: app)
        forecastResultPage = ForecastResultPage(app: app)
        manageProfilePage = ManageProfilePage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        loginPage = nil
        registrationPage = nil
        publicLandingPage = nil
        forecastPage = nil
        forecastResultPage = nil
        manageProfilePage = nil
        try super.tearDownWithError()
    }

    // MARK: - Test

    func testPublicUserFlow() throws {
        // Step 1: Open app — login screen is visible
        XCTAssertTrue(loginPage.isDisplayed, "Step 1: Login screen should be visible on launch")
        attach(name: "Step 1 – Login screen")

        if skipRegistration {
            // Alternative path: sign in with existing test account when email
            // confirmation is required in the target environment
            try XCTSkipUnless(!existingEmail.isEmpty && !existingPassword.isEmpty,
                "PUBLIC_FLOW_SKIP_REGISTRATION=1 requires UI_TEST_EMAIL and UI_TEST_PASSWORD")
            let navigatedAway = loginPage.signIn(email: existingEmail,
                                                 password: existingPassword, timeout: 45)
            XCTAssertTrue(navigatedAway,
                "Step 5 (via sign-in): App should navigate to public landing view")
        } else {
            // Step 2: Tap Create Account
            let createButton = app.buttons["createAccountButton"]
            XCTAssertTrue(createButton.waitForExistence(timeout: 5),
                "Step 2: Create Account button should be visible")
            createButton.tap()
            attach(name: "Step 2 – Registration sheet opened")

            // Step 3: Choose No Community Code
            XCTAssertTrue(registrationPage.isChoiceScreenDisplayed,
                "Step 3: Community code choice screen should appear")
            registrationPage.tapNoCode()
            attach(name: "Step 3 – No Community Code selected")

            // Step 4: Fill registration form
            XCTAssertTrue(registrationPage.isFormDisplayed,
                "Step 4: Registration form should appear after choosing no code")
            let email = testEmail
            registrationPage.fillForm(
                firstName: testFirstName,
                lastName: testLastName,
                email: email,
                password: testPassword
            )
            attach(name: "Step 4 – Form filled")

            // Dismiss keyboard then submit
            app.swipeDown(velocity: .slow)
            _ = registrationPage.registerButton.waitForExistence(timeout: 5)
            registrationPage.tapRegister()
            attach(name: "Step 4 – Register tapped")

            // Step 5: Verify landing on public landing view
            XCTAssertTrue(publicLandingPage.isDisplayed,
                "Step 5: Public landing view should appear after successful registration (requires email auto-confirm)")
            attach(name: "Step 5 – Public landing view")
        }

        // Step 6: Open Fisheries Conditions
        XCTAssertTrue(publicLandingPage.fishingForecastTile.waitForExistence(timeout: 10),
            "Step 6: Fishing Forecast tile should be visible")
        publicLandingPage.tapFishingForecast()
        XCTAssertTrue(forecastPage.isDisplayed,
            "Step 6: Conditions screen should appear")
        attach(name: "Step 6 – Fisheries Conditions screen")

        // Step 7: Click on Babine
        forecastPage.tapRiver("Babine")
        attach(name: "Step 7 – Babine tapped")

        // Step 8: View Babine Results
        XCTAssertTrue(forecastResultPage.isDisplayed(river: "Babine"),
            "Step 8: Babine results view should display the river name")
        attach(name: "Step 8 – Babine results")

        // Step 9: Click Home icon
        publicLandingPage.tapHomeTab()
        XCTAssertTrue(publicLandingPage.fishingForecastTile.waitForExistence(timeout: 10),
            "Step 9: Tapping Home should return to the public landing view")
        attach(name: "Step 9 – Home icon tapped, back on landing")

        // Step 10: Click on Profile
        publicLandingPage.tapProfile()
        XCTAssertTrue(manageProfilePage.isDisplayed,
            "Step 10: Profile / Manage Account screen should appear")
        attach(name: "Step 10 – Profile screen")

        // Step 11: Click on Delete Account (and confirm)
        manageProfilePage.tapDeleteAccount()
        manageProfilePage.confirmDeleteAccount()

        // After deletion the app signs the user out and returns to the login screen
        XCTAssertTrue(loginPage.isDisplayed,
            "Step 11: Login screen should reappear after account deletion")
        attach(name: "Step 11 – Account deleted, returned to login")
    }

    // MARK: - Helpers

    private func attach(name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
