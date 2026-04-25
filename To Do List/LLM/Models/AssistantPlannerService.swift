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
    let proposalCards: [EvaProposalCard]
    let contextReceipt: EvaContextReceipt
    let modelName: String
    let routeBanner: String?
    let shouldPromptDownload: Bool
    let generationSource: String
    let usesModelGenerationForDeliveryGate: Bool
}

struct EvaTurnTraceContext: Equatable {
    let runID: UUID
    let threadID: UUID
    let route: EvaTurnRoute

    var logFields: [String: String] {
        [
            "run_id": runID.uuidString,
            "thread_id": threadID.uuidString,
            "route": String(describing: route)
        ]
    }
}

enum ChatMessageSaveStatus: String, Equatable {
    case persisted
    case emptySanitizedText = "empty_sanitized_text"
    case saveFailed = "save_failed"
}

struct ChatMessageSendOutcome: Equatable {
    let status: ChatMessageSaveStatus
    let messageID: UUID
    let role: String
    let contentType: String
    let preSanitizeLength: Int
    let postSanitizeLength: Int
    let threadID: UUID?
    let errorDescription: String?
}

enum EvaPlanResponseDropReason: String, Equatable {
    case runIDMismatch = "run_id_mismatch"
    case evaluatorCancelled = "evaluator_cancelled"
    case taskCancelled = "task_cancelled"
    case emptySanitizedText = "empty_sanitized_text"
    case saveFailed = "save_failed"
}

enum EvaPlanResponsePayload: Equatable {
    case text(content: String, sourceModelName: String?)
    case proposalCard(content: String, sourceModelName: String?)

    var content: String {
        switch self {
        case .text(let content, _), .proposalCard(let content, _):
            return content
        }
    }

    var sourceModelName: String? {
        switch self {
        case .text(_, let sourceModelName), .proposalCard(_, let sourceModelName):
            return sourceModelName
        }
    }

    var contentType: String {
        switch self {
        case .text:
            return "text"
        case .proposalCard:
            return "proposal_card"
        }
    }
}

enum EvaPlanResponseDeliveryResult: Equatable {
    case persisted(ChatMessageSendOutcome)
    case dropped(EvaPlanResponseDropReason)
}

struct EvaPlanResponseDelivery {
    struct GateState: Equatable {
        let taskCancelled: Bool
        let runIDMatches: Bool
        let evaluatorCancelled: Bool
    }

    static func textPayload(for plan: AssistantPlanResult) -> EvaPlanResponsePayload {
        let trimmedRationale = plan.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return .text(
            content: trimmedRationale.isEmpty ? "Tell me what you want to create, change, or review." : trimmedRationale,
            sourceModelName: plan.modelName
        )
    }

    @discardableResult
    static func deliver(
        payload: EvaPlanResponsePayload,
        traceContext: EvaTurnTraceContext,
        gateState: GateState,
        usesModelGenerationForDeliveryGate: Bool,
        send: (EvaPlanResponsePayload) -> ChatMessageSendOutcome,
        log: (_ event: String, _ message: String, _ fields: [String: String]) -> Void = { event, message, fields in
            logWarning(event: event, message: message, fields: fields)
        }
    ) -> EvaPlanResponseDeliveryResult {
        if gateState.runIDMatches == false {
            return drop(.runIDMismatch, payload: payload, traceContext: traceContext, log: log)
        }
        if gateState.taskCancelled {
            return drop(.taskCancelled, payload: payload, traceContext: traceContext, log: log)
        }
        if usesModelGenerationForDeliveryGate, gateState.evaluatorCancelled {
            return drop(.evaluatorCancelled, payload: payload, traceContext: traceContext, log: log)
        }

        log(
            "eva_plan_response_send_attempted",
            "Attempting to persist EVA planner response",
            traceContext.logFields.merging([
                "content_type": payload.contentType,
                "content_length": String(payload.content.count)
            ]) { _, new in new }
        )
        let outcome = send(payload)
        switch outcome.status {
        case .persisted:
            log(
                "eva_plan_response_persisted",
                "Persisted EVA planner response",
                traceContext.logFields.merging([
                    "content_type": payload.contentType,
                    "message_id": outcome.messageID.uuidString,
                    "pre_sanitize_length": String(outcome.preSanitizeLength),
                    "post_sanitize_length": String(outcome.postSanitizeLength)
                ]) { _, new in new }
            )
            return .persisted(outcome)
        case .emptySanitizedText:
            return drop(.emptySanitizedText, payload: payload, traceContext: traceContext, outcome: outcome, log: log)
        case .saveFailed:
            return drop(.saveFailed, payload: payload, traceContext: traceContext, outcome: outcome, log: log)
        }
    }

