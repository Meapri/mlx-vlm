import XCTest
@testable import MLXVLMCompat

final class ModelRemappingTests: XCTestCase {
    func testCanonicalizesKnownAliasesWithoutChangingExistingModelFormat() {
        XCTAssertEqual(ModelRemapping.canonicalModelType("llava_qwen2"), "fastvlm")
        XCTAssertEqual(ModelRemapping.canonicalModelType("lfm2-vl"), "lfm2_vl")
        XCTAssertEqual(ModelRemapping.canonicalModelType("granite-vision"), "granite_vision")
        XCTAssertEqual(ModelRemapping.canonicalModelType("rf-detr"), "rfdetr")
    }

    func testLowercasesAndPreservesUnknownTypesForExplicitUnsupportedErrors() {
        XCTAssertEqual(ModelRemapping.canonicalModelType("QWEN2_5_VL"), "qwen2_5_vl")
        XCTAssertEqual(ModelRemapping.canonicalModelType("deepseekocr_2"), "deepseekocr_2")
    }

    func testSupportedTypesContainInitialSwiftVLMTargets() {
        let supported = ModelRemapping.supportedModelTypes
        XCTAssertTrue(supported.contains("qwen2_vl"))
        XCTAssertTrue(supported.contains("qwen2_5_vl"))
        XCTAssertTrue(supported.contains("qwen3_vl"))
        XCTAssertTrue(supported.contains("fastvlm"))
        XCTAssertTrue(supported.contains("smolvlm"))
        XCTAssertTrue(supported.contains("gemma3"))
        XCTAssertTrue(supported.contains("gemma4"))
    }

    func testUnsupportedErrorListsCanonicalSupportedTypes() {
        let error = UnsupportedModelTypeError(modelType: "deepseekocr_2")
        let message = error.errorDescription ?? ""
        XCTAssertTrue(message.contains("deepseekocr_2"))
        XCTAssertTrue(message.contains("qwen2_5_vl"))
        XCTAssertTrue(message.contains("fastvlm"))
    }
}
