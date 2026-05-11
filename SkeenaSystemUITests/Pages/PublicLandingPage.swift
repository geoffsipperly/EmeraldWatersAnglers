import XCTest

/// Page Object for the PublicLandingView screen.
struct PublicLandingPage {
    let app: XCUIApplication

    // MARK: - Elements

    var fishingForecastTile: XCUIElement { app.buttons["fishingForecastTile"] }
    var profileButton: XCUIElement { app.buttons["profileButton"] }
    var logoutButton: XCUIElement { app.buttons["logoutCapsule"] }
    var recordActivityButton: XCUIElement { app.buttons["recordActivityButton"] }

    // Welcome screen (fullScreenCover shown to new users on first login)
    var welcomeGetStartedButton: XCUIElement { app.buttons["publicWelcomeGetStartedButton"] }
    var welcomeCloseButton: XCUIElement { app.buttons["publicWelcomeCloseButton"] }

    // MARK: - Bottom toolbar tabs (matched by label text)

    var homeTab: XCUIElement { app.buttons["Home"] }

    // MARK: - Assertions

    /// Returns true once the public landing screen is visible.
    var isDisplayed: Bool {
        fishingForecastTile.waitForExistence(timeout: 30)
    }

    // MARK: - Actions

    /// Taps "Get Started" on the new-user welcome fullScreenCover if it appears.
    /// Call this after registration before asserting on landing-view content.
    ///
    /// Three paths are handled:
    ///   • New user — cover appears, button settles, we tap it.
    ///   • Returning user (welcome key set) — cover never appears, we no-op.
    ///   • Returning user with a transient cover flash — button briefly shows
    ///     in the accessibility tree but never becomes hittable because the
    ///     cover is animating out. We no-op rather than chase a moving target.
    ///
    /// - Parameter timeout: How long to wait for the welcome button to appear.
    ///                      Default 30s for registration flows; callers in
    ///                      post-login paths should pass a shorter value.
    func dismissWelcomeIfPresent(timeout: TimeInterval = 30) {
        guard welcomeGetStartedButton.waitForExistence(timeout: timeout) else { return }
        // Wait briefly for the fullScreenCover animation to settle.
        let settleDeadline = Date().addingTimeInterval(2.0)
        while Date() < settleDeadline, !welcomeGetStartedButton.isHittable {
            Thread.sleep(forTimeInterval: 0.1)
        }
        // The Get Started button sits at the very bottom of the welcome
        // fullScreenCover, in the home-indicator gesture zone. SwiftUI's hit
        // testing rejects taps in that region — both XCTest's standard tap
        // and a coordinate tap on the button are silently no-op'd.
        //
        // The close (X) button at the top of the cover triggers the same
        // dismissal logic and sits clear of the gesture zone, so prefer
        // Get Started when it's actually hittable, otherwise fall back to
        // the close button.
        if welcomeGetStartedButton.isHittable {
            welcomeGetStartedButton.tap()
        } else if welcomeCloseButton.exists {
            welcomeCloseButton.tap()
        }
        // Let the cover finish animating out before returning so subsequent
        // taps on the landing screen don't land on hit point {-1,-1}.
        let dismissDeadline = Date().addingTimeInterval(5.0)
        while Date() < dismissDeadline, !fishingForecastTile.isHittable {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    func tapFishingForecast() {
        fishingForecastTile.tap()
    }

    func tapProfile() {
        profileButton.tap()
    }

    func tapHomeTab() {
        homeTab.tap()
    }
}
