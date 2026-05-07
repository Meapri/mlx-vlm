import Foundation
import MLXVLMCore
import MLXVLM
import MLXLMCommon
import MLXHuggingFace

/// Compile-time integration point for the upstream MLX Swift VLM stack.
///
/// The concrete generation implementation will live here. Keeping this target
/// separate lets DTO/API compatibility tests stay fast while CI verifies the
/// real MLX Swift products continue to resolve and compile.
public enum MLXSwiftRuntimeAvailability {
    public static let requiredProducts = [
        "MLXVLM",
        "MLXLMCommon",
        "MLXHuggingFace"
    ]

    public static var status: String {
        "MLX Swift VLM products are linked; generation bridge implementation pending."
    }
}
