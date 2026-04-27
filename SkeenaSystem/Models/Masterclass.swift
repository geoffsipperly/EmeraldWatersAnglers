// Masterclass.swift

import Foundation

/// A single masterclass video shipped with the app. Backed by
/// `Config/Masterclasses.json`. The `thumbnailAsset` field is optional —
/// when set, the view loads the matching image from Assets.xcassets;
/// when absent, the view renders a numbered placeholder card.
struct Masterclass: Identifiable, Hashable, Decodable {
  let id: Int
  let title: String
  let url: String
  let thumbnailAsset: String?
}

enum MasterclassCatalog {
  static let all: [Masterclass] = load()

  private static func load() -> [Masterclass] {
    guard let url = Bundle.main.url(forResource: "Masterclasses", withExtension: "json") else {
      AppLogging.log("Masterclasses.json missing from bundle", level: .error, category: .ui)
      return []
    }
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode([Masterclass].self, from: data)
    } catch {
      AppLogging.log("Failed to decode Masterclasses.json: \(error)", level: .error, category: .ui)
      return []
    }
  }
}
