import XCTest

/// Page Object for ExploreView (the "Learn" tab).
struct ExplorePage {
    let app: XCUIApplication

    // MARK: - Elements

    var masterclassCard: XCUIElement { app.buttons["masterclassCard"] }

    /// Returns the recommended video card button for a given link name.
    func learnVideoCard(named name: String) -> XCUIElement {
        app.buttons["learnVideo_\(name)"]
    }

    // MARK: - Assertions

    var isDisplayed: Bool {
        app.navigationBars["Learn"].waitForExistence(timeout: 10)
    }

    var isMasterclassVisible: Bool {
        masterclassCard.waitForExistence(timeout: 5)
    }

    // MARK: - Actions

    func tapMasterclass() {
        masterclassCard.tap()
    }

    func tapLearnVideo(named name: String) {
        learnVideoCard(named: name).tap()
    }
}
