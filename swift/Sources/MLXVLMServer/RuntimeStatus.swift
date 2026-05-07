import Foundation

public struct RuntimeStatus: Codable, Equatable, Sendable {
    public let version: String
    public let configPath: String
    public let serverRunning: Bool
    public let ollamaAPIEnabled: Bool
    public let openAIAPIEnabled: Bool
    public let loadedModels: [String]

    enum CodingKeys: String, CodingKey {
        case version
        case configPath = "config_path"
        case serverRunning = "server_running"
        case ollamaAPIEnabled = "ollama_api_enabled"
        case openAIAPIEnabled = "open_ai_api_enabled"
        case loadedModels = "loaded_models"
    }

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
