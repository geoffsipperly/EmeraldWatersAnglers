// Bend Fly Shop
// PublicWelcomeView.swift
//
// First-login welcome overview for Public-role members. Shown once via
// PublicLandingView's fullScreenCover gated on `publicWelcome_<memberId>`,
// and re-presentable anytime from ManageProfileView.

import SwiftUI

struct PublicWelcomeView: View {
  @Environment(\.dismiss) private var dismiss

  /// Called when the user dismisses the view. PublicLandingView uses this
  /// to persist the "has seen welcome" flag for first-time presentation.
  /// Optional so the profile-page re-presentation path can omit it.
  var onDismiss: (() -> Void)? = nil

  private let privacyPolicyURL = URL(string: "https://madthinkertech.com/privacy-policy")!
  private let acceptableUsePolicyURL = URL(string: "https://madthinkertech.com/acceptable-use-policy")!

  /// Trimmed first name from AuthService, or `nil` when unavailable/empty.
  /// Used to personalize the welcome title — gracefully falls back to the
  /// unpersonalized form when the name hasn't been fetched yet.
  private var firstName: String? {
    let raw = AuthService.shared.currentFirstName
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed?.isEmpty == false) ? trimmed : nil
  }

  private var greetingTitle: String {
    if let name = firstName {
      return "\(name), Welcome to Mad Thinker"
    }
    return "Welcome to Mad Thinker"
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          closeButton

          headerSection

          speciesNote

          capabilitiesSection

          closingNote

          policyLinks

          getStartedButton
        }
        .padding(.bottom, 24)
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Sections

  private var closeButton: some View {
    HStack {
      Spacer()
      Button {
        onDismiss?()
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.title3.weight(.semibold))
          .foregroundColor(.white)
          .padding(10)
          .background(Color.white.opacity(0.08), in: Circle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("publicWelcomeCloseButton")
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Single-row greeting — `.title2` fits the average name comfortably;
      // `.minimumScaleFactor` shrinks automatically for unusually long names
      // so the title never wraps to a second row.
      Text(greetingTitle)
        .font(.title2.weight(.bold))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text("You just became part of the living knowledge that protects wild places")
        .font(.callout)
        .foregroundColor(.white.opacity(0.85))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
  }

  private var speciesNote: some View {
    Text("Every contribution helps protect the wild places you love for the next generation")
      .font(.subheadline)
      .foregroundColor(.white)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 20)
  }

  private var capabilitiesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What you can do")
        .font(.headline)
        .foregroundColor(.white)
        .padding(.bottom, 2)

      capabilityRow(
        icon: "camera.fill",
        title: "Record catches",
        subtitle: "Photo-based capture for every fish you land"
      )
      capabilityRow(
        icon: "ruler",
        title: "Estimate length, girth & weight",
        subtitle: "AI measurements derived from your catch photo"
      )
      capabilityRow(
        icon: "leaf.fill",
        title: "Record environmental observations",
        subtitle: "Log water, weather, and habitat notes in the field"
      )
      capabilityRow(
        icon: "map.fill",
        title: "Maps & catch journal",
        subtitle: "See where catches happen and browse your full history"
      )
      capabilityRow(
        icon: "play.rectangle.fill",
        title: "Curated videos",
        subtitle: "Tactics, fly tying, and conservation content"
      )
    }
    .padding(.horizontal, 20)
    .padding(.top, 4)
  }

  private var closingNote: some View {
    Text("Thanks again for joining us. You can revisit this overview anytime from your Profile page.")
      .font(.subheadline)
      .foregroundColor(.white.opacity(0.85))
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 20)
      .padding(.top, 4)
  }

  private var policyLinks: some View {
    VStack(spacing: 8) {
      policyLinkRow(title: "Privacy Policy", icon: "lock.shield", url: privacyPolicyURL)
        .accessibilityIdentifier("publicWelcomePrivacyLink")
      policyLinkRow(title: "Acceptable Use Policy", icon: "doc.text", url: acceptableUsePolicyURL)
        .accessibilityIdentifier("publicWelcomeAcceptableUseLink")
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }

  private var getStartedButton: some View {
    Button {
      onDismiss?()
      dismiss()
    } label: {
      Text("Get Started")
        .font(.headline.weight(.semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .accessibilityIdentifier("publicWelcomeGetStartedButton")
  }

  // MARK: - Row builders

  @ViewBuilder
  private func capabilityRow(icon: String, title: String, subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      // Functional icon doubles as the bullet — green to match the previous
      // checkmark's visual weight, fixed-width so titles line up across rows.
      Image(systemName: icon)
        .font(.subheadline)
        .foregroundColor(.green)
        .frame(width: 20, alignment: .center)
        .padding(.top, 3)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
          .foregroundColor(.white)
        Text(subtitle)
          .font(.caption)
          .foregroundColor(.white.opacity(0.7))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
  }

  @ViewBuilder
  private func policyLinkRow(title: String, icon: String, url: URL) -> some View {
    Link(destination: url) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.7))
          .frame(width: 20)
        Text(title)
          .font(.callout.weight(.semibold))
          .foregroundColor(.blue)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.caption)
          .foregroundColor(.white.opacity(0.4))
      }
      .padding(12)
      .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

#Preview {
  PublicWelcomeView()
}
