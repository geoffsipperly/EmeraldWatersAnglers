import XCTest
@testable import SkeenaSystem

/// Smoke tests: Supabase backend reachability and REST API health.
///
/// These tests hit the live Supabase project configured for the current build
/// (DevTEST scheme → koyegehcwcrvxpfthkxq.supabase.co).
/// They are intentionally fast and narrow: a 200 from the health endpoint
/// and a valid JSON envelope from the REST root are sufficient signals.
///
/// Run with:
///   xcodebuild test -workspace SkeenaSystem.xcworkspace \
///     -scheme SkeenaSystem -destination 'platform=iOS Simulator,...' \
///     -only-testing:SkeenaSystemTests/BackendHealthSmokeTests
final class BackendHealthSmokeTests: XCTestCase {

    private let projectURL = AppEnvironment.shared.projectURL
    private let anonKey = AppEnvironment.shared.anonKey
    private let timeout: TimeInterval = 15

    // MARK: - Tests

    /// Supabase health endpoint returns HTTP 200.
    ///
    /// Endpoint: GET https://<project>.supabase.co/rest/v1/
    /// This route is available to anonymous callers with a valid anon key and
    /// returns the PostgREST OpenAPI schema — a reliable proxy for "the project is up".
    func testSupabaseRestApiReturns200() async throws {
        let url = projectURL.appendingPathComponent("rest/v1/")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse, "Response should be an HTTPURLResponse")
        XCTAssertEqual(http.statusCode, 200, "Supabase REST root should return 200 (project is up and key is valid)")
    }

    /// The REST root endpoint returns a valid JSON body with an OpenAPI structure.
    ///
    /// This verifies not just reachability but that the response schema is intact —
    /// a minimal sanity check that PostgREST is serving a coherent response.
    func testSupabaseRestApiReturnsValidJSON() async throws {
        let url = projectURL.appendingPathComponent("rest/v1/")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)

        // The response should be parseable JSON
        let json = try XCTUnwrap(
            try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            "REST root response body should be a JSON object"
        )

        // PostgREST OpenAPI envelope always includes a "paths" key
        XCTAssertNotNil(json["paths"], "REST root response should contain a 'paths' key (OpenAPI envelope)")
    }

    /// An authenticated REST call using the anon key succeeds without a 4xx error.
    ///
    /// We query the PostgREST root with the Accept header for OpenAPI JSON — a
    /// read-only introspection call that requires no row-level security policy
    /// and exercises the full auth pipeline (key validation, JWT parsing).
    func testAuthenticatedAPICallSucceeds() async throws {
        let url = projectURL.appendingPathComponent("rest/v1/")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/openapi+json", forHTTPHeaderField: "Accept")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertFalse(
            (400...499).contains(http.statusCode),
            "Authenticated REST call should not return a 4xx error (got \(http.statusCode)); check the anon key is valid"
        )
        XCTAssertFalse(
            (500...599).contains(http.statusCode),
            "Authenticated REST call should not return a 5xx error (got \(http.statusCode)); Supabase may be down"
        )
    }
}
