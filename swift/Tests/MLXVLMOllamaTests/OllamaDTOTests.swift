import XCTest
@testable import MLXVLMOllama

final class OllamaDTOTests: XCTestCase {
    func testGenerateRequestDecodesImagesAndOptions() throws {
        let json = """
        {
          "model": "qwen2.5-vl:3b",
          "prompt": "Describe this image",
          "images": ["ZmFrZQ=="],
          "stream": false,
          "options": {
            "temperature": 0.0,
            "top_p": 1.0,
            "num_predict": 128
          }
        }
        """.data(using: .utf8)!

        let request = try JSONDecoder().decode(OllamaGenerateRequest.self, from: json)

        XCTAssertEqual(request.model, "qwen2.5-vl:3b")
        XCTAssertEqual(request.prompt, "Describe this image")
        XCTAssertEqual(request.images, ["ZmFrZQ=="])
        XCTAssertEqual(request.stream, false)
        XCTAssertEqual(request.options?.temperature, 0.0)
        XCTAssertEqual(request.options?.topP, 1.0)
        XCTAssertEqual(request.options?.numPredict, 128)
    }

    func testChatRequestDecodesMessageImages() throws {
        let json = """
        {
          "model": "qwen2.5-vl:3b",
          "messages": [
            {"role": "user", "content": "What is this?", "images": ["ZmFrZQ=="]}
          ],
          "stream": true
        }
        """.data(using: .utf8)!

        let request = try JSONDecoder().decode(OllamaChatRequest.self, from: json)

        XCTAssertEqual(request.model, "qwen2.5-vl:3b")
        XCTAssertEqual(request.messages.first?.role, "user")
        XCTAssertEqual(request.messages.first?.content, "What is this?")
        XCTAssertEqual(request.messages.first?.images, ["ZmFrZQ=="])
        XCTAssertEqual(request.stream, true)
    }

    func testGenerateChunkEncodesOllamaDoneField() throws {
        let chunk = OllamaGenerateResponse(
            model: "qwen2.5-vl:3b",
            createdAt: "2026-05-07T00:00:00Z",
            response: "A cat",
            done: false
        )

        let data = try JSONEncoder.ollama.encode(chunk)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["model"] as? String, "qwen2.5-vl:3b")
        XCTAssertEqual(object?["created_at"] as? String, "2026-05-07T00:00:00Z")
        XCTAssertEqual(object?["response"] as? String, "A cat")
        XCTAssertEqual(object?["done"] as? Bool, false)
    }

    func testTagsResponseUsesOllamaModelShape() throws {
        let response = OllamaTagsResponse(models: [
            OllamaModelTag(
                name: "qwen2.5-vl:3b",
                model: "qwen2.5-vl:3b",
                modifiedAt: "2026-05-07T00:00:00Z",
                size: 0,
                digest: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
                details: OllamaModelDetails(
                    parentModel: "",
                    format: "mlx",
                    family: "qwen2_5_vl",
                    families: ["qwen2_5_vl"],
                    parameterSize: "3B",
                    quantizationLevel: "Q4"
                )
            )
        ])

        let data = try JSONEncoder.ollama.encode(response)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = object?["models"] as? [[String: Any]]
        let details = models?.first?["details"] as? [String: Any]

        XCTAssertEqual(models?.first?["name"] as? String, "qwen2.5-vl:3b")
        XCTAssertEqual(details?["format"] as? String, "mlx")
        XCTAssertEqual(details?["parameter_size"] as? String, "3B")
    }
}
