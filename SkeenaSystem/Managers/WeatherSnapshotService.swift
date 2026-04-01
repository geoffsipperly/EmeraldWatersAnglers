// Bend Fly Shop

import Foundation

// MARK: - Response DTOs

struct WeatherSnapshotResponse: Decodable {
  let current: WeatherCurrentDTO
  let hourlyForecast: [WeatherHourlyDTO]
}

struct WeatherCurrentDTO: Decodable {
  let temperature: Double
  let weatherCode: Int
  let windSpeed: Double
  let windDirection: Int
  let pressure: Double
}

struct WeatherHourlyDTO: Decodable {
  let time: String
  let temperature: Double
  let weatherCode: Int
  let precipitationProbability: Int
  let pressure: Double
}

// MARK: - Pressure trend

enum WeatherPressureTrend {
  case rising, falling, steady

  var sfSymbol: String {
    switch self {
    case .rising:  return "arrow.up.right"
    case .falling: return "arrow.down.right"
    case .steady:  return "equal"
    }
  }
}

// MARK: - Service

enum WeatherSnapshotService {

  static func fetch(lat: Double, lon: Double) async throws -> WeatherSnapshotResponse {
    let base = AppEnvironment.shared.projectURL
    guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
      throw URLError(.badURL)
    }
    let existingPath = comps.path == "/" ? "" : comps.path
    comps.path = existingPath + "/functions/v1/weather-snapshot"
    comps.queryItems = nil
    guard let url = comps.url else { throw URLError(.badURL) }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue(AppEnvironment.shared.anonKey, forHTTPHeaderField: "apikey")

    if let token = await AuthService.shared.currentAccessToken(), !token.isEmpty {
      req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let body: [String: Double] = ["latitude": lat, "longitude": lon]
    req.httpBody = try JSONEncoder().encode(body)

    let (data, resp) = try await URLSession.shared.data(for: req)
    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
    guard (200..<300).contains(code) else {
      AppLogging.log("[Weather] HTTP \(code)", level: .error, category: .network)
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(WeatherSnapshotResponse.self, from: data)
  }

  // MARK: - Display helpers

  static func conditionText(for code: Int) -> String {
    switch code {
    case 0:       return "Clear"
    case 1:       return "Mainly Clear"
    case 2:       return "Partly Cloudy"
    case 3:       return "Overcast"
    case 45, 48:  return "Foggy"
    case 51...55: return "Drizzle"
    case 61...65: return "Rain"
    case 71...75: return "Snow"
    case 80...82: return "Showers"
    case 95:      return "Thunderstorm"
    default:      return "Mixed"
    }
  }

  static func conditionIcon(for code: Int) -> String {
    switch code {
    case 0, 1:    return "sun.max.fill"
    case 2:       return "cloud.sun.fill"
    case 3:       return "cloud.fill"
    case 45, 48:  return "cloud.fog.fill"
    case 51...55: return "cloud.drizzle.fill"
    case 61...65: return "cloud.rain.fill"
    case 71...75: return "cloud.snow.fill"
    case 80...82: return "cloud.heavyrain.fill"
    case 95:      return "cloud.bolt.fill"
    default:      return "cloud.fill"
    }
  }

  static func windCardinal(from degrees: Int) -> String {
    let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let idx = Int((Double(degrees) / 45.0).rounded()) % 8
    return dirs[idx]
  }

  /// Formats "2026-03-31T14:00" → "2 PM"
  static func hourLabel(from isoDateTime: String) -> String {
    let parts = isoDateTime.split(separator: "T")
    guard parts.count == 2 else { return isoDateTime }
    let timePart = String(parts[1].prefix(5)) // "14:00"
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    if let date = fmt.date(from: timePart) {
      let out = DateFormatter()
      out.dateFormat = "ha" // "2PM"
      return out.string(from: date).lowercased()
    }
    return timePart
  }

  /// Compares current pressure to 3 hours ahead in the forecast to determine trend.
  static func pressureTrend(current: Double, hourly: [WeatherHourlyDTO]) -> WeatherPressureTrend {
    guard hourly.count >= 3 else { return .steady }
    let diff = hourly[2].pressure - current
    if diff > 1.0  { return .rising }
    if diff < -1.0 { return .falling }
    return .steady
  }
}
