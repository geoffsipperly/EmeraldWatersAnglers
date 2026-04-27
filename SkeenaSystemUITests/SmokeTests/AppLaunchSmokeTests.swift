import XCTest

/// Smoke tests: app launch and initial screen display.
///
/// These tests verify the most basic requirement — that the app starts
/// without crashing and renders the expected initial UI.
///
/// Run with:
///   xcodebuild test -workspace SkeenaSystem.xcworkspace \
///     -scheme SkeenaSystem -destination 'platform=iOS Simulator,...' \
///     -only-testing:SkeenaSystemUITests/AppLaunchSmokeTests
final class AppLaunchSmokeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        // Signal to the app that it's running under UI tests (can be read via ProcessInfo)
        app.launchArguments += ["-uiTesting"]
        // Disable animations to speed up element waits
        app.launchEnvironment["UITestingDisableAnimations"] = "1"
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// App launches without crashing and the initial screen is displayed within 10 seconds.
    func testAppLaunchesWithoutCrash() throws {
        app.launch()
        XCTAssertTrue(app.state == .runningForeground, "App should be running in the foreground after launch")
        // The app is either on the login screen (unauthenticated) or a landing screen (cached session).
        // Either way, some content must be visible within 10 seconds.
        let loginScreen = app.textFields["emailTextField"]
        let anyLandingContent = app.buttons["logoutCapsule"]
        let isLoginVisible = loginScreen.waitForExistence(timeout: 10)
        let isLandingVisible = anyLandingContent.waitForExistence(timeout: 2)
        XCTAssertTrue(
            isLoginVisible || isLandingVisible,
            "Expected either the login screen or an authenticated landing screen to appear within 10 seconds"
        )
    }

    /// When no cached session exists, the login screen is the first screen shown.
    ///
    /// This test clears keychain state via launch arguments so the app always starts
    /// unauthenticated, giving a deterministic first screen.
    func testLoginScreenIsInitialScreen() throws {
        // Ask the app to clear auth state before launch (handled in AppDelegate / app init
        // when the "-resetAuthForUITests" flag is present).
        app.launchArguments += ["-resetAuthForUITests"]
        app.launch()

        let loginPage = LoginPage(app: app)
        XCTAssertTrue(
            loginPage.isDisplayed,
            "Login screen (emailTextField) should be visible on first launch with no cached session"
        )
    }

    /// Checks that a screenshot of the launch screen can be captured without error.
    func testLaunchScreenshot() throws {
        app.launch()
        _ = app.textFields["emailTextField"].waitForExistence(timeout: 10)
            || app.buttons["logoutCapsule"].waitForExistence(timeout: 10)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Launch Screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
