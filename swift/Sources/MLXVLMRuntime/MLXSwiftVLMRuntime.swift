import Foundation
import MLXVLMCore
import MLX
import MLXVLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

/// Concrete `VLMRuntime` backed by Apple's MLX Swift VLM stack.
///
/// This runtime preserves existing MLX/HuggingFace model identity. `modelSource`
/// can be either:
/// - a local model directory containing `config.json`, tokenizer files, and `*.safetensors`
/// - a HuggingFace model id such as `mlx-community/Qwen2.5-VL-3B-Instruct-4bit`
public actor MLXSwiftVLMRuntime: VLMRuntime {
    private var containers: [String: ModelContainer] = [:]

    public init() {}

    public func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        try await Self.withConfiguredDevice {
            try await generateOnConfiguredDevice(request)
        }
    }

    private func generateOnConfiguredDevice(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        let (images, temporaryFiles) = try Self.decodeImages(request.base64Images)
        defer { Self.removeTemporaryFiles(temporaryFiles) }
        let container = try await container(for: request.modelSource)

        let session = ChatSession(
            container,
            generateParameters: MLXLMCommon.GenerateParameters(
                maxTokens: request.maxTokens,
                temperature: Float(request.temperature),
                topP: Float(request.topP)
            )
        )

        let text = try await session.respond(
            to: request.prompt,
            images: images,
            videos: []
        )

        return RuntimeGenerateChunk(text: text, done: true, finishReason: "stop")
    }

    public nonisolated func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await Self.withConfiguredDevice {
                        let (images, temporaryFiles) = try Self.decodeImages(request.base64Images)
                        defer { Self.removeTemporaryFiles(temporaryFiles) }
                        let container = try await self.container(for: request.modelSource)

                        let session = ChatSession(
                            container,
                            generateParameters: MLXLMCommon.GenerateParameters(
                                maxTokens: request.maxTokens,
                                temperature: Float(request.temperature),
                                topP: Float(request.topP)
                            )
                        )

                        for try await chunk in session.streamResponse(
                            to: request.prompt,
                            images: images,
                            videos: []
                        ) {
                            if Task.isCancelled { break }
                            continuation.yield(RuntimeGenerateChunk(text: chunk, done: false))
                        }
                        continuation.yield(RuntimeGenerateChunk(text: "", done: true, finishReason: "stop"))
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func container(for source: String) async throws -> ModelContainer {
        if let container = containers[source] {
            return container
        }

        let container: ModelContainer
        if Self.isLocalDirectory(source) {
            container = try await loadModelContainer(
                from: URL(fileURLWithPath: source),
                using: #huggingFaceTokenizerLoader()
            )
        } else {
            container = try await loadModelContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                id: source
            )
        }

        containers[source] = container
        return container
    }

    private nonisolated static func withConfiguredDevice<R>(_ operation: () async throws -> R) async throws -> R {
        let requestedDevice = ProcessInfo.processInfo.environment["MLXVLM_SWIFT_DEVICE"]?.lowercased()
        if requestedDevice == "cpu" {
            return try await Device.withDefaultDevice(.cpu) {
                try await operation()
            }
        }
        return try await operation()
    }

    private nonisolated static func isLocalDirectory(_ source: String) -> Bool {
        let path: String
        if source.hasPrefix("file://"), let url = URL(string: source) {
            path = url.path
        } else {
            path = source
        }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private nonisolated static func decodeImages(_ base64Images: [String]) throws -> ([UserInput.Image], [URL]) {
        var images: [UserInput.Image] = []
        var temporaryFiles: [URL] = []

        for encoded in base64Images {
            let payload: String
            if let comma = encoded.firstIndex(of: ",") {
                payload = String(encoded[encoded.index(after: comma)...])
            } else {
                payload = encoded
            }

            guard let data = Data(base64Encoded: payload) else {
                throw MLXSwiftVLMRuntimeError.invalidBase64Image
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("mlx-vlm-swift-")
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("image")
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
            temporaryFiles.append(url)
            images.append(.url(url))
        }

        return (images, temporaryFiles)
    }

    private nonisolated static func removeTemporaryFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

public enum MLXSwiftVLMRuntimeError: LocalizedError, Equatable, Sendable {
    case invalidBase64Image

    public var errorDescription: String? {
        switch self {
        case .invalidBase64Image:
            return "Image input must be base64 data or a data URL containing base64 payload."
        }
    }
}
