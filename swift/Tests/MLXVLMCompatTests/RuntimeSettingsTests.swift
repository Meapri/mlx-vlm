import XCTest
@testable import MLXVLMCore

final class RuntimeSettingsTests: XCTestCase {
    func testDefaultSettingsPreserveOllamaCompatibleServerDefaults() {
        let settings = RuntimeSettings.default

        XCTAssertEqual(settings.host, "127.0.0.1")
        XCTAssertEqual(settings.port, 11434)
        XCTAssertEqual(settings.defaultMaxTokens, 128)
        XCTAssertEqual(settings.defaultTemperature, 0.0)
        XCTAssertEqual(settings.defaultTopP, 1.0)
        XCTAssertTrue(settings.ollamaAPIEnabled)
        XCTAssertFalse(settings.openAIAPIEnabled)
        XCTAssertTrue(settings.keepModelLoaded)
        XCTAssertEqual(settings.aliases.map(\.name), ModelAliasStore().aliases.map(\.name))
    }

    func testSettingsRoundTripThroughJSON() throws {
        var settings = RuntimeSettings.default
        settings.defaultModel = "qwen2.5-vl:3b"
        settings.modelCacheDirectory = "/tmp/models"
        settings.defaultMaxTokens = 256
        settings.defaultTemperature = 0.2

        let encoded = try JSONEncoder.settings.encode(settings)
        let decoded = try JSONDecoder.settings.decode(RuntimeSettings.self, from: encoded)

        XCTAssertEqual(decoded, settings)
    }

    func testSettingsStoreCreatesDefaultFileWhenMissing() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(configDirectory: directory)

        let loaded = try store.loadOrCreateDefault()

        XCTAssertEqual(loaded, RuntimeSettings.default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.configURL.path))
    }

    func testSettingsStorePersistsUpdates() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SettingsStore(configDirectory: directory)
        var settings = RuntimeSettings.default
        settings.host = "0.0.0.0"
        settings.port = 12000
        settings.defaultModel = "local"

        try store.save(settings)
        let loaded = try store.load()

        XCTAssertEqual(loaded, settings)
    }
}
