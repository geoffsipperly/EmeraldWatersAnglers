import XCTest

/// Shared base for all post-login UI tests.
///
/// Each subclass gets a pre-signed-in app on the public landing screen.
/// Override `additionalLaunchArgs` to add flags like `-resetWelcomeStateForUITests`.
class PostLoginTestBase: XCTestCase {

    let app = XCUIApplication()

    /// Override in subclasses to inject extra launch arguments.
    var additionalLaunchArgs: [String] { [] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Auto-dismiss iOS system alerts that appear mid-test. The save-password
        // prompt is the common one after sign-in; we always say "Not Now" since
        // we don't want test runs polluting the sim's keychain.
        addUIInterruptionMonitor(withDescription: "System Dialogs") { alert in
            for label in ["Not Now", "Don't Save", "Cancel", "OK", "Allow"] {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }
        app.launchArguments = [
            "-uiTesting",
            "-resetAuthForUITests",
            "-suppressWelcomeForUITests",
        ] + additionalLaunchArgs
        app.launchEnvironment["UI_TEST_EMAIL"] = ProcessInfo.processInfo.environment["UI_TEST_EMAIL"] ?? "chris@public.com"
        app.launchEnvironment["UI_TEST_PASSWORD"] = ProcessInfo.processInfo.environment["UI_TEST_PASSWORD"] ?? "Fatbikesk123"
        app.launch()
        try signInAndReachLanding()
        // Interruption monitors only fire when an XCTest action runs against
        // the app. Poke the app once so any pending alert is flushed before
        // tests start asserting on landing-screen elements.
        app.tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    /// Signs in and returns once the public landing screen is visible.
    func signInAndReachLanding() throws {
        let login = LoginPage(app: app)
        let email = app.launchEnvironment["UI_TEST_EMAIL"] ?? ""
        let password = app.launchEnvironment["UI_TEST_PASSWORD"] ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            throw XCTSkip("UI_TEST_EMAIL / UI_TEST_PASSWORD not set — skipping post-login tests.")
        }
        _ = login.signIn(email: email, password: password, timeout: 45)
        let landing = PublicLandingPage(app: app)
        XCTAssertTrue(landing.isDisplayed, "Public landing screen should be visible after sign-in")
    }
}
