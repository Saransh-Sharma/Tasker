import Foundation
import MLXLMCommon

enum AssistantPlannerError: LocalizedError {
    case noModelConfigured
    case generationFailed(String)
    case parseFailed(String)
    case pipelineUnavailable

    var errorDescription: String? {
        switch self {
        case .noModelConfigured:
            return "No local model is configured for plan mode."
        case let .generationFailed(message):
            return "Plan generation failed: \(message)"
        case let .parseFailed(message):
            return "Plan output could not be validated: \(message)"
        case .pipelineUnavailable:
            return "Assistant pipeline is unavailable."
        }
    }
}

struct AssistantPlanResult {
    let envelope: AssistantCommandEnvelope
    let rationale: String
    let diffLines: [AssistantDiffLine]
    let modelName: String
    let routeBanner: String?
    let shouldPromptDownload: Bool
}

@MainActor
final class AssistantPlannerService {
    private let llm: LLMEvaluator

    /// Initializes a new instance.
    init(llm: LLMEvaluator? = nil) {
        self.llm = llm ?? LLMRuntimeCoordinator.shared.evaluator
    }

    /// Executes generatePlan.
    func generatePlan(
        userPrompt: String,
        thread: Thread,
        contextPayload: String,
        taskTitleByID: [UUID: String],
        projectNameByID: [UUID: String],
        knownTaskIDs: Set<UUID>
    ) async -> Result<AssistantPlanResult, AssistantPlannerError> {
        let route = AIChatModeRouter.route(for: .planMode)
        guard
            let modelName = route.selectedModelName,
            let model = ModelConfiguration.getModelByName(modelName)
        else {
            return .failure(.noModelConfigured)
        }

        let systemPrompt = planSystemPrompt(contextPayload: contextPayload)
        let output = await llm.generate(
            modelName: model.name,
            thread: thread,
            systemPrompt: systemPrompt,
            profile: .chatPlanJSON,
            requestOptions: .structuredOutput(for: model)
        )

        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.generationFailed("empty_model_output"))
        }

        let validated = AssistantEnvelopeValidator.parseAndValidate(
            rawOutput: output,
            knownTaskIDs: knownTaskIDs
        )

        switch validated {
        case .failure(let error):
            return .failure(.parseFailed(error.localizedDescription))
        case .success(let envelope):
            let diffLines = AssistantDiffPreviewBuilder.build(
                commands: envelope.commands,
                taskTitleByID: taskTitleByID,
                projectNameByID: projectNameByID
            )
            return .success(
                AssistantPlanResult(
                    envelope: envelope,
                    rationale: envelope.rationaleText ?? "Prepared proposed task updates.",
                    diffLines: diffLines,
                    modelName: model.name,
                    routeBanner: route.bannerMessage,
                    shouldPromptDownload: route.shouldPromptDownload
                )
            )
        }
    }

    /// Executes planSystemPrompt.
    private func planSystemPrompt(contextPayload: String) -> String {
        """
        You are Eva in planning mode.
        Return ONLY valid JSON for AssistantCommandEnvelope.
        Never add markdown, prose, or code fences.

        JSON schema:
        {
          "schemaVersion": 2,
          "commands": [AssistantCommand],
          "rationaleText": "short rationale"
        }

        Requirements:
        - include at least one command
        - use only supported commands in the app
        - prefer safe, reversible actions

        \(contextPayload)
        """
    }
}
