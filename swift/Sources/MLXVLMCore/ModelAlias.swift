import Foundation

/// Ollama-style alias that preserves the original MLX/HuggingFace model identity.
///
/// `name` is the user-facing short name, while `source` remains the canonical
/// HuggingFace model ID or local model directory. Compatibility code must never
/// rewrite model files into alias-specific formats.
public struct ModelAlias: Codable, Equatable, Sendable {
    public let name: String
    public let source: String
    public let modelType: String?
    public let localPath: String?

    enum CodingKeys: String, CodingKey {
        case name
        case source
        case modelType = "model_type"
        case localPath = "local_path"
    }

    public init(name: String, source: String, modelType: String? = nil, localPath: String? = nil) {
        self.name = name
        self.source = source
        self.modelType = modelType
        self.localPath = localPath
    }
}

/// In-memory alias resolver. Later this can be backed by a JSON file in
/// Application Support without changing API behavior.
public struct ModelAliasStore: Sendable {
    public let aliases: [ModelAlias]

    public init(aliases: [ModelAlias] = ModelAliasStore.defaultAliases) {
        self.aliases = aliases
    }

    public func resolve(_ nameOrSource: String) -> ModelAlias? {
        aliases.first { $0.name == nameOrSource || $0.source == nameOrSource }
    }

    public func resolveSourceOrIdentity(_ nameOrSource: String) -> String {
        resolve(nameOrSource)?.source ?? nameOrSource
    }

    public static let defaultAliases: [ModelAlias] = [
        ModelAlias(
            name: "qwen2.5-vl:3b",
            source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
            modelType: "qwen2_5_vl"
        ),
        ModelAlias(
            name: "qwen2-vl:2b",
            source: "mlx-community/Qwen2-VL-2B-Instruct-4bit",
            modelType: "qwen2_vl"
        ),
        ModelAlias(
            name: "qwen3-vl:4b",
            source: "lmstudio-community/Qwen3-VL-4B-Instruct-MLX-4bit",
            modelType: "qwen3_vl"
        ),
        ModelAlias(
            name: "smolvlm:500m",
            source: "HuggingFaceTB/SmolVLM2-500M-Video-Instruct-mlx",
            modelType: "smolvlm"
        ),
        ModelAlias(
            name: "gemma3:4b-vl",
            source: "mlx-community/gemma-3-4b-it-qat-4bit",
            modelType: "gemma3"
        )
    ]
}
