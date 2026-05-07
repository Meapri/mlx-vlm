// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "mlx-vlm-swift-compat",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "MLXVLMCore", targets: ["MLXVLMCore"]),
        .library(name: "MLXVLMCompat", targets: ["MLXVLMCompat"]),
        .library(name: "MLXVLMOllama", targets: ["MLXVLMOllama"]),
        .library(name: "MLXVLMServer", targets: ["MLXVLMServer"]),
        .library(name: "MLXVLMRuntime", targets: ["MLXVLMRuntime"]),
        .executable(name: "mlx-vlm-swift", targets: ["mlx-vlm-swift"])
    ],
    dependencies: [
        .package(url: "https://github.com/Meapri/mlx-swift-lm.git", branch: "fix/ci-context-sendable"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", branch: "main"),
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.8.1")
    ],
    targets: [
        .target(name: "MLXVLMCore"),
        .target(name: "MLXVLMCompat", dependencies: ["MLXVLMCore"]),
        .target(name: "MLXVLMOllama", dependencies: ["MLXVLMCore", "MLXVLMCompat"]),
        .target(name: "MLXVLMServer", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama"]),
        .target(
            name: "MLXVLMRuntime",
            dependencies: [
                "MLXVLMCore",
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "HuggingFace", package: "swift-huggingface")
            ]
        ),
        .executableTarget(name: "mlx-vlm-swift", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama", "MLXVLMServer"]),
        .testTarget(name: "MLXVLMCompatTests", dependencies: ["MLXVLMCore", "MLXVLMCompat"]),
        .testTarget(name: "MLXVLMOllamaTests", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama", "MLXVLMServer"]),
        .testTarget(name: "MLXVLMRuntimeTests", dependencies: ["MLXVLMRuntime"])
    ]
)
