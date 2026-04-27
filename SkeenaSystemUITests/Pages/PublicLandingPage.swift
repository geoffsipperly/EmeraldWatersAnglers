import XCTest

/// Page Object for the PublicLandingView screen.
struct PublicLandingPage {
    let app: XCUIApplication

    // MARK: - Elements

    var fishingForecastTile: XCUIElement { app.buttons["fishingForecastTile"] }
    var profileButton: XCUIElement { app.buttons["profileButton"] }
    var logoutButton: XCUIElement { app.buttons["logoutCapsule"] }
    var recordActivityButton: XCUIElement { app.buttons["recordActivityButton"] }

    // Welcome screen (fullScreenCover shown to new users on first login)
    var welcomeGetStartedButton: XCUIElement { app.buttons["publicWelcomeGetStartedButton"] }

    // MARK: - Bottom toolbar tabs (matched by label text)

    var homeTab: XCUIElement { app.buttons["Home"] }

    // MARK: - Assertions

    /// Returns true once the public landing screen is visible.
    var isDisplayed: Bool {
        fishingForecastTile.waitForExistence(timeout: 30)
    }

    // MARK: - Actions

    /// Taps "Get Started" on the new-user welcome fullScreenCover if it appears.
    /// Call this after registration before asserting on landing-view content.
    func dismissWelcomeIfPresent() {
        if welcomeGetStartedButton.waitForExistence(timeout: 30) {
            welcomeGetStartedButton.tap()
        }
    }

    func tapFishingForecast() {
        fishingForecastTile.tap()
    }

    func tapProfile() {
        profileButton.tap()
    }

    func tapHomeTab() {
        homeTab.tap()
    }
}
