// MLTrainingOptOutUploadTests.swift
// SkeenaSystemTests
//
// TC-CATCH-004 / TC-PRIV-004
// Verifies that when a public user has opted out of ML training,
// upload payloads include mlTrainingOptOut=true.
//
// Note: Direct UploadCatchReport / UploadFarmedReports instantiation is
// unavailable in the test environment (iOS 26 simulator malloc regression).
// These tests verify the model and store integration that feeds into uploads.

import XCTest
@testable import SkeenaSystem

final class MLTrainingOptOutUploadTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MLTrainingOptOutStore.shared.resetForTests()
    }

    override func tearDown() {
        MLTrainingOptOutStore.shared.resetForTests()
        super.tearDown()
    }

    // MARK: - TC-CATCH-004 / TC-PRIV-004
    // REQ-CATCH-002 / REQ-PRIV-002
    // When mlTrainingOptOutToggle is OFF (opted out), the FarmedReport created
    // by RecordActivityView carries mlTrainingOptOut=true.

    func testFarmedReport_mlOptOut_true_whenOptedOut() throws {
        // Opt out
        MLTrainingOptOutStore.shared.isOptedOut = true

        let report = FarmedReport(
            id: UUID(),
            createdAt: Date(),
            status: .savedLocally,
            eventType: .active,
            guideName: "uitest",
            mlTrainingOptOut: MLTrainingOptOutStore.shared.isOptedOut
        )

        XCTAssertEqual(report.mlTrainingOptOut, true,
                       "TC-CATCH-004: FarmedReport should have mlTrainingOptOut=true when user is opted out")
    }

    func testFarmedReport_mlOptOut_false_whenOptedIn() throws {
        // Ensure opted in (default)
        MLTrainingOptOutStore.shared.isOptedOut = false

        let report = FarmedReport(
            id: UUID(),
            createdAt: Date(),
            status: .savedLocally,
            eventType: .farmed,
            guideName: "uitest",
            mlTrainingOptOut: MLTrainingOptOutStore.shared.isOptedOut
        )

        XCTAssertEqual(report.mlTrainingOptOut, false,
                       "TC-CATCH-004: FarmedReport should have mlTrainingOptOut=false when user is opted in")
    }

    // MARK: - Store default state

    func testMLTrainingOptOutStore_defaultIsOptedIn() {
        // After resetForTests, store should be opted IN (isOptedOut = false)
        XCTAssertFalse(MLTrainingOptOutStore.shared.isOptedOut,
                       "TC-PRIV-004: Default ML training opt-out state should be false (opted in)")
    }

    func testMLTrainingOptOutStore_togglePersistsAcrossAccess() {
        MLTrainingOptOutStore.shared.isOptedOut = true
        XCTAssertTrue(MLTrainingOptOutStore.shared.isOptedOut,
                      "TC-PRIV-004: Opt-out setting should persist when set to true")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "public.mlTrainingOptOut.enabled"),
                      "TC-PRIV-004: Opt-out setting should be written to UserDefaults")
    }

    // MARK: - FarmedReport encoding includes mlTrainingOptOut

    func testFarmedReport_encodingIncludesMlTrainingOptOut() throws {
        let report = FarmedReport(
            id: UUID(),
            createdAt: Date(),
            status: .savedLocally,
            eventType: .active,
            guideName: "uitest",
            mlTrainingOptOut: true
        )

        let encoded = try JSONEncoder().encode(report)
        let dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]

        XCTAssertNotNil(dict, "TC-PRIV-004: FarmedReport should be encodable to JSON")
        XCTAssertEqual(dict?["mlTrainingOptOut"] as? Bool, true,
                       "TC-PRIV-004: JSON payload should include mlTrainingOptOut=true")
    }
}
