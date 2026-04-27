// Bend Fly Shop

import Combine
import Foundation

/// Per-device preference for whether a public user records catches in the
/// full conservation flow (head photo → identification → length → girth →
/// study/sample/ID barcodes → voice memo) or the abbreviated flow
/// (identification → length → voice memo).
///
/// Persisted in `UserDefaults` so the toggle survives app launches.
/// Read from `ManageProfileView` (the toggle UI, shown only to public users)
/// and from `ReportChatView` (seeds `CatchChatViewModel.conservationMode`
/// before the chat begins).
///
/// Public-only. Guides have their own per-device toggle backed by
/// `ConservationModeStore` (key `guide.conservationMode.enabled`, default
/// off). Researchers always run the conservation flow regardless of any
/// store, gated by `isResearcherRole` on the chat view model.
///
/// Default is `true` — public users opt into the conservation flow unless
/// they explicitly turn it off.
public final class PublicConservationModeStore: ObservableObject {

  // MARK: - Shared instance

  public static let shared = PublicConservationModeStore()

  // MARK: - Storage key

  internal static let defaultsKey = "public.conservationMode.enabled"

  // MARK: - State

  /// When `true`, the public user records catches in the full conservation
  /// flow. Writes are synchronously persisted to `UserDefaults`.
  @Published public var isEnabled: Bool {
    didSet {
      UserDefaults.standard.set(isEnabled, forKey: Self.defaultsKey)
    }
  }

  // MARK: - Init

  private init() {
    // Default ON: if the key is absent, treat the user as opted in. We can't
    // use `UserDefaults.bool(forKey:)` directly because it returns `false`
    // for missing keys, which would silently flip every existing user off.
    if UserDefaults.standard.object(forKey: Self.defaultsKey) == nil {
      self.isEnabled = true
      UserDefaults.standard.set(true, forKey: Self.defaultsKey)
    } else {
      self.isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }
  }

  // MARK: - Test helpers

  /// Reset to factory default (`true`). Tests should call this in
  /// setUp/tearDown so stale state does not leak between cases.
  ///
  /// Order matters: assign `isEnabled = true` FIRST (triggering `didSet`
  /// which writes `true` into UserDefaults) and only THEN remove the key,
  /// otherwise `didSet` would re-create the key with whatever value is
  /// currently held.
  public func resetForTests() {
    isEnabled = true
    UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
  }
}
