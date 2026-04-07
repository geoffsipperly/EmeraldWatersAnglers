// Bend Fly Shop
//
// ResearcherCatchConfirmationView.swift — Review screen shown after the
// researcher completes the chat flow. Displays all collected data for
// confirmation before saving.

import CoreLocation
import SwiftUI

struct ResearcherCatchConfirmationView: View {
  @ObservedObject var chatVM: CatchChatViewModel
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text("Review Catch Report")
              .font(.title3.weight(.bold))
              .foregroundColor(.white)
              .padding(.bottom, 4)

            Group {
              row(label: "Name", value: researcherName)
              row(label: "GPS", value: gpsString)
              row(label: "Species", value: speciesString)
              row(label: "Sex", value: sexString)
              row(label: "Length", value: lengthString)
              row(label: "Girth", value: girthString)
              row(label: "Weight", value: weightString)
              row(label: "Floy Tag Number", value: floyTagString)
              row(label: "Barcode ID", value: barcodeString)
              row(label: "Voice Memo", value: voiceMemoString)
            }

            Spacer(minLength: 24)

            Button(action: onConfirm) {
              Text("Confirm")
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
          }
          .padding(20)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Cancel") { onCancel() }
            .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Data extraction

  private var researcherName: String {
    let first = AuthService.shared.currentFirstName ?? ""
    let last = AuthService.shared.currentLastName ?? ""
    let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    return full.isEmpty ? "-" : full
  }

  private var gpsString: String {
    if let loc = chatVM.currentLocationForDisplay {
      return String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
    }
    return "-"
  }

  private var speciesString: String {
    if let flow = chatVM.researcherFlow, let s = flow.species, !s.isEmpty {
      if let stage = flow.lifecycleStage, !stage.isEmpty {
        return "\(s) (\(stage))"
      }
      return s
    }
    return "-"
  }

  private var sexString: String {
    chatVM.researcherFlow?.sex ?? "-"
  }

  private var lengthString: String {
    if let l = chatVM.researcherFlow?.lengthInches {
      return l.rounded() == l ? "\(Int(l)) inches" : String(format: "%.1f inches", l)
    }
    return "-"
  }

  private var girthString: String {
    if let g = chatVM.researcherFlow?.girthInches {
      let prefix = chatVM.researcherFlow?.girthIsEstimated == true ? "~" : ""
      return "\(prefix)\(String(format: "%.1f inches", g))"
    }
    return "-"
  }

  private var weightString: String {
    if let w = chatVM.researcherFlow?.weightLbs {
      return "~\(String(format: "%.1f lbs", w))"
    }
    return "-"
  }

  private var floyTagString: String {
    chatVM.researcherFlow?.floyTagNumber ?? "None"
  }

  private var barcodeString: String {
    chatVM.researcherFlow?.scaleSampleBarcode ?? "None"
  }

  private var voiceMemoString: String {
    chatVM.attachedVoiceNotes.isEmpty ? "None" : "Attached"
  }

  // MARK: - Row helper

  private func row(label: String, value: String) -> some View {
    HStack(alignment: .top) {
      Text(label)
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.gray)
        .frame(width: 120, alignment: .leading)
      Text(value)
        .font(.subheadline)
        .foregroundColor(.white)
      Spacer()
    }
    .padding(.vertical, 4)
  }
}
