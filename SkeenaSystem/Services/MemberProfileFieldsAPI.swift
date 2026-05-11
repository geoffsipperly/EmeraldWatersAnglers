// Bend Fly Shop
// MemberProfileFieldsAPI.swift
//
// Shared URL composition for the member-profile-fields edge function.
// Used by GearChecklist, AnglerAboutYou (proficiency), and ManagePreferencesView.
//
// URL composition:
//   API_BASE_URL + MEMBER_PROFILE_FIELDS_URL (both from Info.plist)

import Foundation

enum MemberProfileFieldsAPI {
  private static let rawBaseURLString: String = {
    (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }()

  private static let baseURLString: String = {
    var s = rawBaseURLString
    if !s.isEmpty, URL(string: s)?.scheme == nil {
      s = "https://" + s
    }
    return s
  }()

  private static let fieldsPath: String = {
    (Bundle.main.object(forInfoDictionaryKey: "MEMBER_PROFILE_FIELDS_URL") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    ?? "/functions/v1/member-profile-fields"
  }()

  /// GET URL with community_id and category query params.
  static func url(communityId: String, category: String) throws -> URL {
    guard let base = URL(string: baseURLString),
          let scheme = base.scheme,
          let host = base.host
    else { throw URLError(.badURL) }

    var comps = URLComponents()
    comps.scheme = scheme
    comps.host = host
    comps.port = base.port

    let basePath = base.path
    let normalizedBasePath =
      basePath == "/" ? "" : (basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath)
    let normalizedPath = fieldsPath.hasPrefix("/") ? fieldsPath : "/" + fieldsPath
    comps.path = normalizedBasePath + normalizedPath

    comps.queryItems = [
      URLQueryItem(name: "community_id", value: communityId),
      URLQueryItem(name: "category", value: category)
    ]

    guard let url = comps.url else { throw URLError(.badURL) }
    return url
  }

  /// POST URL (no query params).
  static func postURL() throws -> URL {
    guard let base = URL(string: baseURLString),
          let scheme = base.scheme,
          let host = base.host
    else { throw URLError(.badURL) }

    var comps = URLComponents()
    comps.scheme = scheme
    comps.host = host
    comps.port = base.port

    let basePath = base.path
    let normalizedBasePath =
      basePath == "/" ? "" : (basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath)
    let normalizedPath = fieldsPath.hasPrefix("/") ? fieldsPath : "/" + fieldsPath
    comps.path = normalizedBasePath + normalizedPath

    guard let url = comps.url else { throw URLError(.badURL) }
    return url
  }

  /// Encode a preference value for the POST payload.
  /// - When the field has `options.has_details = true`, returns a JSON-stringified
  ///   `{"checked": Bool, "details": String|null}` (sorted keys for deterministic output).
  /// - Otherwise returns a plain `"true"` / `"false"` string.
  /// The backend stores `value` verbatim, so all formatting must happen here.
  static func encodePreferenceValue(checked: Bool, details: String?, hasDetails: Bool) -> String {
    guard hasDetails else { return checked ? "true" : "false" }

    let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let detailsValue: Any = trimmed.isEmpty ? NSNull() : trimmed
    let obj: [String: Any] = ["checked": checked, "details": detailsValue]

    if let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
       let str = String(data: data, encoding: .utf8) {
      return str
    }
    return checked ? "true" : "false"
  }

  /// Decode a preference value from the GET response. Tries (in order):
  ///   1. JSON object `{"checked": Bool, "details": String?}` — the current contract.
  ///   2. Legacy pipe format `"true|details"` — for in-flight data written before the JSON fix.
  ///   3. Bare `"true"` / `"false"` — for fields where `has_details` is false.
  static func decodePreferenceValue(_ raw: String?) -> (checked: Bool, details: String) {
    guard let raw = raw, !raw.isEmpty else { return (false, "") }

    if let data = raw.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let checked = obj["checked"] as? Bool {
      let details = obj["details"] as? String ?? ""
      return (checked, details)
    }

    if raw.contains("|") {
      let parts = raw.split(separator: "|", maxSplits: 1)
      let checked = (parts.first.map(String.init) ?? "") == "true"
      let details = parts.dropFirst().first.map(String.init) ?? ""
      return (checked, details)
    }

    return (raw == "true", "")
  }
}
