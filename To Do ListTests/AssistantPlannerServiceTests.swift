import XCTest
import MLXLMCommon
@testable import To_Do_List

@MainActor
final class AssistantPlannerServiceTests: XCTestCase {
    private let qwenOptiQName = "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"

    func testGeneratePlanUsesResolvedRouteModel() async throws {
        let defaults = UserDefaults.standard
        let originalInstalledData = defaults.data(forKey: LLMPersistedModelSelection.installedModelsKey)
        let originalCurrentModelName = defaults.string(forKey: LLMPersistedModelSelection.currentModelKey)
        defer {
            if let originalInstalledData {
                defaults.set(originalInstalledData, forKey: LLMPersistedModelSelection.installedModelsKey)
            } else {
                defaults.removeObject(forKey: LLMPersistedModelSelection.installedModelsKey)
            }
            if let originalCurrentModelName {
                defaults.set(originalCurrentModelName, forKey: LLMPersistedModelSelection.currentModelKey)
            } else {
                defaults.removeObject(forKey: LLMPersistedModelSelection.currentModelKey)
            }
        }

        LLMPersistedModelSelection.persistInstalledModels([qwenOptiQName], defaults: defaults)
        defaults.set(qwenOptiQName, forKey: LLMPersistedModelSelection.currentModelKey)

        let evaluator = PlannerEvaluatorSpy()
        let service = AssistantPlannerService(llm: evaluator)
        let thread = To_Do_List.Thread()

        let result = await service.generatePlan(
            userPrompt: "Replan my week",
            thread: thread,
            contextPayload: "Context",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case let .success(plan) = result else {
            return XCTFail("Expected planner to succeed")
        }

        XCTAssertEqual(evaluator.capturedModelName, qwenOptiQName)
        XCTAssertEqual(plan.modelName, qwenOptiQName)
        XCTAssertEqual(evaluator.capturedRequestOptions?.chatMode, .answerOnly)
        XCTAssertEqual(evaluator.capturedRequestOptions?.effectiveModelType, .regular)
        XCTAssertFalse(evaluator.capturedRequestOptions?.allowThinking ?? true)
    }
}

@MainActor
private final class PlannerEvaluatorSpy: LLMEvaluator {
    var capturedModelName: String?
    var capturedRequestOptions: LLMGenerationRequestOptions?

    override func generate(
        modelName: String,
        thread: To_Do_List.Thread,
        systemPrompt: String,
        profile: LLMGenerationProfile = .chat,
        requestOptions: LLMGenerationRequestOptions? = nil,
        onFirstToken: (@MainActor () -> Void)? = nil
    ) async -> String {
        capturedModelName = modelName
        capturedRequestOptions = requestOptions

        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [.createTask(projectID: UUID(), title: "Create inbox note")],
            rationaleText: "Prepared proposed task updates."
        )
        let data = try! JSONEncoder().encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }
}
