import XCTest
@testable import MLXVLMCore

private struct EchoRuntime: VLMRuntime {
    func generate(_ request: RuntimeGenerateRequest) async throws -> RuntimeGenerateChunk {
        RuntimeGenerateChunk(text: "model=\(request.modelSource); prompt=\(request.prompt)", done: true, finishReason: "stop")
    }

    func stream(_ request: RuntimeGenerateRequest) -> AsyncThrowingStream<RuntimeGenerateChunk, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(RuntimeGenerateChunk(text: request.prompt, done: false))
            continuation.yield(RuntimeGenerateChunk(text: "", done: true, finishReason: "stop"))
            continuation.finish()
        }
    }
}

final class RuntimeBridgeTests: XCTestCase {
    func testBridgePreservesAliasResolutionBeforeCallingRuntime() async throws {
        let bridge = RuntimeBridge(
            aliases: ModelAliasStore(aliases: [
                ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
            ]),
            runtime: EchoRuntime()
        )

        let chunk = try await bridge.generate(model: "qwen2.5-vl:3b", prompt: "hello")

        XCTAssertEqual(chunk.text, "model=mlx-community/Qwen2.5-VL-3B-Instruct-4bit; prompt=hello")
        XCTAssertEqual(chunk.done, true)
        XCTAssertEqual(chunk.finishReason, "stop")
    }

    func testUnimplementedRuntimeFailsExplicitly() async {
        let bridge = RuntimeBridge(runtime: UnimplementedVLMRuntime())

        do {
            _ = try await bridge.generate(model: "qwen2.5-vl:3b", prompt: "hello")
            XCTFail("Expected runtimeNotConnected")
        } catch let error as RuntimeBridgeError {
            XCTAssertEqual(error, .runtimeNotConnected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
