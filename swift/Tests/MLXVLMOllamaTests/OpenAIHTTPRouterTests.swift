import XCTest
import Foundation
@testable import MLXVLMCore
@testable import MLXVLMOllama
@testable import MLXVLMServer

private struct OpenAIEchoRuntime: VLMRuntime {
    func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        RuntimeGenerateChunk(text: "echo:\(request.modelSource):\(request.prompt):\(request.base64Images.count):\(request.maxTokens)", done: true, finishReason: "stop")
    }

    func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(RuntimeGenerateChunk(text: "hello", done: false))
            continuation.yield(RuntimeGenerateChunk(text: " world", done: false))
            continuation.yield(RuntimeGenerateChunk(text: "", done: true, finishReason: "stop"))
            continuation.finish()
        }
    }
}

private actor OpenAIChunkCollector {
    private var chunks: [String] = []

    func append(_ data: Data) {
        chunks.append(String(decoding: data, as: UTF8.self))
    }

    func joined() -> String {
        chunks.joined()
    }
}

final class OpenAIHTTPRouterTests: XCTestCase {
    func testOpenAIModelsRouteListsAliases() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2-vl:2b", source: "mlx-community/Qwen2-VL-2B-Instruct-4bit", modelType: "qwen2_vl")
        ])
        let router = OllamaHTTPRouter(aliases: aliases)

        let response = try await router.handle(HTTPRequest(method: "GET", path: "/v1/models", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.openAI.decode(OpenAIModelsResponse.self, from: response.body)
        XCTAssertEqual(decoded.object, "list")
        XCTAssertEqual(decoded.data.map(\.id), ["qwen2-vl:2b"])
        XCTAssertEqual(decoded.data.first?.ownedBy, "mlx-vlm")
    }

    func testOpenAIChatCompletionCallsRuntimeAndPreservesAlias() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2-vl:2b", source: "mlx-community/Qwen2-VL-2B-Instruct-4bit", modelType: "qwen2_vl")
        ])
        let handler = OllamaRuntimeHandler(runtime: OpenAIEchoRuntime(), aliases: aliases, now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler, aliases: aliases)
        let request = OpenAIChatCompletionRequest(
            model: "qwen2-vl:2b",
            messages: [OpenAIChatMessage(role: "user", content: "Describe")],
            stream: false,
            maxTokens: 16,
            temperature: 0,
            topP: 1
        )
        let body = try JSONEncoder.openAI.encode(request)

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/v1/chat/completions", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.openAI.decode(OpenAIChatCompletionResponse.self, from: response.body)
        XCTAssertEqual(decoded.object, "chat.completion")
        XCTAssertEqual(decoded.model, "qwen2-vl:2b")
        XCTAssertEqual(decoded.choices.first?.message?.role, "assistant")
        XCTAssertEqual(decoded.choices.first?.message?.content, .text("echo:mlx-community/Qwen2-VL-2B-Instruct-4bit:user: Describe:0:16"))
        XCTAssertEqual(decoded.choices.first?.finishReason, "stop")
    }

    func testOpenAIChatCompletionExtractsDataURIImagesFromContentParts() async throws {
        let handler = OllamaRuntimeHandler(runtime: OpenAIEchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler)
        let request = OpenAIChatCompletionRequest(
            model: "local",
            messages: [
                OpenAIChatMessage(role: "user", content: .parts([
                    OpenAIContentPart(type: "text", text: "What is this?"),
                    OpenAIContentPart(type: "image_url", imageUrl: OpenAIImageURL(url: "data:image/png;base64,ZmFrZQ=="))
                ]))
            ],
            stream: false,
            maxTokens: 8
        )
        let body = try JSONEncoder.openAI.encode(request)

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/v1/chat/completions", headers: [:], body: body))

        let decoded = try JSONDecoder.openAI.decode(OpenAIChatCompletionResponse.self, from: response.body)
        XCTAssertEqual(decoded.choices.first?.message?.content, .text("echo:local:user: What is this?:1:8"))
    }

    func testOpenAIChatCompletionStreamReturnsSSEBodyForRouterFallback() async throws {
        let handler = OllamaRuntimeHandler(runtime: OpenAIEchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler)
        let request = OpenAIChatCompletionRequest(model: "local", messages: [OpenAIChatMessage(role: "user", content: "Hi")], stream: true)
        let body = try JSONEncoder.openAI.encode(request)

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/v1/chat/completions", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headerValue("content-type"), "text/event-stream")
        let text = String(decoding: response.body, as: UTF8.self)
        XCTAssertTrue(text.contains("data: "))
        XCTAssertTrue(text.contains("hello"))
        XCTAssertTrue(text.contains("[DONE]"))
    }

    func testOpenAIChatCompletionSocketStreamWritesSSEChunks() async throws {
        let handler = OllamaRuntimeHandler(runtime: OpenAIEchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler)
        let request = OpenAIChatCompletionRequest(model: "local", messages: [OpenAIChatMessage(role: "user", content: "Hi")], stream: true)
        let body = try JSONEncoder.openAI.encode(request)
        let collector = OpenAIChunkCollector()

        let didStream = try await router.stream(HTTPRequest(method: "POST", path: "/v1/chat/completions", headers: [:], body: body)) { data in
            await collector.append(data)
        }

        XCTAssertTrue(didStream)
        let joined = await collector.joined()
        XCTAssertTrue(joined.contains("data: "))
        XCTAssertTrue(joined.contains("hello"))
        XCTAssertTrue(joined.contains(" world"))
        XCTAssertTrue(joined.contains("data: [DONE]"))
    }
}
