import Foundation
import CryptoKit
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
    let dayOverviewPayload: EvaDayOverviewPayload?
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
    case dayOverviewCard(content: String, sourceModelName: String?)

    var content: String {
        switch self {
        case .text(let content, _), .proposalCard(let content, _), .dayOverviewCard(let content, _):
            return content
        }
    }

    var sourceModelName: String? {
        switch self {
        case .text(_, let sourceModelName), .proposalCard(_, let sourceModelName), .dayOverviewCard(_, let sourceModelName):
            return sourceModelName
        }
    }

    var contentType: String {
        switch self {
        case .text:
            return "text"
        case .proposalCard:
            return "proposal_card"
        case .dayOverviewCard:
            return "day_overview_card"
        }
    }
}

enum EvaPlanResponseDeliveryResult: Equatable {
    case persisted(ChatMessageSendOutcome)
    case dropped(EvaPlanResponseDropReason)
}

enum EvaPlanProposalPersistence {
    static func awaitResult(
        _ start: (@escaping (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    ) async -> Result<AssistantActionRunDefinition, Error> {
        await withCheckedContinuation { continuation in
            start { result in
                continuation.resume(returning: result)
            }
        }
    }
}

enum EvaContextReceiptBuilder {
    static func receipt(from contextPayload: String) -> EvaContextReceipt {
        guard let dictionary = decodeDictionary(from: contextPayload) else {
            return EvaContextReceipt(sources: ["Planning context unavailable"])
        }

        var sources: [String] = []
        if let today = dictionary["today"] as? [String: Any] {
            sources.append(sourceLabel("Today timeline", payload: today, itemKey: "tasks"))
        }
        if let overdue = dictionary["overdue"] as? [String: Any] {
            sources.append(sourceLabel("Overdue tasks", payload: overdue, itemKey: "tasks"))
        }
        if let upcoming = dictionary["upcoming"] as? [String: Any] {
            sources.append(sourceLabel("Upcoming tasks", payload: upcoming, itemKey: "tasks"))
        }
        if let habits = dictionary["habits"] as? [String: Any] {
            sources.append(sourceLabel("Habits", payload: habits, itemKey: "habits"))
        }

        let metadata = (dictionary["metadata"] as? [String: Any]) ?? [:]
        let partialFlags = (dictionary["partial_flags"] as? [String: Any]) ?? [:]
        if (metadata["missing_service"] as? Bool) == true || (partialFlags["missing_service"] as? Bool) == true {
            sources.append("Context service unavailable")
        }
        let reasons = (metadata["partial_reasons"] as? [String])
            ?? (partialFlags["partial_reasons"] as? [String])
            ?? []
        sources.append(contentsOf: reasons.map { "Partial: \($0)" })

        if sources.isEmpty {
            sources.append("Planning context loaded")
        }
        return EvaContextReceipt(sources: sources)
    }

    private static func sourceLabel(_ name: String, payload: [String: Any], itemKey: String) -> String {
        let count = (payload[itemKey] as? [[String: Any]])?.count
            ?? (payload["count"] as? NSNumber)?.intValue
            ?? (payload["count"] as? Int)
        guard let count else { return name }
        return "\(name): \(count)"
    }

    private static func decodeDictionary(from payload: String) -> [String: Any]? {
        let rawJSON: String
        if let start = payload.firstIndex(of: "{"),
           let end = payload.lastIndex(of: "}"),
           start <= end {
            rawJSON = String(payload[start...end])
        } else {
            rawJSON = payload
        }
        guard let data = rawJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }
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

    static func dayOverviewPayload(
        for plan: AssistantPlanResult,
        threadID: String
    ) -> EvaPlanResponsePayload? {
        guard let dayOverview = plan.dayOverviewPayload else { return nil }
        let cardPayload = AssistantCardPayload(
            cardType: .dayOverview,
            threadID: threadID,
            status: .applied,
            rationale: plan.rationale,
            message: plan.rationale,
            dayOverview: dayOverview
        )
        return .dayOverviewCard(
            content: AssistantCardCodec.encode(cardPayload),
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
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let nowProvider: () -> Date

    /// Initializes a new instance.
    init(
        llm: LLMEvaluator? = nil,
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.llm = llm ?? LLMRuntimeCoordinator.shared.evaluator
        self.taskReadModelRepository = taskReadModelRepository
        self.nowProvider = nowProvider
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
        let contextReceipt = EvaContextReceiptBuilder.receipt(from: contextPayload)
        let fallbackContext = AssistantDeterministicPlanner.Context(
            userPrompt: userPrompt,
            contextPayload: contextPayload,
            taskTitleByID: effectiveTaskTitleByID,
            projectNameByID: projectNameByID,
            knownTaskIDs: effectiveKnownTaskIDs,
            contextReceipt: contextReceipt,
            now: nowProvider()
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
                contextReceipt: contextReceipt,
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
                dayOverviewPayload: output.dayOverviewPayload,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_intent_gate",
                route: modelRoute,
                generationSource: "deterministic_intent_gate",
                contextReceipt: contextReceipt,
                traceContext: traceContext
            ))
        }

        if let fallback = await deterministicPlan(context: fallbackContext) {
            return .success(buildResult(
                envelope: fallback.envelope,
                proposalCards: fallback.cards,
                taskTitleByID: effectiveTaskTitleByID,
                projectNameByID: projectNameByID,
                modelName: "deterministic_intent_gate",
                route: modelRoute,
                generationSource: "deterministic_intent_gate",
                contextReceipt: contextReceipt,
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
                contextReceipt: contextReceipt,
                traceContext: traceContext
            ))
        }

        guard
            let modelName = modelRoute.selectedModelName,
            let model = ModelConfiguration.getModelByName(modelName)
        else {
            return .failure(.noModelConfigured)
        }

        let systemPrompt = planSystemPrompt(referenceDate: fallbackContext.now)
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
                    "raw_preview_hash": Self.redactedHash(output)
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
                    contextReceipt: contextReceipt,
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
            if let fallback = await deterministicPlan(context: fallbackContext) {
                return .success(buildResult(
                    envelope: fallback.envelope,
                    proposalCards: fallback.cards,
                    taskTitleByID: effectiveTaskTitleByID,
                    projectNameByID: projectNameByID,
                    modelName: model.name,
                    route: modelRoute,
                    generationSource: "deterministic_fallback",
                    contextReceipt: contextReceipt,
                    traceContext: traceContext
                ))
            }
            logWarning(
                event: "eva_plan_fallback_failed",
                message: "Deterministic EVA plan fallback could not parse prompt",
                fields: traceFields(traceContext, ["prompt_hash": Self.redactedHash(userPrompt)])
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
                        "prompt_hash": Self.redactedHash(userPrompt)
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
                    contextReceipt: contextReceipt,
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
                contextReceipt: contextReceipt,
                traceContext: traceContext
            ))
        }
    }