    private static func drop(
        _ reason: EvaPlanResponseDropReason,
        payload: EvaPlanResponsePayload,
        traceContext: EvaTurnTraceContext,
        outcome: ChatMessageSendOutcome? = nil,
        log: (_ event: String, _ message: String, _ fields: [String: String]) -> Void
    ) -> EvaPlanResponseDeliveryResult {
        var fields = traceContext.logFields
        fields["reason"] = reason.rawValue
        fields["content_type"] = payload.contentType
        fields["content_length"] = String(payload.content.count)
        if let outcome {
            fields["message_id"] = outcome.messageID.uuidString
            fields["pre_sanitize_length"] = String(outcome.preSanitizeLength)
            fields["post_sanitize_length"] = String(outcome.postSanitizeLength)
            if let errorDescription = outcome.errorDescription {
                fields["error"] = errorDescription
            }
        }
        log("eva_plan_response_drop", "Dropped EVA planner response", fields)
        return .dropped(reason)
    }
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
        knownTaskIDs: Set<UUID>,
        route explicitRoute: EvaTurnRoute? = nil,
        traceContext: EvaTurnTraceContext? = nil
    ) async -> Result<AssistantPlanResult, AssistantPlannerError> {
        let modelRoute = AIChatModeRouter.route(for: .planMode)
        let turnRoute = explicitRoute ?? EvaTurnRouter.route(for: userPrompt)
        let contextTaskTitleByID = AssistantDeterministicPlanner.taskTitleByID(from: contextPayload)
        let effectiveTaskTitleByID = contextTaskTitleByID.merging(taskTitleByID) { _, explicit in explicit }
        let effectiveKnownTaskIDs = knownTaskIDs.isEmpty ? Set(contextTaskTitleByID.keys) : knownTaskIDs
        let fallbackContext = AssistantDeterministicPlanner.Context(
            userPrompt: userPrompt,
            contextPayload: contextPayload,
            taskTitleByID: effectiveTaskTitleByID,
            projectNameByID: projectNameByID,
            knownTaskIDs: effectiveKnownTaskIDs,
            now: Date()
        )
        let intent = EvaPlannerIntent.classify(userPrompt, route: turnRoute)
        let contextPolicy = EvaContextPolicy.evaluate(route: turnRoute, contextPayload: contextPayload)
        let requiredContextMissing = contextPolicy.requiredContextReady == false

        if turnRoute == .habitMutation {
            let output = AssistantDeterministicPlanner.habitClarificationPlan(for: userPrompt)
            return .success(buildResult(
                envelope: output.envelope,
                proposalCards: output.cards,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_habit_guard",
                route: modelRoute,
                generationSource: "deterministic_habit_guard",
                traceContext: traceContext
            ))
        }

        if intent == .readOnlyReview {
            let output = AssistantDeterministicPlanner.reviewPlan(
                context: fallbackContext,
                contextIsPartial: requiredContextMissing
            )
            return .success(buildResult(
                envelope: output.envelope,
                proposalCards: output.cards,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_intent_gate",
                route: modelRoute,
                generationSource: "deterministic_intent_gate",
                traceContext: traceContext
            ))
        }

        if let fallback = AssistantDeterministicPlanner.plan(context: fallbackContext) {
            return .success(buildResult(
                envelope: fallback.envelope,
                proposalCards: fallback.cards,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_intent_gate",
                route: modelRoute,
                generationSource: "deterministic_intent_gate",
                traceContext: traceContext
            ))
        }

        if intent == .ambiguous || (intent == .explicitUpdate && effectiveKnownTaskIDs.isEmpty) {
            let output = AssistantDeterministicPlanner.clarificationPlan(for: userPrompt)
            return .success(buildResult(
                envelope: output.envelope,
                proposalCards: output.cards,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_intent_gate",
                route: modelRoute,
                generationSource: "deterministic_intent_gate",
                traceContext: traceContext
            ))
        }

        guard
            let modelName = modelRoute.selectedModelName,
            let model = ModelConfiguration.getModelByName(modelName)
        else {
            return .failure(.noModelConfigured)
        }

        let systemPrompt = planSystemPrompt()
        let plannerThread = cleanPlannerThread(userPrompt: userPrompt, contextPayload: contextPayload)
        logWarning(
            event: "eva_plan_started",
            message: "Started EVA plan generation",
            fields: traceFields(traceContext, [
                "model": model.name,
                "prompt_chars": String(userPrompt.count),
                "context_chars": String(contextPayload.count),
                "clean_thread_message_count": String(plannerThread.messages.count),
                "known_task_count": String(effectiveKnownTaskIDs.count)
            ])
        )
        let output = await llm.generate(
            modelName: model.name,
            thread: plannerThread,
            systemPrompt: systemPrompt,
            profile: .chatPlanJSON,
            requestOptions: .structuredOutput(for: model)
        )

        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.generationFailed("empty_model_output"))
        }

        logJSONShape(rawOutput: output, stage: "model", traceContext: traceContext)
        let validated = AssistantEnvelopeValidator.parseAndValidateDetailed(
            rawOutput: output,
            knownTaskIDs: effectiveKnownTaskIDs,
            allowEmptyCommands: true
        )

        switch validated {
        case .failure(let error):
            logWarning(
                event: "eva_plan_parse_failed",
                message: "EVA plan output failed validation",
                fields: traceFields(traceContext, [
                    "error": error.localizedDescription,
                    "json_shape": AssistantEnvelopeValidator.jsonShape(rawOutput: output).rawValue,
                    "top_level_keys": AssistantEnvelopeValidator.topLevelKeys(rawOutput: output).joined(separator: ","),
                    "raw_preview": LoggingService.previewText(output, maxLength: 220).replacingOccurrences(of: "\n", with: "\\n")
                ])
            )
            if let repaired = await repairPlanOutput(
                rawOutput: output,
                userPrompt: userPrompt,
                contextPayload: contextPayload,
                model: model,
                knownTaskIDs: effectiveKnownTaskIDs,
                intent: intent,
                traceContext: traceContext
            ) {
                logSingleCommandWrappedIfNeeded(repaired, stage: "repair", traceContext: traceContext)
                return .success(buildResult(
                    envelope: repaired.envelope,
                    proposalCards: EvaProposalCardBuilder.build(commands: repaired.envelope.commands, taskTitleByID: effectiveTaskTitleByID),
                    taskTitleByID: effectiveTaskTitleByID,
                    projectNameByID: projectNameByID,
                    modelName: model.name,
                    route: modelRoute,
                    generationSource: repaired.didNormalize ? "repair_normalized" : "repair",
                    traceContext: traceContext
                ))
            }
            logWarning(
                event: "eva_plan_fallback_attempted",
                message: "Attempting deterministic EVA plan fallback",
                fields: traceFields(traceContext, [
                    "prompt_chars": String(userPrompt.count),
                    "context_task_count": String(contextTaskTitleByID.count)
                ])
            )
            if let fallback = AssistantDeterministicPlanner.plan(context: fallbackContext) {
                return .success(buildResult(
                    envelope: fallback.envelope,
                    proposalCards: fallback.cards,
                    taskTitleByID: effectiveTaskTitleByID,
                    projectNameByID: projectNameByID,
                    modelName: model.name,
                    route: modelRoute,
                    generationSource: "deterministic_fallback",
                    traceContext: traceContext
                ))
            }
            logWarning(
                event: "eva_plan_fallback_failed",
                message: "Deterministic EVA plan fallback could not parse prompt",
                fields: traceFields(traceContext, ["prompt_preview": LoggingService.previewText(userPrompt, maxLength: 180)])
            )
            logWarning(
                event: "eva_plan_failure_final",
                message: "EVA plan generation failed after model, repair, and deterministic fallback",
                fields: traceFields(traceContext, ["error": error.localizedDescription])
            )
            return .failure(.parseFailed(error.localizedDescription))
        case .success(let parsed):
            guard let grounded = groundedEnvelope(
                parsed.envelope,
                userPrompt: userPrompt,
                intent: intent,
                knownTaskIDs: effectiveKnownTaskIDs
            ) else {
                logWarning(
                    event: "eva_plan_grounding_rejected",
                    message: "Rejected EVA plan output that was not grounded in the user prompt or context",
                    fields: traceFields(traceContext, [
                        "command_count": String(parsed.envelope.commands.count),
                        "prompt_preview": LoggingService.previewText(userPrompt, maxLength: 180)
                    ])
                )
                let output = AssistantDeterministicPlanner.clarificationPlan(for: userPrompt)
                return .success(buildResult(
                    envelope: output.envelope,
                    proposalCards: output.cards,
                    taskTitleByID: effectiveTaskTitleByID,
                    projectNameByID: projectNameByID,
                    modelName: model.name,
                    route: modelRoute,
                    generationSource: "grounding_rejected",
                    traceContext: traceContext
                ))
            }
            logSingleCommandWrappedIfNeeded(parsed, stage: "model", traceContext: traceContext)
            return .success(buildResult(
                envelope: grounded,
                proposalCards: EvaProposalCardBuilder.build(commands: grounded.commands, taskTitleByID: effectiveTaskTitleByID),
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: model.name,
                route: modelRoute,
                generationSource: parsed.didNormalize ? "model_normalized" : "model",
                traceContext: traceContext
            ))
        }
    }

    /// Executes planSystemPrompt.
    private func planSystemPrompt() -> String {
        """
        You are Eva in planning mode.
        Return ONLY valid JSON for AssistantCommandEnvelope.
        Never add markdown, prose, or code fences.
        Never return a bare command object. The top-level JSON object must contain "schemaVersion", "commands", and "rationaleText".
        Every command inside "commands" MUST include a "type" field.
        All dates MUST be ISO-8601 strings.
        Never copy titles or IDs from examples. Titles must come from user_prompt. Task IDs must come from Context JSON only.
        If the user asks to review, summarize, list, or choose tasks without requesting a change, return an empty commands array with a useful rationaleText.
        If the user request is ambiguous, return an empty commands array and ask for the missing details in rationaleText.

        Scheduled-task envelope shape:
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "createScheduledTask",
              "projectID": "00000000-0000-0000-0000-000000000001",
              "title": "<title from user_prompt>",
              "scheduledStartAt": "2026-04-24T10:00:00Z",
              "scheduledEndAt": "2026-04-24T10:45:00Z",
              "estimatedDuration": 2700,
              "tagIDs": []
            }
          ],
          "rationaleText": "short rationale"
        }

        Inbox envelope example:
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "createInboxTask",
              "projectID": "00000000-0000-0000-0000-000000000001",
              "title": "<untimed title from user_prompt>",
              "estimatedDuration": null,
              "tagIDs": []
            }
          ],
          "rationaleText": "I added these to your Inbox for review."
        }

        Update envelope example:
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "updateTaskSchedule",
              "taskID": "<task id from context>",
              "scheduledStartAt": "2026-04-24T16:00:00Z",
              "scheduledEndAt": "2026-04-24T16:30:00Z",
              "estimatedDuration": 1800,
              "dueDate": "2026-04-24T16:00:00Z"
            }
          ],
          "rationaleText": "I moved the matching task for review."
        }

        No-change envelope:
        {
          "schemaVersion": 3,
          "commands": [],
          "rationaleText": "I need the task title and time before I can create a scheduled plan."
        }

        Rules:
        - timed tasks use createScheduledTask
        - untimed capture uses createInboxTask
        - existing schedule changes use updateTaskSchedule with task IDs from context only
        - read-only review questions must use commands: []
        - do not invent any title that is not in user_prompt
        - do not answer conversationally
        """
    }

    private func cleanPlannerThread(userPrompt: String, contextPayload: String) -> Thread {
        let thread = Thread()
        let now = Date()
        let body = """
        current_time: \(now.ISO8601Format())
        selected_day: \(Calendar.current.startOfDay(for: now).ISO8601Format())
        user_prompt:
        \(userPrompt)

        \(contextPayload)
        """
        thread.messages.append(Message(role: .user, content: body, thread: thread))
        return thread
    }

    private func repairPlanOutput(
        rawOutput: String,
        userPrompt: String,
        contextPayload: String,
        model: ModelConfiguration,
        knownTaskIDs: Set<UUID>,
        intent: EvaPlannerIntent,
        traceContext: EvaTurnTraceContext?
    ) async -> AssistantEnvelopeValidator.ParsedEnvelope? {
        let thread = Thread()
        let prompt = """
        The previous output was not a valid AssistantCommandEnvelope.
        Convert it to ONLY a full AssistantCommandEnvelope JSON object. Do not return a bare command object. If it cannot be converted, return a full envelope containing createInboxTask commands for explicit untimed tasks or createScheduledTask commands for explicit timed tasks.

        user_prompt:
        \(userPrompt)

        invalid_output:
        \(LoggingService.previewText(rawOutput, maxLength: 1_200))

        \(contextPayload)
        """
        thread.messages.append(Message(role: .user, content: prompt, thread: thread))
        let output = await llm.generate(
            modelName: model.name,
            thread: thread,
            systemPrompt: planSystemPrompt(),
            profile: .chatPlanJSON,
            requestOptions: .structuredOutput(for: model)
        )
        logJSONShape(rawOutput: output, stage: "repair", traceContext: traceContext)
        let parsed = AssistantEnvelopeValidator.parseAndValidateDetailed(
            rawOutput: output,
            knownTaskIDs: knownTaskIDs,
            allowEmptyCommands: true
        )
        guard case .success(let parsedEnvelope) = parsed,
              groundedEnvelope(
                parsedEnvelope.envelope,
                userPrompt: userPrompt,
                intent: intent,
                knownTaskIDs: knownTaskIDs
              ) != nil else {
            logWarning(
                event: "eva_plan_repair_failed",
                message: "EVA plan repair output failed validation",
                fields: traceFields(traceContext, [
                    "json_shape": AssistantEnvelopeValidator.jsonShape(rawOutput: output).rawValue,
                    "top_level_keys": AssistantEnvelopeValidator.topLevelKeys(rawOutput: output).joined(separator: ","),
                    "raw_preview": LoggingService.previewText(output, maxLength: 220).replacingOccurrences(of: "\n", with: "\\n")
                ])
            )
            return nil
        }
        return parsedEnvelope
    }

    private func groundedEnvelope(
        _ envelope: AssistantCommandEnvelope,
        userPrompt: String,
        intent: EvaPlannerIntent,
        knownTaskIDs: Set<UUID>
    ) -> AssistantCommandEnvelope? {
        if intent == .readOnlyReview {
            return envelope.commands.isEmpty ? envelope : nil
        }
        if intent == .ambiguous, envelope.commands.isEmpty == false {
            return nil
        }

        for command in envelope.commands {
            switch command {
            case .createTask(_, let title):
                guard EvaPlannerGrounding.title(title, isGroundedIn: userPrompt) else { return nil }
            case .createInboxTask(_, let title, _, _, _, _, _, _):
                guard EvaPlannerGrounding.title(title, isGroundedIn: userPrompt) else { return nil }
            case .createScheduledTask(_, let title, _, _, _, _, _, _, _, _, _, _):
                guard EvaPlannerGrounding.title(title, isGroundedIn: userPrompt),
                      EvaPlannerGrounding.promptMentionsTime(userPrompt) else {
                    return nil
                }
            default:
                guard let referencedTaskID = EvaPlannerGrounding.referencedTaskID(for: command),
                      knownTaskIDs.contains(referencedTaskID) else {
                    return nil
                }
            }
        }

        return envelope
    }

    private func buildResult(
        envelope: AssistantCommandEnvelope,
        proposalCards: [EvaProposalCard],
        taskTitleByID: [UUID: String],
        projectNameByID: [UUID: String],
        modelName: String,
        route: AIModelRoute,
        generationSource: String,
        traceContext: EvaTurnTraceContext? = nil
    ) -> AssistantPlanResult {
        logWarning(
            event: "eva_plan_generated",
            message: "EVA plan generated",
            fields: traceFields(traceContext, [
                "source": generationSource,
                "command_count": String(envelope.commands.count)
            ])
        )
        return AssistantPlanResult(
            envelope: envelope,
            rationale: envelope.rationaleText ?? "Prepared proposed task updates.",
            diffLines: AssistantDiffPreviewBuilder.build(
                commands: envelope.commands,
                taskTitleByID: taskTitleByID,
                projectNameByID: projectNameByID
            ),
            proposalCards: proposalCards,
            contextReceipt: EvaContextReceipt(sources: ["Today timeline", "Inbox", "Projects", "Habits", "Calendar"]),
            modelName: modelName,
            routeBanner: route.bannerMessage,
            shouldPromptDownload: route.shouldPromptDownload,
            generationSource: generationSource,
            usesModelGenerationForDeliveryGate: Self.usesModelGenerationForDeliveryGate(source: generationSource)
        )
    }

    private func logJSONShape(rawOutput: String, stage: String, traceContext: EvaTurnTraceContext?) {
        logWarning(
            event: "eva_plan_json_shape_detected",
            message: "Detected EVA plan JSON output shape",
            fields: traceFields(traceContext, [
                "stage": stage,
                "json_shape": AssistantEnvelopeValidator.jsonShape(rawOutput: rawOutput).rawValue,
                "top_level_keys": AssistantEnvelopeValidator.topLevelKeys(rawOutput: rawOutput).joined(separator: ",")
            ])
        )
    }

    private func logSingleCommandWrappedIfNeeded(
        _ parsed: AssistantEnvelopeValidator.ParsedEnvelope,
        stage: String,
        traceContext: EvaTurnTraceContext?
    ) {
        guard parsed.didNormalize else { return }
        guard parsed.jsonShape == .bareCommand || parsed.jsonShape == .commandArray || parsed.jsonShape == .commandsWithoutSchema else { return }
        let commandType: String
        if let first = parsed.envelope.commands.first {
            commandType = String(describing: first).components(separatedBy: "(").first ?? "unknown"
        } else {
            commandType = "none"
        }
        logWarning(
            event: "eva_plan_single_command_wrapped",
            message: "Wrapped non-envelope EVA plan output into schema v3 envelope",
            fields: traceFields(traceContext, [
                "stage": stage,
                "json_shape": parsed.jsonShape.rawValue,
                "command_type": commandType
            ])
        )
    }

    private func traceFields(_ traceContext: EvaTurnTraceContext?, _ fields: [String: String]) -> [String: String] {
        guard let traceContext else { return fields }
        return traceContext.logFields.merging(fields) { _, new in new }
    }

    private static func usesModelGenerationForDeliveryGate(source: String) -> Bool {
        switch source {
        case "model", "model_normalized", "repair", "repair_normalized":
            return true
        default:
            return false
        }
    }
}

