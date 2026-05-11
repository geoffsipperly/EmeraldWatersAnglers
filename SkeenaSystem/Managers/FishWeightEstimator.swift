// Bend Fly Shop
// FishWeightEstimator.swift — Pure-calculation utility for estimating fish weight from length.
//
// Uses the standard fisheries formula: Weight (lbs) = Length (in) x Girth (in)^2 / Divisor
// When girth is unknown: Girth = Length x FISH_DEFAULT_GIRTH_RATIO (xcconfig, default 0.52)
// Simplified: Weight = Length^3 x ratio^2 / Divisor
//
// Divisor lookup follows a cascading hierarchy:
//   1. River + species match (e.g. "Babine" + "steelhead" -> 690)
//   2. Species-only match (e.g. "steelhead" -> 775)
//   3. Default: 800

import Foundation

// MARK: - Result

struct FishWeightEstimate {
  let girthInches: Double
  let weightLbs: Double
  let divisor: Int
  let divisorSource: String       // e.g. "Babine River steelhead", "General steelhead", "Default"
  let girthRatio: Double          // species-specific or FISH_DEFAULT_GIRTH_RATIO default
  let girthRatioSource: String    // e.g. "Steelhead average", "Default (freshwater average)"
  let girthIsEstimated: Bool      // true = formula-derived, false = manually measured
}

// MARK: - Estimator

enum FishWeightEstimator {

  /// Default girth-to-length ratio when species is unknown (read from FISH_DEFAULT_GIRTH_RATIO xcconfig).
  static var defaultGirthRatio: Double { AppEnvironment.shared.fishDefaultGirthRatio }

  /// General-purpose default divisor when species is unknown.
  static let defaultDivisor: Int = 800

  // MARK: - Public API

  /// Estimate girth and weight from length alone (girth derived via species-specific ratio).
  static func estimate(
    lengthInches: Double,
    species: String?,
    river: String?
  ) -> FishWeightEstimate {
    let (divisor, divisorSrc) = lookupDivisor(species: species, river: river)
    let (ratio, ratioSrc) = lookupGirthRatio(species: species)
    let girth = lengthInches * ratio
    let weight = lengthInches * girth * girth / Double(divisor)

    return FishWeightEstimate(
      girthInches: round(girth * 10) / 10,
      weightLbs: round(weight * 100) / 100,
      divisor: divisor,
      divisorSource: divisorSrc,
      girthRatio: ratio,
      girthRatioSource: ratioSrc,
      girthIsEstimated: true
    )
  }

  /// Estimate weight using a known (manually measured) girth.
  static func estimateWeight(
    lengthInches: Double,
    girthInches: Double,
    species: String?,
    river: String?
  ) -> FishWeightEstimate {
    let (divisor, divisorSrc) = lookupDivisor(species: species, river: river)
    let (ratio, ratioSrc) = lookupGirthRatio(species: species)
    let weight = lengthInches * girthInches * girthInches / Double(divisor)

    return FishWeightEstimate(
      girthInches: round(girthInches * 10) / 10,
      weightLbs: round(weight * 100) / 100,
      divisor: divisor,
      divisorSource: divisorSrc,
      girthRatio: ratio,
      girthRatioSource: ratioSrc,
      girthIsEstimated: false
    )
  }

  // MARK: - Divisor Lookup

  /// Returns (divisor, humanReadableSource) using cascading hierarchy:
  /// 1. River + species override
  /// 2. Species-level divisor
  /// 3. Default (800)
  static func lookupDivisor(species: String?, river: String?) -> (Int, String) {
    let normalizedSpecies = normalizeSpecies(species)
    let normalizedRiver = river?.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    // 1. River + species override
    if !normalizedRiver.isEmpty, let speciesKey = normalizedSpecies {
      for entry in riverOverrides {
        let riverMatches = entry.riverPatterns.contains { normalizedRiver.contains($0) }
        if riverMatches && entry.speciesKey == speciesKey {
          return (entry.divisor, entry.source)
        }
      }
    }

    // 2. Species-level divisor
    if let speciesKey = normalizedSpecies, let entry = speciesDivisors[speciesKey] {
      return (entry.divisor, entry.source)
    }

    // 3. Default
    return (defaultDivisor, "Default")
  }

  // MARK: - Girth Ratio Lookup

  /// Returns (girthRatio, humanReadableSource). All species use FISH_DEFAULT_GIRTH_RATIO.
  static func lookupGirthRatio(species: String?) -> (Double, String) {
    return (defaultGirthRatio, "Configured default")
  }

