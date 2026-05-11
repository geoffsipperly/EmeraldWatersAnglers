import XCTest
import CoreFoundation

/// Page Object for the LoginView screen.
///
/// Wraps element queries so smoke tests don't hard-code accessibility identifiers
/// or know the internal structure of the login screen.
struct LoginPage {
    let app: XCUIApplication

    // MARK: - Elements

    var emailField: XCUIElement { app.textFields["emailTextField"] }
    var passwordField: XCUIElement { app.secureTextFields["passwordTextField"] }
    var signInButton: XCUIElement { app.buttons["signInButton"] }
    var errorLabel: XCUIElement { app.staticTexts["loginErrorLabel"] }

    /// Visible once the user is authenticated.
    ///
    /// SwiftUI ToolbarItem buttons in NavigationStack report {-1,-1} hit points to
    /// XCUITest regardless of tapping strategy, so we use this element only to confirm
    /// the landing screen is present before triggering sign-out via Darwin notification.
    var logoutButton: XCUIElement {
        app.buttons["logoutCapsule"]
    }

    // MARK: - Assertions

    /// Returns true if the login screen is currently visible.
    var isDisplayed: Bool {
        emailField.waitForExistence(timeout: 5)
    }

    // MARK: - Actions

    func enterEmail(_ email: String) {
        emailField.tap()
        emailField.typeText(email)
    }

    func enterPassword(_ password: String) {
        passwordField.tap()
        passwordField.typeText(password)
    }

    func tapSignIn() {
        signInButton.tap()
    }

    /// Fills credentials and taps sign in; waits for the login screen to disappear.
    /// - Returns: true if the app navigated away from login within `timeout` seconds.
    ///
    /// Uses `waitForNonExistence` — the inverse of `waitForExistence` — because after a
    /// successful sign-in the email field is removed from the hierarchy. `waitForExistence`
    /// would return true immediately (the field exists right now) and give a false failure.
    @discardableResult
    func signIn(email: String, password: String, timeout: TimeInterval = 20) -> Bool {
        enterEmail(email)
        enterPassword(password)
        tapSignIn()
        return emailField.waitForNonExistence(timeout: timeout)
    }

    /// Triggers sign-out and waits for the login screen to return.
    ///
    /// SwiftUI ToolbarItem buttons in NavigationStack report {-1,-1} hit points to XCUITest
    /// and their taps are intercepted by the full-screen content hosting view regardless of
    /// whether element-based or coordinate-based tap is used. We work around this by:
    ///  1. Confirming the landing screen is visible (logoutButton.waitForExistence)
    ///  2. Posting a Darwin notification that the app (registered in SkeenaSystemApp.init
    ///     when `-uiTesting` is present) observes to call `AuthService.signOutRemote()`
    @discardableResult
    func signOut(waitForButton: TimeInterval = 20, timeout: TimeInterval = 30) -> Bool {
        _ = logoutButton.waitForExistence(timeout: waitForButton)
        // Post cross-process Darwin notification; app calls signOutRemote() on receipt
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName("com.madthinker.uitest.signout" as CFString),
            nil, nil, true
        )
        return emailField.waitForExistence(timeout: timeout)
    }
}
