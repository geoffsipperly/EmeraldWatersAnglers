// Bend Fly Shop

import CoreData
import Security
import SwiftUI

@main
struct SkeenaSystemApp: App {
  // Your Core Data stack singleton
  private let persistence = PersistenceController.shared
  @Environment(\.scenePhase) private var scenePhase
    
    /// This initializer runs before the body is evaluated.
      init() {
        // When launched by UI tests with -resetAuthForUITests, wipe stored tokens
        // so every test run starts from a clean unauthenticated state.
        if CommandLine.arguments.contains("-resetAuthForUITests") {
          Self.clearAuthKeychainEntries()
          UserDefaults.standard.removeObject(forKey: "OfflineLastEmail")
          UserDefaults.standard.removeObject(forKey: "OfflineRememberMeEnabled")
        }
        if CommandLine.arguments.contains("-resetWelcomeStateForUITests") {
          let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("publicWelcome_") }
          keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        }
        // In UI-testing mode, listen for a Darwin notification that the test runner
        // can post to trigger sign-out without going through the SwiftUI toolbar button
        // (NavigationStack ToolbarItems report {-1,-1} hit points to XCUITest).
        if CommandLine.arguments.contains("-uiTesting") {
          Self.registerUITestSignOutHook()
        }
        AppLogging.log("Environment project URL: \(AppEnvironment.shared.projectURL)", level: .info, category: .auth)
        AppLogging.log("Log level: \(AppEnvironment.shared.logLevel)", level: .info, category: .auth)
      }

      /// Registers a Darwin notification observer that signs out when the UI test runner
      /// posts `com.madthinker.uitest.signout`. Darwin notifications cross process
      /// boundaries so the XCUITest host can trigger app-side actions mid-test.
      private static func registerUITestSignOutHook() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
          center,
          nil,
          { _, _, _, _, _ in Task { await AuthService.shared.signOutRemote() } },
          "com.madthinker.uitest.signout" as CFString,
          nil,
          .deliverImmediately
        )
      }

      private static func clearAuthKeychainEntries() {
        let accounts = [
          "epicwaters.auth.access_token",
          "epicwaters.auth.refresh_token",
          "epicwaters.auth.access_token_exp",
          "OfflineLastPassword",
        ]
        for account in accounts {
          let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: account]
          SecItemDelete(query as CFDictionary)
        }
      }

  var body: some Scene {
    WindowGroup {
      // Switches Login ↔ Landing internally based on auth state
      AppRootView()
        .environment(\.managedObjectContext, persistence.container.viewContext)
        .onAppear {
          // Reduce merge conflicts when background tasks write to Core Data
          persistence.container.viewContext.automaticallyMergesChangesFromParent = true
          persistence.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    .onChange(of: scenePhase) { phase in
      // Lightweight safety net to persist any in-flight edits
      if phase == .background || phase == .inactive {
        let context = persistence.container.viewContext
        if context.hasChanges {
          do { try context.save() } catch {
            // You can also log this if you have a logger
            // print("Core Data save on background failed: \(error)")
          }
        }
      }
    }
  }
}
