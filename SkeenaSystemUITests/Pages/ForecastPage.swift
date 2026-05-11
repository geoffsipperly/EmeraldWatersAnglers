import XCTest

/// Page Object for FishingForecastRequestView (the river-picker screen).
struct ForecastPage {
    let app: XCUIApplication

    // MARK: - Assertions

    /// Returns true once the Conditions screen is visible (any river row rendered).
    var isDisplayed: Bool {
        app.navigationBars["Conditions"].waitForExistence(timeout: 10)
    }

    // MARK: - Actions

    /// Taps the row for the named river/water body.
    func tapRiver(_ name: String) {
        let riverButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        if riverButton.waitForExistence(timeout: 10) {
            riverButton.tap()
        }
    }
}

/// Page Object for FishingForecastResultView (the conditions result screen).
struct ForecastResultPage {
    let app: XCUIApplication

    // MARK: - Assertions

    /// Returns true once the result view's navigation title containing the river name appears.
    func isDisplayed(river: String) -> Bool {
        // The result view renders the river name as the navigation bar principal title
        let titleElement = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", river)).firstMatch
        return titleElement.waitForExistence(timeout: 15)
    }
}
