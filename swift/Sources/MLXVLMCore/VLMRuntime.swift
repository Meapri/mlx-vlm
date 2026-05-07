import Foundation

public struct RuntimeGenerateRequest: Equatable, Sendable {
    public let modelSource: String
    public let prompt: String
    public let base64Images: [String]
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double

    public init(modelSource: String, prompt: String, base64Images: [String] = [], maxTokens: Int = 128, temperature: Double = 0.0, topP: Double = 1.0) {
        self.modelSource = modelSource
        self.prompt = prompt
        self.base64Images = base64Images
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
}

public struct RuntimeGenerateChunk: Equatable, Sendable {
    public let text: String
    public let done: Bool
    public let finishReason: String?

    public init(text: String, done: Bool, finishReason: String? = nil) {
        self.text = text
        self.done = done
        self.finishReason = finishReason
    }
}

public protocol VLMRuntime: Sendable {
    func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk
    func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error>
}

public protocol RuntimeStateReporting: Sendable {
    func loadedModelSources() async -> [String]
}

public enum RuntimeBridgeError: LocalizedError, Equatable, Sendable {
    case runtimeNotConnected

    public var errorDescription: String? {
        switch self {
        case .runtimeNotConnected:
            return "Swift runtime bridge is defined, but MLX Swift / MLXVLM execution is not connected yet."
        }
    }
}

/// Placeholder runtime used by API adapters until the MLX Swift dependency is
/// wired. It keeps API/server code testable without pretending inference works.
public struct UnimplementedVLMRuntime: VLMRuntime {
    public init() {}

    public func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        throw RuntimeBridgeError.runtimeNotConnected
    }

    public func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: RuntimeBridgeError.runtimeNotConnected)
        }
    }
}
