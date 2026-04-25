import XCTest
@testable import SkeenaSystem

/// Tests for CommunityConfig — verifies the flag fallback chain,
/// branding resolution, JSON decoding, and the CommunityInfo.config merge.
final class CommunityConfigTests: XCTestCase {

    // MARK: - Flag Fallback Chain

    func testFlag_returnsBackendValue_whenPresent() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: ["E_TEST_FLAG": true],
            geography: .empty,
            units: nil
        )
        XCTAssertTrue(config.flag("E_TEST_FLAG"),
                      "Should return backend value when key is present")
    }

    func testFlag_returnsBackendFalse_whenExplicitlyFalse() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: ["E_TEST_FLAG": false],
            geography: .empty,
            units: nil
        )
        XCTAssertFalse(config.flag("E_TEST_FLAG"),
                       "Should return false when backend explicitly sets it to false")
    }

    func testFlag_fallsBackToXcconfig_whenKeyAbsent() {
        let config = CommunityConfig.default
        // E_CATCH_CAROUSEL is true in DevTEST xcconfig
        let xcconfigValue = readEntitlement("E_CATCH_CAROUSEL")
        XCTAssertEqual(config.flag("E_CATCH_CAROUSEL"), xcconfigValue,
                       "Should fall back to xcconfig when key absent from backend")
    }

    func testFlag_returnsFalse_whenKeyAbsentFromBothSources() {
        let config = CommunityConfig.default
        XCTAssertFalse(config.flag("E_NONEXISTENT_12345"),
                       "Should return false when key absent from both backend and xcconfig")
    }

    func testFlag_backendOverridesXcconfig() {
        // E_CATCH_CAROUSEL is true in DevTEST xcconfig — backend overrides to false
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: ["E_CATCH_CAROUSEL": false],
            geography: .empty,
            units: nil
        )
        XCTAssertFalse(config.flag("E_CATCH_CAROUSEL"),
                       "Backend value should override xcconfig value")
    }

    // MARK: - Branding Resolution

    func testResolvedLogoAssetName_returnsBackendValue_whenPresent() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: "BendFlyShopLogo", tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: [:],
            geography: .empty,
            units: nil
        )
        XCTAssertEqual(config.resolvedLogoAssetName, "BendFlyShopLogo")
    }

    func testResolvedLogoAssetName_fallsBackToXcconfig_whenNil() {
        let config = CommunityConfig.default
        XCTAssertEqual(config.resolvedLogoAssetName, AppEnvironment.shared.appLogoAsset,
                       "Should fall back to xcconfig APP_LOGO_ASSET")
    }

    func testResolvedLogoAssetName_fallsBackToXcconfig_whenEmpty() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: "", tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: [:],
            geography: .empty,
            units: nil
        )
        XCTAssertEqual(config.resolvedLogoAssetName, AppEnvironment.shared.appLogoAsset,
                       "Should fall back to xcconfig when asset name is empty string")
    }

    func testResolvedDisplayName_returnsBackendValue_whenPresent() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: "Custom Name", learnUrl: nil,
            entitlements: [:],
            geography: .empty,
            units: nil
        )
        XCTAssertEqual(config.resolvedDisplayName, "Custom Name")
    }

    func testResolvedDisplayName_fallsBackToXcconfig_whenNil() {
        let config = CommunityConfig.default
        XCTAssertEqual(config.resolvedDisplayName, AppEnvironment.shared.appDisplayName)
    }

    func testResolvedTagline_returnsBackendValue_whenPresent() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: "Custom Tagline", displayName: nil, learnUrl: nil,
            entitlements: [:],
            geography: .empty,
            units: nil
        )
        XCTAssertEqual(config.resolvedTagline, "Custom Tagline")
    }

    // MARK: - Default Config

    func testDefault_hasEmptyFeatureFlags() {
        XCTAssertTrue(CommunityConfig.default.entitlements.isEmpty,
                      "Default config should have no backend entitlements")
    }

    func testDefault_hasNilBranding() {
        let d = CommunityConfig.default
        XCTAssertNil(d.logoUrl)
        XCTAssertNil(d.logoAssetName)
        XCTAssertNil(d.tagline)
        XCTAssertNil(d.displayName)
    }

    // MARK: - JSON Decoding

    func testDecoding_fullConfig() throws {
        let json = """
        {
            "logoUrl": "https://example.com/logo.png",
            "logoAssetName": "TestLogo",
            "tagline": "Test Tagline",
            "displayName": "Test Community",
            "learnUrl": "https://example.com/learn",
            "entitlements": {"E_MEET_STAFF": true, "E_FLIGHT_INFO": false},
            "geography": {"default_river": "Hoh River", "lodge_rivers": ["Hoh River", "Green River"], "forecast_location": "Western Washington"}
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(CommunityConfig.self, from: json)

        XCTAssertEqual(config.logoUrl, "https://example.com/logo.png")
        XCTAssertEqual(config.logoAssetName, "TestLogo")
        XCTAssertEqual(config.tagline, "Test Tagline")
        XCTAssertEqual(config.displayName, "Test Community")
        XCTAssertEqual(config.learnUrl, "https://example.com/learn")
        XCTAssertEqual(config.entitlements["E_MEET_STAFF"], true)
        XCTAssertEqual(config.entitlements["E_FLIGHT_INFO"], false)
        XCTAssertEqual(config.entitlements.count, 2)
    }

    func testDecoding_roundtrip() throws {
        let original = CommunityConfig(
            logoUrl: "https://example.com/logo.png",
            logoAssetName: "TestLogo",
            tagline: "Tagline",
            displayName: "Name",
            learnUrl: "https://example.com/learn",
            entitlements: ["E_A": true, "E_B": false],
            geography: CommunityGeography(
                defaultRiver: "Hoh River", lodgeRivers: ["Hoh River"],
                defaultWaterBody: "Puget Sound", lodgeWaterBodies: ["Puget Sound"],
                forecastLocation: "Western WA", defaultMapLatitude: 47.9, defaultMapLongitude: -122.8
            ),
            units: nil
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CommunityConfig.self, from: data)

        XCTAssertEqual(original, decoded, "Encode/decode roundtrip should produce equal config")
    }

    // MARK: - CommunityInfo.config Merge

    func testCommunityInfo_config_mergesBrandingAndFlags() {
        let typeInfo = CommunityTypeInfo(
            id: "type-1",
            name: "Lodge",
            entitlements: ["E_MEET_STAFF": true, "E_FLIGHT_INFO": false]
        )

        let communityInfo = CommunityInfo(
            id: "comm-1",
            name: "Test Lodge",
            code: "ABC123",
            isActive: true,
            communityTypeId: "type-1",
            logoUrl: "https://example.com/logo.png",
            logoAssetName: "TestLogo",
            tagline: "Welcome",
            displayName: "Test Lodge Display",
            learnUrl: nil,
            customUrls: nil,
            geography: CommunityGeography(
                defaultRiver: "Hoh River", lodgeRivers: ["Hoh River", "Green River"],
                defaultWaterBody: nil, lodgeWaterBodies: nil,
                forecastLocation: "Western WA", defaultMapLatitude: 47.9, defaultMapLongitude: -122.8
            ),
            units: nil,
            communityTypes: typeInfo
        )

        let config = communityInfo.config

        // Branding from community
        XCTAssertEqual(config.logoUrl, "https://example.com/logo.png")
        XCTAssertEqual(config.logoAssetName, "TestLogo")
        XCTAssertEqual(config.tagline, "Welcome")
        XCTAssertEqual(config.displayName, "Test Lodge Display")

        // Flags from type
        XCTAssertTrue(config.flag("E_MEET_STAFF"))
        XCTAssertFalse(config.flag("E_FLIGHT_INFO"))
    }

    func testCommunityInfo_config_withNilType_returnsEmptyFlags() {
        let communityInfo = CommunityInfo(
            id: "comm-1",
            name: "Test",
            code: "ABC123",
            isActive: true,
            communityTypeId: nil,
            logoUrl: nil,
            logoAssetName: nil,
            tagline: nil,
            displayName: nil,
            learnUrl: nil,
            customUrls: nil,
            geography: nil,
            units: nil,
            communityTypes: nil
        )

        let config = communityInfo.config

        XCTAssertTrue(config.entitlements.isEmpty,
                      "Config should have empty entitlements when community has no type")
    }

    // MARK: - Equatable

    func testEquatable_sameValues_areEqual() {
        let a = CommunityConfig(
            logoUrl: "url", logoAssetName: "asset", tagline: "tag", displayName: "name", learnUrl: nil,
            entitlements: ["E_A": true], geography: .empty, units: nil
        )
        let b = CommunityConfig(
            logoUrl: "url", logoAssetName: "asset", tagline: "tag", displayName: "name", learnUrl: nil,
            entitlements: ["E_A": true], geography: .empty, units: nil
        )
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentFlags_areNotEqual() {
        let a = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: ["E_A": true], geography: .empty, units: nil
        )
        let b = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: ["E_A": false], geography: .empty, units: nil
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Geography Resolution

    func testResolvedGeography_returnsBackendValues_whenPresent() {
        let geo = CommunityGeography(
            defaultRiver: "Skeena River",
            lodgeRivers: ["Skeena River", "Kispiox River"],
            defaultWaterBody: "Pacific Ocean",
            lodgeWaterBodies: ["Pacific Ocean"],
            forecastLocation: "Northern BC",
            defaultMapLatitude: 54.5,
            defaultMapLongitude: -128.6
        )
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: [:], geography: geo,
            units: nil
        )

        XCTAssertEqual(config.resolvedDefaultRiver, "Skeena River")
        XCTAssertEqual(config.resolvedLodgeRivers, ["Skeena River", "Kispiox River"])
        XCTAssertEqual(config.resolvedDefaultWaterBody, "Pacific Ocean")
        XCTAssertEqual(config.resolvedLodgeWaterBodies, ["Pacific Ocean"])
        XCTAssertEqual(config.resolvedForecastLocation, "Northern BC")
        XCTAssertEqual(config.resolvedDefaultMapLatitude, 54.5)
        XCTAssertEqual(config.resolvedDefaultMapLongitude, -128.6)
    }

    func testResolvedGeography_returnsNilAndEmpty_whenNotConfigured() {
        let config = CommunityConfig.default

        XCTAssertNil(config.resolvedDefaultRiver, "Should be nil when no geography configured")
        XCTAssertTrue(config.resolvedLodgeRivers.isEmpty, "Should be empty when no geography configured")
        XCTAssertNil(config.resolvedForecastLocation, "Should be nil when no geography configured")
        XCTAssertNil(config.resolvedDefaultMapLatitude, "Should be nil when no geography configured")
        XCTAssertNil(config.resolvedDefaultMapLongitude, "Should be nil when no geography configured")
        XCTAssertFalse(config.hasGeography, "hasGeography should be false when nothing configured")
    }

    func testHasGeography_trueWhenRiversConfigured() {
        let geo = CommunityGeography(
            defaultRiver: nil, lodgeRivers: ["Test River"],
            defaultWaterBody: nil, lodgeWaterBodies: nil,
            forecastLocation: nil, defaultMapLatitude: nil, defaultMapLongitude: nil
        )
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: [:], geography: geo,
            units: nil
        )
        XCTAssertTrue(config.hasGeography)
    }

    // MARK: - Learn URL Resolution

    func testResolvedLearnUrl_returnsBackendValue_whenPresent() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil,
            learnUrl: "https://community.example.com/learn",
            entitlements: [:], geography: .empty, units: nil
        )
        XCTAssertEqual(config.resolvedLearnUrl, "https://community.example.com/learn")
    }

    func testResolvedLearnUrl_fallsBackToXcconfig_whenNil() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: nil,
            entitlements: [:], geography: .empty, units: nil
        )
        XCTAssertEqual(config.resolvedLearnUrl, AppEnvironment.shared.defaultLearnURL,
                       "Should fall back to xcconfig DEFAULT_LEARN_URL when learnUrl is nil")
    }

    func testResolvedLearnUrl_fallsBackToXcconfig_whenEmpty() {
        let config = CommunityConfig(
            logoUrl: nil, logoAssetName: nil, tagline: nil, displayName: nil, learnUrl: "",
            entitlements: [:], geography: .empty, units: nil
        )
        XCTAssertEqual(config.resolvedLearnUrl, AppEnvironment.shared.defaultLearnURL,
                       "Should fall back to xcconfig DEFAULT_LEARN_URL when learnUrl is empty string")
    }

    func testCommunityInfo_config_passesLearnUrlThrough() {
        let communityInfo = CommunityInfo(
            id: "comm-1",
            name: "Test",
            code: "TST001",
            isActive: true,
            communityTypeId: nil,
            logoUrl: nil,
            logoAssetName: nil,
            tagline: nil,
            displayName: nil,
            learnUrl: "https://custom.example.com/tutorials",
            customUrls: nil,
            geography: nil,
            units: nil,
            communityTypes: nil
        )
        XCTAssertEqual(communityInfo.config.resolvedLearnUrl, "https://custom.example.com/tutorials")
    }
}
