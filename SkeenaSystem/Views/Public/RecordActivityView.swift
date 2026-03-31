// Bend Fly Shop

import CoreLocation
import SwiftUI

// MARK: - RecordActivityView
//
// Pushed from PublicLandingView when the user taps "Record new activity".
// Presents all activity tiles: Record a Catch, Observations, and the four
// no-catch event types (Active, Farmed, Promising, Passed).

struct RecordActivityView: View {
  @StateObject private var auth = AuthService.shared
  @Environment(\.guideNavigateTo) private var guideNavigateTo

  // Location for no-catch reports
  @StateObject private var locationManager = LocationManager()

  // Navigation
  @State private var goToAssistant = false

  // No-catch tile feedback
  @State private var savedEventType: NoCatchEventType? = nil

  var body: some View {
    DarkPageTemplate {
      ScrollView {
        VStack(spacing: 16) {
          Text("Record new activity")
            .font(.title3.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)

          // Action tiles — Record a Catch + Observations
          HStack(spacing: 12) {
            Button { goToAssistant = true } label: {
              actionTile(icon: "square.and.pencil", label: "Record a Catch")
            }
            .accessibilityIdentifier("landedTile")

            Button { guideNavigateTo(.observations) } label: {
              actionTile(icon: "waveform", label: "Observations")
            }
            .accessibilityIdentifier("observationsTile")
          }
          .padding(.horizontal, 16)

          // No-catch event tiles — single row, 4 across
          HStack(spacing: 8) {
            ForEach(NoCatchEventType.allCases, id: \.self) { eventType in
              Button { logNoCatchReport(eventType: eventType) } label: {
                noCatchTile(eventType: eventType)
              }
              .disabled(savedEventType != nil)
              .accessibilityIdentifier("\(eventType.rawValue)Tile")
            }
          }
          .padding(.horizontal, 16)
        }
      }
    }
    .navigationTitle("New Activity")
    .navigationDestination(isPresented: $goToAssistant) {
      ReportChatView(alwaysSolo: true, directToChat: true)
        .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear {
      locationManager.request()
      locationManager.start()
    }
  }

  // MARK: - Actions

  private func logNoCatchReport(eventType: NoCatchEventType) {
    let report = FarmedReport(
      id: UUID(),
      createdAt: Date(),
      status: .savedLocally,
      eventType: eventType,
      guideName: auth.currentFirstName ?? "",
      lat: locationManager.lastLocation?.coordinate.latitude,
      lon: locationManager.lastLocation?.coordinate.longitude,
      memberId: nil
    )
    FarmedReportStore.shared.add(report)

    savedEventType = eventType
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      savedEventType = nil
    }
  }

  // MARK: - Tile views

  private func actionTile(icon: String, label: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.blue)
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundColor(.blue)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 11)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
  }

  private func noCatchTile(eventType: NoCatchEventType) -> some View {
    let icon: String = {
      switch eventType {
      case .active:    return "eye"
      case .farmed:    return "leaf.arrow.circlepath"
      case .promising: return "sparkles"
      case .passed:    return "xmark.circle"
      }
    }()
    return VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.white)
      Text(savedEventType == eventType ? "Saved!" : eventType.displayName)
        .font(.caption.weight(.semibold))
        .foregroundColor(.white)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 11)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
  }
}
