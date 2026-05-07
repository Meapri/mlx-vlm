import Foundation

/// Mirrors the compatibility remapping behavior used by Python mlx-vlm while
/// keeping unsupported architectures explicit.
public enum ModelRemapping {
    public static let remapping: [String: String] = [
        "llava_qwen2": "fastvlm",
        "llava-qwen2": "llava_bunny",
        "bunny-llama": "llava_bunny",
        "lfm2-vl": "lfm2_vl",
        "cohere2_vision": "aya_vision",
        "phi4-siglip": "phi4_siglip",
        "sam3_video": "sam3",
        "sam3.1_video": "sam3_1",
        "granite-vision": "granite_vision",
        "granite4-vision": "granite4_vision",
        "granite4_vision": "granite4_vision",
        "rf-detr": "rfdetr",
        "falcon-perception": "falcon_perception",
        "nemotronh_nano_omni_reasoning_v3": "nemotron_h_nano_omni"
    ]

    /// Initial Swift VLM runtime support target. This is intentionally smaller
    /// than Python mlx-vlm's full support matrix and must be surfaced clearly.
    public static let supportedModelTypes: Set<String> = [
        "qwen2_vl",
        "qwen2_5_vl",
        "qwen3_vl",
        "fastvlm",
        "smolvlm",
        "gemma3",
        "gemma4",
        "paligemma",
        "idefics3",
        "pixtral",
        "mistral3",
        "lfm2_vl",
        "glm_ocr"
    ]

    public static func canonicalModelType(_ rawValue: String) -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return remapping[normalized] ?? normalized
    }

    public static func isSupported(_ rawValue: String) -> Bool {
        supportedModelTypes.contains(canonicalModelType(rawValue))
    }
}

public struct UnsupportedModelTypeError: LocalizedError, Equatable, Sendable {
    public let modelType: String

    public init(modelType: String) {
        self.modelType = modelType
    }

    public var errorDescription: String? {
        let supported = ModelRemapping.supportedModelTypes.sorted().joined(separator: ", ")
        return "Unsupported model_type: \(modelType). The MLX file format remains compatible, but this Swift runtime has not ported that architecture yet. Supported model types: \(supported)."
    }
}
