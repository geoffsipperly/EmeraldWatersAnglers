//
//  LicenseRegions.swift
//  SkeenaSystem
//
//  Country and state/province data for fishing license jurisdiction.
//  Used in registration and trip angler forms.
//

import Foundation

enum LicenseCountry: String, CaseIterable, Identifiable {
    case US
    case CA

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .US: return "United States"
        case .CA: return "Canada"
        }
    }

    var subdivisions: [String] {
        switch self {
        case .US: return Self.usStates
        case .CA: return Self.caProvinces
        }
    }

    var subdivisionLabel: String {
        switch self {
        case .US: return "State"
        case .CA: return "Province"
        }
    }

    // MARK: - US States (50)

    private static let usStates: [String] = [
        "Alabama", "Alaska", "Arizona", "Arkansas", "California",
        "Colorado", "Connecticut", "Delaware", "Florida", "Georgia",
        "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa",
        "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland",
        "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri",
        "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey",
        "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio",
        "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina",
        "South Dakota", "Tennessee", "Texas", "Utah", "Vermont",
        "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
    ]

    // MARK: - Canadian Provinces & Territories (13)

    private static let caProvinces: [String] = [
        "Alberta", "British Columbia", "Manitoba", "New Brunswick",
        "Newfoundland and Labrador", "Northwest Territories", "Nova Scotia",
        "Nunavut", "Ontario", "Prince Edward Island", "Quebec",
        "Saskatchewan", "Yukon"
    ]
}
