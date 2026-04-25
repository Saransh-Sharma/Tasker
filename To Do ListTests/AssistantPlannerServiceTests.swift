import XCTest
import MLXLMCommon
@testable import To_Do_List

@MainActor
final class AssistantPlannerServiceTests: XCTestCase {
    func testEvaTurnRouterKeepsNormalChatOutOfProposalPlanner() {
        XCTAssertEqual(EvaTurnRouter.route(for: "Can you explain why I keep overplanning?"), .chatAnswer)
        XCTAssertEqual(EvaTurnRouter.route(for: "What are my tasks for today"), .readOnlyReview)
        XCTAssertEqual(EvaTurnRouter.route(for: "Help me plan my day. What are my tasks?"), .readOnlyReview)
        XCTAssertEqual(EvaTurnRouter.route(for: "Help me plan my day"), .dayPlanning)
        XCTAssertEqual(EvaTurnRouter.route(for: "Help me plan making tech debts doc"), .taskMutation)
        XCTAssertEqual(EvaTurnRouter.route(for: "Design review at 4 PM for 45 minutes"), .taskMutation)
        XCTAssertEqual(EvaTurnRouter.route(for: "Create Design review at 4 PM for 45 minutes"), .taskMutation)
        XCTAssertEqual(EvaTurnRouter.route(for: "Create a habit to drink water"), .habitMutation)
        XCTAssertEqual(EvaTurnRouter.route(for: "Plan next week"), .weeklyPlanning)
    }

    func testEvaContextPolicyAllowsTodayReviewWithOptionalPartialContext() {
        let ready = EvaContextPolicy.evaluate(
            route: .readOnlyReview,
            contextPayload: #"{"today":{"tasks":[]},"metadata":{"context_partial":true,"partial_reasons":["upcoming_timeout"]}}"#
        )
        XCTAssertTrue(ready.requiredContextReady)
        XCTAssertTrue(ready.optionalContextPartial)

        let blocked = EvaContextPolicy.evaluate(
            route: .weeklyPlanning,
            contextPayload: #"{"metadata":{"context_partial":true,"partial_reasons":["upcoming_timeout"]}}"#
        )
        XCTAssertFalse(blocked.requiredContextReady)
    }

    func testGeneratePlanUsesResolvedRouteModel() async throws {
        let modelName = ModelConfiguration.defaultModel.name
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

        LLMPersistedModelSelection.persistInstalledModels([modelName], defaults: defaults)
        defaults.set(modelName, forKey: LLMPersistedModelSelection.currentModelKey)
        let route = AIChatModeRouter.route(for: .planMode)
        guard route.selectedModelName == modelName else {
            throw XCTSkip("No supported local model route is available in this test environment.")
        }

        let evaluator = PlannerEvaluatorSpy()
        evaluator.stubbedOutput = """
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "createInboxTask",
              "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
              "title": "roadmap summary",
              "estimatedDuration": null,
              "tagIDs": []
            }
          ],
          "rationaleText": "Captured from the prompt."
        }
        """
        let service = AssistantPlannerService(llm: evaluator)
        let thread = To_Do_List.Thread()
        thread.messages.append(Message(role: .assistant, content: "EVA could not finish this plan.", thread: thread))

        let result = await service.generatePlan(
            userPrompt: "Schedule roadmap summary",
            thread: thread,
            contextPayload: "Context",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case let .success(plan) = result else {
            return XCTFail("Expected planner to succeed")
        }

        XCTAssertEqual(evaluator.capturedModelName, modelName)
        XCTAssertEqual(plan.modelName, modelName)
        XCTAssertEqual(evaluator.capturedRequestOptions?.chatMode, .answerOnly)
        XCTAssertEqual(evaluator.capturedRequestOptions?.effectiveModelType, .regular)
        XCTAssertFalse(evaluator.capturedRequestOptions?.allowThinking ?? true)
        XCTAssertEqual(plan.proposalCards.first?.badgeText, "CREATE")
        XCTAssertEqual(evaluator.capturedMessageCount, 1)
        XCTAssertTrue(evaluator.capturedUserPrompt?.contains("user_prompt:") ?? false)
        XCTAssertFalse(evaluator.capturedUserPrompt?.contains("EVA could not finish this plan.") ?? true)
    }

    func testSchemaV3ScheduledCommandRoundTripsAndValidates() throws {
        let projectID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(45 * 60)
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [
                .createScheduledTask(
                    projectID: projectID,
                    title: "Design review",
                    scheduledStartAt: start,
                    scheduledEndAt: end,
                    estimatedDuration: TimeInterval(45 * 60),
                    lifeAreaID: nil,
                    priority: .high,
                    energy: nil,
                    category: nil,
                    context: nil,
                    details: "Bring agenda",
                    tagIDs: []
                )
            ],
            rationaleText: "Scheduled from the user's prompt."
        )

        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AssistantCommandEnvelope.self, from: data)
        let validated = try AssistantEnvelopeValidator.validate(envelope: decoded)

