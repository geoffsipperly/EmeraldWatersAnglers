// Bend Fly Shop

import CoreLocation
import SwiftUI

// MARK: - GuideRecordActivityView
//
// Pushed from LandingView when the guide taps "Record".
// Presents: Record a Catch (→ full trip/angler/chat flow) and the four
// no-catch event tiles (Active, Farmed, Promising, Passed).

struct GuideRecordActivityView: View {
  @StateObject private var auth = AuthService.shared
  @Environment(\.dismiss) private var dismiss

  /// Called after a catch is successfully saved — used by LandingView to pop
  /// all the way back to root.
  var onCatchSaved: (() -> Void)? = nil

  // Location for no-catch reports
  @StateObject private var locationManager = LocationManager()

  // Navigation
  @State private var goToAssistant = false

  // No-catch tile feedback
  @State private var savedEventType: NoCatchEventType? = nil

  var body: some View {
    DarkPageTemplate {
      ScrollView {
        VStack(spacing: 12) {
          // Record a Catch tile (blue)
          Button { goToAssistant = true } label: {
            actionTile(icon: "square.and.pencil", label: "Record a Catch")
          }
          .accessibilityIdentifier("landedTile")
          .padding(.horizontal, 16)
          .padding(.top, 16)

          // Section divider
          Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 0.5)
            .padding(.vertical, 4)

          // No-catch event tiles — 2 per row
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
      ReportChatView(onSaved: {
        dismiss()              // pop GuideRecordActivityView
        onCatchSaved?()        // let LandingView reset its nav stack
      })
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
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(.blue)
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.blue)
    }
    .frame(maxWidth: .infinity, minHeight: 56)
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
    .frame(maxWidth: .infinity, minHeight: 70)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
  }
}