    /// Executes planSystemPrompt.
    private func planSystemPrompt(referenceDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let scheduledStart = calendar.date(byAdding: .hour, value: 10, to: dayStart) ?? referenceDate
        let scheduledEnd = calendar.date(byAdding: .minute, value: 45, to: scheduledStart) ?? scheduledStart
        let updateStart = calendar.date(byAdding: .hour, value: 16, to: dayStart) ?? referenceDate
        let updateEnd = calendar.date(byAdding: .minute, value: 30, to: updateStart) ?? updateStart
        return """
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
              "scheduledStartAt": "\(scheduledStart.ISO8601Format())",
              "scheduledEndAt": "\(scheduledEnd.ISO8601Format())",
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
              "scheduledStartAt": "\(updateStart.ISO8601Format())",
              "scheduledEndAt": "\(updateEnd.ISO8601Format())",
              "estimatedDuration": 1800,
              "dueDate": "\(updateStart.ISO8601Format())"
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
        let now = nowProvider()
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

    private func deterministicPlan(context: AssistantDeterministicPlanner.Context) async -> AssistantDeterministicPlanner.Output? {
        if let request = AssistantDeterministicPlanner.taskSelectionRequest(context: context),
           let tasks = await fetchDeterministicTasks(for: request) {
            return AssistantDeterministicPlanner.plan(context: context, repositoryTasks: tasks)
        }
        return AssistantDeterministicPlanner.plan(context: context)
    }

    private func fetchDeterministicTasks(
        for request: AssistantDeterministicPlanner.TaskSelectionRequest
    ) async -> [TaskDefinition]? {
        guard taskReadModelRepository != nil else { return nil }
        let dueWindow = await fetchTasks(query: TaskReadQuery(
            includeCompleted: false,
            dueDateStart: request.sourceStart,
            dueDateEnd: request.sourceEnd,
            sortBy: .dueDateAscending,
            limit: request.limit,
            offset: 0
        ))
        let openTasks = await fetchTasks(query: TaskReadQuery(
            includeCompleted: false,
            sortBy: .dueDateAscending,
            limit: request.limit,
            offset: 0
        ))
        let calendar = Calendar.current
        var byID: [UUID: TaskDefinition] = [:]
        for task in dueWindow + openTasks {
            guard task.isComplete == false else { continue }
            let isInSourceWindow = [
                task.dueDate,
                task.scheduledStartAt
            ].contains { date in
                guard let date else { return false }
                return date >= request.sourceStart && date <= request.sourceEnd
            }
            let isUnscheduled = request.includeUnscheduled
                && task.dueDate == nil
                && task.scheduledStartAt == nil
            guard isInSourceWindow || isUnscheduled else { continue }
            byID[task.id] = task
        }
        return byID.values.sorted { lhs, rhs in
            let lhsDate = lhs.scheduledStartAt ?? lhs.dueDate ?? lhs.updatedAt
            let rhsDate = rhs.scheduledStartAt ?? rhs.dueDate ?? rhs.updatedAt
            if calendar.compare(lhsDate, to: rhsDate, toGranularity: .second) == .orderedSame {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhsDate < rhsDate
        }
    }

    private func fetchTasks(query: TaskReadQuery) async -> [TaskDefinition] {
        guard let taskReadModelRepository else { return [] }
        return await withCheckedContinuation { continuation in
            taskReadModelRepository.fetchTasks(query: query) { result in
                continuation.resume(returning: (try? result.get().tasks) ?? [])
            }
        }
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
            systemPrompt: planSystemPrompt(referenceDate: nowProvider()),
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
                    "raw_preview_hash": Self.redactedHash(output)
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
        dayOverviewPayload: EvaDayOverviewPayload? = nil,
        taskTitleByID: [UUID: String],
        projectNameByID: [UUID: String],
        modelName: String,
        route: AIModelRoute,
        generationSource: String,
        contextReceipt: EvaContextReceipt,
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
            dayOverviewPayload: dayOverviewPayload,
            contextReceipt: contextReceipt,
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

    private static func redactedHash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(6).map { String(format: "%02x", $0) }.joined()
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

        let habitMarkers = ["habit", "habits", "streak", "check in", "check-in", "pause habit", "resume habit"]
        let mutationMarkers = [
            "add", "create", "schedule", "setup", "set up", "make", "write", "plan", "move", "reschedule", "defer",
            "drop", "mark", "rename", "complete", "shift", "push", "carry over", "pause", "resume", "log"
        ]
        if habitMarkers.contains(where: { lower.contains($0) }) &&
            mutationMarkers.contains(where: { containsWord(lower, $0) }) {
            return .habitMutation
        }

        if lower.contains("week") && (lower.contains("plan") || lower.contains("review")) {
            return .weeklyPlanning
        }

        if isReadOnlyReviewPrompt(lower) {
            return .readOnlyReview
        }

        if isPlanningCoachingPrompt(lower) {
            return .chatAnswer
        }

        if lower.contains("help me plan my day")
            || lower.contains("plan my day")
            || lower.contains("plan today")
            || lower.contains("plan tomorrow")
            || lower.contains("review today") {
            return .dayPlanning
        }

        let updateMarkers = [
            "move", "reschedule", "defer", "drop", "mark", "rename", "complete", "running late", "shift", "push", "carry over"
        ]
        if updateMarkers.contains(where: { containsWord(lower, $0) || lower.contains($0) }) {
            return .taskMutation
        }

        if (mentionsTime(lower) || mentionsDuration(lower)) && lower.contains("?") == false {
            return .taskMutation
        }

        if lower.contains("help me plan making")
            || lower.contains("help me plan writing") {
            return .taskMutation
        }

        if lower.hasPrefix("i need to ") && lower.contains("?") == false {
            return .taskMutation
        }

        let createMarkers = ["add", "create", "schedule", "setup", "set up", "make", "write"]
        if createMarkers.contains(where: { containsWord(lower, $0) && hasConcreteCreateObject(after: $0, in: lower) }) {
            return .taskMutation
        }

        return .chatAnswer
    }

    private static func isPlanningCoachingPrompt(_ text: String) -> Bool {
        let asksHow = text.hasPrefix("how do i ")
            || text.hasPrefix("how can i ")
            || text.hasPrefix("how should i ")
            || text.hasPrefix("what is the best way")
        return asksHow && (text.contains("plan my day") || text.contains("plan today"))
    }

    private static func normalized(_ prompt: String) -> String {
        prompt
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func mentionsDuration(_ text: String) -> Bool {
        let pattern = #"\b\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    fileprivate static func isReadOnlyReviewPrompt(_ text: String) -> Bool {
        if dayReviewPhrases.contains(where: { text.contains($0) }) {
            return true
        }

        if fuzzyDayReviewSignals(text) {
            return true
        }

        return false
    }

    private static func fuzzyDayReviewSignals(_ text: String) -> Bool {
        if text.contains("how do i plan") || text.contains("how can i plan") {
            return false
        }
        let asksForReview = [
            "what", "show", "list", "review", "brief", "walk me through", "give me", "how"
        ].contains(where: text.contains)
        guard asksForReview else { return false }

        let workTargets = [
            "tasks", "task", "habits", "habit", "open work", "open items", "open tasks", "plate",
            "agenda", "day", "today", "pending", "due", "left", "focus", "work on", "attention"
        ]
        return workTargets.contains(where: text.contains)
    }

    private static let dayReviewPhrases: [String] = [
        "what are my tasks today",
        "what are my tasks for today",
        "what do i need to do today",
        "what do i have today",
        "what s on my plate",
        "what is on my plate",
        "what s on my agenda",
        "what is on my agenda",
        "show my open tasks",
        "show me my open tasks",
        "show my tasks",
        "show me my tasks",
        "list my tasks",
        "list my open tasks",
        "what s due today",
        "what is due today",
        "what s left today",
        "what is left today",
        "what do i still need to do today",
        "what should i focus on today",
        "what should i work on today",
        "what needs attention today",
        "what s pending today",
        "what is pending today",
        "give me my day",
        "give me today s tasks",
        "give me my open items",
        "how is my day",
        "how does my day look",
        "how is my day looking",
        "walk me through today",
        "brief me on today",
        "give me a quick overview of today",
        "what do i have open",
        "what s open today",
        "what is open today",
        "what tasks and habits do i have today",
        "show today s tasks and habits",
        "review my day",
        "review the day",
        "today s open work",
        "this morning s tasks"
    ]
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
            let rawJSON: String
            if let start = payload.firstIndex(of: "{"),
               let end = payload.lastIndex(of: "}"),
               start <= end {
                rawJSON = String(payload[start...end])
            } else {
                rawJSON = payload
            }

            guard let data = rawJSON.data(using: .utf8),
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
        let normalized = lower
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if EvaTurnRouter.isReadOnlyReviewPrompt(normalized) {
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
            "shift ",
            "push ",
            "carry over"
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
        var contextReceipt: EvaContextReceipt = EvaContextReceipt(sources: [])
        let now: Date
    }

    struct Output {
        let envelope: AssistantCommandEnvelope
        let cards: [EvaProposalCard]
        let dayOverviewPayload: EvaDayOverviewPayload?
    }

    struct TaskSelectionRequest: Equatable {
        let sourceStart: Date
        let sourceEnd: Date
        let includeUnscheduled: Bool
        let limit: Int
    }

    struct ContextTask {
        let id: UUID
        let title: String
        let dueDate: Date?
        let scheduledStartAt: Date?
        let scheduledEndAt: Date?
        let estimatedDuration: TimeInterval?
        let projectName: String?
        let tagNames: [String]
        let isCompleted: Bool
    }

    private struct TimedTaskSpec: Hashable {
        let title: String
        let start: Date
        let duration: TimeInterval
    }

    private struct UntimedTaskSpec: Hashable {
        let title: String
        let estimatedDuration: TimeInterval?
    }

    static func taskTitleByID(from contextPayload: String) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: extractContextTasks(from: contextPayload).map { ($0.id, $0.title) })
    }

    static func reviewPlan(context: Context, contextIsPartial: Bool) -> Output {
        let dayOverview = EvaDayOverviewBuilder.build(
            prompt: context.userPrompt,
            contextPayload: context.contextPayload,
            contextReceipt: context.contextReceipt,
            generatedAt: context.now
        )
        let message = dayOverview.summary
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [],
            dayOverviewPayload: dayOverview.payload
        )
    }

    static func clarificationPlan(for prompt: String) -> Output {
        let message = "Tell me the task title, and add a time if it belongs on your timeline."
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [EvaProposalCardBuilder.noOpCard(title: "Needs more detail", subtitle: message)],
            dayOverviewPayload: nil
        )
    }

    static func habitClarificationPlan(for prompt: String) -> Output {
        let message = "I can review habits and include them in planning, but habit changes cannot be applied from this assistant card yet. Tell me if you want a task added to support that habit."
        let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
        return Output(
            envelope: envelope,
            cards: [EvaProposalCardBuilder.noOpCard(title: "Habit review only", subtitle: message)],
            dayOverviewPayload: nil
        )
    }

    static func plan(context: Context, repositoryTasks: [TaskDefinition]? = nil) -> Output? {
        let prompt = context.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return nil }
        let tasks = repositoryTasks.map(contextTasks(from:)) ?? extractContextTasks(from: context.contextPayload)
        let titleByID = context.taskTitleByID.merging(Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })) { current, _ in current }

        if let batch = batchReschedulePlan(prompt: prompt, tasks: tasks, now: context.now) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: batch.commands,
                rationaleText: batch.rationale
            )
            return Output(
                envelope: envelope,
                cards: batch.commands.isEmpty
                    ? [EvaProposalCardBuilder.noOpCard(title: batch.noOpTitle ?? "No matching tasks found", subtitle: batch.rationale)]
                    : EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID),
                dayOverviewPayload: nil
            )
        }

        if let timed = timedCreatePlan(prompt: prompt, now: context.now, projectID: defaultProjectID(projectNameByID: context.projectNameByID)) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: timed,
                rationaleText: "Here's how your day is planned:"
            )
            return Output(
                envelope: envelope,
                cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID),
                dayOverviewPayload: nil
            )
        }

        if let inbox = inboxPlan(prompt: prompt) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: inbox.map {
                    .createInboxTask(projectID: ProjectConstants.inboxProjectID, title: $0, estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
                },
                rationaleText: "Here's how your day is planned:"
            )
            return Output(
                envelope: envelope,
                cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID),
                dayOverviewPayload: nil
            )
        }

        if let untimed = untimedCreatePlan(prompt: prompt) {
            let envelope = AssistantCommandEnvelope(
                schemaVersion: 3,
                commands: untimed.map {
                    .createInboxTask(projectID: ProjectConstants.inboxProjectID, title: $0.title, estimatedDuration: $0.estimatedDuration, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
                },
                rationaleText: "I added this to your Inbox for review."
            )
            return Output(
                envelope: envelope,
                cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID),
                dayOverviewPayload: nil
            )
        }

        if let edit = editPlan(prompt: prompt, tasks: tasks, now: context.now) {
            let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [edit], rationaleText: "Here's how your day is planned:")
            return Output(
                envelope: envelope,
                cards: EvaProposalCardBuilder.build(commands: envelope.commands, taskTitleByID: titleByID),
                dayOverviewPayload: nil
            )
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
                    cards: [EvaProposalCardBuilder.noOpCard(title: "No matching tasks found", subtitle: message)],
                    dayOverviewPayload: nil
                )
            }
        }

        if prompt.localizedCaseInsensitiveContains("help me plan") || prompt.localizedCaseInsensitiveContains("plan my day") {
            let message = "Tell me your timed plans or add a list for Inbox, and your assistant will turn them into review cards."
            let envelope = AssistantCommandEnvelope(schemaVersion: 3, commands: [], rationaleText: message)
            return Output(
                envelope: envelope,
                cards: [EvaProposalCardBuilder.noOpCard(title: "Tell me your plans", subtitle: message)],
                dayOverviewPayload: nil
            )
        }

        return nil
    }

    static func taskSelectionRequest(context: Context) -> TaskSelectionRequest? {
        guard let intent = BatchRescheduleIntent.parse(prompt: context.userPrompt, now: context.now) else {
            return nil
        }
        return TaskSelectionRequest(
            sourceStart: intent.source.start,
            sourceEnd: intent.source.end,
            includeUnscheduled: intent.includeUnscheduled,
            limit: 200
        )
    }

    private struct DayWindow: Equatable {
        let start: Date
        let end: Date
    }

    private enum BatchRescheduleMode: Equatable {
        case moveToDay(Date)
        case shift(TimeInterval)
        case anchor(Date)
        case drop(AssistantDropDestination)
    }

    private struct BatchRescheduleIntent: Equatable {
        let source: DayWindow
        let mode: BatchRescheduleMode
        let includeUnscheduled: Bool
        let projectFilter: String?
        let tagFilter: String?

        static func parse(prompt: String, now: Date) -> BatchRescheduleIntent? {
            let lower = normalized(prompt)
            guard mentionsBatchOpenWork(lower), mentionsRescheduleAction(lower) else { return nil }
            let source = sourceWindow(from: lower, now: now)
            let includeUnscheduled = lower.contains("all open")
                || lower.contains("all my open")
                || lower.contains("unscheduled")
                || lower.contains("everything")
            let mode: BatchRescheduleMode
            if lower.contains("to inbox") {
                mode = .drop(.inbox)
            } else if lower.contains("to later") {
                mode = .drop(.later)
            } else if let shift = shiftSeconds(from: lower) {
                mode = .shift(shift)
            } else if let anchor = anchorDate(from: lower, source: source, now: now) {
                mode = .anchor(anchor)
            } else {
                let targetDay = targetDayStart(from: lower, now: now)
                    ?? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))
                    ?? Calendar.current.startOfDay(for: now)
                mode = .moveToDay(targetDay)
            }
            return BatchRescheduleIntent(
                source: source,
                mode: mode,
                includeUnscheduled: includeUnscheduled,
                projectFilter: phrase(after: "in project", in: lower) ?? phrase(after: "project", in: lower),
                tagFilter: phrase(after: "tagged", in: lower)
            )
        }

        private static func mentionsBatchOpenWork(_ lower: String) -> Bool {
            let subjects = [
                "unfinished", "open", "incomplete", "remaining", "left from today", "didn t finish",
                "did not finish", "overdue", "past due", "everything", "all tasks", "all my tasks",
                "carry over"
            ]
            return subjects.contains(where: { lower.contains($0) })
        }

        private static func mentionsRescheduleAction(_ lower: String) -> Bool {
            ["reschedule", "move", "push", "shift", "defer", "carry over", "drop"].contains { lower.contains($0) }
        }

        private static func normalized(_ prompt: String) -> String {
            prompt
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9:\\s]", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private static func sourceWindow(from lower: String, now: Date) -> DayWindow {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            if lower.contains("yesterday") {
                return dayWindow(start: calendar.date(byAdding: .day, value: -1, to: today) ?? today)
            }
            if lower.contains("from tomorrow")
                || lower.contains("tomorrow s")
                || lower.contains("tomorrows") {
                return dayWindow(start: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
            }
            if lower.contains("this week") {
                let interval = calendar.dateInterval(of: .weekOfYear, for: now)
                return DayWindow(start: interval?.start ?? today, end: (interval?.end ?? today).addingTimeInterval(-1))
            }
            if lower.contains("overdue") || lower.contains("past due") {
                return DayWindow(start: .distantPast, end: today.addingTimeInterval(-1))
            }
            return dayWindow(start: today)
        }

        private static func dayWindow(start: Date) -> DayWindow {
            let end = (Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start).addingTimeInterval(-1)
            return DayWindow(start: start, end: end)
        }

        private static func targetDayStart(from lower: String, now: Date) -> Date? {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            if lower.contains("to today") { return today }
            if lower.contains("to tomorrow") || lower.contains("next day") {
                return calendar.date(byAdding: .day, value: 1, to: today)
            }
            if lower.contains("next week") {
                return calendar.date(byAdding: .day, value: 7, to: today)
            }
            let weekdays = [
                "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                "thursday": 5, "friday": 6, "saturday": 7
            ]
            for (name, weekday) in weekdays where lower.contains(name) {
                return nextWeekday(weekday, from: now)
            }
            if lower.contains("tomorrow")
                && lower.contains("tomorrow s") == false
                && lower.contains("tomorrows") == false {
                return calendar.date(byAdding: .day, value: 1, to: today)
            }
            return explicitMonthDay(from: lower, now: now)
        }

        private static func nextWeekday(_ weekday: Int, from now: Date) -> Date? {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: now)
            let current = calendar.component(.weekday, from: today)
            let delta = (weekday - current + 7) % 7
            return calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: today)
        }

        private static func explicitMonthDay(from lower: String, now: Date) -> Date? {
            let months = [
                "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3,
                "apr": 4, "april": 4, "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7,
                "aug": 8, "august": 8, "sep": 9, "sept": 9, "september": 9,
                "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12
            ]
            for (name, month) in months {
                let pattern = #"\b\#(name)\s+(\d{1,2})(?:st|nd|rd|th)?\b"#
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower)),
                      let dayRange = Range(match.range(at: 1), in: lower),
                      let day = Int(lower[dayRange]) else { continue }
                var components = Calendar.current.dateComponents([.year], from: now)
                components.month = month
                components.day = day
                return Calendar.current.date(from: components).map { Calendar.current.startOfDay(for: $0) }
            }
            let numericPattern = #"\b(?:to\s+)?(\d{1,2})(?:st|nd|rd|th)\b"#
            guard let regex = try? NSRegularExpression(pattern: numericPattern),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower)),
                  let dayRange = Range(match.range(at: 1), in: lower),
                  let day = Int(lower[dayRange]) else { return nil }
            var components = Calendar.current.dateComponents([.year, .month], from: now)
            components.day = day
            return Calendar.current.date(from: components).map { Calendar.current.startOfDay(for: $0) }
        }

        private static func shiftSeconds(from lower: String) -> TimeInterval? {
            let direction: Double
            if lower.contains("back") || lower.contains("earlier") {
                direction = -1
            } else if lower.contains("forward") || lower.contains("later") || lower.contains("push") || lower.contains("shift") {
                direction = 1
            } else {
                return nil
            }
            guard let duration = durationSeconds(in: lower) else { return nil }
            return direction * duration
        }

        private static func anchorDate(from lower: String, source: DayWindow, now: Date) -> Date? {
            let anchorDay = targetDayStart(from: lower, now: now) ?? source.start
            if lower.contains("morning") {
                return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: anchorDay)
            }
            if lower.contains("afternoon") {
                return Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: anchorDay)
            }
            if lower.contains("evening") {
                return Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: anchorDay)
            }
            let pattern = #"\b(?:at|after|from)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm))\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower)),
                  let range = Range(match.range(at: 1), in: lower) else { return nil }
            return date(for: String(lower[range]), on: anchorDay)
        }

        private static func phrase(after marker: String, in lower: String) -> String? {
            guard let range = lower.range(of: marker) else { return nil }
            let stopWords = Set(["to", "from", "by", "after", "tomorrow", "today", "yesterday", "next"])
            let trailing = lower[range.upperBound...]
                .split(separator: " ")
                .prefix { !stopWords.contains(String($0)) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trailing.isEmpty ? nil : trailing
        }
    }

    private struct BatchReschedulePlan {
        let commands: [AssistantCommand]
        let rationale: String
        let noOpTitle: String?
    }

    private static func batchReschedulePlan(
        prompt: String,
        tasks: [ContextTask],
        now: Date
    ) -> BatchReschedulePlan? {
        guard let intent = BatchRescheduleIntent.parse(prompt: prompt, now: now) else { return nil }
        let candidates = batchCandidates(tasks: tasks, intent: intent)
        guard candidates.isEmpty == false else {
            return BatchReschedulePlan(
                commands: [],
                rationale: "I checked the requested scope and did not find open tasks to reschedule.",
                noOpTitle: "No matching open tasks"
            )
        }
        let maxCommands = 20
        guard candidates.count <= maxCommands else {
            return BatchReschedulePlan(
                commands: [],
                rationale: "I found \(candidates.count) matching open tasks. Narrow the scope before applying a batch reschedule.",
                noOpTitle: "Too many matching tasks"
            )
        }

        let commands: [AssistantCommand]
        switch intent.mode {
        case .moveToDay(let targetDay):
            commands = candidates.map { moveCommand(task: $0, targetDay: targetDay) }
        case .shift(let delta):
            commands = candidates.compactMap { shiftCommand(task: $0, delta: delta) }
        case .anchor(let anchor):
            commands = anchoredCommands(tasks: candidates, anchor: anchor)
        case .drop(let destination):
            commands = candidates.map { .dropTaskFromToday(taskID: $0.id, destination: destination, reason: "Requested batch reschedule") }
        }
        guard commands.isEmpty == false else {
            return BatchReschedulePlan(
                commands: [],
                rationale: "I found matching tasks, but they need a date or time target before \(AssistantIdentityText.currentSnapshot().displayName) can reschedule them.",
                noOpTitle: "Needs a target"
            )
        }
        return BatchReschedulePlan(
            commands: commands,
            rationale: "I prepared \(commands.count) open task\(commands.count == 1 ? "" : "s") for review.",
            noOpTitle: nil
        )
    }

    private static func batchCandidates(tasks: [ContextTask], intent: BatchRescheduleIntent) -> [ContextTask] {
        tasks
            .filter { task in
                guard task.isCompleted == false else { return false }
                if let projectFilter = intent.projectFilter,
                   task.projectName?.localizedCaseInsensitiveContains(projectFilter) != true {
                    return false
                }
                if let tagFilter = intent.tagFilter,
                   task.tagNames.contains(where: { $0.localizedCaseInsensitiveContains(tagFilter) }) == false {
                    return false
                }
                if intent.includeUnscheduled, task.dueDate == nil, task.scheduledStartAt == nil {
                    return true
                }
                return [task.dueDate, task.scheduledStartAt].contains { date in
                    guard let date else { return false }
                    return date >= intent.source.start && date <= intent.source.end
                }
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.scheduledStartAt ?? lhs.dueDate ?? .distantFuture
                let rhsDate = rhs.scheduledStartAt ?? rhs.dueDate ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhsDate < rhsDate
            }
    }

    private static func moveCommand(task: ContextTask, targetDay: Date) -> AssistantCommand {
        if let start = task.scheduledStartAt {
            let newStart = preservingTime(from: start, on: targetDay)
            let duration = duration(for: task, fallback: 1_800)
            return .updateTaskSchedule(
                taskID: task.id,
                scheduledStartAt: newStart,
                scheduledEndAt: newStart.addingTimeInterval(duration),
                estimatedDuration: duration,
                dueDate: newStart
            )
        }
        return .deferTask(taskID: task.id, targetDate: targetDay, reason: .userRequested)
    }

    private static func shiftCommand(task: ContextTask, delta: TimeInterval) -> AssistantCommand? {
        guard let start = task.scheduledStartAt ?? task.dueDate else { return nil }
        let newStart = start.addingTimeInterval(delta)
        if task.scheduledStartAt == nil, task.scheduledEndAt == nil {
            return .deferTask(taskID: task.id, targetDate: newStart, reason: .userRequested)
        }
        let duration = duration(for: task, fallback: 1_800)
        return .updateTaskSchedule(
            taskID: task.id,
            scheduledStartAt: newStart,
            scheduledEndAt: newStart.addingTimeInterval(duration),
            estimatedDuration: duration,
            dueDate: newStart
        )
    }

    private static func anchoredCommands(tasks: [ContextTask], anchor: Date) -> [AssistantCommand] {
        var cursor = anchor
        return tasks.map { task in
            let duration = duration(for: task, fallback: 1_800)
            let start = cursor
            let end = start.addingTimeInterval(duration)
            cursor = end
            return .updateTaskSchedule(
                taskID: task.id,
                scheduledStartAt: start,
                scheduledEndAt: end,
                estimatedDuration: duration,
                dueDate: start
            )
        }
    }

    private static func duration(for task: ContextTask, fallback: TimeInterval) -> TimeInterval {
        if let start = task.scheduledStartAt, let end = task.scheduledEndAt, end > start {
            return end.timeIntervalSince(start)
        }
        if let estimated = task.estimatedDuration, estimated > 0 {
            return estimated
        }
        return fallback
    }

    private static func preservingTime(from source: Date, on day: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: source)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: day
        ) ?? day
    }

    private static func contextTasks(from tasks: [TaskDefinition]) -> [ContextTask] {
        tasks.map { task in
            ContextTask(
                id: task.id,
                title: task.title,
                dueDate: task.dueDate,
                scheduledStartAt: task.scheduledStartAt,
                scheduledEndAt: task.scheduledEndAt,
                estimatedDuration: task.estimatedDuration,
                projectName: task.projectName,
                tagNames: [],
                isCompleted: task.isComplete
            )
        }
    }

    private static func untimedCreatePlan(prompt: String) -> [UntimedTaskSpec]? {
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
            || lower.contains("setup")
            || lower.contains("set up")
            || lower.contains("plan ")
            || lower.hasPrefix("i need to ")
            || lower.contains(" this task") else {
            return nil
        }

        let source = firstTaskSentence(from: prompt)
        let duration = durationSeconds(in: source)
        let stripped = source
            .replacingOccurrences(
                of: #"(?i)^\s*(please\s+)?(can you\s+)?(help me\s+)?(i\s+need\s+to\s+)?(plan|make|write|create|add|setup|set\s+up)\s+(?:a\s+|an\s+|the\s+)?(?:(?:task|todo|to-do|item)\s+(?:to|for)\s+)?(making\s+|writing\s+)?"#,
                with: "",
                options: .regularExpression
            )
        let title = cleanTitle(stripped)
        guard title.count > 1 else { return nil }
        return [UntimedTaskSpec(title: title, estimatedDuration: duration)]
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
            pattern: #"(?i)(?:^|[,;\n])\s*(?:(?:schedule|create|add|setup|set\s+up)\s+)?(?:a|an|the)?\s*(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr)\s+(.+?)\s+(?:at|starting at|from)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm))(?=\s*(?:,|;|\band\b|$))"#,
            timeGroup: 4,
            titleGroup: 3,
            durationGroup: 1,
            unitGroup: 2,
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
            if let taskArray = dict["tasks"] as? [[String: Any]] {
                for item in taskArray {
                    appendContextTask(from: item, into: &tasks)
                }
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

    private static func appendContextTask(from dict: [String: Any], into tasks: inout [ContextTask]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = dict["title"] as? String else {
            return
        }
        tasks.append(ContextTask(
            id: id,
            title: title,
            dueDate: parseDate(dict["due_date"]),
            scheduledStartAt: parseDate(dict["scheduled_start_at"]),
            scheduledEndAt: parseDate(dict["scheduled_end_at"]),
            estimatedDuration: Self.timeInterval(from: dict["estimated_duration_minutes"]).map { $0 * 60 },
            projectName: dict["project"] as? String,
            tagNames: dict["tag_names"] as? [String] ?? [],
            isCompleted: dict["is_completed"] as? Bool ?? false
        ))
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

    private static func durationSeconds(in text: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\b(\d+)\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) else {
            return nil
        }
        return durationSeconds(match: match, prompt: text, valueGroup: 1, unitGroup: 2)
    }

    private static func firstTaskSentence(from prompt: String) -> String {
        let setupSuffix = #"(?i)\s*(setup|set\s+up|create|add)\s+(this\s+)?(task|todo|to-do|item)\s*$"#
        let durationSentence = prompt
            .components(separatedBy: CharacterSet(charactersIn: ".?!\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.isEmpty == false && durationSeconds(in: $0) != nil }
        let source = durationSentence ?? prompt
        return source
            .replacingOccurrences(of: setupSuffix, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        if let date = ISO8601DateFormatter.makeTaskerPlannerWithFraction().date(from: string) {
            return date
        }
        return ISO8601DateFormatter.makeTaskerPlanner().date(from: string)
    }

    private static func timeInterval(from value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        return nil
    }

    private static func cleanTitle(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"(?i)\b(for|at)\s+\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+\s*(minutes?|mins?|min|hours?|hrs?|hr)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*i\s+need\s+to\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(schedule|create|add|setup|set\s+up)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(a|an|the)?\s*(task|todo|to-do|item)\s+(to|for)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s+(this\s+)?(task|todo|to-do|item)\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(a|an|the)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

private extension ISO8601DateFormatter {
    static func makeTaskerPlanner() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static func makeTaskerPlannerWithFraction() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
