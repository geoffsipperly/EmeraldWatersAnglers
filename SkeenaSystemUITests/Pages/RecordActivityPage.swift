import XCTest

/// Page Object for RecordActivityView — the activity-type picker shown after tapping "Record".
struct RecordActivityPage {
    let app: XCUIApplication

    // MARK: - Primary action tiles

    var recordCatchTile: XCUIElement { app.buttons["landedTile"] }
    var recordObservationTile: XCUIElement { app.buttons["observationsTile"] }

    // MARK: - No-catch event tiles

    var activeTile: XCUIElement { app.buttons["activeTile"] }
    var farmedTile: XCUIElement { app.buttons["farmedTile"] }
    var promisingTile: XCUIElement { app.buttons["promisingTile"] }
    var passedTile: XCUIElement { app.buttons["passedTile"] }

    // MARK: - Assertions

    var isDisplayed: Bool {
        recordCatchTile.waitForExistence(timeout: 10)
    }

    // MARK: - Actions

    func tapRecordCatch() {
        recordCatchTile.tap()
    }

    func tapRecordObservation() {
        recordObservationTile.tap()
    }

    func tapNoCatchEvent(_ type: NoCatchEventType) {
        switch type {
        case .active:     activeTile.tap()
        case .farmed:     farmedTile.tap()
        case .promising:  promisingTile.tap()
        case .passed:     passedTile.tap()
        }
    }

    enum NoCatchEventType {
        case active, farmed, promising, passed
    }
}
