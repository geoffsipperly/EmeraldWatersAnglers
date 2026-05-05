// Bend Fly Shop

import SwiftUI

/// SwiftUI callout displayed via MapViewAnnotation when a guide catch pin is tapped.
/// Shows species, lifecycle stage, length, angler number, and date — matching the
/// previous MapKit callout content from the TerrainMapView coordinator.
struct CatchReportCalloutView: View {
  let title: String
  let lifecycleStage: String?
  let lengthInches: Int
  let memberId: String
  let createdAt: Date
  let onDismiss: () -> Void

  private static let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Species: \(title)")
        .font(.brandSubheadline.weight(.semibold))
        .foregroundColor(.primary)

      Text("Lifecycle: \(lifecycleStage ?? "—")")
        .font(.brandCaption)
        .foregroundColor(.primary)

      Text("Length: \(lengthInches > 0 ? "\(lengthInches)\"" : "—")")
        .font(.brandCaption)
        .foregroundColor(.primary)

      Text("Member Number: \(memberId)")
        .font(.brandCaption)
        .foregroundColor(.primary)

      Text(Self.dateFormatter.string(from: createdAt))
        .font(.brandCaption)
        .foregroundColor(.secondary)
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.regularMaterial)
        .shadow(radius: 4)
    )
    .onTapGesture { onDismiss() }
  }
}
