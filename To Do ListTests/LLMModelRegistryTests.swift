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

    func testRouterUsesFastModelForTopThreeWhenFastModeEnabled() {
        let snapshot = AIRuntimeSnapshot(
            selectedModelName: nil,
            installedModels: [
                ModelConfiguration.qwen_3_0_6b_4bit.name,
                ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name
            ],
            availableMemoryGB: 8,
            userInterfaceIdiom: .phone,
            fastModeEnabled: true
        )

        let route = AIChatModeRouter.route(for: .topThree, snapshot: snapshot)

        XCTAssertEqual(route.selectedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
    }

    func testRouterKeepsPlanModeQualityModelWhenFastModeEnabled() {
        let snapshot = AIRuntimeSnapshot(
            selectedModelName: nil,
            installedModels: [
                ModelConfiguration.qwen_3_0_6b_4bit.name,
                ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name
            ],
            availableMemoryGB: 8,
            userInterfaceIdiom: .phone,
            fastModeEnabled: true
        )

        let route = AIChatModeRouter.route(for: .planMode, snapshot: snapshot)

        XCTAssertEqual(route.selectedModelName, ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name)
    }
}
