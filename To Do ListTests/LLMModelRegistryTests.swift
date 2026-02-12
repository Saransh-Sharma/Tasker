//
//  LLMModelRegistryTests.swift
//  To Do ListTests
//

import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMModelRegistryTests: XCTestCase {
    private let qwenModelName = "mlx-community/Qwen3-0.6B-4bit"

    func testAvailableModelsContainsQwenPointSixB() {
        let modelNames = ModelConfiguration.availableModels.map(\.name)
        XCTAssertTrue(modelNames.contains(qwenModelName))
    }

    func testGetModelByNameReturnsQwenPointSixB() {
        let model = ModelConfiguration.getModelByName(qwenModelName)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.name, qwenModelName)
    }

    func testQwenPointSixBModelTypeIsReasoning() {
        let model = ModelConfiguration.getModelByName(qwenModelName)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.modelType, .reasoning)
    }

    func testQwenPointSixBModelSizeIsNonNilAndPositive() {
        let model = ModelConfiguration.getModelByName(qwenModelName)
        XCTAssertNotNil(model)
        XCTAssertNotNil(model?.modelSize)

        if let size = model?.modelSize {
            XCTAssertGreaterThan(size, 0)
        }
    }

    func testDefaultModelIsQwenPointSixB() {
        XCTAssertEqual(ModelConfiguration.defaultModel.name, qwenModelName)
    }
}
