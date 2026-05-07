import Foundation
import MLXVLMCore
import MLXVLMCompat

public struct GenerateParameters: Equatable, Sendable {
    public let model: String
    public let prompt: String
    public let images: [String]
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double

    public init(model: String, prompt: String, images: [String] = [], maxTokens: Int = 128, temperature: Double = 0.0, topP: Double = 1.0) {
        self.model = model
        self.prompt = prompt
        self.images = images
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }
}

public enum OllamaAdapter {
    public static func generateParameters(from request: OllamaGenerateRequest, aliases: ModelAliasStore = ModelAliasStore()) -> GenerateParameters {
        GenerateParameters(
            model: aliases.resolveSourceOrIdentity(request.model),
            prompt: request.prompt,
            images: request.images ?? [],
            maxTokens: request.options?.numPredict ?? 128,
            temperature: request.options?.temperature ?? 0.0,
            topP: request.options?.topP ?? 1.0
        )
    }

    public static func promptFromChat(_ request: OllamaChatRequest) -> String {
        request.messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
    }

    public static func imageInputsFromChat(_ request: OllamaChatRequest) -> [String] {
        request.messages.flatMap { $0.images ?? [] }
    }

    public static func tagsResponse(from aliases: [ModelAlias], createdAt: String = "1970-01-01T00:00:00Z") -> OllamaTagsResponse {
        OllamaTagsResponse(models: aliases.map { alias in
            let family = alias.modelType ?? "unknown"
            return OllamaModelTag(
                name: alias.name,
                model: alias.name,
                modifiedAt: createdAt,
                size: 0,
                digest: alias.source,
                details: OllamaModelDetails(
                    parentModel: "",
                    format: "mlx",
                    family: family,
                    families: [family],
                    parameterSize: parameterSizeGuess(from: alias.name),
                    quantizationLevel: quantizationGuess(from: alias.source)
                )
            )
        })
    }

    private static func parameterSizeGuess(from name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("500m") { return "500M" }
        if lower.contains("2b") { return "2B" }
        if lower.contains("3b") { return "3B" }
        if lower.contains("4b") { return "4B" }
        if lower.contains("7b") { return "7B" }
        return "unknown"
    }

    private static func quantizationGuess(from source: String) -> String {
        let lower = source.lowercased()
        if lower.contains("4bit") || lower.contains("qat-4bit") { return "Q4" }
        if lower.contains("8bit") { return "Q8" }
        return "unknown"
    }
}