  // MARK: - Species Normalization

  /// Maps various species names/labels to a canonical key for divisor lookup.
  private static func normalizeSpecies(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }

    let lower = raw.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)

    // Strip lifecycle stage suffixes
    let stripped = lower
      .replacingOccurrences(of: " holding", with: "")
      .replacingOccurrences(of: " traveler", with: "")
      .replacingOccurrences(of: " lake", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    // Direct key match
    if speciesDivisors[stripped] != nil { return stripped }

    // Alias lookup
    for (alias, canonical) in speciesAliases {
      if stripped.contains(alias) { return canonical }
    }

    return nil
  }

  // MARK: - Divisor Tables

  private struct SpeciesEntry {
    let divisor: Int
    let source: String
  }

  /// Species-level divisors (from the Fish Weight Estimation Brief).
  private static let speciesDivisors: [String: SpeciesEntry] = [
    "steelhead":        SpeciesEntry(divisor: 775, source: "General steelhead"),
    "chinook":          SpeciesEntry(divisor: 740, source: "Chinook salmon"),
    "coho":             SpeciesEntry(divisor: 790, source: "Coho salmon"),
    "atlantic salmon":  SpeciesEntry(divisor: 800, source: "Atlantic salmon"),
    "rainbow":          SpeciesEntry(divisor: 900, source: "Rainbow trout"),
    "rainbow trout":    SpeciesEntry(divisor: 900, source: "Rainbow trout"),
    "brown trout":      SpeciesEntry(divisor: 900, source: "Brown trout"),
    "brook trout":      SpeciesEntry(divisor: 900, source: "Brook trout"),
    "brook":            SpeciesEntry(divisor: 900, source: "Brook trout"),
    "cutthroat":        SpeciesEntry(divisor: 900, source: "Cutthroat trout"),
    "cutthroat trout":  SpeciesEntry(divisor: 900, source: "Cutthroat trout"),
    "arctic char":      SpeciesEntry(divisor: 900, source: "Arctic char"),
    "articchar":        SpeciesEntry(divisor: 900, source: "Arctic char"),
    "grayling":         SpeciesEntry(divisor: 900, source: "Grayling"),
    "largemouth bass":  SpeciesEntry(divisor: 800, source: "Largemouth bass"),
    "smallmouth bass":  SpeciesEntry(divisor: 800, source: "Smallmouth bass"),
    "northern pike":    SpeciesEntry(divisor: 900, source: "Northern pike"),
    "sea-run trout":    SpeciesEntry(divisor: 900, source: "Sea-run trout"),
    "sea run trout":    SpeciesEntry(divisor: 900, source: "Sea-run trout"),
  ]

  /// Aliases that map to canonical species keys.
  private static let speciesAliases: [String: String] = [
    "king":       "chinook",
    "chinook":    "chinook",
    "silver":     "coho",
    "coho":       "coho",
    "steelhead":  "steelhead",
    "rainbow":    "rainbow",
    "brown":      "brown trout",
    "brook":      "brook trout",
    "cutthroat":  "cutthroat",
    "arctic":     "arctic char",
    "grayling":   "grayling",
    "pike":       "northern pike",
    "musky":      "northern pike",
    "largemouth": "largemouth bass",
    "smallmouth": "smallmouth bass",
    "atlantic":   "atlantic salmon",
    "sea-run":    "sea-run trout",
    "sea run":    "sea run trout",
  ]

  // MARK: - River Overrides

  private struct RiverOverride {
    let riverPatterns: [String]
    let speciesKey: String
    let divisor: Int
    let source: String
  }

  /// River + species overrides from field-calibrated studies.
  private static let riverOverrides: [RiverOverride] = [
    RiverOverride(
      riverPatterns: ["babine"],
      speciesKey: "steelhead",
      divisor: 690,
      source: "Babine River steelhead"
    ),
    RiverOverride(
      riverPatterns: ["skeena", "kispiox"],
      speciesKey: "steelhead",
      divisor: 690,
      source: "Skeena/Kispiox steelhead"
    ),
    RiverOverride(
      riverPatterns: ["dean"],
      speciesKey: "steelhead",
      divisor: 752,
      source: "Dean River steelhead"
    ),
    RiverOverride(
      riverPatterns: ["kanektok"],
      speciesKey: "steelhead",
      divisor: 775,
      source: "Kanektok River steelhead"
    ),
  ]
}