enum EvaTurnRoute: Equatable {
    case chatAnswer
    case readOnlyReview
    case taskMutation
    case habitMutation
    case dayPlanning
    case weeklyPlanning
    case clarification
}

enum EvaTurnRouter {
    static func route(for prompt: String) -> EvaTurnRoute {
        let lower = normalized(prompt)
        guard lower.isEmpty == false else { return .clarification }

        let readOnlyMarkers = [
            "what are my tasks",
            "what tasks",
            "review my day",
            "review the day",
            "what should i focus",
            "what shall i focus",
            "what do i have",
            "show me my tasks",
            "list my tasks",
            "how is my day",
            "what's on my plate",
            "whats on my plate"
        ]
        if readOnlyMarkers.contains(where: { lower.contains($0) }) {
            return .readOnlyReview
        }

        let habitMarkers = ["habit", "habits", "streak", "check in", "check-in", "pause habit", "resume habit"]
        let mutationMarkers = [
            "add", "create", "schedule", "make", "write", "plan", "move", "reschedule", "defer",
            "drop", "mark", "rename", "complete", "shift", "pause", "resume", "log"
        ]
        if habitMarkers.contains(where: { lower.contains($0) }) &&
            mutationMarkers.contains(where: { containsWord(lower, $0) }) {
            return .habitMutation
        }

        if lower.contains("week") && (lower.contains("plan") || lower.contains("review")) {
            return .weeklyPlanning
        }

        if lower.contains("help me plan my day")
            || lower.contains("plan my day")
            || lower.contains("plan today")
            || lower.contains("plan tomorrow")
            || lower.contains("review today") {
            return .dayPlanning
        }

        let updateMarkers = [
            "move", "reschedule", "defer", "drop", "mark", "rename", "complete", "running late", "shift"
        ]
        if updateMarkers.contains(where: { containsWord(lower, $0) || lower.contains($0) }) {
            return .taskMutation
        }

        if mentionsTime(lower) && lower.contains("?") == false {
            return .taskMutation
        }

        if lower.contains("help me plan making")
            || lower.contains("help me plan writing") {
            return .taskMutation
        }

        let createMarkers = ["add", "create", "schedule", "make", "write"]
        if createMarkers.contains(where: { containsWord(lower, $0) && hasConcreteCreateObject(after: $0, in: lower) }) {
            return .taskMutation
        }

        return .chatAnswer
    }

