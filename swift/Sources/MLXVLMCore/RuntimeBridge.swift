import Foundation

public struct RuntimeBridge {
    public let aliases: ModelAliasStore
    public let runtime: any VLMRuntime

    public init(aliases: ModelAliasStore = ModelAliasStore(), runtime: any VLMRuntime = UnimplementedVLMRuntime()) {
        self.aliases = aliases
        self.runtime = runtime
    }

    public func makeRequest(model: String, prompt: String, base64Images: [String], maxTokens: Int, temperature: Double, topP: Double) -> RuntimeGenerateRequest {
        RuntimeGenerateRequest(
            modelSource: aliases.resolveSourceOrIdentity(model),
            prompt: prompt,
            base64Images: base64Images,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
    }

    public func generate(model: String, prompt: String, base64Images: [String] = [], maxTokens: Int = 128, temperature: Double = 0.0, topP: Double = 1.0) async throws -> RuntimeGenerateChunk {
        let request = makeRequest(
            model: model,
            prompt: prompt,
            base64Images: base64Images,
            maxTokens: maxTokens,
            temperature: temperature,
            topP: topP
        )
        return try await runtime.generate(request)
    }
}
