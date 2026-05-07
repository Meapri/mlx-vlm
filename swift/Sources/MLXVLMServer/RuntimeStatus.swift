import Foundation

public struct RuntimeStatus: Codable, Equatable, Sendable {
    public let version: String
    public let configPath: String
    public let serverRunning: Bool
    public let ollamaAPIEnabled: Bool
    public let openAIAPIEnabled: Bool
    public let loadedModels: [String]

    public init(
        version: String,
        configPath: String,
        serverRunning: Bool,
        ollamaAPIEnabled: Bool,
        openAIAPIEnabled: Bool,
        loadedModels: [String] = []
    ) {
        self.version = version
        self.configPath = configPath
        self.serverRunning = serverRunning
        self.ollamaAPIEnabled = ollamaAPIEnabled
        self.openAIAPIEnabled = openAIAPIEnabled
        self.loadedModels = loadedModels
    }
}
