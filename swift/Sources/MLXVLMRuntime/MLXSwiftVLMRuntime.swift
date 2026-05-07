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
public actor MLXSwiftVLMRuntime: VLMRuntime, RuntimeModelStateReporting, RuntimeModelExpirationManaging {
    private struct LoadedContainer {
        var container: ModelContainer
        var loadedAt: Date
        var lastUsedAt: Date
        var expiresAt: Date?
    }

    private var containers: [String: LoadedContainer] = [:]

    public init() {
        if Self.requestedDevice() == "cpu" {
            Device.setDefault(device: .cpu)
        }
    }

    public func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        try await generateOnConfiguredDevice(request)
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
                    try await self.streamOnConfiguredDevice(request, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func streamOnConfiguredDevice(
        _ request: RuntimeGenerateRequest,
        continuation: AsyncThrowingStream<RuntimeGenerateChunk, Error>.Continuation
    ) async throws {
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

    public func loadedModelSources() async -> [String] {
        pruneExpiredModels()
        return containers.keys.sorted()
    }

    public func loadedModels() async -> [RuntimeLoadedModel] {
        pruneExpiredModels()
        return containers
            .map { source, loaded in
                RuntimeLoadedModel(
                    source: source,
                    loadedAt: Self.iso8601String(from: loaded.loadedAt),
                    lastUsedAt: Self.iso8601String(from: loaded.lastUsedAt),
                    expiresAt: loaded.expiresAt.map(Self.iso8601String(from:)),
                    size: 0,
                    family: Self.modelFamily(from: source),
                    parameterSize: Self.parameterSize(from: source),
                    quantizationLevel: Self.quantizationLevel(from: source)
                )
            }
            .sorted { $0.source < $1.source }
    }

    @discardableResult
    public func unloadModelSource(_ source: String) async -> Bool {
        containers.removeValue(forKey: source) != nil
    }

    public func setModelExpiration(source: String, expiresAt: Date?) async {
        pruneExpiredModels()
        guard var loaded = containers[source] else { return }
        loaded.expiresAt = expiresAt
        containers[source] = loaded
    }

    private func container(for source: String) async throws -> ModelContainer {
        pruneExpiredModels()
        if var loaded = containers[source] {
            loaded.lastUsedAt = Date()
            containers[source] = loaded
            return loaded.container
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

        containers[source] = LoadedContainer(container: container, loadedAt: Date(), lastUsedAt: Date(), expiresAt: nil)
        return container
    }

    private func pruneExpiredModels(now: Date = Date()) {
        containers = containers.filter { _, loaded in
            guard let expiresAt = loaded.expiresAt else { return true }
            return expiresAt > now
        }
    }

    private nonisolated static func requestedDevice() -> String? {
        ProcessInfo.processInfo.environment["MLXVLM_SWIFT_DEVICE"]?.lowercased()
    }

    private nonisolated static func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private nonisolated static func modelFamily(from source: String) -> String {
        let lowercased = source.lowercased()
        if lowercased.contains("qwen2.5") || lowercased.contains("qwen2_5") { return "qwen2_5_vl" }
        if lowercased.contains("qwen2-vl") || lowercased.contains("qwen2_vl") { return "qwen2_vl" }
        if lowercased.contains("smolvlm") { return "smolvlm" }
        if lowercased.contains("fastvlm") { return "fastvlm" }
        if lowercased.contains("gemma") { return "gemma" }
        return "vlm"
    }

    private nonisolated static func parameterSize(from source: String) -> String {
        let lowercased = source.lowercased()
        if lowercased.contains("256m") { return "256M" }
        if lowercased.contains("0.5b") { return "0.5B" }
        if lowercased.contains("2b") { return "2B" }
        if lowercased.contains("3b") { return "3B" }
        if lowercased.contains("7b") { return "7B" }
        return "unknown"
    }

    private nonisolated static func quantizationLevel(from source: String) -> String {
        let lowercased = source.lowercased()
        if lowercased.contains("4bit") || lowercased.contains("4-bit") { return "Q4" }
        if lowercased.contains("8bit") || lowercased.contains("8-bit") { return "Q8" }
        return "unknown"
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

            let fileExtension = Self.imageFileExtension(for: data)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("mlx-vlm-swift-")
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
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

    private nonisolated static func imageFileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(16))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }
        if bytes.count >= 12,
           bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
           bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50 {
            return "webp"
        }
        if let rawPrefix = String(data: data.prefix(256), encoding: .utf8) {
            let prefix = rawPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if prefix.hasPrefix("<svg") || prefix.hasPrefix("<?xml") {
                return "svg"
            }
        }
        return "png"
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
