// Bend Fly Shop
// LandingView.swift
// Bend Fly Shop – iOS 15+ nav-bar button + pinned footer
import CoreLocation
import SwiftUI

// MARK: - LandingView

struct LandingView: View {
  @Environment(\.managedObjectContext) private var context
  @StateObject private var auth = AuthService.shared
  @ObservedObject private var communityService = CommunityService.shared

  // Reactive entitlement — driven by backend config with xcconfig fallback
  private var E_MANAGE_OPS: Bool { communityService.activeCommunityConfig.flag("E_MANAGE_OPS") }
  @State private var goToAssistant = false

  // Farmed button state
  @StateObject private var locationManager = LocationManager()
  @State private var savedEventType: NoCatchEventType? = nil
  @State private var showFarmedList = false

  // Path-based nav for guide toolbar navigation
  @State private var navPath = NavigationPath()

  // One-time camera/location onboarding for guides
  @AppStorage("hasSeenGuideCameraLocationOnboarding")
  private var hasSeenGuideCameraLocationOnboarding: Bool = false

  @State private var showGuideLocationOnboarding = false

  var body: some View {
    NavigationStack(path: $navPath) {
      DarkPageTemplate(bottomToolbar: {
        RoleAwareToolbar(activeTab: "home")
      }) {
        content
      }
      .navigationDestination(isPresented: $goToAssistant) {
        ReportChatView()
          .navigationBarTitleDisplayMode(.inline)
      }
      .navigationDestination(isPresented: $showFarmedList) {
        FarmedReportsListView()
      }
      .navigationDestination(for: GuideDestination.self) { dest in
        switch dest {
        case .conditions:
          FishingForecastRequestView()
            .environment(\.userRole, .guide)
            .environment(\.guideNavigateTo, handleGuideNavigateTo)
        case .community:
          CommunityForumView()
            .environment(\.userRole, .guide)
            .environment(\.guideNavigateTo, handleGuideNavigateTo)
            .environmentObject(auth)
        case .trips:
          ManageTripsView(guideFirstName: auth.currentFirstName ?? "Guide")
            .environment(\.userRole, .guide)
            .environment(\.guideNavigateTo, handleGuideNavigateTo)
        case .catches:
          ReportsListViewPicMemo()
            .environment(\.userRole, .guide)
            .environment(\.guideNavigateTo, handleGuideNavigateTo)
        case .observations:
          ObservationsListView()
            .environment(\.userRole, .guide)
            .environment(\.guideNavigateTo, handleGuideNavigateTo)
        case .learn:
          // Guides don't use Learn — should not be reached
          EmptyView()
        }
      }
      .toolbar {
        // Leading community switcher (only visible with multiple communities)
        ToolbarItem(placement: .navigationBarLeading) {
          CommunityToolbarButton()
        }
        // Trailing logout
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
      // NEW: one-time camera/location onboarding for guides
      .fullScreenCover(isPresented: $showGuideLocationOnboarding) {
        GuideCameraLocationOnboardingView {
          // Mark as seen and dismiss
          hasSeenGuideCameraLocationOnboarding = true
          showGuideLocationOnboarding = false
        }
      }
      // Decide when to show the onboarding
      .onAppear {
        if auth.currentUserType == .guide,
           !hasSeenGuideCameraLocationOnboarding {
          showGuideLocationOnboarding = true
        }
        // Start location updates for farmed button
        locationManager.request()
        locationManager.start()
      }
      // Sync server trips into Core Data so they're available
      // when the guide taps "Record a Catch".
      .task {
        await TripSyncService.shared.syncTripsIfNeeded(context: context)
      }
    }
    .environment(\.userRole, .guide)
    .environment(\.guideNavigateTo, handleGuideNavigateTo)
    .environmentObject(auth)
  }

  // MARK: - Main content

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        AppHeader()
          .padding(.top, 20)

        // Greeting row — ticket icon appears only when E_MANAGE_OPS
        HStack(alignment: .center) {
          Text("Welcome, \(auth.currentFirstName ?? "Guide")!")
            .font(.title3.weight(.semibold))
            .foregroundColor(.white)
          Spacer()
          if E_MANAGE_OPS {
            NavigationLink { OpsTicketsListView() } label: {
              Image(systemName: "ticket")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
            }
            .accessibilityIdentifier("manageTicketsTile")
          }
        }
        .padding(.horizontal, 20)

        // FEATURE TILES
        VStack(spacing: 12) {
          // Top row: action tiles (blue)
          HStack(spacing: 12) {
            Button { goToAssistant = true } label: {
              actionTile(icon: "square.and.pencil", label: "Record a Catch")
            }
            .accessibilityIdentifier("landedTile")

            Button { handleGuideNavigateTo(.conditions) } label: {
              actionTile(icon: "cloud.sun.rain", label: "Conditions")
            }
            .accessibilityIdentifier("fishingForecastTile")
          }

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
      guideName: auth.currentFirstName ?? "Guide",
      lat: locationManager.lastLocation?.coordinate.latitude,
      lon: locationManager.lastLocation?.coordinate.longitude,
      memberId: nil
    )

    FarmedReportStore.shared.add(report)

    // Brief visual confirmation on the tapped tile only
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

  // MARK: - Guide Navigation

  /// Centralized handler for guide toolbar navigation.
  /// Pass `nil` to pop to root (Home). Pass a destination to navigate there.
  private func handleGuideNavigateTo(_ destination: GuideDestination?) {
    guard let destination else {
      // Home — pop to root
      navPath = NavigationPath()
      return
    }

    // Replace the entire path with the new destination in one step
    // to avoid flashing the landing screen.
    var newPath = NavigationPath()
    newPath.append(destination)
    navPath = newPath
  }

  // MARK: - Action Tile (blue — Record a Catch, Conditions)

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
}
