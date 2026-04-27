import XCTest

/// Page Object for ManageProfileView (the profile/account management screen).
struct ManageProfilePage {
    let app: XCUIApplication

    // MARK: - Elements

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
