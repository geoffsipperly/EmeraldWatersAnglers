// Bend Fly Shop

import CoreLocation
import SwiftUI

// MARK: - GuideRecordActivityView
//
// Pushed from GuideLandingView when the guide taps "Record".
// Presents: Record a Catch (→ full trip/angler/chat flow) and the four
// no-catch event tiles (Active, Farmed, Promising, Passed).

struct GuideRecordActivityView: View {
  @StateObject private var auth = AuthService.shared
  @Environment(\.guideNavigateTo) private var guideNavigateTo
  @Environment(\.dismiss) private var dismiss

  /// Called after a catch is successfully saved — used by GuideLandingView to pop
  /// all the way back to root.
  var onCatchSaved: (() -> Void)? = nil

  // Location for no-catch reports
  @StateObject private var locationManager = LocationManager()

  // Navigation
  @State private var goToAssistant = false

  // Record observation sheet
  @State private var showRecordObservation = false

  // No-catch tile feedback
  @State private var savedEventType: NoCatchEventType? = nil

  var body: some View {
    DarkPageTemplate {
      GeometryReader { geo in
        VStack(spacing: 0) {
          // ── Top 1/3: Record catch + Record observation (1.5× larger) ──
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button { goToAssistant = true } label: {
              actionTile(icon: "square.and.pencil", label: "Catch")
            }
            .accessibilityIdentifier("landedTile")

            Button { showRecordObservation = true } label: {
              actionTile(icon: "waveform", label: "Observation")
            }
            .accessibilityIdentifier("observationsTile")
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .frame(height: geo.size.height / 3)

          // Section divider
          Rectangle()
            .fill(Color.brandStroke)
            .frame(height: 0.5)

          // ── Bottom 2/3: No-catch tiles + descriptions ──
          ScrollView {
            VStack(spacing: 12) {
              // Section header — groups the four no-catch event tiles below
              // under a single "Marks" umbrella, consistent with how the
              // rest of the app refers to these waypoints (e.g. Activities
              // → Observations → Marks).
              Text("Marks")
                .font(.brandHeadline)
                .foregroundColor(.brandTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)

              // No-catch event tiles — 2 per row (30% larger)
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
              .padding(.top, 12)

              Spacer(minLength: 16)

              // Explanatory text
              VStack(alignment: .leading, spacing: 12) {
                ForEach([
                  ("eye",                  "Active",     "You saw signs of fish but didn't hook up"),
                  ("leaf.arrow.circlepath","Farmed",     "You hooked a fish but lost it before landing"),
                  ("sparkles",             "Promising",  "The spot looked promising and you want to remember it"),
                  ("xmark.circle",         "Passed",     "You checked the spot and decided to move on"),
                ], id: \.1) { icon, title, description in
                  HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                      .font(.brandCaption)
                      .foregroundColor(.brandTextPrimary.opacity(0.5))
                      .frame(width: 16, alignment: .center)
                      .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                      Text(title)
                        .font(.brandCaption.weight(.semibold))
                        .foregroundColor(.brandTextPrimary)
                      Text(description)
                        .font(.brandCaption)
                        .foregroundColor(.brandTextPrimary.opacity(0.55))
                    }
                  }
                }
              }
              .padding(.horizontal, 20)
              .padding(.bottom, 24)
            }
          }
        }
      }
    }
    .navigationTitle("New Activity")
    .navigationDestination(isPresented: $goToAssistant) {
      ReportChatView(onSaved: {
        dismiss()              // pop GuideRecordActivityView
        onCatchSaved?()        // let GuideLandingView reset its nav stack
      })
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear {
      locationManager.request()
      locationManager.start()
    }
    .fullScreenCover(isPresented: $showRecordObservation) {
      RecordObservationSheet { _ in
        showRecordObservation = false
      }
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
      memberId: auth.currentMemberId,
      communityId: CommunityService.shared.activeCommunityId,
      mlTrainingOptOut: auth.currentUserType == .public
        ? MLTrainingOptOutStore.shared.isOptedOut
        : false
    )
    FarmedReportStore.shared.add(report)

    savedEventType = eventType
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      savedEventType = nil
    }
  }

  // MARK: - Tile views

  private func actionTile(icon: String, label: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: icon)
        .font(.brandTitle2)
        .foregroundColor(.brandAccent)
      Text(label)
        .font(.brandSubheadline.weight(.semibold))
        .foregroundColor(.brandAccent)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: 105)
    .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 16))
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
    return VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.brandTitle3)
        .foregroundColor(.brandTextPrimary)
      Text(savedEventType == eventType ? "Saved!" : eventType.displayName)
        .font(.brandCaption.weight(.semibold))
        .foregroundColor(.brandTextPrimary)
        .lineLimit(1)
    }
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, minHeight: 70)
    .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 16))
  }
}
