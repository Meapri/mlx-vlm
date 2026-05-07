import XCTest
@testable import MLXVLMCore

final class ModelAliasTests: XCTestCase {
    func testAliasPreservesSourceModelIdentity() throws {
        let alias = ModelAlias(
            name: "qwen2.5-vl:3b",
            source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
            modelType: "qwen2_5_vl",
            localPath: nil
        )

        XCTAssertEqual(alias.name, "qwen2.5-vl:3b")
        XCTAssertEqual(alias.source, "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        XCTAssertEqual(alias.modelType, "qwen2_5_vl")
        XCTAssertNil(alias.localPath)
    }

    func testStoreResolvesAliasBeforeSourceFallback() throws {
        let store = ModelAliasStore(aliases: [
            ModelAlias(
                name: "qwen2.5-vl:3b",
                source: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
                modelType: "qwen2_5_vl"
            )
        ])

        XCTAssertEqual(store.resolve("qwen2.5-vl:3b")?.source, "mlx-community/Qwen2.5-VL-3B-Instruct-4bit")
        XCTAssertEqual(store.resolveSourceOrIdentity("mlx-community/Other"), "mlx-community/Other")
    }
}
