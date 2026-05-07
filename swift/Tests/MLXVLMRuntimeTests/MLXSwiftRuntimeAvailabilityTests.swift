import XCTest
@testable import MLXVLMRuntime

final class MLXSwiftRuntimeAvailabilityTests: XCTestCase {
    func testRuntimeTargetLinksExpectedMLXSwiftProducts() {
        XCTAssertEqual(
            MLXSwiftRuntimeAvailability.requiredProducts,
            ["MLXVLM", "MLXLMCommon", "MLXHuggingFace"]
        )
        XCTAssertTrue(MLXSwiftRuntimeAvailability.status.contains("linked"))
    }
}
