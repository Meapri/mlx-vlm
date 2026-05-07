import XCTest
import Foundation
@testable import MLXVLMCore
@testable import MLXVLMServer

final class SettingsHTTPRouterTests: XCTestCase {
    func testSettingsRouteLoadsPersistedSettings() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(configDirectory: directory)
        var settings = RuntimeSettings.default
        settings.host = "0.0.0.0"
        settings.port = 12000
        settings.defaultModel = "qwen2.5-vl:3b"
        try store.save(settings)

        let router = OllamaHTTPRouter(settingsStore: store)
        let response = try await router.handle(HTTPRequest(method: "GET", path: "/mlx-vlm/settings", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.settings.decode(RuntimeSettings.self, from: response.body)
        XCTAssertEqual(decoded, settings)
    }

    func testSettingsRoutePersistsUpdatedSettings() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(configDirectory: directory)
        var settings = RuntimeSettings.default
        settings.defaultModel = "local-model"
        settings.defaultMaxTokens = 512
        let body = try JSONEncoder.settings.encode(settings)

        let router = OllamaHTTPRouter(settingsStore: store)
        let response = try await router.handle(HTTPRequest(method: "PUT", path: "/mlx-vlm/settings", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.settings.decode(RuntimeSettings.self, from: response.body)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(try store.load(), settings)
    }

    func testStatusRouteReportsServerAndConfigState() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(configDirectory: directory)
        let router = OllamaHTTPRouter(settingsStore: store, version: "test-version")

        let response = try await router.handle(HTTPRequest(method: "GET", path: "/mlx-vlm/status", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.settings.decode(RuntimeStatus.self, from: response.body)
        XCTAssertEqual(decoded.version, "test-version")
        XCTAssertEqual(decoded.configPath, store.configURL.path)
        XCTAssertTrue(decoded.ollamaAPIEnabled)
        XCTAssertFalse(decoded.openAIAPIEnabled)
    }
}
