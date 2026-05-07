import Foundation
import MLXVLMCore
import MLXVLMCompat
import MLXVLMOllama

/// Lightweight route manifest used before binding to a concrete Swift HTTP
/// framework. Keeping this separate lets the compatibility/API contract land
/// without prematurely choosing Vapor vs Hummingbird.
public struct ServerRoute: Equatable, Sendable {
    public let method: String
    public let path: String
    public let purpose: String

    public init(method: String, path: String, purpose: String) {
        self.method = method
        self.path = path
        self.purpose = purpose
    }
}

public enum ServerShell {
    public static let defaultHost = "127.0.0.1"
    public static let defaultPort = 11434

    public static let routes: [ServerRoute] = [
        ServerRoute(method: "POST", path: "/api/generate", purpose: "Ollama-compatible text/VLM generation"),
        ServerRoute(method: "POST", path: "/api/chat", purpose: "Ollama-compatible chat generation"),
        ServerRoute(method: "GET", path: "/api/tags", purpose: "Ollama-compatible local model alias list"),
        ServerRoute(method: "POST", path: "/api/show", purpose: "Ollama-compatible model metadata"),
        ServerRoute(method: "GET", path: "/api/ps", purpose: "Ollama-compatible loaded/running model list"),
        ServerRoute(method: "GET", path: "/api/version", purpose: "Ollama-compatible version response"),
        ServerRoute(method: "POST", path: "/v1/chat/completions", purpose: "OpenAI-compatible chat completions"),
        ServerRoute(method: "GET", path: "/v1/models", purpose: "OpenAI-compatible model list"),
        ServerRoute(method: "GET", path: "/", purpose: "Static local web UI")
    ]

    public static func routeSummary() -> String {
        routes
            .map { "\($0.method) \($0.path) - \($0.purpose)" }
            .joined(separator: "\n")
    }
}
