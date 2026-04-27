import XCTest

/// Page Object for the MemberRegistrationView screen.
///
/// Covers the community-code choice screen and the full-registration form
/// (Path C: no community code). Invite-path (Path A) is not covered here.
struct RegistrationPage {
    let app: XCUIApplication

    // MARK: - Community code choice screen

    var noCodeButton: XCUIElement { app.buttons["noCodeButton"] }
    var hasCodeButton: XCUIElement { app.buttons["hasCodeButton"] }

    // MARK: - Full registration form fields

    var firstNameField: XCUIElement { app.textFields["firstNameTextField"] }
    var lastNameField: XCUIElement { app.textFields["lastNameTextField"] }
    var phoneField: XCUIElement { app.textFields["phoneTextField"] }
    var emailField: XCUIElement { app.textFields["emailTextField_reg"] }
    var passwordField: XCUIElement { app.secureTextFields["passwordTextField_reg"] }
    var confirmPasswordField: XCUIElement { app.secureTextFields["confirmPasswordTextField_reg"] }
    var registerButton: XCUIElement { app.buttons["registerButton"] }

    // MARK: - Assertions

    var isChoiceScreenDisplayed: Bool {
        noCodeButton.waitForExistence(timeout: 5)
    }

    var isFormDisplayed: Bool {
        firstNameField.waitForExistence(timeout: 5)
    }

    // MARK: - Actions

    func tapNoCode() {
        noCodeButton.tap()
    }

    /// Fill the full registration form (no community code path).
    ///
    /// Strategy:
    /// - Name fields are tapped normally (always hittable at the top of the form).
    /// - Email may have scrolled near the nav bar — forceTap bypasses hittability.
    /// - After email, dismiss keyboard via Return so password field is hittable.
    /// - After password, try keyboard "Next" to advance to confirm without
    ///   dismissing. If not found, dismiss keyboard and tap confirm directly,
    ///   waiting for the keyboard to reappear before typing.
    func fillForm(firstName: String, lastName: String, email: String, password: String, phone: String = "") {
        // Name fields
        if firstNameField.waitForExistence(timeout: 5) {
            firstNameField.tap()
            firstNameField.typeText(firstName)
        }
        if lastNameField.exists {
            lastNameField.tap()
            lastNameField.typeText(lastName)
        }
        if !phone.isEmpty, phoneField.exists {
            phoneField.forceTap()
            phoneField.typeText(phone)
        }

        // Email — forceTap bypasses "not hittable" when the keyboard from name fields
        // has scrolled the registration form so the email field sits near the sheet
        // navigation bar edge.
        if emailField.waitForExistence(timeout: 5) {
            emailField.forceTap()
            emailField.typeText(email)
        }

        // Dismiss keyboard so password field is fully visible and hittable.
        emailField.typeText("\n")

        // Password SecureField: tap now that keyboard is dismissed.
        if passwordField.waitForExistence(timeout: 3) {
            passwordField.tap()
            // Wait for keyboard to appear before typing.
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
            passwordField.typeText(password)
        }

        // Advance to confirm. Prefer keyboard "Next" (keeps keyboard up, no
        // animation gap). Fall back to dismiss + tap if "Next" isn't found.
        if tapKeyboardNextIfVisible() {
            // Confirm field now has focus — wait for any focus-transition animation.
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
            confirmPasswordField.typeText(password)
        } else {
            // Dismiss keyboard, then tap confirm and wait for keyboard to reappear.
            passwordField.typeText("\n")
            if confirmPasswordField.waitForExistence(timeout: 5) {
                confirmPasswordField.tap()
                _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
                confirmPasswordField.typeText(password)
            }
        }
    }

    /// Taps the keyboard Return/Next key. Returns true if found and tapped.
    @discardableResult
    private func tapKeyboardNextIfVisible() -> Bool {
        let kb = app.keyboards
        for label in ["next", "Next", "Next Field", "return", "Return"] {
            let btn = kb.buttons[label]
            if btn.waitForExistence(timeout: 1) {
                btn.tap()
                return true
            }
        }
        return false
    }

    func tapRegister() {
        registerButton.tap()
    }

    /// Dismisses the keyboard before tapping Register (avoids obscured-button failures).
    func dismissKeyboardAndRegister() {
        for label in ["done", "Done", "Return"] {
            app.keyboards.buttons[label].tapIfExists()
        }
        registerButton.tap()
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }

    /// Taps via coordinate, bypassing XCUITest's hittability check.
    ///
    /// Use for fields that exist in the hierarchy but report "not hittable" because
    /// the keyboard has scrolled the form to an edge position. Avoid for SecureField
    /// when keyboard focus transfer is required — use the keyboard's Next/Return key
    /// to advance through the responder chain instead.
    func forceTap() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
