import XCTest
@testable import MLXVLMServer

final class ServerShellTests: XCTestCase {
    func testRouteManifestIncludesOllamaAndOpenAICompatibilityRoutes() {
        let routeKeys = Set(ServerShell.routes.map { "\($0.method) \($0.path)" })

        XCTAssertTrue(routeKeys.contains("POST /api/generate"))
        XCTAssertTrue(routeKeys.contains("POST /api/chat"))
        XCTAssertTrue(routeKeys.contains("GET /api/tags"))
        XCTAssertTrue(routeKeys.contains("GET /api/version"))
        XCTAssertTrue(routeKeys.contains("POST /v1/chat/completions"))
        XCTAssertTrue(routeKeys.contains("GET /v1/models"))
        XCTAssertTrue(routeKeys.contains("GET /"))
    }
}
