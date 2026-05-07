import XCTest
@testable import MLXVLMCore
@testable import MLXVLMOllama

private struct EchoRuntime: VLMRuntime {
    func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        RuntimeGenerateChunk(
            text: "model=\(request.modelSource); prompt=\(request.prompt); images=\(request.base64Images.count); max=\(request.maxTokens)",
            done: true,
            finishReason: "stop"
        )
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

final class OllamaRuntimeHandlerTests: XCTestCase {
    func testGenerateHandlerResolvesAliasAndReturnsOllamaResponse() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), aliases: aliases, now: { "2026-05-07T00:00:00Z" })
        let request = OllamaGenerateRequest(
            model: "qwen2.5-vl:3b",
            prompt: "Describe",
            images: ["ZmFrZQ=="],
            stream: false,
            options: OllamaOptions(temperature: 0, topP: 1, numPredict: 64)
        )

        let response = try await handler.generate(request)

        XCTAssertEqual(response.model, "qwen2.5-vl:3b")
        XCTAssertEqual(response.createdAt, "2026-05-07T00:00:00Z")
        XCTAssertEqual(response.response, "model=mlx-community/Qwen2.5-VL-3B-Instruct-4bit; prompt=Describe; images=1; max=64")
        XCTAssertTrue(response.done)
        XCTAssertEqual(response.doneReason, "stop")
    }

    func testChatHandlerUsesChatPromptAndImages() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), aliases: aliases, now: { "2026-05-07T00:00:00Z" })
        let request = OllamaChatRequest(
            model: "qwen2.5-vl:3b",
            messages: [
                OllamaMessage(role: "system", content: "Be concise"),
                OllamaMessage(role: "user", content: "What is this?", images: ["a", "b"])
            ],
            options: OllamaOptions(numPredict: 32)
        )

        let response = try await handler.chat(request)

        XCTAssertEqual(response.model, "qwen2.5-vl:3b")
        XCTAssertEqual(response.message.role, "assistant")
        XCTAssertEqual(response.message.content, "model=mlx-community/Qwen2.5-VL-3B-Instruct-4bit; prompt=system: Be concise\nuser: What is this?; images=2; max=32")
        XCTAssertTrue(response.done)
        XCTAssertEqual(response.doneReason, "stop")
    }

    func testGenerateStreamMapsRuntimeChunksToOllamaResponses() async throws {
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let request = OllamaGenerateRequest(model: "local-model", prompt: "Hi", stream: true)

        var chunks: [OllamaGenerateResponse] = []
        for try await chunk in handler.generateStream(request) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.map(\.response), ["hello", " world", ""])
        XCTAssertEqual(chunks.map(\.done), [false, false, true])
        XCTAssertEqual(chunks.last?.doneReason, "stop")
    }

    func testChatStreamMapsRuntimeChunksToOllamaChatResponses() async throws {
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let request = OllamaChatRequest(model: "local-model", messages: [OllamaMessage(role: "user", content: "Hi")], stream: true)

        var chunks: [OllamaChatResponse] = []
        for try await chunk in handler.chatStream(request) {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks.map { $0.message.content }, ["hello", " world", ""])
        XCTAssertEqual(chunks.map(\.done), [false, false, true])
        XCTAssertEqual(chunks.last?.doneReason, "stop")
    }

    func testKeepAliveDurationParsesOllamaDurations() {
        XCTAssertEqual(OllamaRuntimeHandler.keepAliveDurationSeconds("0"), 0)
        XCTAssertEqual(OllamaRuntimeHandler.keepAliveDurationSeconds("30s"), 30)
        XCTAssertEqual(OllamaRuntimeHandler.keepAliveDurationSeconds("5m"), 300)
        XCTAssertEqual(OllamaRuntimeHandler.keepAliveDurationSeconds("2h"), 7200)
        XCTAssertEqual(OllamaRuntimeHandler.keepAliveDurationSeconds("1d"), 86400)
        XCTAssertNil(OllamaRuntimeHandler.keepAliveDurationSeconds("forever"))
    }
}
