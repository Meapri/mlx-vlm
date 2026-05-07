import Foundation

public extension JSONEncoder {
    static var ollama: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

public extension JSONDecoder {
    static var ollama: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

public struct OllamaOptions: Codable, Equatable, Sendable {
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let numPredict: Int?
    public let seed: Int?

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case numPredict = "num_predict"
        case seed
    }

    public init(temperature: Double? = nil, topP: Double? = nil, topK: Int? = nil, numPredict: Int? = nil, seed: Int? = nil) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.numPredict = numPredict
        self.seed = seed
    }
}

public struct OllamaGenerateRequest: Codable, Equatable, Sendable {
    public let model: String
    public let prompt: String
    public let suffix: String?
    public let images: [String]?
    public let stream: Bool?
    public let raw: Bool?
    public let format: String?
    public let options: OllamaOptions?
    public let keepAlive: String?

    public init(model: String, prompt: String, suffix: String? = nil, images: [String]? = nil, stream: Bool? = nil, raw: Bool? = nil, format: String? = nil, options: OllamaOptions? = nil, keepAlive: String? = nil) {
        self.model = model
        self.prompt = prompt
        self.suffix = suffix
        self.images = images
        self.stream = stream
        self.raw = raw
        self.format = format
        self.options = options
        self.keepAlive = keepAlive
    }
}

public struct OllamaMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: String
    public let images: [String]?

    public init(role: String, content: String, images: [String]? = nil) {
        self.role = role
        self.content = content
        self.images = images
    }
}

public struct OllamaChatRequest: Codable, Equatable, Sendable {
    public let model: String
    public let messages: [OllamaMessage]
    public let tools: [String: String]?
    public let stream: Bool?
    public let format: String?
    public let options: OllamaOptions?
    public let keepAlive: String?

    public init(model: String, messages: [OllamaMessage], tools: [String: String]? = nil, stream: Bool? = nil, format: String? = nil, options: OllamaOptions? = nil, keepAlive: String? = nil) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.stream = stream
        self.format = format
        self.options = options
        self.keepAlive = keepAlive
    }
}

public struct OllamaGenerateResponse: Codable, Equatable, Sendable {
    public let model: String
    public let createdAt: String
    public let response: String
    public let done: Bool
    public let doneReason: String?
    public let totalDuration: Int?
    public let loadDuration: Int?
    public let promptEvalCount: Int?
    public let promptEvalDuration: Int?
    public let evalCount: Int?
    public let evalDuration: Int?

    public init(model: String, createdAt: String, response: String, done: Bool, doneReason: String? = nil, totalDuration: Int? = nil, loadDuration: Int? = nil, promptEvalCount: Int? = nil, promptEvalDuration: Int? = nil, evalCount: Int? = nil, evalDuration: Int? = nil) {
        self.model = model
        self.createdAt = createdAt
        self.response = response
        self.done = done
        self.doneReason = doneReason
        self.totalDuration = totalDuration
        self.loadDuration = loadDuration
        self.promptEvalCount = promptEvalCount
        self.promptEvalDuration = promptEvalDuration
        self.evalCount = evalCount
        self.evalDuration = evalDuration
    }
}

public struct OllamaChatResponse: Codable, Equatable, Sendable {
    public let model: String
    public let createdAt: String
    public let message: OllamaMessage
    public let done: Bool
    public let doneReason: String?

    public init(model: String, createdAt: String, message: OllamaMessage, done: Bool, doneReason: String? = nil) {
        self.model = model
        self.createdAt = createdAt
        self.message = message
        self.done = done
        self.doneReason = doneReason
    }
}

public struct OllamaTagsResponse: Codable, Equatable, Sendable {
    public let models: [OllamaModelTag]

    public init(models: [OllamaModelTag]) {
        self.models = models
    }
}

public struct OllamaModelTag: Codable, Equatable, Sendable {
    public let name: String
    public let model: String
    public let modifiedAt: String
    public let size: Int
    public let digest: String
    public let details: OllamaModelDetails
    public let expiresAt: String?

    public init(name: String, model: String, modifiedAt: String, size: Int, digest: String, details: OllamaModelDetails, expiresAt: String? = nil) {
        self.name = name
        self.model = model
        self.modifiedAt = modifiedAt
        self.size = size
        self.digest = digest
        self.details = details
        self.expiresAt = expiresAt
    }
}

public struct OllamaModelDetails: Codable, Equatable, Sendable {
    public let parentModel: String
    public let format: String
    public let family: String
    public let families: [String]
    public let parameterSize: String
    public let quantizationLevel: String

    public init(parentModel: String = "", format: String = "mlx", family: String, families: [String], parameterSize: String = "unknown", quantizationLevel: String = "unknown") {
        self.parentModel = parentModel
        self.format = format
        self.family = family
        self.families = families
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
    }
}

public struct OllamaShowRequest: Codable, Equatable, Sendable {
    public let model: String
}

public struct OllamaVersionResponse: Codable, Equatable, Sendable {
    public let version: String

    public init(version: String) {
        self.version = version
    }
}

public struct OllamaRunningModelsResponse: Codable, Equatable, Sendable {
    public let models: [OllamaModelTag]

    public init(models: [OllamaModelTag]) {
        self.models = models
    }
}
