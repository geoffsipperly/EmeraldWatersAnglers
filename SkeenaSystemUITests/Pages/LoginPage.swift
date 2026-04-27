import XCTest

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

    /// Visible only once the user is authenticated and the app navigates away from login.
    /// We detect logout by looking for the logout capsule on any landing view.
    var logoutButton: XCUIElement { app.buttons["logoutCapsule"] }

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
    @discardableResult
    func signIn(email: String, password: String, timeout: TimeInterval = 20) -> Bool {
        enterEmail(email)
        enterPassword(password)
        tapSignIn()
        return !emailField.waitForExistence(timeout: timeout)
    }

    /// Taps the logout button from any landing screen and waits for the login screen to return.
    @discardableResult
    func signOut(timeout: TimeInterval = 10) -> Bool {
        logoutButton.tap()
        return emailField.waitForExistence(timeout: timeout)
    }
}
