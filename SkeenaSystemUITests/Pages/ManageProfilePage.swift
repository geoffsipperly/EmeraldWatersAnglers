import XCTest

/// Page Object for ManageProfileView (the profile/account management screen).
struct ManageProfilePage {
    let app: XCUIApplication

    // MARK: - Elements

    // MARK: - Profile fields

    var firstNameField: XCUIElement { app.textFields["firstNameTextField"] }
    var lastNameField: XCUIElement { app.textFields["lastNameTextField"] }
    var phoneField: XCUIElement { app.textFields["phoneTextField"] }
    var dobPicker: XCUIElement { app.datePickers["dobPicker"] }
    var saveButton: XCUIElement { app.buttons["saveProfileButton"] }
    var conservationModeToggle: XCUIElement { app.switches["conservationModeToggle"] }
    var mlTrainingToggle: XCUIElement { app.switches["mlTrainingOptOutToggle"] }
    var appOverviewButton: XCUIElement { app.buttons["appOverviewButton"] }
    var leaveCommunityButton: XCUIElement { app.buttons["leaveCommunityButton"] }
    var deleteAccountButton: XCUIElement { app.buttons["deleteAccountButton"] }

    // MARK: - Confirmation alert elements

    var deleteAlert: XCUIElement { app.alerts["Delete Mad Thinker Account?"] }
    var deleteConfirmationField: XCUIElement { deleteAlert.textFields.firstMatch }
    var deleteConfirmButton: XCUIElement { deleteAlert.buttons["Delete"] }
    var cancelDeleteButton: XCUIElement { deleteAlert.buttons["Cancel"] }

    // MARK: - Assertions

    var isDisplayed: Bool {
        deleteAccountButton.waitForExistence(timeout: 10)
    }

    // MARK: - Actions

    func setFirstName(_ name: String) {
        firstNameField.tap()
        firstNameField.clearAndEnterText(name)
    }

    func setLastName(_ name: String) {
        lastNameField.tap()
        lastNameField.clearAndEnterText(name)
    }

    func setPhone(_ phone: String) {
        phoneField.tap()
        phoneField.clearAndEnterText(phone)
    }

    func tapSave() {
        saveButton.tap()
    }

    func tapDeleteAccount() {
        deleteAccountButton.tap()
    }

    /// Confirms account deletion by typing "DELETE" and tapping the destructive button.
    func confirmDeleteAccount() {
        _ = deleteAlert.waitForExistence(timeout: 5)
        deleteConfirmationField.tap()
        deleteConfirmationField.typeText("DELETE")
        deleteConfirmButton.tap()
    }
}

// MARK: - XCUIElement helper

private extension XCUIElement {
    /// Clears any existing text then types the new value.
    func clearAndEnterText(_ text: String) {
        guard let current = value as? String, !current.isEmpty else {
            typeText(text)
            return
        }
        let deleteChars = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        typeText(deleteChars)
        typeText(text)
    }
}