    private static func normalized(_ prompt: String) -> String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func containsWord(_ text: String, _ word: String) -> Bool {
        guard word.contains(" ") == false else {
            return text.contains(word)
        }
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return text.range(of: #"(?<![a-z0-9])\#(escaped)(?![a-z0-9])"#, options: .regularExpression) != nil
    }

    private static func hasConcreteCreateObject(after marker: String, in text: String) -> Bool {
        guard let range = text.range(of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: marker))(?![a-z0-9])"#, options: .regularExpression) else {
            return false
        }
        var trimSet = CharacterSet.whitespacesAndNewlines
        trimSet.formUnion(.punctuationCharacters)
        let trailing = text[range.upperBound...]
            .replacingOccurrences(of: #"^(?:\s+(?:a|an|the|task|todo|to-do|item|event|reminder|plan|for|me|please))+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: trimSet)
        let genericObjects = ["", "task", "todo", "to-do", "item", "event", "reminder", "plan", "something", "anything"]
        return genericObjects.contains(trailing) == false && trailing.count > 1
    }

    private static func mentionsTime(_ text: String) -> Bool {
        let pattern = #"\b\d{1,2}(?::\d{2})?\s*(am|pm)\b|\bfor\s+\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

enum EvaContextPolicy {
    struct Result: Equatable {
        let requiredContextReady: Bool
        let optionalContextPartial: Bool
    }

    static func evaluate(route: EvaTurnRoute, contextPayload: String) -> Result {
        let isPartial = EvaPlannerContextInspector.isPartial(contextPayload)
        let context = ContextShape(payload: contextPayload)

        switch route {
        case .readOnlyReview, .dayPlanning:
            return Result(
                requiredContextReady: context.missingService == false
                    && context.todayTimedOut == false
                    && (context.hasToday || context.hasInbox || isPartial == false),
                optionalContextPartial: isPartial && (context.overdueTimedOut || context.upcomingTimedOut)
            )
        case .weeklyPlanning:
            return Result(
                requiredContextReady: context.missingService == false
                    && context.upcomingTimedOut == false
                    && (context.hasUpcoming || isPartial == false),
                optionalContextPartial: isPartial && context.hasToday
            )
        case .habitMutation:
            return Result(
                requiredContextReady: context.missingService == false
                    && (context.hasHabit || isPartial == false),
                optionalContextPartial: isPartial
            )
        case .taskMutation, .clarification, .chatAnswer:
            return Result(requiredContextReady: true, optionalContextPartial: isPartial)
        }
    }

    private struct ContextShape {
        let hasToday: Bool
        let hasInbox: Bool
        let hasUpcoming: Bool
        let hasHabit: Bool
        let missingService: Bool
        let todayTimedOut: Bool
        let overdueTimedOut: Bool
        let upcomingTimedOut: Bool

        init(payload: String) {
            let object = Self.decode(payload)
            hasToday = Self.hasSection(named: "today", in: object)
            hasInbox = Self.hasSection(named: "inbox", in: object)
            hasUpcoming = Self.hasSection(named: "upcoming", in: object)
            hasHabit = Self.hasSection(named: "habits", in: object) || Self.hasSection(named: "habit", in: object)

            let partialFlags = object["partial_flags"] as? [String: Any]
            let metadata = object["metadata"] as? [String: Any]
            let reasons = (metadata?["partial_reasons"] as? [String]) ?? []
            missingService = Self.boolValue(partialFlags?["missing_service"]) || reasons.contains("missing_service")
            todayTimedOut = Self.boolValue(partialFlags?["today_timed_out"]) || reasons.contains("today_timeout")
            overdueTimedOut = Self.boolValue(partialFlags?["overdue_timed_out"]) || reasons.contains("overdue_timeout")
            upcomingTimedOut = Self.boolValue(partialFlags?["upcoming_timed_out"]) || reasons.contains("upcoming_timeout")
        }

        private static func decode(_ payload: String) -> [String: Any] {
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: []),
                  let dictionary = object as? [String: Any] else {
                return [:]
            }
            return dictionary
        }

        private static func hasSection(named key: String, in object: [String: Any]) -> Bool {
            guard let section = object[key] else { return false }
            if section is NSNull { return false }
            return true
        }

        private static func boolValue(_ value: Any?) -> Bool {
            if let value = value as? Bool { return value }
            if let value = value as? NSNumber { return value.boolValue }
            if let value = value as? String { return value.lowercased() == "true" }
            return false
        }
    }
}

enum EvaPlannerIntent: Equatable {
    case readOnlyReview
    case explicitCreate
    case explicitUpdate
    case ambiguous

