// Bend Fly Shop

import SwiftUI

struct Toast: View {
  let message: String
  var body: some View {
    Text(message)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(Color.brandScrim.opacity(0.85))
      .foregroundColor(.brandTextPrimary)
      .cornerRadius(12)
      .shadow(radius: 4)
  }
}