        XCTAssertEqual(validated.schemaVersion, 3)
        guard case .createScheduledTask(_, let title, let decodedStart, let decodedEnd, let duration, _, let priority, _, _, _, let details, _) = validated.commands.first else {
            return XCTFail("Expected createScheduledTask")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(decodedStart, start)
        XCTAssertEqual(decodedEnd, end)
        XCTAssertEqual(duration, TimeInterval(45 * 60))
        XCTAssertEqual(priority, TaskPriority.high)
        XCTAssertEqual(details, "Bring agenda")
    }

    func testValidateRejectsInvalidV3Schedule() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [
                .updateTaskSchedule(
                    taskID: UUID(),
                    scheduledStartAt: start,
                    scheduledEndAt: start.addingTimeInterval(-60),
                    estimatedDuration: TimeInterval(30 * 60),
                    dueDate: nil
                )
            ]
        )

        XCTAssertThrowsError(try AssistantEnvelopeValidator.validate(envelope: envelope)) { error in
            guard case AssistantEnvelopeValidationError.invalidSchedule = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testParseSchemaV3EnvelopeWithISO8601Dates() throws {
        let json = """
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "createScheduledTask",
              "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
              "title": "Design review",
              "scheduledStartAt": "2026-04-24T10:00:00Z",
              "scheduledEndAt": "2026-04-24T10:45:00Z",
              "estimatedDuration": 2700,
              "tagIDs": []
            }
          ],
          "rationaleText": "Scheduled from the prompt."
        }
        """

        let result = AssistantEnvelopeValidator.parseAndValidate(rawOutput: json)

        guard case .success(let envelope) = result else {
            return XCTFail("Expected ISO-8601 envelope to parse")
        }
        XCTAssertEqual(envelope.schemaVersion, 3)
        guard case .createScheduledTask(_, let title, let start, let end, let duration, _, _, _, _, _, _, _) = envelope.commands.first else {
            return XCTFail("Expected createScheduledTask")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(duration, 2700)
        XCTAssertEqual(end.timeIntervalSince(start), 45 * 60)
    }

    func testDeterministicFallbackCreatesTimedScheduleCards() {
        let now = Date(timeIntervalSince1970: 1_777_000_000)
        let output = AssistantDeterministicPlanner.plan(context: .init(
            userPrompt: "Create scheduled timeline tasks for today, not inbox: 3:30 PM Design review for 45 minutes, 4:30 PM Deep work product spec for 60 minutes.",
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            now: now
        ))

        XCTAssertEqual(output?.envelope.commands.count, 2)
        XCTAssertEqual(output?.cards.map(\.badgeText), ["CREATE", "CREATE"])
        guard case .createScheduledTask(_, let title, _, _, let duration, _, _, _, _, _, _, _) = output?.envelope.commands.first else {
            return XCTFail("Expected scheduled task")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(duration, 45 * 60)
    }

    func testDeterministicFallbackCreatesTitleFirstTimedScheduleCards() {
        let now = Date(timeIntervalSince1970: 1_777_000_000)
        let output = AssistantDeterministicPlanner.plan(context: .init(
            userPrompt: "Design review at 4 PM for 45 minutes",
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            now: now
        ))

        XCTAssertEqual(output?.envelope.commands.count, 1)
        guard case .createScheduledTask(_, let title, _, _, let duration, _, _, _, _, _, _, _) = output?.envelope.commands.first else {
            return XCTFail("Expected scheduled task")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(duration, 45 * 60)
    }

    func testDeterministicFallbackCreatesScheduleFirstTimedScheduleCards() {
        let now = Date(timeIntervalSince1970: 1_777_000_000)
        let output = AssistantDeterministicPlanner.plan(context: .init(
            userPrompt: "Schedule Design review for 45 minutes at 4 PM",
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            now: now
        ))

        XCTAssertEqual(output?.envelope.commands.count, 1)
        guard case .createScheduledTask(_, let title, _, _, let duration, _, _, _, _, _, _, _) = output?.envelope.commands.first else {
            return XCTFail("Expected scheduled task")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(duration, 45 * 60)
    }

    func testDeterministicFallbackCreatesInboxCards() {
        let output = AssistantDeterministicPlanner.plan(context: .init(
            userPrompt: "Add these to my inbox: call dentist, buy groceries, pay electricity bill",
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            now: Date()
        ))

        XCTAssertEqual(output?.envelope.commands.count, 3)
        guard case .createInboxTask(_, let title, _, _, _, _, _, _) = output?.envelope.commands.first else {
            return XCTFail("Expected inbox task")
        }
        XCTAssertEqual(title, "call dentist")
    }

    func testReadOnlyTodayTasksPromptDoesNotCreateCopiedExampleTask() async throws {
        let evaluator = PlannerEvaluatorSpy()
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "What are my tasks for today",
            thread: Thread(),
            contextPayload: #"{"today":{"tasks":[{"id":"\#(UUID().uuidString)","title":"Ship EVA fix","is_completed":false,"due_date":"2026-04-24T10:00:00Z"}]},"metadata":{"context_partial":false}}"#,
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected read-only review plan")
        }
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertEqual(plan.generationSource, "deterministic_intent_gate")
        XCTAssertNil(evaluator.capturedModelName)
        XCTAssertFalse(encodedEnvelope(plan.envelope).contains("Design review"))
    }

    func testReadOnlyTodayTasksPromptWithPartialContextDoesNotProceedToModel() async throws {
        let evaluator = PlannerEvaluatorSpy()
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "What are my tasks for today",
            thread: Thread(),
            contextPayload: """
            Planning context:
            Status: partial
            """,
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected read-only partial-context fallback")
        }
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertTrue(plan.rationale.contains("couldn't load your tasks"))
        XCTAssertNil(evaluator.capturedModelName)
    }

    func testReadOnlyTodayTasksPromptUsesTodayContextWhenOnlyOptionalSlicesArePartial() async throws {
        let evaluator = PlannerEvaluatorSpy()
        let service = AssistantPlannerService(llm: evaluator)
        let taskID = UUID()
        let result = await service.generatePlan(
            userPrompt: "What are my tasks for today",
            thread: Thread(),
            contextPayload: """
            {
              "today": {
                "tasks": [
                  {
                    "id": "\(taskID.uuidString)",
                    "title": "Ship EVA fix",
                    "is_completed": false
                  }
                ]
              },
              "metadata": {
                "context_partial": true,
                "partial_reasons": ["upcoming_timeout"]
              }
            }
            """,
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected read-only review to use available today context")
        }
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertTrue(plan.rationale.contains("Ship EVA fix"))
        XCTAssertFalse(plan.rationale.contains("couldn't load your tasks"))
        XCTAssertNil(evaluator.capturedModelName)
    }

    func testHelpMePlanMyDayClarifiesWithoutInventingTask() async throws {
        let service = AssistantPlannerService(llm: PlannerEvaluatorSpy())
        let result = await service.generatePlan(
            userPrompt: "Help me plan my day",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected clarification plan")
        }
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertEqual(plan.proposalCards.first?.kind, .noOp)
        XCTAssertFalse(plan.usesModelGenerationForDeliveryGate)
    }

    func testDeterministicPlannerDoesNotDependOnGenerateClearingCancellation() async throws {
        let evaluator = PlannerEvaluatorSpy()
        evaluator.cancelled = true
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "Help me plan my day",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected deterministic day-planning clarification")
        }
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertNil(evaluator.capturedModelName)
        XCTAssertTrue(evaluator.cancelled)
        XCTAssertFalse(plan.usesModelGenerationForDeliveryGate)
    }

    func testHelpMePlanMakingDocCreatesInboxTaskFromPrompt() async throws {
        let service = AssistantPlannerService(llm: PlannerEvaluatorSpy())
        let result = await service.generatePlan(
            userPrompt: "Help me plan making tech debts doc",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected inbox create plan")
        }
        XCTAssertEqual(plan.envelope.commands.count, 1)
        guard case .createInboxTask(_, let title, _, _, _, _, _, _) = plan.envelope.commands.first else {
            return XCTFail("Expected createInboxTask")
        }
        XCTAssertEqual(title, "tech debts doc")
        XCTAssertFalse(title.localizedCaseInsensitiveContains("Design review"))
    }

    func testDeterministicFallbackNoOpsRunningLateWithoutFutureTasks() {
        let output = AssistantDeterministicPlanner.plan(context: .init(
            userPrompt: "I am running 90 minutes late. Shift all remaining tasks today by 90 minutes.",
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [],
            now: Date()
        ))

        XCTAssertEqual(output?.envelope.commands.count, 0)
        XCTAssertEqual(output?.cards.first?.kind, .noOp)
        XCTAssertEqual(output?.cards.first?.title, "No matching tasks found")
    }

    func testPlannerFallsBackWhenModelReturnsProse() async throws {
        let evaluator = PlannerEvaluatorSpy()
        evaluator.stubbedOutput = "I can help you plan. Please share more details."
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "Add these to my inbox: call dentist, buy groceries",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected deterministic fallback to recover from prose")
        }
        XCTAssertEqual(plan.generationSource, "deterministic_intent_gate")
        XCTAssertEqual(plan.envelope.commands.count, 2)
        XCTAssertNil(evaluator.capturedModelName)
    }

    func testPlannerNormalizesBareCommandModelOutput() async throws {
        let restoreDefaults = try configureSupportedPlanRouteOrSkip()
        defer { restoreDefaults() }

        let evaluator = PlannerEvaluatorSpy()
        evaluator.stubbedOutput = """
        {
          "type": "createScheduledTask",
          "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
          "title": "Design review",
          "scheduledStartAt": "2026-04-24T10:00:00Z",
          "scheduledEndAt": "2026-04-24T10:45:00Z",
          "estimatedDuration": 2700,
          "tagIDs": []
        }
        """
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "Design review at 4 PM for 45 minutes",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected model normalization to recover")
        }
        XCTAssertEqual(plan.generationSource, "model_normalized")
        XCTAssertEqual(plan.envelope.commands.count, 1)
    }

    func testPlannerRejectsCopiedExampleCreateWhenPromptDoesNotContainTitle() async throws {
        let restoreDefaults = try configureSupportedPlanRouteOrSkip()
        defer { restoreDefaults() }

        let evaluator = PlannerEvaluatorSpy()
        evaluator.stubbedOutput = """
        {
          "schemaVersion": 3,
          "commands": [
            {
              "type": "createScheduledTask",
              "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
              "title": "Design review",
              "scheduledStartAt": "2026-04-24T10:00:00Z",
              "scheduledEndAt": "2026-04-24T10:45:00Z",
              "estimatedDuration": 2700,
              "tagIDs": []
            }
          ],
          "rationaleText": "I created a scheduled task for the Design review."
        }
        """
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "Schedule roadmap summary",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: []
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected grounding rejection to become clarification")
        }
        XCTAssertEqual(plan.generationSource, "grounding_rejected")
        XCTAssertEqual(plan.envelope.commands.count, 0)
        XCTAssertFalse(encodedEnvelope(plan.envelope).contains("Design review"))
    }

    func testPlannerNormalizesBareCommandRepairOutput() async throws {
        let restoreDefaults = try configureSupportedPlanRouteOrSkip()
        defer { restoreDefaults() }

        let evaluator = PlannerEvaluatorSpy()
        evaluator.stubbedOutputs = [
            "I can help plan that.",
            """
            {
              "type": "createScheduledTask",
              "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
              "title": "Design review",
              "scheduledStartAt": "2026-04-24T10:00:00Z",
              "scheduledEndAt": "2026-04-24T10:45:00Z",
              "estimatedDuration": 2700,
              "tagIDs": []
            }
            """
        ]
        let service = AssistantPlannerService(llm: evaluator)
        let result = await service.generatePlan(
            userPrompt: "Move Design review to 4 PM for 45 minutes",
            thread: Thread(),
            contextPayload: "{}",
            taskTitleByID: [:],
            projectNameByID: [:],
            knownTaskIDs: [UUID()]
        )

        guard case .success(let plan) = result else {
            return XCTFail("Expected repair normalization to recover")
        }
        XCTAssertEqual(plan.generationSource, "repair_normalized")
        XCTAssertEqual(plan.envelope.commands.count, 1)
        XCTAssertTrue(plan.usesModelGenerationForDeliveryGate)
    }

    func testEvaPlanDeliveryPersistsDeterministicZeroCommandWhenEvaluatorCancelled() {
        let traceContext = EvaTurnTraceContext(runID: UUID(), threadID: UUID(), route: .dayPlanning)
        let plan = makePlanResult(commandCount: 0, usesModelGate: false)
        var sentPayloads: [EvaPlanResponsePayload] = []
        var loggedDrops: [[String: String]] = []

        let result = EvaPlanResponseDelivery.deliver(
            payload: EvaPlanResponseDelivery.textPayload(for: plan),
            traceContext: traceContext,
            gateState: .init(taskCancelled: false, runIDMatches: true, evaluatorCancelled: true),
            usesModelGenerationForDeliveryGate: plan.usesModelGenerationForDeliveryGate,
            send: { payload in
                sentPayloads.append(payload)
                return makeSendOutcome(status: .persisted, traceContext: traceContext)
            },
            log: { event, _, fields in
                if event == "eva_plan_response_drop" {
                    loggedDrops.append(fields)
                }
            }
        )

        guard case .persisted = result else {
            return XCTFail("Expected deterministic text to persist despite stale evaluator cancellation")
        }
        XCTAssertEqual(sentPayloads.count, 1)
        XCTAssertEqual(sentPayloads.first?.contentType, "text")
        XCTAssertTrue(loggedDrops.isEmpty)
    }

    func testEvaPlanDeliveryPersistsRequiredContextFailureText() {
        let traceContext = EvaTurnTraceContext(runID: UUID(), threadID: UUID(), route: .weeklyPlanning)
        var sentPayloads: [EvaPlanResponsePayload] = []

        let result = EvaPlanResponseDelivery.deliver(
            payload: .text(content: "I couldn't load enough planning context right now.", sourceModelName: nil),
            traceContext: traceContext,
            gateState: .init(taskCancelled: false, runIDMatches: true, evaluatorCancelled: false),
            usesModelGenerationForDeliveryGate: false,
            send: { payload in
                sentPayloads.append(payload)
                return makeSendOutcome(status: .persisted, traceContext: traceContext)
            }
        )

        guard case .persisted = result else {
            return XCTFail("Expected context failure text to persist")
        }
        XCTAssertEqual(sentPayloads.first?.contentType, "text")
    }

    func testEvaPlanDeliveryZeroCommandUsesTextPayloadOnly() {
        let plan = makePlanResult(commandCount: 0, usesModelGate: false)
        let payload = EvaPlanResponseDelivery.textPayload(for: plan)

        XCTAssertEqual(payload.contentType, "text")
        XCTAssertFalse(AssistantCardCodec.isCard(payload.content))
    }

    func testEvaPlanDeliveryDropsRunIDMismatchWithoutSending() {
        let traceContext = EvaTurnTraceContext(runID: UUID(), threadID: UUID(), route: .dayPlanning)
        var didSend = false
        var loggedReason: String?

        let result = EvaPlanResponseDelivery.deliver(
            payload: .text(content: "Visible response", sourceModelName: nil),
            traceContext: traceContext,
            gateState: .init(taskCancelled: false, runIDMatches: false, evaluatorCancelled: false),
            usesModelGenerationForDeliveryGate: false,
            send: { _ in
                didSend = true
                return makeSendOutcome(status: .persisted, traceContext: traceContext)
            },
            log: { event, _, fields in
                if event == "eva_plan_response_drop" {
                    loggedReason = fields["reason"]
                }
            }
        )

        XCTAssertEqual(result, .dropped(.runIDMismatch))
        XCTAssertFalse(didSend)
        XCTAssertEqual(loggedReason, "run_id_mismatch")
    }

    func testEvaPlanDeliveryDropsModelBackedResponseWhenEvaluatorCancelled() {
        let traceContext = EvaTurnTraceContext(runID: UUID(), threadID: UUID(), route: .taskMutation)
        var didSend = false
        var loggedReason: String?

        let result = EvaPlanResponseDelivery.deliver(
            payload: .text(content: "Model-backed response", sourceModelName: "model"),
            traceContext: traceContext,
            gateState: .init(taskCancelled: false, runIDMatches: true, evaluatorCancelled: true),
            usesModelGenerationForDeliveryGate: true,
            send: { _ in
                didSend = true
                return makeSendOutcome(status: .persisted, traceContext: traceContext)
            },
            log: { event, _, fields in
                if event == "eva_plan_response_drop" {
                    loggedReason = fields["reason"]
                }
            }
        )

        XCTAssertEqual(result, .dropped(.evaluatorCancelled))
        XCTAssertFalse(didSend)
        XCTAssertEqual(loggedReason, "evaluator_cancelled")
    }

    func testEvaProposalCardsUseStructuredBadgesAndRiskDefaults() {
        let taskID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(30 * 60)

        let cards = EvaProposalCardBuilder.build(
            commands: [
                .createScheduledTask(
                    projectID: UUID(),
                    title: "Design review",
                    scheduledStartAt: start,
                    scheduledEndAt: end,
                    estimatedDuration: TimeInterval(30 * 60),
                    lifeAreaID: nil,
                    priority: nil,
                    energy: nil,
                    category: nil,
                    context: nil,
                    details: nil,
                    tagIDs: []
                ),
                .updateTaskSchedule(
                    taskID: taskID,
                    scheduledStartAt: start.addingTimeInterval(60 * 60),
                    scheduledEndAt: end.addingTimeInterval(60 * 60),
                    estimatedDuration: TimeInterval(30 * 60),
                    dueDate: nil
                ),
                .dropTaskFromToday(taskID: taskID, destination: .later, reason: "Too much for today")
            ],
            taskTitleByID: [taskID: "Deep work"]
        )

        XCTAssertEqual(cards.map { $0.badgeText }, ["CREATE", "EDIT", "DROP"])
        XCTAssertTrue(cards[0].primaryAction == EvaProposalAction.add)
        XCTAssertTrue(cards[1].primaryAction == EvaProposalAction.save)
        XCTAssertTrue(cards[0].isSelectedByDefault)
        XCTAssertTrue(cards[1].isSelectedByDefault)
        XCTAssertFalse(cards[2].isSelectedByDefault)
        XCTAssertTrue(cards[2].riskLevel == EvaProposalRisk.destructive)
    }

    func testSelectedEnvelopeCompilesOnlySelectedCommandIndexes() {
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [
                .createInboxTask(projectID: UUID(), title: "Call dentist", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: []),
                .createInboxTask(projectID: UUID(), title: "Buy groceries", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
            ],
            rationaleText: "Inbox capture."
        )
        let cards = EvaProposalCardBuilder.build(commands: envelope.commands)

        let selected = EvaProposalCardBuilder.selectedEnvelope(
            from: envelope,
            selectedCardIDs: [cards[1].id],
            cards: cards
        )

        XCTAssertEqual(selected.schemaVersion, 3)
        XCTAssertEqual(selected.commands.count, 1)
        guard case .createInboxTask(_, let title, _, _, _, _, _, _) = selected.commands.first else {
            return XCTFail("Expected createInboxTask")
        }
        XCTAssertEqual(title, "Buy groceries")
    }

    func testEvaProposalApplyGateAllowsSmallSafeSelectionsOnly() {
        let safeCards = EvaProposalCardBuilder.build(commands: [
            .createInboxTask(projectID: UUID(), title: "Call dentist", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: []),
            .createInboxTask(projectID: UUID(), title: "Buy groceries", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
        ])

        XCTAssertEqual(EvaProposalApplyGate.validate(selectedCards: []), .blocked(message: "Select at least one card to apply."))
        XCTAssertEqual(EvaProposalApplyGate.validate(selectedCards: safeCards), .allowed(appliedCount: 2))

        let largeSafeSelection = EvaProposalCardBuilder.build(commands: (0..<5).map { index in
            .createInboxTask(projectID: UUID(), title: "Task \(index)", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
        })
        XCTAssertEqual(
            EvaProposalApplyGate.validate(selectedCards: largeSafeSelection),
            .blocked(message: "This plan changes 5 or more tasks. Apply a smaller selection first.")
        )
    }

    func testEvaProposalApplyGateBlocksStrictRiskCards() {
        let taskID = UUID()
        let cards = EvaProposalCardBuilder.build(
            commands: [
                .dropTaskFromToday(taskID: taskID, destination: .later, reason: "Too much for today")
            ],
            taskTitleByID: [taskID: "Deep work"]
        )

        XCTAssertEqual(
            EvaProposalApplyGate.validate(selectedCards: cards),
            .blocked(message: "Drop and delete changes need a separate confirmation before EVA can apply them.")
        )
    }

    func testEvaAppliedRunHistoryStorePersistsRecentEntries() {
        let suiteName = "EvaAppliedRunHistoryStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = EvaAppliedRunHistoryStore(defaults: defaults)
        let runID = UUID()
        let card = EvaProposalCardBuilder.build(commands: [
            .createInboxTask(projectID: UUID(), title: "Call dentist", estimatedDuration: nil, lifeAreaID: nil, priority: nil, category: nil, details: nil, tagIDs: [])
        ])[0]
        let entry = EvaAppliedRunHistoryEntry(
            runID: runID,
            threadID: "thread",
            prompt: "Create Call dentist",
            summary: "Created one task.",
            appliedCards: [card],
            discardedCardCount: 0,
            contextReceipt: EvaContextReceipt(sources: ["Inbox"]),
            appliedAt: Date(timeIntervalSince1970: 1_800_000_000),
            undoExpiresAt: Date(timeIntervalSince1970: 1_800_001_800),
            status: AssistantCardStatus.applied.rawValue,
            undoStatus: AssistantCardStatus.undoAvailable.rawValue
        )

        store.record(entry)

        XCTAssertEqual(store.entries(), [entry])
    }
}

private func configureSupportedPlanRouteOrSkip() throws -> () -> Void {
    let modelName = ModelConfiguration.defaultModel.name
    let defaults = UserDefaults.standard
    let originalInstalledData = defaults.data(forKey: LLMPersistedModelSelection.installedModelsKey)
    let originalCurrentModelName = defaults.string(forKey: LLMPersistedModelSelection.currentModelKey)
    LLMPersistedModelSelection.persistInstalledModels([modelName], defaults: defaults)
    defaults.set(modelName, forKey: LLMPersistedModelSelection.currentModelKey)
    let route = AIChatModeRouter.route(for: .planMode)
    guard route.selectedModelName == modelName else {
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
        throw XCTSkip("No supported local model route is available in this test environment.")
    }
    return {
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
}

private func encodedEnvelope(_ envelope: AssistantCommandEnvelope) -> String {
    let data = try! JSONEncoder().encode(envelope)
    return String(decoding: data, as: UTF8.self)
}

private func makePlanResult(commandCount: Int, usesModelGate: Bool) -> AssistantPlanResult {
    let commands: [AssistantCommand] = (0..<commandCount).map { index in
        .createInboxTask(
            projectID: ProjectConstants.inboxProjectID,
            title: "Task \(index)",
            estimatedDuration: nil,
            lifeAreaID: nil,
            priority: nil,
            category: nil,
            details: nil,
            tagIDs: []
        )
    }
    let envelope = AssistantCommandEnvelope(
        schemaVersion: 3,
        commands: commands,
        rationaleText: "Visible planner response."
    )
    return AssistantPlanResult(
        envelope: envelope,
        rationale: envelope.rationaleText ?? "",
        diffLines: [],
        proposalCards: [],
        contextReceipt: EvaContextReceipt(sources: []),
        modelName: usesModelGate ? "model" : "deterministic_intent_gate",
        routeBanner: nil,
        shouldPromptDownload: false,
        generationSource: usesModelGate ? "model" : "deterministic_intent_gate",
        usesModelGenerationForDeliveryGate: usesModelGate
    )
}

private func makeSendOutcome(
    status: ChatMessageSaveStatus,
    traceContext: EvaTurnTraceContext
) -> ChatMessageSendOutcome {
    ChatMessageSendOutcome(
        status: status,
        messageID: UUID(),
        role: "assistant",
        contentType: "text",
        preSanitizeLength: 24,
        postSanitizeLength: status == .emptySanitizedText ? 0 : 24,
        threadID: traceContext.threadID,
        errorDescription: status == .saveFailed ? "save failed" : nil
    )
}

@MainActor
private final class PlannerEvaluatorSpy: LLMEvaluator {
    var capturedModelName: String?
    var capturedRequestOptions: LLMGenerationRequestOptions?
    var capturedMessageCount: Int?
    var capturedUserPrompt: String?
    var stubbedOutput: String?
    var stubbedOutputs: [String] = []

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
        capturedMessageCount = thread.messages.count
        capturedUserPrompt = thread.sortedMessages.last?.content

        if stubbedOutputs.isEmpty == false {
            return stubbedOutputs.removeFirst()
        }
        if let stubbedOutput {
            return stubbedOutput
        }

        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [.createTask(projectID: UUID(), title: "Create inbox note")],
            rationaleText: "Prepared proposed task updates."
        )
        let data = try! JSONEncoder().encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }
}
