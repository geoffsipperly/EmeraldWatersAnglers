// Bend Fly Shop
// GuideCameraLocationOnboardingView.swift

import SwiftUI
import UIKit

struct GuideCameraLocationOnboardingView: View {
  /// Called when the user finishes the onboarding ("Next"/"Continue").
  let onDone: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.brandBackground.ignoresSafeArea()

      VStack(spacing: 20) {
        // Top bar with optional close button
        HStack {
          Spacer()
          Button {
            onDone()
          } label: {
            Image(systemName: "xmark")
              .font(.brandHeadline.weight(.semibold))
              .foregroundColor(.brandTextPrimary.opacity(0.8))
              .padding(8)
          }
        }
        .padding(.horizontal)
        .padding(.top, 8)

        Spacer(minLength: 12)

        // Main content
        VStack(spacing: 16) {
          Image(systemName: "camera.viewfinder")
            .font(.system(size: 60, weight: .regular))
            .foregroundColor(.brandAccent)
            .padding(.bottom, 4)

          Text("Enable Camera Location")
            .font(.brandTitle2.weight(.bold))
            .foregroundColor(.brandTextPrimary)
            .multilineTextAlignment(.center)

          Text("Turn on location tagging for your photos so we can automatically attach GPS and time to your catch reports.")
            .font(.brandBody)
            .foregroundColor(.brandTextPrimary.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          // Benefits list
          VStack(alignment: .leading, spacing: 10) {
            benefitRow(
              icon: "mappin.and.ellipse",
              text: "Drop pins on the right river or lake automatically."
            )
            benefitRow(
              icon: "clock",
              text: "Use the exact time the photo was taken for each catch."
            )
            benefitRow(
              icon: "shield.checkerboard",
              text: "Improves data quality for conservation without extra typing."
            )
          }
          .padding(.top, 8)
          .padding(.horizontal)
        }

        Spacer()

        // Instructions + buttons
        VStack(spacing: 14) {
          VStack(alignment: .leading, spacing: 4) {
            Text("How to turn this on")
              .font(.brandHeadline)
              .foregroundColor(.brandTextPrimary)
              .frame(maxWidth: .infinity, alignment: .leading)

            Text("""
1. Tap “Open Settings” below.
2. In Settings, go to **Privacy & Security → Location Services**.
3. Make sure **Location Services** are ON.
4. Scroll down to **Camera**, set **Allow Location Access** to **While Using the App**.
""")
            .font(.brandFootnote)
            .foregroundColor(.brandTextPrimary.opacity(0.8))
          }
          .padding(.horizontal)

          Button(action: openSystemSettings) {
            HStack {
              Image(systemName: "gearshape")
              Text("Open Settings")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandAccent)
            .foregroundColor(.brandTextPrimary)
            .cornerRadius(14)
          }
          .padding(.horizontal)

          Button {
            onDone()
          } label: {
            Text("Continue to app")
              .fontWeight(.semibold)
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.brandStroke)
              .foregroundColor(.brandTextPrimary)
              .cornerRadius(14)
          }
          .padding(.horizontal)
          .padding(.bottom, 20)

          Text("You can change this later in Settings at any time.")
            .font(.brandFootnote)
            .foregroundColor(.brandTextSecondary)
            .padding(.bottom, 8)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Subviews

  private func benefitRow(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .font(.brandBody.weight(.semibold))
        .foregroundColor(.brandAccent)
        .frame(width: 24)

      Text(text)
        .font(.brandFootnote)
        .foregroundColor(.brandTextPrimary.opacity(0.9))
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 0)
    }
  }

  // MARK: - Actions

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
  }
}
