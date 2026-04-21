// Bend Fly Shop

import Combine
import Foundation

/// Per-device preference for whether a public user has opted OUT of having
/// their anonymized catch and non-catch submissions used to improve our
/// species-detection and length-estimation models.
///
/// Persisted in `UserDefaults` so the toggle survives app launches.
/// Read from `ManageProfileView` (the toggle UI, shown only to public users)
/// and from upload paths (`UploadCatchReport`, `UploadFarmedReports`) via
/// `CatchChatViewModel` / FarmedReport creation sites.
///
/// Only public users have a choice; lodge-provisioned guides, anglers, and
/// conservation-agency researchers always send `mlTrainingOptOut = false`
/// because their data-sharing consent is governed by the organization's
/// agreement with Mad Thinker (per Privacy Policy §5).
public final class MLTrainingOptOutStore: ObservableObject {

  // MARK: - Shared instance

  public static let shared = MLTrainingOptOutStore()

  // MARK: - Storage key

  internal static let defaultsKey = "public.mlTrainingOptOut.enabled"

  // MARK: - State

  /// When `true`, the user has opted OUT — uploads will send
  /// `mlTrainingOptOut = true` so the backend excludes their data from
  /// model training. Default is `false` (opted in).
  @Published public var isOptedOut: Bool {
    didSet {
      UserDefaults.standard.set(isOptedOut, forKey: Self.defaultsKey)
    }
  }

  // MARK: - Init

  private init() {
    self.isOptedOut = UserDefaults.standard.bool(forKey: Self.defaultsKey)
  }

  // MARK: - Test helpers

  /// Reset to factory default. Tests should call this in setUp/tearDown.
  /// Order matters: assign `isOptedOut = false` first (triggering `didSet`
  /// which writes `false` into UserDefaults) and only then remove the key.
  public func resetForTests() {
    isOptedOut = false
    UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
  }
}
