import XCTest
import MLXLMCommon
@testable import To_Do_List

@MainActor
final class AISuggestionServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "currentModelName")
        UserDefaults.standard.removeObject(forKey: "installedModels")
        UserDefaults.standard.removeObject(forKey: "feature.assistant.fast_mode")
    }

    func testSuggestFieldsParsesWrappedJSONAndClampsConfidence() async {
        configureInstalledModels([ModelConfiguration.qwen_3_0_6b_4bit.name])
        let service = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, _, _, _, _ in
                """
                Sure, here's the output:
                ```json
                {"priority":"high","energy":"high","type":"morning","context":"computer","rationale":"deadline language detected","confidence":1.7}
                ```
                """
            }
        )

        let suggestion = await service.suggestFields(
            for: "write annual report by Friday",
            projectName: "Work"
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.priority, .high)
        XCTAssertEqual(suggestion?.energy, .high)
        XCTAssertEqual(suggestion?.type, .morning)
        XCTAssertEqual(suggestion?.context, .computer)
        XCTAssertEqual(suggestion?.rationale, "deadline language detected")
        XCTAssertEqual(suggestion?.confidence, 1.0)
        XCTAssertEqual(suggestion?.modelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
    }

    func testSuggestFieldsFallsBackToHeuristicsWhenOutputInvalid() async {
        configureInstalledModels([ModelConfiguration.qwen_3_0_6b_4bit.name])
        let service = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, _, _, _, _ in "not valid json" }
        )

        let suggestion = await service.suggestFields(
            for: "call dentist tomorrow",
            projectName: "Personal"
        )

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.context, .phone)
        XCTAssertEqual(suggestion?.modelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(suggestion?.confidence ?? 0, 0.78, accuracy: 0.001)
    }

    func testChooseTopThreeFiltersUnknownIDsAndClampsConfidence() async {
        configureInstalledModels([ModelConfiguration.deepseek_r1_distill_qwen_1_5b_4bit.name])
        let validID = UUID()
        let tasks = [
            TaskDefinition(id: validID, title: "File expense report", priority: .high),
            TaskDefinition(id: UUID(), title: "Book dentist appointment", priority: .low),
            TaskDefinition(id: UUID(), title: "Review sprint board", priority: .low)
        ]

        let service = AISuggestionService(
            llm: LLMEvaluator(),
            generateOutput: { _, _, _, _, _ in
                """
                {"items":[
                    {"task_id":"\(validID.uuidString)","rationale":"due soon","confidence":1.4},
                    {"task_id":"\(UUID().uuidString)","rationale":"unknown","confidence":0.9}
                ]}
                """
            }
        )

        let suggestions = await service.chooseTopThree(from: tasks)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertEqual(suggestions.first?.taskID, validID)
        XCTAssertEqual(suggestions.first?.confidence, 1.0)
    }

    func testImmediateFieldSuggestionIsAvailableWithoutModel() {
        configureInstalledModels([])
        let service = AISuggestionService(llm: LLMEvaluator(), generateOutput: { _, _, _, _, _ in "" })

        let suggestion = service.immediateFieldSuggestion(for: "call pharmacy", projectName: "Personal")

        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.context, .phone)
        XCTAssertNil(suggestion?.modelName)
    }

    private func configureInstalledModels(_ models: [String]) {
        let data = try? JSONEncoder().encode(models)
        UserDefaults.standard.set(data, forKey: "installedModels")
        UserDefaults.standard.removeObject(forKey: "currentModelName")
    }
}

@MainActor
final class LLMEvaluatorGuardTests: XCTestCase {
    func testWarmupFailsFastWhenInferenceNotAllowed() async {
        let evaluator = LLMEvaluator(
            inferenceAllowedProvider: { false },
            appStateDescriptionProvider: { "background" }
        )

        let succeeded = await evaluator.warmup(modelName: ModelConfiguration.defaultModel.name)

        XCTAssertFalse(succeeded)
        XCTAssertTrue(evaluator.modelInfo.contains("Local AI is unavailable"))
        XCTAssertTrue(evaluator.modelInfo.contains("background"))
    }

    func testGenerateReturnsSafeFailureWhenInferenceNotAllowed() async {
        let evaluator = LLMEvaluator(
            inferenceAllowedProvider: { false },
            appStateDescriptionProvider: { "background" }
        )
        let thread = To_Do_List.Thread()
        thread.messages.append(Message(role: .user, content: "Hello", thread: thread))

        let output = await evaluator.generate(
            modelName: ModelConfiguration.defaultModel.name,
            thread: thread,
            systemPrompt: "You are a helpful assistant."
        )

        XCTAssertTrue(output.contains("Local AI is unavailable"))
        XCTAssertTrue(output.contains("background"))
    }
}
