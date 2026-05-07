import XCTest
import MLXVLMCore
@testable import MLXVLMRuntime

final class MLXSwiftVLMRuntimeTests: XCTestCase {
    func testRuntimeCanBeConstructedAsVLMRuntime() {
        let runtime: any VLMRuntime = MLXSwiftVLMRuntime()
        XCTAssertNotNil(runtime)
    }

    func testInvalidBase64ImageFailsBeforeModelLoad() async {
        let runtime = MLXSwiftVLMRuntime()
        let request = RuntimeGenerateRequest(
            modelSource: "/definitely/not/a/local/model",
            prompt: "Describe this image",
            base64Images: ["not-base64"],
            maxTokens: 1,
            temperature: 0,
            topP: 1
        )

        do {
            _ = try await runtime.generate(request)
            XCTFail("Expected invalidBase64Image")
        } catch let error as MLXSwiftVLMRuntimeError {
            XCTAssertEqual(error, .invalidBase64Image)
        } catch {
            // If this changes, the runtime started loading before validating image input.
            XCTFail("Unexpected error: \(error)")
        }
    }
}
