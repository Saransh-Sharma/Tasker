//
//  LLMModelRegistryTests.swift
//  To Do ListTests
//

import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMModelRegistryTests: XCTestCase {
    private let qwenModelName = "mlx-community/Qwen3-0.6B-4bit"
    private var originalContextStrategy: LLMChatContextStrategy = .bounded

    override func setUp() {
        super.setUp()
        originalContextStrategy = V2FeatureFlags.llmChatContextStrategy
    }

    override func tearDown() {
        V2FeatureFlags.llmChatContextStrategy = originalContextStrategy
        super.tearDown()
    }

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

    func testQwenPointSixBIsPrewarmEligible() {
        let model = ModelConfiguration.getModelByName(qwenModelName)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.isPrewarmEligible(), true)
    }

    func testLlamaOneBIsNotPrewarmEligible() {
        let model = ModelConfiguration.llama_3_2_1b_4bit
        XCTAssertEqual(model.isPrewarmEligible(), false)
    }

    func testUnknownModelIsNotPrewarmEligible() {
        let unknown = ModelConfiguration(id: "mlx-community/Unknown-Model")
        XCTAssertEqual(unknown.isPrewarmEligible(), false)
    }

    func testPromptHistoryAppliesBoundedMessageBudget() {
        V2FeatureFlags.llmChatContextStrategy = .bounded
        let thread = To_Do_List.Thread()
        for idx in 0..<80 {
            let message = Message(role: idx % 2 == 0 ? .user : .assistant, content: "Message \(idx)", thread: thread)
            thread.messages.append(message)
        }

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        XCTAssertLessThanOrEqual(history.count, LLMChatBudgets.bounded.maxThreadMessages + 2)
        XCTAssertEqual(history.first?["role"], "system")
        XCTAssertTrue((history.dropFirst().first?["content"] ?? "").contains("Earlier context recap"))
    }

    func testPromptHistoryRetainsMoreMessagesInFullMode() {
        V2FeatureFlags.llmChatContextStrategy = .full
        let thread = To_Do_List.Thread()
        for idx in 0..<80 {
            let message = Message(role: idx % 2 == 0 ? .user : .assistant, content: "Message \(idx)", thread: thread)
            thread.messages.append(message)
        }

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        XCTAssertGreaterThan(history.count, 70)
    }

    func testPromptHistoryHardCapsCharacterBudget() {
        V2FeatureFlags.llmChatContextStrategy = .bounded
        let thread = To_Do_List.Thread()
        let suffix = "LATEST_SUFFIX_SHOULD_SURVIVE"
        let oversizedContent = String(repeating: "x", count: LLMChatBudgets.bounded.maxPromptChars * 2) + suffix
        let message = Message(role: .user, content: oversizedContent, thread: thread)
        thread.messages.append(message)

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        let totalChars = history.reduce(0) { partial, item in
            partial + (item["content"]?.count ?? 0)
        }

        XCTAssertLessThanOrEqual(totalChars, LLMChatBudgets.bounded.maxPromptChars)
        XCTAssertEqual(history.last?["role"], "user")
        XCTAssertTrue((history.last?["content"] ?? "").hasSuffix(suffix))
    }
}
