import Foundation
import MLXVLMCore
import MLXVLMOllama
import MLXVLMServer
import MLXVLMRuntime

@main
struct MLXVLMCompatCLI {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "help"

        switch command {
        case "generate":
            try await runGenerate(Array(arguments.dropFirst()))
        case "routes":
            print(ServerShell.routeSummary())
        case "aliases":
            let store = ModelAliasStore()
            for alias in store.aliases {
                print("\(alias.name) -> \(alias.source)")
            }
        case "serve":
            try runServe(Array(arguments.dropFirst()))
        case "help", "--help", "-h":
            fallthrough
        default:
            printHelp()
        }
    }

    private static func runGenerate(_ arguments: [String]) async throws {
        let options = CLIOptions(arguments)
        guard let model = options.value(for: "--model") else {
            throw CLIError.missingRequiredOption("--model")
        }
        guard let prompt = options.value(for: "--prompt") else {
            throw CLIError.missingRequiredOption("--prompt")
        }

        let settings = try SettingsStore().loadOrCreateDefault()
        let aliases = ModelAliasStore(aliases: settings.aliases)
        let runtime = MLXSwiftVLMRuntime()
        let bridge = RuntimeBridge(aliases: aliases, runtime: runtime)
        let request = bridge.makeRequest(
            model: model,
            prompt: prompt,
            base64Images: imageInputs(from: options),
            maxTokens: options.intValue(for: "--max-tokens") ?? settings.defaultMaxTokens,
            temperature: options.doubleValue(for: "--temperature") ?? settings.defaultTemperature,
            topP: options.doubleValue(for: "--top-p") ?? settings.defaultTopP
        )

        if options.hasFlag("--stream") {
            for try await chunk in runtime.stream(request) {
                if !chunk.text.isEmpty {
                    print(chunk.text, terminator: "")
                    fflush(stdout)
                }
            }
            print("")
        } else {
            let chunk = try await runtime.generate(request)
            print(chunk.text)
        }
    }

    private static func runServe(_ arguments: [String]) throws -> Never {
        let options = CLIOptions(arguments)
        let settingsStore = SettingsStore()
        let settings = try settingsStore.loadOrCreateDefault()
        let host = options.value(for: "--host") ?? settings.host
        let port = options.intValue(for: "--port") ?? settings.port
        let aliases = ModelAliasStore(aliases: settings.aliases)
        let runtime = MLXSwiftVLMRuntime()
        let handler = OllamaRuntimeHandler(runtime: runtime, aliases: aliases)
        let router = OllamaHTTPRouter(runtimeHandler: handler, aliases: aliases, settingsStore: settingsStore)
        let server = OllamaNetworkServer(host: host, port: port, router: router)

        print("MLX-VLM Swift Ollama-compatible server listening on http://\(host):\(port)")
        print(ServerShell.routeSummary())
        return try server.runForever()
    }

    private static func imageInputs(from options: CLIOptions) -> [String] {
        var images = options.values(for: "--image-base64")
        for path in options.values(for: "--image") {
            if let data = FileManager.default.contents(atPath: path) {
                images.append(data.base64EncodedString())
            }
        }
        return images
    }

    private static func printHelp() {
        print("""
        mlx-vlm-swift compatibility CLI

        Commands:
          generate  Run MLX Swift VLM generation
          routes    Print planned Ollama/OpenAI-compatible HTTP routes
          aliases   Print built-in Ollama-style model aliases
          serve     Run Ollama-compatible HTTP server

        Generate example:
          mlx-vlm-swift generate \
            --model mlx-community/Qwen2.5-VL-3B-Instruct-4bit \
            --image ./cat.jpg \
            --prompt "Describe this image" \
            --max-tokens 128 \
            --temperature 0

        Generate options:
          --model <alias|hf-id|local-path>  Required. Alias resolves without changing model files.
          --prompt <text>                  Required.
          --image <path>                   Optional, repeatable. Encoded as base64 then passed to runtime.
          --image-base64 <payload>         Optional, repeatable. Raw base64 or data URL.
          --max-tokens <n>                 Default: 128
          --temperature <float>            Default: 0.0
          --top-p <float>                  Default: 1.0
          --stream                         Stream chunks to stdout.

        Compatibility target:
          Existing MLX model directories remain unchanged. Aliases resolve to
          original HuggingFace IDs or local paths.
        """)
    }
}

private struct CLIOptions {
    private let pairs: [(String, String?)]

    init(_ arguments: [String]) {
        var parsed: [(String, String?)] = []
        var index = 0
        while index < arguments.count {
            let item = arguments[index]
            if item.hasPrefix("--") {
                if index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") {
                    parsed.append((item, arguments[index + 1]))
                    index += 2
                } else {
                    parsed.append((item, nil))
                    index += 1
                }
            } else {
                index += 1
            }
        }
        self.pairs = parsed
    }

    func value(for key: String) -> String? {
        pairs.first { $0.0 == key }?.1
    }

    func values(for key: String) -> [String] {
        pairs.compactMap { $0.0 == key ? $0.1 : nil }
    }

    func hasFlag(_ key: String) -> Bool {
        pairs.contains { $0.0 == key }
    }

    func intValue(for key: String) -> Int? {
        value(for: key).flatMap(Int.init)
    }

    func doubleValue(for key: String) -> Double? {
        value(for: key).flatMap(Double.init)
    }
}

private enum CLIError: LocalizedError {
    case missingRequiredOption(String)

    var errorDescription: String? {
        switch self {
        case .missingRequiredOption(let option):
            return "Missing required option: \(option)"
        }
    }
}
