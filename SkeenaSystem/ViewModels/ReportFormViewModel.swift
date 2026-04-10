// Bend Fly Shop

import Combine
import CoreLocation
import SwiftUI

final class ReportFormViewModel: ObservableObject {
  // MARK: - Required for save & upload

  @Published var river: String = CommunityService.shared.activeCommunityConfig.resolvedDefaultRiver ?? ""
  @Published var species: String = ""
  @Published var sex: String = ""
  @Published var origin: String = "" // "Wild" | "Hatchery"
  @Published var lengthInches: Int = 0
  @Published var quality: String = ""
  @Published var tactic: String = "Swinging"
  @Published var guideName: String = ""
  @Published var clientName: String = ""
  @Published var memberId: String = "" // REQUIRED in catch payload

  // MARK: - Optional

  @Published var tagId: String = "" // required only when origin == "Hatchery"
  @Published var notes: String = ""
  @Published var photo: UIImage?
  @Published var photoPath: String? // full file path to persist in Core Data
  @Published var classifiedWatersLicenseNumber: String? // OPTIONAL in catch payload

  // MARK: - UI

  @Published var isSaving: Bool = false
  @Published var showToast: Bool = false
  @Published var toastMessage: String = ""

  // MARK: - Location (provided by LocationManager)

  var currentLocation: CLLocation?

  // Match view’s length picker
  let lengths: [Int] = Array(20 ... 45)

  // MARK: - Validation (explicit; licences optional)

  var isValid: Bool {
    let requiredFilled =
      !river.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      lengthInches > 0 &&
      !quality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !tactic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !guideName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
      !memberId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    let tagOK = (origin != "Hatchery") ||
      !tagId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

    return requiredFilled && tagOK
  }

  // MARK: - Reset after save

  func reset() {
    species = ""
    sex = ""
    origin = ""
    lengthInches = 0
    quality = ""
    tagId = ""
    notes = ""
    photo = nil
    photoPath = nil
    classifiedWatersLicenseNumber = nil
    // Keep river/guide/tactic defaults; the view re-selects client/angler
  }

  // MARK: - Toast

  private func toast(_ message: String) {
    toastMessage = message
    withAnimation { showToast = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation { self.showToast = false }
    }
  }
}
