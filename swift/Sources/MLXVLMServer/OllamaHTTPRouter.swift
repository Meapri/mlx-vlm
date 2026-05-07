import Foundation
import MLXVLMCore
import MLXVLMOllama

public struct OllamaHTTPRouter: Sendable {
    private let runtimeHandler: OllamaRuntimeHandler
    private let aliases: ModelAliasStore
    private let version: String

    public init(
        runtimeHandler: OllamaRuntimeHandler = OllamaRuntimeHandler(runtime: UnimplementedVLMRuntime()),
        aliases: ModelAliasStore = ModelAliasStore(),
        version: String = "mlx-vlm-swift-compat"
    ) {
        self.runtimeHandler = runtimeHandler
        self.aliases = aliases
        self.version = version
    }

    public func handle(_ request: HTTPRequest) async throws -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/api/version"):
            return try HTTPResponse.json(OllamaVersionResponse(version: version))
        case ("GET", "/api/tags"):
            return try HTTPResponse.json(OllamaAdapter.tagsResponse(from: aliases.aliases, createdAt: OllamaRuntimeHandler.iso8601Now()))
        case ("GET", "/api/ps"):
            return try HTTPResponse.json(OllamaRunningModelsResponse(models: []))
        case ("POST", "/api/generate"):
            return try await handleGenerate(request)
        case ("POST", "/api/chat"):
            return try await handleChat(request)
        case ("GET", "/"):
            return HTTPResponse.text(Self.webUIHTML, contentType: "text/html; charset=utf-8")
        default:
            return HTTPResponse.notFound()
        }
    }

    private func handleGenerate(_ httpRequest: HTTPRequest) async throws -> HTTPResponse {
        let request = try JSONDecoder.ollama.decode(OllamaGenerateRequest.self, from: httpRequest.body)
        if request.stream == true {
            var lines: [String] = []
            for try await chunk in runtimeHandler.generateStream(request) {
                let encoded = try JSONEncoder.ollama.encode(chunk)
                lines.append(String(decoding: encoded, as: UTF8.self))
            }
            return HTTPResponse(
                statusCode: 200,
                headers: ["content-type": "application/x-ndjson"],
                body: Data((lines.joined(separator: "\n") + "\n").utf8)
            )
        }

        return try await HTTPResponse.json(runtimeHandler.generate(request))
    }

    private func handleChat(_ httpRequest: HTTPRequest) async throws -> HTTPResponse {
        let request = try JSONDecoder.ollama.decode(OllamaChatRequest.self, from: httpRequest.body)
        if request.stream == true {
            var lines: [String] = []
            for try await chunk in runtimeHandler.chatStream(request) {
                let encoded = try JSONEncoder.ollama.encode(chunk)
                lines.append(String(decoding: encoded, as: UTF8.self))
            }
            return HTTPResponse(
                statusCode: 200,
                headers: ["content-type": "application/x-ndjson"],
                body: Data((lines.joined(separator: "\n") + "\n").utf8)
            )
        }

        return try await HTTPResponse.json(runtimeHandler.chat(request))
    }

    private static let webUIHTML = """
    <!doctype html>
    <html lang=\"ko\">
    <head><meta charset=\"utf-8\"><title>MLX-VLM Swift</title></head>
    <body><h1>MLX-VLM Swift</h1><p>Ollama-compatible API server is running.</p></body>
    </html>
    """
}
