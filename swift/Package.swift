// swift-tools-version: 5.10
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
        .executable(name: "mlx-vlm-swift", targets: ["mlx-vlm-swift"])
    ],
    dependencies: [
        // Runtime MLX dependencies will be enabled after baseline DTO/compat tests land.
        // .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main"),
        // .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main")
    ],
    targets: [
        .target(name: "MLXVLMCore"),
        .target(name: "MLXVLMCompat", dependencies: ["MLXVLMCore"]),
        .target(name: "MLXVLMOllama", dependencies: ["MLXVLMCore", "MLXVLMCompat"]),
        .target(name: "MLXVLMServer", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama"]),
        .executableTarget(name: "mlx-vlm-swift", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama", "MLXVLMServer"]),
        .testTarget(name: "MLXVLMCompatTests", dependencies: ["MLXVLMCore", "MLXVLMCompat"]),
        .testTarget(name: "MLXVLMOllamaTests", dependencies: ["MLXVLMCore", "MLXVLMCompat", "MLXVLMOllama", "MLXVLMServer"])
    ]
)
