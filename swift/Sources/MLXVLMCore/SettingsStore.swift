import Foundation

public struct SettingsStore: Sendable {
    public let configDirectory: URL
    public let configURL: URL

    public init(configDirectory: URL? = nil) {
        let directory = configDirectory ?? SettingsStore.defaultConfigDirectory()
        self.configDirectory = directory
        self.configURL = directory.appendingPathComponent("config.json")
    }

    public func load() throws -> RuntimeSettings {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder.settings.decode(RuntimeSettings.self, from: data)
    }

    @discardableResult
    public func loadOrCreateDefault() throws -> RuntimeSettings {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try load()
        }

        let settings = RuntimeSettings.default
        try save(settings)
        return settings
    }

    public func save(_ settings: RuntimeSettings) throws {
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.settings.encode(settings)
        try data.write(to: configURL, options: [.atomic])
    }

    private static func defaultConfigDirectory() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #if os(macOS)
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("MLXVLMSwift", isDirectory: true)
        #else
        return home
            .appendingPathComponent(".mlx-vlm-swift", isDirectory: true)
        #endif
    }
}
