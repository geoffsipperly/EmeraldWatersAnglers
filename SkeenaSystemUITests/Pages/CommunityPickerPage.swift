import XCTest

/// Page Object for CommunityPickerView — shown when user has multiple communities.
struct CommunityPickerPage {
    let app: XCUIApplication

    // MARK: - Elements

    var joinCommunityButton: XCUIElement { app.buttons["joinCommunityButton"] }
    var logoutButton: XCUIElement { app.buttons["logoutCapsule"] }

    /// Returns the tile button for a community by its display name.
    func communityTile(named name: String) -> XCUIElement {
        app.buttons["communityTile_\(name)"]
    }

    // MARK: - Assertions

    var isDisplayed: Bool {
        app.staticTexts["Select Your Community"].waitForExistence(timeout: 10)
    }

    // MARK: - Actions

    func tapCommunity(named name: String) {
        communityTile(named: name).tap()
    }

    func tapJoinCommunity() {
        joinCommunityButton.tap()
    }
}
