import Foundation
import MLXVLMCore
import MLXVLMServer

@main
struct MLXVLMCompatCLI {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "help"

        switch command {
        case "routes":
            print(ServerShell.routeSummary())
        case "aliases":
            let store = ModelAliasStore()
            for alias in store.aliases {
                print("\(alias.name) -> \(alias.source)")
            }
        case "serve":
            print("Server implementation pending HTTP framework binding.")
            print("Default target: http://\(ServerShell.defaultHost):\(ServerShell.defaultPort)")
            print(ServerShell.routeSummary())
        case "help", "--help", "-h":
            fallthrough
        default:
            print("""
            mlx-vlm-swift compatibility CLI

            Commands:
              routes   Print planned Ollama/OpenAI-compatible HTTP routes
              aliases  Print built-in Ollama-style model aliases
              serve    Print server target and route manifest (HTTP binding pending)

            Compatibility target:
              Existing MLX model directories remain unchanged. Aliases resolve to
              original HuggingFace IDs or local paths.
            """)
        }
    }
}