    static func classify(_ prompt: String, route: EvaTurnRoute? = nil) -> EvaPlannerIntent {
        if let route {
            switch route {
            case .readOnlyReview:
                return .readOnlyReview
            case .taskMutation, .habitMutation, .dayPlanning, .weeklyPlanning:
                break
            case .chatAnswer, .clarification:
                return .ambiguous
            }
        }

        let lower = prompt.lowercased()
        let readOnlyMarkers = [
            "what are my tasks",
            "what tasks",
            "review my day",
            "review the day",
            "what should i focus",
            "what shall i focus",
            "what do i have",
            "show me my tasks",
            "list my tasks"
        ]
        if readOnlyMarkers.contains(where: { lower.contains($0) }) {
            return .readOnlyReview
        }

        let updateMarkers = [
            "move ",
            "reschedule ",
            "defer ",
            "drop ",
            "mark ",
            "rename ",
            "complete ",
            "running late",
            "shift "
        ]
        if updateMarkers.contains(where: { lower.contains($0) }) {
            return .explicitUpdate
        }

        let createMarkers = [
            "add ",
            "create ",
            "schedule ",
            "make ",
            "write "
        ]
        if lower.contains("help me plan making")
            || lower.contains("help me plan writing")
            || createMarkers.contains(where: { marker in
                let word = marker.trimmingCharacters(in: .whitespaces)
                return (lower.contains(marker) || lower.hasPrefix(word)) &&
                    hasConcreteCreateObject(after: word, in: lower)
            }) {
            return .explicitCreate
        }

        return .ambiguous
    }

