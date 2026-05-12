// Bend Fly Shop
//
// AlphaBadge.swift — small grey "Alpha" pill rendered only when the
// `BETA_RELEASE` Info.plist value (sourced from `BETA_RELEASE` in xcconfig)
// is true. Replaces the older blue "Pilot" capsule. Self-gates so call sites
// don't have to repeat the BETA_RELEASE plumbing — just drop `AlphaBadge()`
// where you want it and the view returns `EmptyView` in release builds.

import SwiftUI

struct AlphaBadge: View {
  var body: some View {
    if Self.isBetaRelease {
      Text("Alpha")
        .font(.brandCaption2.weight(.semibold))
        .foregroundColor(.brandTextPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.gray.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityIdentifier("alphaBadge")
    }
  }

  /// Reads `BETA_RELEASE` out of the active xcconfig (boolean or string form).
  /// Returns false on anything that isn't an obvious truthy value so a missing
  /// or malformed entry stays safe.
  static var isBetaRelease: Bool {
    if let boolVal = Bundle.main.object(forInfoDictionaryKey: "BETA_RELEASE") as? Bool {
      return boolVal
    }
    if let strVal = Bundle.main.object(forInfoDictionaryKey: "BETA_RELEASE") as? String {
      return strVal.lowercased() == "true" || strVal == "1"
    }
    return false
  }
}
