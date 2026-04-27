import XCTest
@testable import SkeenaSystem

/// Smoke tests: Supabase backend reachability and auth API health.
///
/// These tests hit the live Supabase project configured for the current build
/// (DevTEST scheme → koyegehcwcrvxpfthkxq.supabase.co).
///
/// Endpoints used:
///   GET /auth/v1/health   — GoTrue health; accepts anon key, returns version JSON
///   GET /auth/v1/settings — auth config; accepts anon key only (no Authorization header needed)
///
/// Note: GET /rest/v1/ requires the service_role key (not anon) on this project,
/// so the auth/v1 routes are used as the health proxy instead.
///
/// Run with:
///   xcodebuild test -workspace SkeenaSystem.xcworkspace \
///     -scheme SkeenaSystem -destination 'platform=iOS Simulator,...' \
///     -only-testing:SkeenaSystemTests/BackendHealthSmokeTests
final class BackendHealthSmokeTests: XCTestCase {

    private let projectURL = AppEnvironment.shared.projectURL
    private let anonKey = AppEnvironment.shared.anonKey
    private let timeout: TimeInterval = 15

    // MARK: - Helpers

    private func authURL(_ path: String) -> URL {
        projectURL.appendingPathComponent("auth/v1/\(path)")
    }

    // MARK: - Tests

    /// GoTrue health endpoint returns HTTP 200.
    ///
    /// Endpoint: GET /auth/v1/health
    /// Returns GoTrue version JSON — a reliable "backend is up" signal.
    func testSupabaseHealthReturns200() async throws {
        var request = URLRequest(url: authURL("health"), timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse, "Response should be HTTPURLResponse")
        XCTAssertEqual(http.statusCode, 200, "GoTrue health endpoint should return 200")
    }

    /// GoTrue health response contains expected version fields.
    ///
    /// Verifies not just reachability but that the response body is a coherent
    /// GoTrue JSON envelope (name, version, description keys).
    func testSupabaseHealthReturnsValidJSON() async throws {
        var request = URLRequest(url: authURL("health"), timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200, "GoTrue health endpoint should return 200")

        let json = try XCTUnwrap(
            try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Health response should be a JSON object"
        )
        XCTAssertNotNil(json["name"], "Health response should contain a 'name' key")
        XCTAssertNotNil(json["version"], "Health response should contain a 'version' key")
    }

    /// Auth settings endpoint accepts the anon key and returns configuration JSON.
    ///
    /// GET /auth/v1/settings returns the project's auth provider config.
    /// A 200 here confirms the anon key is valid and the auth pipeline is healthy.
    func testAuthenticatedSettingsCallSucceeds() async throws {
        var request = URLRequest(url: authURL("settings"), timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200, "Auth settings should return 200 (anon key is valid)")

        let json = try XCTUnwrap(
            try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Settings response should be a JSON object"
        )
        // Must contain the external providers map — presence confirms schema integrity
        XCTAssertNotNil(json["external"], "Settings response should contain an 'external' key")
    }
}
