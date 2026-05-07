import Foundation

public extension JSONEncoder {
    static var openAI: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

public extension JSONDecoder {
    static var openAI: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

public struct OpenAIModelsResponse: Codable, Equatable, Sendable {
    public let object: String
    public let data: [OpenAIModel]

    public init(object: String = "list", data: [OpenAIModel]) {
        self.object = object
        self.data = data
    }
}

public struct OpenAIModel: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String

    public init(id: String, object: String = "model", created: Int = 0, ownedBy: String = "mlx-vlm") {
        self.id = id
        self.object = object
        self.created = created
        self.ownedBy = ownedBy
    }
}

public struct OpenAIChatCompletionRequest: Codable, Equatable, Sendable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let stream: Bool?
    public let maxTokens: Int?
    public let temperature: Double?
    public let topP: Double?

    public init(model: String, messages: [OpenAIChatMessage], stream: Bool? = nil, maxTokens: Int? = nil, temperature: Double? = nil, topP: Double? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
}

public struct OpenAIChatMessage: Codable, Equatable, Sendable {
    public let role: String
    public let content: OpenAIMessageContent

    public init(role: String, content: OpenAIMessageContent) {
        self.role = role
        self.content = content
    }

    public init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }
}

public enum OpenAIMessageContent: Codable, Equatable, Sendable {
    case text(String)
    case parts([OpenAIContentPart])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
            return
        }
        self = .parts(try container.decode([OpenAIContentPart].self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

public struct OpenAIContentPart: Codable, Equatable, Sendable {
    public let type: String
    public let text: String?
    public let imageUrl: OpenAIImageURL?

    public init(type: String, text: String? = nil, imageUrl: OpenAIImageURL? = nil) {
        self.type = type
        self.text = text
        self.imageUrl = imageUrl
    }
}

public struct OpenAIImageURL: Codable, Equatable, Sendable {
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

public struct OpenAIChatCompletionResponse: Codable, Equatable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatChoice]
    public let usage: OpenAIUsage?

    public init(id: String, object: String = "chat.completion", created: Int, model: String, choices: [OpenAIChatChoice], usage: OpenAIUsage? = nil) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
        self.usage = usage
    }
}

public struct OpenAIChatChoice: Codable, Equatable, Sendable {
    public let index: Int
    public let message: OpenAIChatMessage?
    public let delta: OpenAIChatDelta?
    public let finishReason: String?

    public init(index: Int, message: OpenAIChatMessage? = nil, delta: OpenAIChatDelta? = nil, finishReason: String? = nil) {
        self.index = index
        self.message = message
        self.delta = delta
        self.finishReason = finishReason
    }
}

public struct OpenAIChatDelta: Codable, Equatable, Sendable {
    public let role: String?
    public let content: String?

    public init(role: String? = nil, content: String? = nil) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIUsage: Codable, Equatable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int

    public init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
