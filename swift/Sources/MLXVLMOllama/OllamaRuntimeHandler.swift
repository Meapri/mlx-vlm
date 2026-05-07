import Foundation
import MLXVLMCore

public struct OllamaRuntimeHandler: Sendable {
    public typealias Clock = @Sendable () -> String

    private let runtime: any VLMRuntime
    private let aliases: ModelAliasStore
    private let now: Clock

    public init(
        runtime: any VLMRuntime,
        aliases: ModelAliasStore = ModelAliasStore(),
        now: @escaping Clock = OllamaRuntimeHandler.iso8601Now
    ) {
        self.runtime = runtime
        self.aliases = aliases
        self.now = now
    }

    public func generate(_ request: OllamaGenerateRequest) async throws -> OllamaGenerateResponse {
        let runtimeRequest = makeRuntimeRequest(from: request)
        let chunk = try await runtime.generate(runtimeRequest)
        return OllamaGenerateResponse(
            model: request.model,
            createdAt: now(),
            response: chunk.text,
            done: chunk.done,
            doneReason: chunk.finishReason
        )
    }

    public func generateStream(_ request: OllamaGenerateRequest) -> AsyncThrowingStream<OllamaGenerateResponse, Error> {
        let runtimeRequest = makeRuntimeRequest(from: request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in runtime.stream(runtimeRequest) {
                        continuation.yield(OllamaGenerateResponse(
                            model: request.model,
                            createdAt: now(),
                            response: chunk.text,
                            done: chunk.done,
                            doneReason: chunk.finishReason
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func chat(_ request: OllamaChatRequest) async throws -> OllamaChatResponse {
        let runtimeRequest = makeRuntimeRequest(from: request)
        let chunk = try await runtime.generate(runtimeRequest)
        return OllamaChatResponse(
            model: request.model,
            createdAt: now(),
            message: OllamaMessage(role: "assistant", content: chunk.text),
            done: chunk.done,
            doneReason: chunk.finishReason
        )
    }

    public func chatStream(_ request: OllamaChatRequest) -> AsyncThrowingStream<OllamaChatResponse, Error> {
        let runtimeRequest = makeRuntimeRequest(from: request)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in runtime.stream(runtimeRequest) {
                        continuation.yield(OllamaChatResponse(
                            model: request.model,
                            createdAt: now(),
                            message: OllamaMessage(role: "assistant", content: chunk.text),
                            done: chunk.done,
                            doneReason: chunk.finishReason
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func loadedModelSources() async -> [String] {
        guard let reporting = runtime as? any RuntimeStateReporting else {
            return []
        }
        return await reporting.loadedModelSources()
    }

    @discardableResult
    public func unloadModel(_ model: String) async -> Bool {
        guard let management = runtime as? any RuntimeModelManagement else {
            return false
        }
        return await management.unloadModelSource(aliases.resolveSourceOrIdentity(model))
    }

    public static func shouldUnload(_ keepAlive: String?) -> Bool {
        guard let value = keepAlive?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return value == "0" || value == "0s" || value == "0m" || value == "0h"
    }

    private func makeRuntimeRequest(from request: OllamaGenerateRequest) -> RuntimeGenerateRequest {
        RuntimeGenerateRequest(
            modelSource: aliases.resolveSourceOrIdentity(request.model),
            prompt: request.prompt,
            base64Images: request.images ?? [],
            maxTokens: request.options?.numPredict ?? 128,
            temperature: request.options?.temperature ?? 0.0,
            topP: request.options?.topP ?? 1.0
        )
    }

    private func makeRuntimeRequest(from request: OllamaChatRequest) -> RuntimeGenerateRequest {
        RuntimeGenerateRequest(
            modelSource: aliases.resolveSourceOrIdentity(request.model),
            prompt: OllamaAdapter.promptFromChat(request),
            base64Images: OllamaAdapter.imageInputsFromChat(request),
            maxTokens: request.options?.numPredict ?? 128,
            temperature: request.options?.temperature ?? 0.0,
            topP: request.options?.topP ?? 1.0
        )
    }

    public static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
