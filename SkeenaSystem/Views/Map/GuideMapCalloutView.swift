// Bend Fly Shop

import SwiftUI

/// Callout shown when a catch pin is tapped on the guide landing map.
/// Displays species, length, and date. Tapping anywhere dismisses it.
struct GuideMapCalloutView: View {
  let species: String?
  let lengthInches: Int?
  let date: Date
  let onDismiss: () -> Void

  private static let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    return df
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let species, !species.isEmpty {
        Text(species)
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.primary)
      }
      if let length = lengthInches {
        Text("\(length)″")
          .font(.caption.weight(.medium))
          .foregroundColor(.secondary)
      }
      Text(Self.dateFormatter.string(from: date))
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(.regularMaterial)
        .shadow(radius: 4)
    )
    .onTapGesture { onDismiss() }
  }
}
