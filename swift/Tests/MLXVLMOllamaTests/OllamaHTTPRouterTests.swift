import XCTest
import Foundation
@testable import MLXVLMCore
@testable import MLXVLMOllama
@testable import MLXVLMServer

private struct EchoRuntime: VLMRuntime {
    func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        RuntimeGenerateChunk(text: "echo:\(request.modelSource):\(request.prompt):\(request.base64Images.count)", done: true, finishReason: "stop")
    }

    func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(RuntimeGenerateChunk(text: "a", done: false))
            continuation.yield(RuntimeGenerateChunk(text: "b", done: false))
            continuation.yield(RuntimeGenerateChunk(text: "", done: true, finishReason: "stop"))
            continuation.finish()
        }
    }
}

final class OllamaHTTPRouterTests: XCTestCase {
    func testVersionRouteReturnsOllamaVersionJSON() async throws {
        let router = OllamaHTTPRouter(version: "test-version")
        let response = try await router.handle(HTTPRequest(method: "GET", path: "/api/version", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headerValue("content-type"), "application/json")
        let decoded = try JSONDecoder.ollama.decode(OllamaVersionResponse.self, from: response.body)
        XCTAssertEqual(decoded.version, "test-version")
    }

    func testTagsRouteReturnsBuiltInAliases() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])
        let router = OllamaHTTPRouter(aliases: aliases)
        let response = try await router.handle(HTTPRequest(method: "GET", path: "/api/tags", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.ollama.decode(OllamaTagsResponse.self, from: response.body)
        XCTAssertEqual(decoded.models.map(\.name), ["qwen2.5-vl:3b"])
    }

    func testGenerateRouteCallsRuntimeHandler() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), aliases: aliases, now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler, aliases: aliases)
        let body = try JSONEncoder.ollama.encode(OllamaGenerateRequest(model: "qwen2.5-vl:3b", prompt: "Describe", images: ["a"], stream: false))

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/api/generate", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.ollama.decode(OllamaGenerateResponse.self, from: response.body)
        XCTAssertEqual(decoded.model, "qwen2.5-vl:3b")
        XCTAssertEqual(decoded.response, "echo:mlx-community/Qwen2.5-VL-3B-Instruct-4bit:Describe:1")
        XCTAssertTrue(decoded.done)
    }

    func testGenerateStreamRouteReturnsJSONLines() async throws {
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler)
        let body = try JSONEncoder.ollama.encode(OllamaGenerateRequest(model: "local", prompt: "Hi", stream: true))

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/api/generate", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headerValue("content-type"), "application/x-ndjson")
        let lines = String(decoding: response.body, as: UTF8.self).split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        let decoded = try lines.map { try JSONDecoder.ollama.decode(OllamaGenerateResponse.self, from: Data($0.utf8)) }
        XCTAssertEqual(decoded.map(\.response), ["a", "b", ""])
        XCTAssertEqual(decoded.map(\.done), [false, false, true])
    }

    func testChatRouteCallsRuntimeHandler() async throws {
        let handler = OllamaRuntimeHandler(runtime: EchoRuntime(), now: { "2026-05-07T00:00:00Z" })
        let router = OllamaHTTPRouter(runtimeHandler: handler)
        let request = OllamaChatRequest(model: "local", messages: [OllamaMessage(role: "user", content: "Hi")], stream: false)
        let body = try JSONEncoder.ollama.encode(request)

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/api/chat", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.ollama.decode(OllamaChatResponse.self, from: response.body)
        XCTAssertEqual(decoded.message.role, "assistant")
        XCTAssertEqual(decoded.message.content, "echo:local:user: Hi:0")
    }

    func testShowRouteReturnsModelMetadataForAlias() async throws {
        let aliases = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])
        let router = OllamaHTTPRouter(aliases: aliases)
        let body = try JSONEncoder.ollama.encode(OllamaShowRequest(model: "qwen2.5-vl:3b"))

        let response = try await router.handle(HTTPRequest(method: "POST", path: "/api/show", headers: [:], body: body))

        XCTAssertEqual(response.statusCode, 200)
        let decoded = try JSONDecoder.ollama.decode(OllamaModelTag.self, from: response.body)
        XCTAssertEqual(decoded.name, "qwen2.5-vl:3b")
        XCTAssertEqual(decoded.digest, "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        XCTAssertEqual(decoded.details.family, "qwen2_5_vl")
    }

    func testRootRouteServesInteractiveWebUI() async throws {
        let router = OllamaHTTPRouter()

        let response = try await router.handle(HTTPRequest(method: "GET", path: "/", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headerValue("content-type"), "text/html; charset=utf-8")
        let html = String(decoding: response.body, as: UTF8.self)
        XCTAssertTrue(html.contains("/api/tags"))
        XCTAssertTrue(html.contains("/api/generate"))
        XCTAssertTrue(html.contains("MLX-VLM Swift"))
    }

    func testUnknownRouteReturns404() async throws {
        let router = OllamaHTTPRouter()
        let response = try await router.handle(HTTPRequest(method: "GET", path: "/missing", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 404)
    }
}
