import SwiftUI
import UIKit

// Brand color tokens. Today's values mirror the existing dark-first palette.
// When new branding lands (including the planned shift to a lighter background),
// edit only the values below — call sites stay unchanged.
//
// SwiftUI tokens (`Color.brand…`) and UIKit tokens (`UIColor.brand…`) are kept
// side-by-side here so they cannot drift apart during a rebrand.
extension Color {
    // Backgrounds & surfaces
    static let brandBackground = Color.black
    static let brandSurface = Color.white.opacity(0.08)
    static let brandSurfaceMuted = Color.white.opacity(0.05)
    static let brandNavBar = Color(UIColor.systemGray6)

    // Strokes & dividers
    static let brandStroke = Color.white.opacity(0.12)
    static let brandStrokeStrong = Color.white.opacity(0.15)
    static let brandStrokeSubtle = Color.white.opacity(0.06)

    // Text
    static let brandTextPrimary = Color.white
    static let brandTextSecondary = Color.gray
    static let brandTextTertiary = Color.white.opacity(0.7)

    // Action & status
    static let brandAccent = Color.blue
    static let brandSuccess = Color.green
    static let brandWarning = Color.orange
    static let brandError = Color.red

    /// Translucent dark overlay used on top of photos/maps for text legibility.
    /// Stays dark even after the planned shift to a lighter app background — a
    /// light scrim over a photo would lose contrast.
    static let brandScrim = Color.black

    /// Inverted surface — explicitly white islands within an otherwise dark UI
    /// (e.g. a white pill button or info card). Does NOT auto-flip when the app
    /// background lightens; use a regular `brandSurface*` token for that.
    static let brandSurfaceInverted = Color.white

    /// Text/icon color used on top of `brandSurfaceInverted` (or other light
    /// backgrounds within the app). Explicitly black, not theme-derived.
    static let brandTextOnLight = Color.black
}

// UIKit equivalents for places that touch UIAppearance / UIKit APIs directly
// (e.g. `UINavigationBarAppearance` in `DarkPageTemplate.swift` and
// `UITextView.backgroundColor` in form sheets).
extension UIColor {
    static let brandBackground = UIColor.black
    static let brandNavBar = UIColor.systemGray6
    static let brandTextPrimary = UIColor.white
    static let brandAccent = UIColor.systemBlue
    static let brandSurface = UIColor.white.withAlphaComponent(0.08)
}
