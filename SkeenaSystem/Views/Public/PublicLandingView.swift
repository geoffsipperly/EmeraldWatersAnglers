// Bend Fly Shop

import CoreLocation
import SwiftUI

// MARK: - PublicLandingView
//
// Landing screen for users with the "public" community role.
// Identical to LandingView except:
//   - No trip sync on appear (public users have no trip concept)
//   - No trip navigation destination
//   - ReportChatView opened in alwaysSolo mode
//   - userRole environment is .public (toolbar shows no Trips tab)

struct PublicLandingView: View {
  @StateObject private var auth = AuthService.shared
  @ObservedObject private var communityService = CommunityService.shared

  @State private var goToAssistant = false

  // No-catch tile state
  @StateObject private var locationManager = LocationManager()
  @State private var savedEventType: NoCatchEventType? = nil
  @State private var showFarmedList = false

  // Path-based nav for toolbar navigation
  @State private var navPath = NavigationPath()

  var body: some View {
    NavigationStack(path: $navPath) {
      DarkPageTemplate(bottomToolbar: {
        RoleAwareToolbar(activeTab: "home")
      }) {
        content
      }
      .navigationDestination(isPresented: $goToAssistant) {
        ReportChatView(alwaysSolo: true, directToChat: true)
          .navigationBarTitleDisplayMode(.inline)
      }
      .navigationDestination(isPresented: $showFarmedList) {
        FarmedReportsListView()
      }
      .navigationDestination(for: GuideDestination.self) { dest in
        switch dest {
        case .conditions:
          FishingForecastRequestView()
            .environment(\.userRole, .public)
            .environment(\.guideNavigateTo, handleNavigateTo)
        case .community:
          CommunityForumView()
            .environment(\.userRole, .public)
            .environment(\.guideNavigateTo, handleNavigateTo)
            .environmentObject(auth)
        case .catches:
          ReportsListViewPicMemo()
            .environment(\.userRole, .public)
            .environment(\.guideNavigateTo, handleNavigateTo)
        case .observations:
          ObservationsListView()
            .environment(\.userRole, .public)
            .environment(\.guideNavigateTo, handleNavigateTo)
        case .trips:
          // Public users have no trips — should never be reached
          EmptyView()
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          CommunityToolbarButton()
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: logoutTapped) {
            HStack(spacing: 6) {
              Image(systemName: "person.crop.circle.badge.xmark")
                .font(.title3.weight(.semibold))
              Text("Log out")
                .font(.footnote.weight(.semibold))
            }
          }
          .accessibilityIdentifier("logoutCapsule")
        }
      }
      .onAppear {
        locationManager.request()
        locationManager.start()
      }
    }
    .environment(\.userRole, .public)
    .environment(\.guideNavigateTo, handleNavigateTo)
    .environmentObject(auth)
  }

  // MARK: - Main content

  private var content: some View {
    ScrollView {
      VStack(spacing: 20) {
        AppHeader(subtitle: "Welcome, \(auth.currentFirstName ?? "")!")
          .padding(.top, 20)

        VStack(spacing: 12) {
          // Landed — primary call-to-action
          Button { goToAssistant = true } label: {
            HStack(spacing: 12) {
              Image(systemName: "square.and.pencil")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
              Text("Record a Catch")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
          }
          .padding(.top, 16)
          .accessibilityIdentifier("landedTile")

          // No-catch tiles — 2×2 grid
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(NoCatchEventType.allCases, id: \.self) { eventType in
              Button { logNoCatchReport(eventType: eventType) } label: {
                noCatchTile(eventType: eventType)
              }
              .disabled(savedEventType != nil)
              .accessibilityIdentifier("\(eventType.rawValue)Tile")
            }
          }
        }
        .padding(.horizontal, 16)

        Spacer(minLength: 8)
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
      memberId: nil
    )
    FarmedReportStore.shared.add(report)

    savedEventType = eventType
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      savedEventType = nil
    }
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

  private func logoutTapped() {
    Task {
      await auth.signOutRemote()
      await MainActor.run {
        AuthStore.shared.clear()
      }
    }
  }

  // MARK: - Navigation

  private func handleNavigateTo(_ destination: GuideDestination?) {
    guard let destination else {
      navPath = NavigationPath()
      return
    }
    var newPath = NavigationPath()
    newPath.append(destination)
    navPath = newPath
  }

}
