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
    /// Phone is optional on the backend; pass an empty string to skip it.
    func fillForm(firstName: String, lastName: String, email: String, password: String, phone: String = "") {
        if firstNameField.waitForExistence(timeout: 5) {
            firstNameField.tap()
            firstNameField.typeText(firstName)
        }
        if lastNameField.exists {
            lastNameField.tap()
            lastNameField.typeText(lastName)
        }
        if !phone.isEmpty, phoneField.exists {
            phoneField.tap()
            phoneField.typeText(phone)
        }
        if emailField.exists {
            emailField.tap()
            emailField.typeText(email)
        }
        if passwordField.exists {
            passwordField.tap()
            passwordField.typeText(password)
        }
        if confirmPasswordField.exists {
            confirmPasswordField.tap()
            confirmPasswordField.typeText(password)
        }
    }

    func tapRegister() {
        registerButton.tap()
    }

    /// Dismisses the keyboard before tapping Register (avoids obscured-button failures).
    func dismissKeyboardAndRegister() {
        app.keyboards.buttons["Done"].tapIfExists()
        app.keyboards.buttons["Return"].tapIfExists()
        registerButton.tap()
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}
