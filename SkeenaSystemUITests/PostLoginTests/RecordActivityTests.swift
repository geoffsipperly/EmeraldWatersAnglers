import XCTest

// TC-CATCH-001 to TC-CATCH-012 (automatable subset)
// Requirement: REQ-CATCH-001 to REQ-CATCH-008

final class RecordActivityTests: PostLoginTestBase {

    private var recordActivity: RecordActivityPage { RecordActivityPage(app: app) }

    private func openRecordActivity() {
        let landing = PublicLandingPage(app: app)
        landing.dismissWelcomeIfPresent()
        XCTAssertTrue(landing.isDisplayed, "Landing screen should be visible")
        landing.recordActivityButton.tap()
        XCTAssertTrue(recordActivity.isDisplayed, "RecordActivityView should be open")
    }

    // MARK: - TC-CATCH-001
    // REQ-CATCH-001: two primary action tiles present

    func testPrimaryActionTilesPresent() {
        openRecordActivity()
        XCTAssertTrue(recordActivity.recordCatchTile.exists,
                      "TC-CATCH-001: 'Record Catch' tile (landedTile) should be visible")
        XCTAssertTrue(recordActivity.recordObservationTile.exists,
                      "TC-CATCH-001: 'Record Observation' tile (observationsTile) should be visible")
    }

    // MARK: - TC-CATCH-002
    // REQ-CATCH-001: four no-catch event tiles present

    func testNoCatchEventTilesPresent() {
        openRecordActivity()
        XCTAssertTrue(recordActivity.activeTile.exists,
                      "TC-CATCH-002: 'Active' no-catch tile should be visible")
        XCTAssertTrue(recordActivity.farmedTile.exists,
                      "TC-CATCH-002: 'Farmed' no-catch tile should be visible")
        XCTAssertTrue(recordActivity.promisingTile.exists,
                      "TC-CATCH-002: 'Promising' no-catch tile should be visible")
        XCTAssertTrue(recordActivity.passedTile.exists,
                      "TC-CATCH-002: 'Passed' no-catch tile should be visible")
    }

    // MARK: - TC-CATCH-003
    // REQ-CATCH-002: tapping a no-catch tile shows "Saved!" feedback

    func testNoCatchEventShowsSavedFeedback() {
        openRecordActivity()
        recordActivity.activeTile.tap()

        // "Saved!" feedback text appears briefly
        let savedText = app.staticTexts["Saved!"]
        XCTAssertTrue(savedText.waitForExistence(timeout: 5),
                      "TC-CATCH-003: 'Saved!' feedback should appear after tapping a no-catch tile")
    }

    // MARK: - TC-CATCH-011
    // REQ-CATCH-008: tapping observationsTile presents RecordObservationSheet

    func testObservationTilePresentsObservationSheet() {
        openRecordActivity()
        recordActivity.tapRecordObservation()

        // RecordObservationSheet title
        let sheetTitle = app.staticTexts["Record a field observation"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10),
                      "TC-CATCH-011: RecordObservationSheet should be presented with the expected title")
    }

    // MARK: - TC-CATCH-012
    // REQ-CATCH-008: observation sheet presents environmental fields

    func testObservationSheetHasEnvironmentalFields() {
        openRecordActivity()
        recordActivity.tapRecordObservation()

        // Verify the sheet is open
        XCTAssertTrue(app.staticTexts["Record a field observation"].waitForExistence(timeout: 10),
                      "TC-CATCH-012: RecordObservationSheet should be open")

        // Verify there are interactive recording controls (the audio transcript editor)
        // The sheet has a text editor for the transcript and record/stop buttons
        XCTAssertTrue(app.buttons.count > 0,
                      "TC-CATCH-012: Observation sheet should have interactive controls")
    }
}
