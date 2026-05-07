import XCTest
@testable import MLXVLMCore
@testable import MLXVLMOllama

final class OllamaAdapterTests: XCTestCase {
    func testGenerateRequestMapsAliasAndOptionsToCoreParameters() {
        let request = OllamaGenerateRequest(
            model: "qwen2.5-vl:3b",
            prompt: "Describe this image",
            images: ["ZmFrZQ=="],
            stream: false,
            options: OllamaOptions(temperature: 0.2, topP: 0.9, numPredict: 64)
        )
        let store = ModelAliasStore(aliases: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])

        let parameters = OllamaAdapter.generateParameters(from: request, aliases: store)

        XCTAssertEqual(parameters.model, "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        XCTAssertEqual(parameters.prompt, "Describe this image")
        XCTAssertEqual(parameters.images, ["ZmFrZQ=="])
        XCTAssertEqual(parameters.maxTokens, 64)
        XCTAssertEqual(parameters.temperature, 0.2)
        XCTAssertEqual(parameters.topP, 0.9)
    }

    func testChatRequestCollectsPromptAndImages() {
        let request = OllamaChatRequest(
            model: "qwen2.5-vl:3b",
            messages: [
                OllamaMessage(role: "system", content: "Be concise"),
                OllamaMessage(role: "user", content: "What is this?", images: ["a", "b"])
            ]
        )

        XCTAssertEqual(OllamaAdapter.promptFromChat(request), "system: Be concise\nuser: What is this?")
        XCTAssertEqual(OllamaAdapter.imageInputsFromChat(request), ["a", "b"])
    }

    func testTagsResponsePreservesAliasAndSourceDigest() {
        let response = OllamaAdapter.tagsResponse(from: [
            ModelAlias(name: "qwen2.5-vl:3b", source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit", modelType: "qwen2_5_vl")
        ])

        XCTAssertEqual(response.models.first?.name, "qwen2.5-vl:3b")
        XCTAssertEqual(response.models.first?.digest, "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        XCTAssertEqual(response.models.first?.details.format, "mlx")
        XCTAssertEqual(response.models.first?.details.family, "qwen2_5_vl")
        XCTAssertEqual(response.models.first?.details.parameterSize, "3B")
        XCTAssertEqual(response.models.first?.details.quantizationLevel, "Q4")
    }
}
