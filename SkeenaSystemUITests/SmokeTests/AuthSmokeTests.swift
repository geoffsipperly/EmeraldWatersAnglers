import XCTest

/// Smoke tests: sign-in, session state transitions, and sign-out.
///
/// These tests require real Supabase credentials provided via environment variables.
/// If the variables are absent the tests are skipped automatically so CI can run
/// the suite in environments where credentials are not configured.
///
/// Required environment variables (set in the Xcode scheme under Test > Arguments):
///   UI_TEST_EMAIL     — email of a pre-existing test account
///   UI_TEST_PASSWORD  — password for that account
///
/// Sign-up testing is intentionally omitted from this smoke suite because Supabase
/// requires email confirmation for new accounts. Sign-up flows should be covered
/// by dedicated integration tests that use the Supabase Admin API to confirm the
/// account programmatically.
///
/// Run with:
///   xcodebuild test -workspace SkeenaSystem.xcworkspace \
///     -scheme SkeenaSystem -destination 'platform=iOS Simulator,...' \
///     -only-testing:SkeenaSystemUITests/AuthSmokeTests
final class AuthSmokeTests: XCTestCase {

    private var app: XCUIApplication!
    private var loginPage: LoginPage!

    // MARK: - Credentials from environment

    private var testEmail: String {
        ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? ""
    }

    private var testPassword: String {
        ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? ""
    }

    private var hasCredentials: Bool {
        !testEmail.isEmpty && !testPassword.isEmpty
    }

    // MARK: - Setup / teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-resetAuthForUITests"]
        app.launchEnvironment["UITestingDisableAnimations"] = "1"
        app.launch()

        loginPage = LoginPage(app: app)
    }

    override func tearDownWithError() throws {
        app = nil
        loginPage = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// Sign in with valid credentials transitions the UI away from the login screen.
    func testSignInWithValidCredentials() throws {
        try XCTSkipUnless(hasCredentials, "UI_TEST_EMAIL / UI_TEST_PASSWORD not set — skipping auth smoke test")

        XCTAssertTrue(loginPage.isDisplayed, "Login screen should be visible before sign-in")

        let navigatedAway = loginPage.signIn(email: testEmail, password: testPassword, timeout: 30)
        XCTAssertTrue(navigatedAway, "App should navigate away from login screen after successful sign-in")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Post Sign-In State"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Sign in then sign out returns the user to the login screen.
    func testSignInThenSignOut() throws {
        try XCTSkipUnless(hasCredentials, "UI_TEST_EMAIL / UI_TEST_PASSWORD not set — skipping auth smoke test")

        XCTAssertTrue(loginPage.isDisplayed, "Login screen should be visible before sign-in")

        // Sign in
        let navigatedAway = loginPage.signIn(email: testEmail, password: testPassword, timeout: 30)
        XCTAssertTrue(navigatedAway, "App should navigate away from login screen after successful sign-in")

        // Sign out
        let returnedToLogin = loginPage.signOut(timeout: 10)
        XCTAssertTrue(returnedToLogin, "App should return to login screen after sign-out")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Post Sign-Out State"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Entering invalid credentials shows an error label and keeps the user on the login screen.
    func testSignInWithInvalidCredentialShowsError() throws {
        XCTAssertTrue(loginPage.isDisplayed, "Login screen should be visible")

        loginPage.enterEmail("notareal@example.invalid")
        loginPage.enterPassword("wrongpassword123")
        loginPage.tapSignIn()

        // Error label should appear
        let errorVisible = loginPage.errorLabel.waitForExistence(timeout: 15)
        XCTAssertTrue(errorVisible, "An error label should appear for invalid credentials")

        // Should still be on the login screen
        XCTAssertTrue(loginPage.emailField.exists, "Email field should still be visible after failed sign-in")
    }
}
