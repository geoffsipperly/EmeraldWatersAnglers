//
//  CommunityConfig.swift
//  SkeenaSystem
//
//  Unified community configuration that merges branding (from communities table)
//  and entitlements (from community_types table). Provides typed accessors with
//  xcconfig fallback so communities without backend config behave identically
//  to the current static system.
//

import Foundation

struct CommunityConfig: Codable, Equatable {

    // MARK: - Branding (from communities table)

    let logoUrl: String?
    let logoAssetName: String?
    let tagline: String?
    let displayName: String?
    let learnUrl: String?

    // MARK: - Entitlements (from community_types.entitlements JSONB)

    let entitlements: [String: Bool]

    // MARK: - Geography (from communities.geography JSONB)

    let geography: CommunityGeography

    // MARK: - Units ("imperial" | "metric", defaults to "metric")

    let units: String?

    /// True when the community uses imperial measurements (°F, mph, in, mi).
    var isImperial: Bool { units == "imperial" }

    // MARK: - Unit conversion helpers

    /// °C → °F (or passthrough for metric)
    func temperature(_ celsius: Double) -> Int {
        isImperial ? Int((celsius * 9 / 5 + 32).rounded()) : Int(celsius.rounded())
    }

    /// Temperature unit label
    var tempUnit: String { isImperial ? "°F" : "°C" }

    /// km/h → mph (or passthrough for metric)
    func windSpeed(_ kmh: Double) -> Int {
        isImperial ? Int((kmh * 0.621371).rounded()) : Int(kmh.rounded())
    }

    /// Wind speed unit label
    var windUnit: String { isImperial ? "mph" : "km/h" }

    /// inches → cm (or passthrough for imperial)
    func length(_ inches: Double) -> Double {
        isImperial ? inches : inches * 2.54
    }

    /// Length unit label
    var lengthUnit: String { isImperial ? "in" : "cm" }

    // MARK: - Entitlement accessor with xcconfig fallback

    /// Returns the backend entitlement value if present, otherwise falls back to
    /// the compile-time xcconfig value via `readEntitlement(_:)`.
    func flag(_ key: String) -> Bool {
        entitlements[key] ?? readEntitlement(key)
    }

    // MARK: - Resolved branding with xcconfig fallback

    var resolvedLogoAssetName: String {
        if let name = logoAssetName, !name.isEmpty { return name }
        return AppEnvironment.shared.appLogoAsset
    }

    var resolvedTagline: String {
        if let t = tagline, !t.isEmpty { return t }
        return AppEnvironment.shared.communityTagline
    }

    var resolvedDisplayName: String {
        if let d = displayName, !d.isEmpty { return d }
        return AppEnvironment.shared.appDisplayName
    }

    // MARK: - Resolved learn URL (falls back to xcconfig DEFAULT_LEARN_URL)

    var resolvedLearnUrl: String {
        if let u = learnUrl, !u.isEmpty { return u }
        return AppEnvironment.shared.defaultLearnURL
    }

    // MARK: - Resolved geography (no xcconfig fallback — empty means not configured)

    var resolvedDefaultRiver: String? {
        if let r = geography.defaultRiver, !r.isEmpty { return r }
        return nil
    }

    var resolvedLodgeRivers: [String] {
        geography.lodgeRivers ?? []
    }

    var resolvedDefaultWaterBody: String? {
        if let w = geography.defaultWaterBody, !w.isEmpty { return w }
        return nil
    }

    var resolvedLodgeWaterBodies: [String] {
        geography.lodgeWaterBodies ?? []
    }

    var resolvedForecastLocation: String? {
        if let f = geography.forecastLocation, !f.isEmpty { return f }
        return nil
    }

    var resolvedDefaultMapLatitude: Double? {
        geography.defaultMapLatitude
    }

    /// True when the community has no geography configured on the backend
    var hasGeography: Bool {
        !resolvedLodgeRivers.isEmpty || resolvedForecastLocation != nil
    }

    var resolvedDefaultMapLongitude: Double? {
        geography.defaultMapLongitude
    }

    // MARK: - Default (falls through entirely to xcconfig)

    static let `default` = CommunityConfig(
        logoUrl: nil,
        logoAssetName: nil,
        tagline: nil,
        displayName: nil,
        learnUrl: nil,
        entitlements: [:],
        geography: .empty,
        units: nil
    )
}
