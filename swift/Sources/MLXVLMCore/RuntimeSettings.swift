import Foundation

public struct RuntimeSettings: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int
    public var defaultModel: String?
    public var modelCacheDirectory: String?
    public var defaultMaxTokens: Int
    public var defaultTemperature: Double
    public var defaultTopP: Double
    public var keepModelLoaded: Bool
    public var ollamaAPIEnabled: Bool
    public var openAIAPIEnabled: Bool
    public var aliases: [ModelAlias]

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case defaultModel = "default_model"
        case modelCacheDirectory = "model_cache_directory"
        case defaultMaxTokens = "default_max_tokens"
        case defaultTemperature = "default_temperature"
        case defaultTopP = "default_top_p"
        case keepModelLoaded = "keep_model_loaded"
        case ollamaAPIEnabled = "ollama_api_enabled"
        case openAIAPIEnabled = "open_ai_api_enabled"
        case aliases
    }

    public init(
        host: String = "127.0.0.1",
        port: Int = 11434,
        defaultModel: String? = nil,
        modelCacheDirectory: String? = nil,
        defaultMaxTokens: Int = 128,
        defaultTemperature: Double = 0.0,
        defaultTopP: Double = 1.0,
        keepModelLoaded: Bool = true,
        ollamaAPIEnabled: Bool = true,
        openAIAPIEnabled: Bool = false,
        aliases: [ModelAlias] = ModelAliasStore().aliases
    ) {
        self.host = host
        self.port = port
        self.defaultModel = defaultModel
        self.modelCacheDirectory = modelCacheDirectory
        self.defaultMaxTokens = defaultMaxTokens
        self.defaultTemperature = defaultTemperature
        self.defaultTopP = defaultTopP
        self.keepModelLoaded = keepModelLoaded
        self.ollamaAPIEnabled = ollamaAPIEnabled
        self.openAIAPIEnabled = openAIAPIEnabled
        self.aliases = aliases
    }

    public static let `default` = RuntimeSettings()
}

public extension JSONEncoder {
    static var settings: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

public extension JSONDecoder {
    static var settings: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