    private static func hasConcreteCreateObject(after marker: String, in text: String) -> Bool {
        guard let range = text.range(of: #"(?<![a-z0-9])\#(NSRegularExpression.escapedPattern(for: marker))(?![a-z0-9])"#, options: .regularExpression) else {
            return false
        }
        var trimSet = CharacterSet.whitespacesAndNewlines
        trimSet.formUnion(.punctuationCharacters)
        let trailing = text[range.upperBound...]
            .replacingOccurrences(of: #"^(?:\s+(?:a|an|the|task|todo|to-do|item|event|reminder|plan|for|me|please))+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: trimSet)
        let genericObjects = ["", "task", "todo", "to-do", "item", "event", "reminder", "plan", "something", "anything"]
        return genericObjects.contains(trailing) == false && trailing.count > 1
    }
}

enum EvaPlannerContextInspector {
    static func isPartial(_ contextPayload: String) -> Bool {
        let lower = contextPayload.lowercased()
        if lower.contains("status: partial") || lower.contains(#""context_partial":true"#) {
            return true
        }
        return false
    }
}

enum EvaPlannerGrounding {
    private static let stopWords: Set<String> = [
        "a", "an", "and", "at", "for", "from", "help", "in", "into", "later", "make", "making",
        "me", "my", "of", "on", "plan", "please", "schedule", "task", "tasks", "the", "to",
        "today", "tomorrow", "write", "writing"
    ]

    static func title(_ title: String, isGroundedIn prompt: String) -> Bool {
        let titleTokens = semanticTokens(title)
        guard titleTokens.isEmpty == false else { return false }
        let promptTokens = semanticTokens(prompt)
        return titleTokens.contains(where: { promptTokens.contains($0) })
    }

    static func promptMentionsTime(_ prompt: String) -> Bool {
        let pattern = #"(?i)\b\d{1,2}(?::\d{2})?\s*(am|pm)\b|\bfor\s+\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#
        return prompt.range(of: pattern, options: .regularExpression) != nil
    }

    static func referencedTaskID(for command: AssistantCommand) -> UUID? {
        switch command {
        case .createTask, .createScheduledTask, .createInboxTask:
            return nil
        case let .restoreTask(taskID, _, _, _, _, _):
            return taskID
        case let .restoreTaskSnapshot(snapshot):
            return snapshot.id
        case let .deleteTask(taskID):
            return taskID
        case let .updateTask(taskID, _, _):
            return taskID
        case let .setTaskCompletion(taskID, _, _):
            return taskID
        case let .completeTask(taskID):
            return taskID
        case let .moveTask(taskID, _):
            return taskID
        case let .updateTaskSchedule(taskID, _, _, _, _):
            return taskID
        case let .updateTaskFields(taskID, _, _, _, _, _, _, _, _):
            return taskID
        case let .deferTask(taskID, _, _):
            return taskID
        case let .dropTaskFromToday(taskID, _, _):
            return taskID
        }
    }

    private static func semanticTokens(_ text: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            text.lowercased()
                .components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 3 && stopWords.contains($0) == false }
        )
    }
}

struct AssistantDeterministicPlanner {
    struct Context {
        let userPrompt: String
        let contextPayload: String
        let taskTitleByID: [UUID: String]
        let projectNameByID: [UUID: String]
        let knownTaskIDs: Set<UUID>
        let now: Date
    }

    struct Output {
        let envelope: AssistantCommandEnvelope
        let cards: [EvaProposalCard]
    }

    private struct ContextTask {
        let id: UUID
        let title: String
        let scheduledStartAt: Date?
        let scheduledEndAt: Date?
        let isCompleted: Bool
    }

    private struct TimedTaskSpec: Hashable {
        let title: String
        let start: Date
        let duration: TimeInterval
    }

