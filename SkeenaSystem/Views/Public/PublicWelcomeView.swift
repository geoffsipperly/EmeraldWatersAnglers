// Bend Fly Shop
// PublicWelcomeView.swift
//
// First-login welcome overview for Public-role members. Shown once via
// PublicLandingView's fullScreenCover gated on `publicWelcome_<memberId>`,
// and re-presentable anytime from ManageProfileView.

import SwiftUI

struct PublicWelcomeView: View {
  /// Single capability tile shown in the body's "What you can do" section.
  struct Capability: Equatable {
    let icon: String     // SF Symbol name
    let title: String
    let subtitle: String
  }

  /// Locked list of capability tiles. Source of truth for the body's
  /// `capabilitiesSection`. Tests assert against this so reordering or
  /// silently dropping a capability surfaces in CI.
  static let capabilities: [Capability] = [
    .init(icon: "camera.fill",
          title: "Record catches",
          subtitle: "Photo-based capture for every fish you land"),
    .init(icon: "ruler",
          title: "Estimate length, girth & weight",
          subtitle: "AI measurements derived from your catch photo"),
    .init(icon: "leaf.fill",
          title: "Record environmental observations",
          subtitle: "Log water, weather, and habitat notes in the field"),
    .init(icon: "map.fill",
          title: "Maps & catch journal",
          subtitle: "See where catches happen and browse your full history"),
    .init(icon: "play.rectangle.fill",
          title: "Curated videos",
          subtitle: "Tactics, fly tying, and conservation content"),
  ]

  /// Pure title formatter — exposed so tests can lock the personalization
  /// logic without standing up an AuthService mock. Trims whitespace and
  /// gracefully degrades to the unpersonalized form for empty/whitespace
  /// names.
  static func greetingTitle(firstName: String?) -> String {
    let trimmed = firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let name = trimmed, !name.isEmpty {
      return "\(name), Welcome to Mad Thinker"
    }
    return "Welcome to Mad Thinker"
  }

  @Environment(\.dismiss) private var dismiss

  /// Called when the user dismisses the view. PublicLandingView uses this
  /// to persist the "has seen welcome" flag for first-time presentation.
  /// Optional so the profile-page re-presentation path can omit it.
  var onDismiss: (() -> Void)? = nil

  private var greetingTitle: String {
    Self.greetingTitle(firstName: AuthService.shared.currentFirstName)
  }

  var body: some View {
    ZStack {
      Color.brandBackground.ignoresSafeArea()

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
          .font(.brandTitle3.weight(.semibold))
          .foregroundColor(.brandTextPrimary)
          .padding(10)
          .background(Color.brandSurface, in: Circle())
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
        .font(.brandTitle2.weight(.bold))
        .foregroundColor(.brandTextPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text("You just became part of the living knowledge that protects wild places")
        .font(.callout)
        .foregroundColor(.brandTextPrimary.opacity(0.85))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
  }

  private var speciesNote: some View {
    Text("Every contribution helps protect the wild places you love for the next generation")
      .font(.brandSubheadline)
      .foregroundColor(.brandTextPrimary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 20)
  }

  private var capabilitiesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("What you can do")
        .font(.brandHeadline)
        .foregroundColor(.brandTextPrimary)
        .padding(.bottom, 2)

      ForEach(Self.capabilities, id: \.title) { cap in
        capabilityRow(icon: cap.icon, title: cap.title, subtitle: cap.subtitle)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 4)
  }

  private var closingNote: some View {
    Text("Thanks again for joining us. You can revisit this overview anytime from your Profile page.")
      .font(.brandSubheadline)
      .foregroundColor(.brandTextPrimary.opacity(0.85))
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 20)
      .padding(.top, 4)
  }

  private var policyLinks: some View {
    VStack(spacing: 8) {
      policyLinkRow(title: "Privacy Policy", icon: "lock.shield", url: LegalURLs.privacyPolicy)
        .accessibilityIdentifier("publicWelcomePrivacyLink")
      policyLinkRow(title: "Acceptable Use Policy", icon: "doc.text", url: LegalURLs.acceptableUsePolicy)
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
        .font(.brandHeadline.weight(.semibold))
        .foregroundColor(.brandTextPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 12))
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
        .font(.brandSubheadline)
        .foregroundColor(.brandSuccess)
        .frame(width: 20, alignment: .center)
        .padding(.top, 3)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.callout.weight(.semibold))
          .foregroundColor(.brandTextPrimary)
        Text(subtitle)
          .font(.brandCaption)
          .foregroundColor(.brandTextPrimary.opacity(0.7))
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
          .font(.brandSubheadline)
          .foregroundColor(.brandTextPrimary.opacity(0.7))
          .frame(width: 20)
        Text(title)
          .font(.callout.weight(.semibold))
          .foregroundColor(.brandAccent)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.brandCaption)
          .foregroundColor(.brandTextPrimary.opacity(0.4))
      }
      .padding(12)
      .background(Color.brandStrokeSubtle, in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

#Preview {
  PublicWelcomeView()
}