    static func taskTitleByID(from contextPayload: String) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: extractContextTasks(from: contextPayload).map { ($0.id, $0.title) })
    }

    static func reviewPlan(context: Context, contextIsPartial: Bool) -> Output {
        let message: String
        if contextIsPartial {
            message = "I couldn't load your tasks right now, so I won't invent a plan. Try again once task context is available."
        } else {
            let openTasks = extractContextTasks(from: context.contextPayload)
                .filter { $0.isCompleted == false }
                .prefix(6)
                .map(\.title)
            if openTasks.isEmpty {
                message = "I didn't find open tasks in the available context for today."
            } else {
                message = "I found these open tasks: \(openTasks.joined(separator: ", "))."
            }
        }
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [EvaProposalCardBuilder.noOpCard(title: "Review only", subtitle: message)]
        )
    }

    static func clarificationPlan(for prompt: String) -> Output {
        let message = "Tell me the task title, and add a time if it belongs on your timeline."
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [EvaProposalCardBuilder.noOpCard(title: "Needs more detail", subtitle: message)]
        )
    }

    static func habitClarificationPlan(for prompt: String) -> Output {
        let message = "I can review habits and include them in planning, but habit changes are not applyable from this EVA card yet. Tell me if you want a task added to support that habit."
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [EvaProposalCardBuilder.noOpCard(title: "Habit review only", subtitle: message)]
        )
    }

    static func plan(context: Context) -> Output? {
        let prompt = context.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return nil }
        let tasks = extractContextTasks(from: context.contextPayload)
        let titleByID = context.taskTitleByID.merging(Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })) { current, _ in current }

        if let timed = timedCreatePlan(prompt: prompt, now: context.now, projectID: defaultProjectID(projectNameByID: context.projectNameByID)) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: timed,
                rationaleText: "Here's how your day is planned:"
            )
            return Output(envelope: envelope, cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID))
        }

        if let inbox = inboxPlan(prompt: prompt) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: inbox.map {
                    .createInboxTask(projectID: ProjectConstants.inboxProjectID, title: $0, estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
                },
                rationaleText: "Here's how your day is planned:"
            )
            return Output(envelope: envelope, cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID))
        }

        if let untimed = untimedCreatePlan(prompt: prompt) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: untimed.map {
                    .createInboxTask(projectID: ProjectConstants.inboxProjectID, title: $0, estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
                },
                rationaleText: "I added this to your Inbox for review."
            )
            return Output(envelope: envelope, cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID))
        }

        if let edit = editPlan(prompt: prompt, tasks: tasks, now: context.now) {
            let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [edit], rationaleText: "Here's how your day is planned:")
            return Output(envelope: envelope, cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID))
        }

        if prompt.localizedCaseInsensitiveContains("late") || prompt.localizedCaseInsensitiveContains("shift") {
            let futureTasks = tasks.filter { task in
                task.isCompleted == false && (task.scheduledStartAt ?? .distantPast) > context.now
            }
            if futureTasks.isEmpty {
                let message = "I checked the rest of today and did not find uncompleted scheduled tasks to move."
                let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
                return Output(
                    envelope: envelope,
                    cards: [EvaProposalCardBuilder.noOpCard(title: "No matching tasks found", subtitle: message)]
                )
            }
        }

        if prompt.localizedCaseInsensitiveContains("help me plan") || prompt.localizedCaseInsensitiveContains("plan my day") {
            let message = "Tell me your timed plans or add a list for Inbox, and EVA will turn them into review cards."
            let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
            return Output(
                envelope: envelope,
                cards: [EvaProposalCardBuilder.noOpCard(title: "Tell me your plans", subtitle: message)]
            )
        }

        return nil
    }

    private static func untimedCreatePlan(prompt: String) -> [String]? {
        let lower = prompt.lowercased()
        let genericPlanningPrompts = [
            "help me plan my day",
            "plan my day",
            "plan today",
            "what shall i focus",
            "what should i focus"
        ]
        if genericPlanningPrompts.contains(where: { lower.trimmingCharacters(in: .whitespacesAndNewlines) == $0 }) {
            return nil
        }
        guard lower.contains("help me plan")
            || lower.contains("make ")
            || lower.contains("write ")
            || lower.contains("create ")
            || lower.contains("add ")
            || lower.contains("plan ") else {
            return nil
        }

        let stripped = prompt
            .replacingOccurrences(
                of: #"(?i)^\s*(please\s+)?(can you\s+)?(help me\s+)?(plan|make|write|create|add)\s+(making\s+|writing\s+)?"#,
                with: "",
                options: .regularExpression
            )
        let title = cleanTitle(stripped)
        guard title.count > 1 else { return nil }
        return [title]
    }

    private static func inboxPlan(prompt: String) -> [String]? {
        let lower = prompt.lowercased()
        guard lower.contains("inbox"), lower.contains("not inbox") == false else { return nil }
        let source: String
        if let colon = prompt.firstIndex(of: ":") {
            source = String(prompt[prompt.index(after: colon)...])
        } else {
            source = prompt
                .replacingOccurrences(of: "add these to my inbox", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "add to my inbox", with: "", options: .caseInsensitive)
        }
        let normalized = source
            .replacingOccurrences(of: " and ", with: ", ", options: .caseInsensitive)
            .replacingOccurrences(of: "\n", with: ", ")
        let items = normalized
            .split(separator: ",")
            .map { cleanTitle(String($0)) }
            .filter { $0.count > 1 }
        return items.isEmpty ? nil : items
    }

    private static func timedCreatePlan(prompt: String, now: Date, projectID: UUID) -> [AssistantCommand]? {
        let day = baseDay(for: prompt, now: now)
        var specs: [TimedTaskSpec] = []
        var seen = Set<String>()

        appendTimedSpecs(
            from: prompt,
            pattern: #"(?i)\b(\d{1,2}(?::\d{2})?\s*(?:am|pm))\s+([^,;\n]+?)(?:\s+for\s+(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr))?(?=\s*(?:,|;|\band\b|$))"#,
            timeGroup: 1,
            titleGroup: 2,
            durationGroup: 3,
            unitGroup: 4,
            day: day,
            seen: &seen,
            specs: &specs
        )
        appendTimedSpecs(
            from: prompt,
            pattern: #"(?i)(?:^|[,;\n])\s*(?:schedule|create|add)\s+(.+?)\s+for\s+(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr)\s+(?:at|starting at|from)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm))(?=\s*(?:,|;|\band\b|$))"#,
            timeGroup: 4,
            titleGroup: 1,
            durationGroup: 2,
            unitGroup: 3,
            day: day,
            seen: &seen,
            specs: &specs
        )
        appendTimedSpecs(
            from: prompt,
            pattern: #"(?i)(?:^|[,;\n])\s*(.+?)\s+(?:at|starting at|from)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm))(?:\s+for\s+(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr))?(?=\s*(?:,|;|\band\b|$))"#,
            timeGroup: 2,
            titleGroup: 1,
            durationGroup: 3,
            unitGroup: 4,
            day: day,
            seen: &seen,
            specs: &specs
        )
        guard specs.isEmpty == false else { return nil }

        let commands: [AssistantCommand] = specs.map { spec in
            .createScheduledTask(
                projectID: projectID,
                title: spec.title,
                scheduledStartAt: spec.start,
                scheduledEndAt: spec.start.addingTimeInterval(spec.duration),
                estimatedDuration: spec.duration,
                lifeAreaID: nil,
                priority: nil,
                energy: nil,
                category: nil,
                context: nil,
                details: nil,
                tagIDs: []
            )
        }
        return commands
    }

    private static func appendTimedSpecs(
        from prompt: String,
        pattern: String,
        timeGroup: Int,
        titleGroup: Int,
        durationGroup: Int,
        unitGroup: Int,
        day: Date,
        seen: inout Set<String>,
        specs: inout [TimedTaskSpec]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        for match in regex.matches(in: prompt, range: range) {
            guard
                let timeRange = Range(match.range(at: timeGroup), in: prompt),
                let titleRange = Range(match.range(at: titleGroup), in: prompt),
                let start = date(for: String(prompt[timeRange]), on: day)
            else {
                continue
            }
            let title = cleanTitle(String(prompt[titleRange]))
            guard title.isEmpty == false else { continue }
            let duration = durationSeconds(match: match, prompt: prompt, valueGroup: durationGroup, unitGroup: unitGroup) ?? 3_600
            let spec = TimedTaskSpec(title: title, start: start, duration: duration)
            let key = "\(title.lowercased())|\(start.timeIntervalSinceReferenceDate)"
            if seen.insert(key).inserted {
                specs.append(spec)
            }
        }
    }

    private static func editPlan(prompt: String, tasks: [ContextTask], now: Date) -> AssistantCommand? {
        let pattern = #"(?i)\bmove\s+(.+?)\s+to\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm))(?:\s+for\s+(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: prompt, range: NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)),
              let titleRange = Range(match.range(at: 1), in: prompt),
              let timeRange = Range(match.range(at: 2), in: prompt) else {
            return nil
        }
        let requestedTitle = cleanTitle(String(prompt[titleRange]))
        guard let task = bestTaskMatch(title: requestedTitle, tasks: tasks) else { return nil }
        let day = task.scheduledStartAt ?? baseDay(for: prompt, now: now)
        guard let start = date(for: String(prompt[timeRange]), on: day) else { return nil }
        let duration = durationSeconds(match: match, prompt: prompt) ?? task.scheduledEndAt.map { $0.timeIntervalSince(task.scheduledStartAt ?? start) } ?? 1_800
        return .updateTaskSchedule(
            taskID: task.id,
            scheduledStartAt: start,
            scheduledEndAt: start.addingTimeInterval(duration),
            estimatedDuration: duration,
            dueDate: start
        )
    }

    private static func extractContextTasks(from contextPayload: String) -> [ContextTask] {
        guard let data = contextPayload.data(using: .utf8) else { return [] }
        let rawObject = (try? JSONSerialization.jsonObject(with: data)) ?? jsonObjectFromContextBlock(contextPayload)
        var tasks: [ContextTask] = []
        collectTasks(from: rawObject, into: &tasks)
        var seen = Set<UUID>()
        return tasks.filter { seen.insert($0.id).inserted }
    }

    private static func jsonObjectFromContextBlock(_ raw: String) -> Any? {
        guard let first = raw.firstIndex(of: "{"), let last = raw.lastIndex(of: "}"), first <= last else { return nil }
        let candidate = String(raw[first...last])
        guard let data = candidate.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectTasks(from object: Any?, into tasks: inout [ContextTask]) {
        if let dict = object as? [String: Any] {
            if let idString = dict["id"] as? String,
               let id = UUID(uuidString: idString),
               let title = dict["title"] as? String {
                tasks.append(ContextTask(
                    id: id,
                    title: title,
                    scheduledStartAt: parseDate(dict["due_date"]),
                    scheduledEndAt: nil,
                    isCompleted: dict["is_completed"] as? Bool ?? false
                ))
            }
            for value in dict.values {
                collectTasks(from: value, into: &tasks)
            }
        } else if let array = object as? [Any] {
            for item in array {
                collectTasks(from: item, into: &tasks)
            }
        }
    }

    private static func defaultProjectID(projectNameByID: [UUID: String]) -> UUID {
        projectNameByID.keys.first(where: { $0 != ProjectConstants.inboxProjectID }) ?? ProjectConstants.inboxProjectID
    }

    private static func bestTaskMatch(title: String, tasks: [ContextTask]) -> ContextTask? {
        let normalized = title.lowercased()
        return tasks.first { task in
            let candidate = task.title.lowercased()
            return candidate == normalized || candidate.contains(normalized) || normalized.contains(candidate)
        }
    }

    private static func baseDay(for prompt: String, now: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        if prompt.localizedCaseInsensitiveContains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        return today
    }

    private static func date(for timeText: String, on day: Date) -> Date? {
        let normalized = timeText
            .replacingOccurrences(of: #"(?i)\s+"#, with: " ", options: .regularExpression)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in ["h:mm a", "h a"] {
            formatter.dateFormat = format
            if let time = formatter.date(from: normalized) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: time)
                return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: day)
            }
        }
        return nil
    }

    private static func durationSeconds(match: NSTextCheckingResult, prompt: String) -> TimeInterval? {
        durationSeconds(match: match, prompt: prompt, valueGroup: 3, unitGroup: 4)
    }

    private static func durationSeconds(match: NSTextCheckingResult, prompt: String, valueGroup: Int, unitGroup: Int) -> TimeInterval? {
        guard match.numberOfRanges > max(valueGroup, unitGroup),
              match.range(at: valueGroup).location != NSNotFound,
              let valueRange = Range(match.range(at: valueGroup), in: prompt),
              let value = Double(String(prompt[valueRange])) else {
            return nil
        }
        let unit = Range(match.range(at: unitGroup), in: prompt).map { String(prompt[$0]).lowercased() } ?? "minutes"
        return unit.hasPrefix("h") ? value * 3_600 : value * 60
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter.taskerPlannerWithFraction.date(from: string) {
            return date
        }
        return ISO8601DateFormatter.taskerPlanner.date(from: string)
    }

    private static func cleanTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"(?i)\b(for|at)\s+\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(schedule|create|add)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

private extension ISO8601DateFormatter {
    static let taskerPlanner: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let taskerPlannerWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
