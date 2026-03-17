import CoreData
import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMProjectionTimeoutTests: XCTestCase {
    func testTimeoutReturnsFallbackPayload() async {
        let startedAt = Date()
        let result = await LLMProjectionTimeout.execute(timeoutMs: 25) {
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 250_000_000)
                return #"{"late":true}"#
            } catch {
                return #"{"cancelled":true}"#
            }
        }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        XCTAssertEqual(result.payload, "{}")
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(elapsedMs, 200)
    }

    func testFastProjectionReturnsPayloadWithoutTimeout() async {
        let result = await LLMProjectionTimeout.execute(timeoutMs: 250) {
            #"{"ok":true}"#
        }

        XCTAssertEqual(result.payload, #"{"ok":true}"#)
        XCTAssertFalse(result.timedOut)
    }
}

final class LLMContextProjectionServiceTests: XCTestCase {
    func testBuildOverdueJSONIncludesOnlyOpenOverdueTasks() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = makeTask(
            title: "Overdue",
            dueDate: calendar.date(byAdding: .hour, value: -1, to: startOfToday),
            isComplete: false
        )
        let todayTask = makeTask(
            title: "Today",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )
        let completedOverdueTask = makeTask(
            title: "Completed Overdue",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: true
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(
                tasks: [overdueTask, todayTask, completedOverdueTask]
            ),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Overdue"])
    }

    func testBuildOverdueJSONExcludesStartOfDayBoundary() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let boundaryTask = makeTask(
            title: "Boundary",
            dueDate: startOfToday,
            isComplete: false
        )
        let overdueTask = makeTask(
            title: "Past Boundary",
            dueDate: startOfToday.addingTimeInterval(-1),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [boundaryTask, overdueTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Past Boundary"])
        XCTAssertFalse(titles.contains("Boundary"))
    }

    func testBuildTodayJSONKeepsOpenAndCompletedTodayOnly() async throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let dueToday = calendar.date(byAdding: .hour, value: 3, to: startOfToday)
        let completedTodayAt = calendar.date(byAdding: .hour, value: 4, to: startOfToday)
        let completedYesterdayAt = calendar.date(byAdding: .day, value: -1, to: completedTodayAt ?? now)

        var completedToday = makeTask(title: "Completed Today", dueDate: dueToday, isComplete: true)
        completedToday.dateCompleted = completedTodayAt
        var completedYesterday = makeTask(title: "Completed Yesterday", dueDate: dueToday, isComplete: true)
        completedYesterday.dateCompleted = completedYesterdayAt
        let openToday = makeTask(title: "Open Today", dueDate: dueToday, isComplete: false)

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(
                tasks: [completedToday, completedYesterday, openToday]
            ),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildTodayJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Completed Today", "Open Today"])
        XCTAssertFalse(titles.contains("Completed Yesterday"))
    }

    func testContextEnvelopeBuilderMarksMissingServiceAsPartial() async throws {
        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 25, service: nil)
        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        let partialFlags = try XCTUnwrap(payload["partial_flags"] as? [String: Any])

        XCTAssertEqual(metadata["context_partial"] as? Bool, true)
        XCTAssertEqual(partialFlags["missing_service"] as? Bool, true)
        XCTAssertEqual(partialFlags["context_partial"] as? Bool, true)
        XCTAssertTrue(result.usedTimeoutFallback)
    }

    func testContextEnvelopeBuilderIncludesOverdueSlice() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = makeTask(
            title: "Urgent overdue",
            dueDate: calendar.date(byAdding: .hour, value: -4, to: startOfToday),
            isComplete: false
        )
        let todayTask = makeTask(
            title: "Today",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask, todayTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )
        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 250, service: service)

        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let overdue = try XCTUnwrap(payload["overdue"] as? [String: Any])
        XCTAssertEqual(overdue["context_type"] as? String, "overdue")
        XCTAssertEqual(overdue["count"] as? Int, 1)
    }

    func testBuildOverdueJSONIncludesTagNamesFromRepository() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let urgentTag = TagDefinition(name: "Urgent")
        var task = makeTask(
            title: "Overdue tagged",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )
        task.tagIDs = [urgentTag.id]

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [task]),
            projectRepository: MockProjectRepository(),
            tagRepository: MockTagRepository(tags: [urgentTag])
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let firstTask = try XCTUnwrap(tasks.first)
        let tagNames = try XCTUnwrap(firstTask["tag_names"] as? [String])
        XCTAssertEqual(tagNames, ["Urgent"])
    }

    func testContextEnvelopeBuilderMarksTimedOutSlicesAsPartial() async throws {
        let slowRepository = MockTaskReadModelRepository(
            tasks: [makeTask(title: "Slow", dueDate: Date(), isComplete: false)],
            fetchDelayMs: 150
        )
        let service = LLMContextProjectionService(
            taskReadModelRepository: slowRepository,
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 10, service: service)
        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        let partialFlags = try XCTUnwrap(payload["partial_flags"] as? [String: Any])

        XCTAssertEqual(metadata["context_partial"] as? Bool, true)
        XCTAssertEqual(partialFlags["today_timed_out"] as? Bool, true)
        XCTAssertEqual(partialFlags["overdue_timed_out"] as? Bool, true)
        XCTAssertEqual(partialFlags["upcoming_timed_out"] as? Bool, true)
    }

    func testContextProjectionRespectsPerSliceBudget() async throws {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let tasks = (0..<20).map { index in
            makeTask(
                title: "Task \(index)",
                dueDate: tomorrow.addingTimeInterval(Double(index) * 60),
                isComplete: false
            )
        }
        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: tasks),
            projectRepository: MockProjectRepository(),
            tagRepository: nil,
            maxTasksPerSlice: 3,
            compactTaskPayload: true
        )

        let json = await service.buildUpcomingJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        XCTAssertEqual(payload["count"] as? Int, 3)
    }

    func testBuildChatPlanningContextUsesPlaintextSectionsAndLifeAreaNames() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let career = LifeArea(name: "Career")
        let health = LifeArea(name: "Health")
        let workProject = Project(name: "Work")
        let wellnessProject = Project(name: "Wellness")

        let overdueTask = TaskDefinition(
            projectID: workProject.id,
            projectName: workProject.name,
            lifeAreaID: career.id,
            title: "Prepare slides",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )
        let todayTask = TaskDefinition(
            projectID: wellnessProject.id,
            projectName: wellnessProject.name,
            lifeAreaID: health.id,
            title: "Go for a run",
            dueDate: startOfToday.addingTimeInterval(3_600),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask, todayTask]),
            projectRepository: MockProjectRepository(projects: [Project.createInbox(), workProject, wellnessProject]),
            lifeAreaRepository: MockLifeAreaRepository(lifeAreas: [career, health]),
            tagRepository: nil
        )

        let context = await service.buildChatPlanningContext(query: "plan my week", maxChars: 4_000)

        XCTAssertTrue(context.contains("Planning context:"))
        XCTAssertTrue(context.contains("Summary: 1 overdue, 1 today, 0 tomorrow, 0 this week"))
        XCTAssertTrue(context.contains("Focus:"))
        XCTAssertTrue(context.contains("Prepare slides | overdue | Work"))
        XCTAssertTrue(context.contains("Go for a run | today | Wellness"))
        XCTAssertTrue(context.contains("Life areas:"))
        XCTAssertTrue(context.contains("- Career"))
        XCTAssertTrue(context.contains("- Health"))
        XCTAssertTrue(context.contains("Projects:"))
        XCTAssertTrue(context.contains("- Work"))
        XCTAssertTrue(context.contains("- Wellness"))
        XCTAssertFalse(context.contains("Status: full"))
        XCTAssertFalse(context.contains("\"context_type\""))
        XCTAssertFalse(context.contains(overdueTask.id.uuidString))
        XCTAssertFalse(context.contains(workProject.id.uuidString))
    }

    func testBuildChatPlanningContextFailsSoftWithoutLifeAreaRepository() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let workProject = Project(name: "Work")
        let overdueTask = TaskDefinition(
            projectID: workProject.id,
            projectName: workProject.name,
            title: "Prepare slides",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask]),
            projectRepository: MockProjectRepository(projects: [Project.createInbox(), workProject]),
            lifeAreaRepository: nil,
            tagRepository: nil
        )

        let context = await service.buildChatPlanningContext(query: "what is overdue", maxChars: 2_000)

        XCTAssertTrue(context.contains("Planning context:"))
        XCTAssertTrue(context.contains("Projects:"))
        XCTAssertTrue(context.contains("Prepare slides | overdue | Work"))
        XCTAssertFalse(context.contains("Career"))
    }

    func testBuildChatPlanningContextAddsRetrospectiveHistoryForLastWeekQueries() async throws {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? now
        let completedAt = calendar.date(byAdding: .day, value: 2, to: lastWeekStart) ?? now
        let dueAt = calendar.date(byAdding: .day, value: 3, to: lastWeekStart) ?? now
        let workProject = Project(name: "Work")

        var completedTask = TaskDefinition(
            projectID: workProject.id,
            projectName: workProject.name,
            title: "Shipped release notes",
            dueDate: dueAt,
            isComplete: true
        )
        completedTask.dateCompleted = completedAt
        completedTask.updatedAt = completedAt

        let openTask = TaskDefinition(
            projectID: workProject.id,
            projectName: workProject.name,
            title: "Finish customer follow-up",
            dueDate: dueAt,
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [completedTask, openTask]),
            projectRepository: MockProjectRepository(projects: [Project.createInbox(), workProject]),
            lifeAreaRepository: nil,
            tagRepository: nil
        )

        let context = await service.buildChatPlanningContext(
            query: "How was my last week in terms of productivity?",
            maxChars: 4_000
        )

        XCTAssertTrue(context.contains("History:"))
        XCTAssertTrue(context.contains("- Period: Last week"))
        XCTAssertTrue(context.contains("- Completed tasks: 1"))
        XCTAssertTrue(context.contains("- Open due tasks in period: 1"))
        XCTAssertTrue(context.contains("- Projects touched: 1"))
    }

    func testBuildChatPlanningContextSurvivesDuplicateInboxProjectIDs() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = TaskDefinition(
            projectID: ProjectConstants.inboxProjectID,
            projectName: nil,
            title: "Review duplicate inbox task",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )
        let primaryInbox = Project(id: ProjectConstants.inboxProjectID, name: "Inbox")
        let duplicateInbox = Project(id: ProjectConstants.inboxProjectID, name: "Inbox Duplicate")

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask]),
            projectRepository: MockProjectRepository(projects: [primaryInbox, duplicateInbox]),
            lifeAreaRepository: nil,
            tagRepository: nil
        )

        let context = await service.buildChatPlanningContext(query: "plan my week", maxChars: 4_000)

        XCTAssertTrue(context.contains("Planning context:"))
        XCTAssertTrue(context.contains("Review duplicate inbox task"))
    }

    func testBuildOverdueJSONSurvivesDuplicateTagIDs() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let duplicateTagID = UUID()
        var taggedTask = TaskDefinition(
            title: "Overdue tagged task",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )
        taggedTask.tagIDs = [duplicateTagID]
        let duplicateTags = [
            TagDefinition(id: duplicateTagID, name: "Urgent"),
            TagDefinition(id: duplicateTagID, name: "Priority")
        ]

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [taggedTask]),
            projectRepository: MockProjectRepository(),
            lifeAreaRepository: nil,
            tagRepository: MockTagRepository(tags: duplicateTags)
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        XCTAssertEqual(tasks.count, 1)
        let firstTask = try XCTUnwrap(tasks.first)
        let tagNames = try XCTUnwrap(firstTask["tag_names"] as? [String])
        XCTAssertEqual(tagNames, ["Urgent"])
    }

    func testContextEnvelopeBuilderShortCircuitsRemainingSlicesAfterTimeout() async throws {
        let lock = NSLock()
        var fetchCount = 0
        let slowRepository = MockTaskReadModelRepository(
            tasks: [makeTask(title: "Slow", dueDate: Date(), isComplete: false)],
            fetchDelayMs: 150,
            onFetch: {
                lock.lock()
                fetchCount += 1
                lock.unlock()
            }
        )
        let service = LLMContextProjectionService(
            taskReadModelRepository: slowRepository,
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let _ = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 10, service: service)
        try? await _Concurrency.Task.sleep(nanoseconds: 300_000_000)
        lock.lock()
        let observedFetchCount = fetchCount
        lock.unlock()
        XCTAssertEqual(observedFetchCount, 1)
    }

    private func makeTask(
        title: String,
        dueDate: Date?,
        isComplete: Bool
    ) -> TaskDefinition {
        TaskDefinition(
            title: title,
            dueDate: dueDate,
            isComplete: isComplete
        )
    }

    private func parseJSONDictionary(_ raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}

final class LLMVisibleOutputFormatterTests: XCTestCase {
    func testFormatterStripsThinkBlocksAndTemplateArtifacts() {
        let raw = """
        <think>
        long hidden reasoning
        even more hidden reasoning
        </think>
        Focus
        Plan the release tasks.
        <end_of_turn>
        <|im_start|>user
        """

        let visible = LLMVisibleOutputFormatter.formatVisibleText(raw, profile: .chat)

        XCTAssertFalse(visible.contains("<think>"))
        XCTAssertFalse(visible.contains("hidden reasoning"))
        XCTAssertFalse(visible.contains("<end_of_turn>"))
        XCTAssertFalse(visible.contains("<|im_start|>"))
        XCTAssertEqual(visible, "Focus\nPlan the release tasks.")
    }

    func testFormatterTrimsLongVisibleOutputToCharacterBudget() {
        let raw = String(repeating: "a", count: 2_600)
        let visible = LLMVisibleOutputFormatter.formatVisibleText(raw, profile: .chat)

        XCTAssertLessThanOrEqual(visible.count, 2_403)
        XCTAssertTrue(visible.hasSuffix("..."))
    }
}

final class LLMChatTextSanitizerTests: XCTestCase {
    func testSanitizerStripsLeadingImStartAssistantMarker() {
        let raw = "<|im_start|>assistant What tasks are due today?"

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true
        ).text

        XCTAssertEqual(sanitized, "What tasks are due today?")
    }

    func testSanitizerStripsLeadingImStartAssistantMarkerWithNewline() {
        let raw = """
        <|im_start|>assistant
        What tasks are due today?
        """

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        ).text

        XCTAssertEqual(sanitized, "What tasks are due today?")
    }

    func testSanitizerStripsLeadingWideAssistantMarker() {
        let raw = "<｜assistant｜>What tasks are due today?"

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true
        ).text

        XCTAssertEqual(sanitized, "What tasks are due today?")
    }

    func testSanitizerRemovesDanglingTemplateFenceTail() {
        let raw = """
        Summary
        ```json
        {"ok":true}
        ```
        <end_of_turn>
        ```json
        {"bad":true}
        """

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true
        ).text

        XCTAssertEqual(sanitized, "Summary\n```json\n{\"ok\":true}\n```")
    }

    func testSanitizerTrimsMixedTrailingTemplateMarkersOnly() {
        let raw = """
        Summary
        ```json
        {"ok":true}
        ```
        <|end_of_turn|>
        <｜assistant｜>This should never render.
        """

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true
        ).text

        XCTAssertEqual(sanitized, "Summary\n```json\n{\"ok\":true}\n```")
    }

    func testSanitizerTrimsCompoundTrailingMarkersFromEarliestBoundary() {
        let raw = """
        Focus on the release checklist.
        <｜end▁of▁sentence｜>
        <|end_of_turn|>
        """

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: false,
            stripTemplateArtifacts: true,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        ).text

        XCTAssertEqual(sanitized, "Focus on the release checklist.")
    }

    func testSanitizerKeepsAnswerAfterThinkBlockAndTrailingEndMarker() {
        let raw = """
        <｜Assistant｜>
        <think>
        hidden chain of thought
        </think>
        Focus on the release checklist.
        <｜end▁of▁sentence｜>
        """

        let sanitized = LLMChatTextSanitizer.sanitize(
            raw,
            stripReasoningBlocks: true,
            stripTemplateArtifacts: true,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        ).text

        XCTAssertEqual(sanitized, "Focus on the release checklist.")
    }
}

final class LLMPromptHistoryFormattingTests: XCTestCase {
    func testReasoningModelFormatForTokenizerDoesNotInjectLeadingWhitespace() {
        let formatted = ModelConfiguration.qwen_3_0_6b_4bit.formatForTokenizer("Focus on overdue tasks.")
        XCTAssertEqual(formatted, "Focus on overdue tasks.")
    }

    func testReasoningModelFormatForTokenizerStripsThinkBlocksWithoutDroppingAnswer() {
        let formatted = ModelConfiguration.qwen_3_0_6b_4bit.formatForTokenizer(
            """
            <think>
            hidden reasoning
            </think>
            Focus on overdue tasks.
            """
        )

        XCTAssertEqual(formatted, "Focus on overdue tasks.")
    }

    func testSalvageRecoverableTextKeepsAnswerWhenTrailingTemplateArtifactsRemain() {
        let salvaged = LLMChatTextSanitizer.salvageRecoverableText(
            """
            <｜Assistant｜>
            Focus on overdue tasks.
            <|end_of_turn|>
            """,
            stripReasoningBlocks: true,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        )

        XCTAssertEqual(salvaged, "Focus on overdue tasks.\n<|end_of_turn|>")
    }

    func testInteractiveChatRequestOptionsEnableVisibleThinkingForSupportedQwenModels() {
        let options = LLMGenerationRequestOptions.interactiveChat(for: .qwen_3_0_6b_4bit)

        XCTAssertTrue(options.allowThinking)
        XCTAssertTrue(options.isReasoningEnabled)
        XCTAssertTrue(options.showsVisibleThinking)
        XCTAssertTrue(options.templateContext.isEmpty)
    }

    func testStructuredOutputRequestOptionsDisableThinkingAndReasoningBudgeting() {
        let options = LLMGenerationRequestOptions.structuredOutput(for: .qwen_3_0_6b_4bit)

        XCTAssertFalse(options.allowThinking)
        XCTAssertFalse(options.isReasoningEnabled)
        XCTAssertEqual(options.templateContext["enable_thinking"] as? Bool, false)
        XCTAssertEqual(options.effectiveModelType, .regular)
    }

    func testReasoningEnabledRequestOptionsPreserveReasoningMode() {
        let options = LLMGenerationRequestOptions.reasoningEnabled(for: .qwen_3_0_6b_4bit)

        XCTAssertTrue(options.allowThinking)
        XCTAssertTrue(options.isReasoningEnabled)
        XCTAssertTrue(options.templateContext.isEmpty)
        XCTAssertEqual(options.effectiveModelType, .reasoning)
    }

    func testChatProfileUsesModelSpecificVisibleThinkingTuning() {
        let model = ModelConfiguration.qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit
        let options = LLMGenerationRequestOptions.interactiveChat(for: model)
        let profile = LLMGenerationProfile.chatProfile(for: model, requestOptions: options)

        XCTAssertTrue(profile.preservesVisibleThinking)
        XCTAssertEqual(profile.reasoningMaxRawTokens, 1_536)
        XCTAssertEqual(profile.reasoningMinAnswerTokensAfterAnswerPhase, 320)
        XCTAssertEqual(profile.maxVisibleCharacters, 6_400)
        XCTAssertEqual(profile.temperature, 0.5)
        XCTAssertEqual(profile.topP, 0.95)
        XCTAssertEqual(profile.repetitionPenalty, 1.02)
    }
}

final class LLMDataControllerRecoveryTests: XCTestCase {
    func testCocoaMigrationCodeDoesNotTriggerStoreRecreation() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSPersistentStoreIncompatibleSchemaError,
            userInfo: nil
        )

        XCTAssertEqual(
            LLMDataController.recoveryDisposition(for: error),
            .fallbackWithoutRecreation(reason: "persistent_store_migration_failed")
        )
    }

    func testMigrationLikeErrorDoesNotTriggerStoreRecreation() {
        let error = NSError(
            domain: "LLMDataControllerTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The model used to open the store is incompatible with the one used to create the store"]
        )

        XCTAssertEqual(
            LLMDataController.recoveryDisposition(for: error),
            .fallbackWithoutRecreation(reason: "persistent_store_migration_failed")
        )
    }

    func testCorruptionLikeErrorTriggersStoreRecreation() {
        let error = NSError(
            domain: "LLMDataControllerTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "database disk image is malformed"]
        )

        XCTAssertEqual(
            LLMDataController.recoveryDisposition(for: error),
            .recreatePersistentStore(reason: "persistent_store_corrupted")
        )
    }
}

final class LLMChatQualityGateTests: XCTestCase {
    func testQualityGateRejectsGenericIntroAndRepetitionLoop() {
        let output = """
        Okay, I'm ready to be your proactive personal assistant.
        Focus on overdue tasks first.
        Focus on overdue tasks first.
        Focus on overdue tasks first.
        """

        let assessment = LLMChatQualityGate.assess(
            output,
            userPrompt: "What tasks should I focus on?",
            terminationReason: "eos"
        )

        XCTAssertFalse(assessment.isAcceptable)
        XCTAssertTrue(assessment.hardFailureReasons.contains("generic_intro"))
        XCTAssertTrue(assessment.reasons.contains("repetition_loop"))
        XCTAssertEqual(assessment.repetitionDiagnostics?.confidence, "high_confidence_loop")
    }

    func testQualityGateAcceptsShortDirectAnswer() {
        let assessment = LLMChatQualityGate.assess(
            """
            Focus:
            - Prepare slides
            - Review roadmap
            """,
            userPrompt: "What tasks should I focus on?",
            terminationReason: "eos"
        )

        XCTAssertTrue(assessment.isAcceptable)
        XCTAssertFalse(assessment.shouldRetry)
    }

    func testQualityGateAcceptsStructuredPlanningOutputWithoutFalseRepetitionLoop() {
        let assessment = LLMChatQualityGate.assess(
            """
            Focus today:
            - Clear the most urgent overdue task in Inbox.
            - Reply on the SINGULARITY thread with the next concrete step.
            - Block 30 minutes for PZ_2026 prep this afternoon.
            """,
            userPrompt: "What should I do today?",
            terminationReason: "eos"
        )

        XCTAssertTrue(assessment.isAcceptable)
        XCTAssertFalse(assessment.reasons.contains("repetition_loop"))
        XCTAssertNil(assessment.repetitionDiagnostics)
    }

    func testQualityGateTreatsLowConfidenceStructuredRepetitionAsSoftWarningOnEOS() {
        let assessment = LLMChatQualityGate.assess(
            """
            Focus today:
            - Review the overdue Inbox task.
            - Review the overdue Inbox task.
            """,
            userPrompt: "What should I do today?",
            terminationReason: "eos"
        )

        XCTAssertTrue(assessment.isAcceptable)
        XCTAssertTrue(assessment.softWarningReasons.contains("low_confidence_structured_repetition"))
        XCTAssertEqual(assessment.reasons, ["low_confidence_structured_repetition"])
    }

    func testQualityGateAllowsRepeatedProjectNamesAcrossDistinctBullets() {
        let assessment = LLMChatQualityGate.assess(
            """
            Focus today:
            - SINGULARITY: confirm the overdue deliverable and next owner.
            - SINGULARITY: reply with the concrete unblocker needed today.
            - PZ_2026: prepare the review notes for the afternoon sync.
            """,
            userPrompt: "What should I do today?",
            terminationReason: "eos"
        )

        XCTAssertTrue(assessment.isAcceptable)
        XCTAssertFalse(assessment.reasons.contains("repetition_loop"))
    }

    func testOutputClassifierTreatsThinkingOnlyOutputAsRetryable() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            <think>
            Okay, let me reason through the user's schedule.
            """,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "raw_cap"
        )

        XCTAssertTrue(assessment.finalOutput.hasPrefix("<think>"))
        XCTAssertTrue(assessment.salvageOutput.isEmpty)
        XCTAssertTrue(assessment.thinkingOnlyOutput)
        XCTAssertFalse(assessment.templateMismatch)
        XCTAssertEqual(assessment.qualityAssessment.reasons, ["answer_missing_after_thinking"])
        XCTAssertTrue(assessment.qualityAssessment.shouldRetry)
    }

    func testOutputClassifierPreservesVisibleThinkingForPlainTextReasoningModels() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            Thinking Process:
            1. Analyze the request.
            2. Summarize the likely priorities.
            """,
            modelName: ModelConfiguration.qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "raw_cap"
        )

        XCTAssertTrue(assessment.hasVisibleThinking)
        XCTAssertFalse(assessment.hasAnswer)
        XCTAssertEqual(assessment.extractionMode, "plaintext")
        XCTAssertEqual(assessment.qualityAssessment.reasons, ["answer_missing_after_thinking"])
        XCTAssertTrue(assessment.qualityAssessment.shouldRetry)
        XCTAssertTrue(assessment.finalOutput.hasPrefix("<think>"))
    }

    func testOutputClassifierAssessesAnswerInsteadOfCombinedThinkingLength() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            <think>
            Let me reason through the user's request in detail and think carefully.
            </think>

            Focus on the top 2 overdue tasks and one prep item for tomorrow.
            """,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "raw_cap"
        )

        XCTAssertTrue(assessment.qualityAssessment.isAcceptable)
        XCTAssertTrue(assessment.hasVisibleThinking)
        XCTAssertTrue(assessment.hasAnswer)
        XCTAssertEqual(
            assessment.finalOutput,
            """
            <think>
            Let me reason through the user's request in detail and think carefully.
            </think>

            Focus on the top 2 overdue tasks and one prep item for tomorrow.
            """
        )
    }

    func testOutputClassifierAcceptsLongStructuredAnswerOnEOS() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            Let me analyze the current planning context.

            Focus today:
            - Clear the highest-priority overdue task in Inbox.
            - Respond on SINGULARITY with the next concrete deliverable.
            - Reserve time for PZ_2026 preparation before end of day.
            """,
            modelName: ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "eos"
        )

        XCTAssertTrue(assessment.qualityAssessment.isAcceptable)
        XCTAssertFalse(assessment.qualityAssessment.reasons.contains("repetition_loop"))
    }

    func testAnswerCompletionRetryDisablesVisibleThinkingForSupportedModel() {
        let options = LLMGenerationRequestOptions.answerCompletionRetry(
            for: .qwen_3_0_6b_4bit
        )

        XCTAssertFalse(options.allowThinking)
        XCTAssertFalse(options.isReasoningEnabled)
        XCTAssertFalse(options.showsVisibleThinking)
        XCTAssertEqual(options.templateContext["enable_thinking"] as? Bool, false)
        XCTAssertEqual(options.effectiveModelType, .regular)
    }

    func testOutputClassifierTreatsTerminalMarkersOnlyAsEmptyOutputAndRetryable() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            <|end_of_turn|>
            <|im_end|>
            """,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "raw_cap"
        )

        XCTAssertTrue(assessment.finalOutput.isEmpty)
        XCTAssertTrue(assessment.salvageOutput.isEmpty)
        XCTAssertFalse(assessment.templateMismatch)
        XCTAssertEqual(assessment.qualityAssessment.reasons, ["empty_output"])
        XCTAssertTrue(assessment.qualityAssessment.shouldRetry)
    }

    func testOutputClassifierPreservesVisibleAnswerWhenTemplateMarkersAreRecoverable() {
        let assessment = LLMChatOutputClassifier.assess(
            rawOutput: """
            <think>
            hidden reasoning
            </think>
            <｜Assistant｜>Visible answer that salvage can recover.
            <|end_of_turn|>
            """,
            modelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
            userPrompt: "What should I do today?",
            terminationReason: "raw_cap"
        )

        XCTAssertTrue(assessment.finalOutput.isEmpty == false)
        XCTAssertFalse(assessment.templateMismatch)
        XCTAssertEqual(
            assessment.finalOutput,
            """
            <think>
            hidden reasoning
            </think>

            Visible answer that salvage can recover.
            """
        )
    }
}

final class LLMChatGenerationLimiterTests: XCTestCase {
    func testReasoningLimiterAllowsAnswerFloorAfterLateAnswerPhase() {
        var limiter = LLMChatGenerationLimiter(
            maxRawTokens: 768,
            minAnswerTokensAfterAnswerPhase: 200
        )

        XCTAssertNil(limiter.stopReason(currentTokenCount: 768))
        limiter.markAnswerPhaseStarted(currentTokenCount: 820)
        XCTAssertNil(limiter.stopReason(currentTokenCount: 900))
        XCTAssertEqual(limiter.stopReason(currentTokenCount: 1_019), "answer_floor_reached")
    }

    func testReasoningLimiterUsesGraceBeforeAnyAnswerStarts() {
        var limiter = LLMChatGenerationLimiter(
            maxRawTokens: 768,
            minAnswerTokensAfterAnswerPhase: 200
        )

        XCTAssertNil(limiter.stopReason(currentTokenCount: 900))
        XCTAssertEqual(limiter.stopReason(currentTokenCount: 968), "raw_cap")
    }
}

final class PromptMiddlewareTests: XCTestCase {
    override func tearDown() {
        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: nil,
            projectRepository: nil,
            tagRepository: nil
        )
        super.tearDown()
    }

    func testTodaySummaryIncludesOverdueSection() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = TaskDefinition(
            title: "Overdue Task",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: false
        )
        let todayTask = TaskDefinition(
            title: "Today Task",
            dueDate: calendar.date(byAdding: .hour, value: 1, to: startOfToday),
            isComplete: false
        )

        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [todayTask, overdueTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let summary = PromptMiddleware.buildTasksSummary(range: .today)
        XCTAssertTrue(summary.contains("Overdue:"))
        XCTAssertTrue(summary.contains("• [overdue] Overdue Task"))
        XCTAssertTrue(summary.contains("Due today:"))
        XCTAssertTrue(summary.contains("• [today] Today Task"))
    }
}

final class SlashCommandCatalogTests: XCTestCase {
    func testParseTodoAliasResolvesToTodayInvocation() {
        let result = SlashCommandCatalog.parse("/todo")
        switch result {
        case .invocation(let invocation):
            XCTAssertEqual(invocation.id, .today)
        default:
            XCTFail("Expected /todo to parse as a today invocation")
        }
    }

    func testParseUnknownSlashCommandReturnsUnknownResult() {
        let result = SlashCommandCatalog.parse("/notreal")
        switch result {
        case .unknown(let command):
            XCTAssertEqual(command, "/notreal")
        default:
            XCTFail("Expected unknown command parse result")
        }
    }

    func testParseProjectWithoutNameReturnsMissingArgument() {
        let result = SlashCommandCatalog.parse("/project")
        switch result {
        case .missingRequiredArgument(let commandID, let partial):
            XCTAssertEqual(commandID, .project)
            XCTAssertNil(partial)
        default:
            XCTFail("Expected missing argument parse result for /project")
        }
    }

    func testFilteredDescriptorsPrioritizesRecentsBeforePopularity() {
        let filtered = SlashCommandCatalog.filteredDescriptors(
            query: "",
            recents: [.month, .project],
            limit: 3
        )

        XCTAssertEqual(filtered.map(\.id), [.month, .project, .today])
    }
}

final class SlashCommandExecutionServiceTests: XCTestCase {
    func testTodayExecutionIncludesOverdueAndDueTodayOnly() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = TaskDefinition(
            title: "Overdue task",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: false
        )
        let dueTodayTask = TaskDefinition(
            title: "Due today task",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )
        let completedOverdueTask = TaskDefinition(
            title: "Completed overdue",
            dueDate: calendar.date(byAdding: .hour, value: -4, to: startOfToday),
            isComplete: true
        )

        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask, dueTodayTask, completedOverdueTask]),
            projectRepository: MockProjectRepository()
        )
        let result = try await service.execute(
            invocation: SlashCommandInvocation(id: .today, projectQuery: nil, projectName: nil)
        )

        XCTAssertEqual(result.commandID, .today)
        XCTAssertEqual(result.totalTaskCount, 2)
        XCTAssertEqual(Set(result.sections.map(\.id)), Set(["overdue", "today"]))
        let titles = Set(result.sections.flatMap { $0.tasks.map(\.title) })
        XCTAssertEqual(titles, Set(["Overdue task", "Due today task"]))
        XCTAssertFalse(titles.contains("Completed overdue"))
    }

    func testProjectExecutionDoesNotFallbackToAllTasksWhenProjectMissing() async throws {
        var inboxTask = TaskDefinition(title: "Inbox task", dueDate: Date(), isComplete: false)
        inboxTask.projectName = "Inbox"
        var workTask = TaskDefinition(title: "Work task", dueDate: Date(), isComplete: false)
        workTask.projectName = "Work"

        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [inboxTask, workTask]),
            projectRepository: MockProjectRepository(projects: [
                Project.createInbox(),
                Project(name: "Work")
            ])
        )

        do {
            _ = try await service.execute(
                invocation: SlashCommandInvocation(id: .project, projectQuery: "Unknown Project", projectName: nil)
            )
            XCTFail("Expected missing project query to fail")
        } catch let error as SlashCommandExecutionError {
            switch error {
            case .projectNotFound(let query):
                XCTAssertEqual(query, "Unknown Project")
            default:
                XCTFail("Expected projectNotFound error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProjectExecutionReturnsAmbiguousErrorForNonUniqueMatch() async throws {
        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: []),
            projectRepository: MockProjectRepository(projects: [
                Project.createInbox(),
                Project(name: "Work Alpha"),
                Project(name: "Work Beta")
            ])
        )

        do {
            _ = try await service.execute(
                invocation: SlashCommandInvocation(id: .project, projectQuery: "Work", projectName: nil)
            )
            XCTFail("Expected ambiguous project match to fail")
        } catch let error as SlashCommandExecutionError {
            switch error {
            case .ambiguousProjectName(let query, let matches):
                XCTAssertEqual(query, "Work")
                XCTAssertEqual(Set(matches), Set(["Work Alpha", "Work Beta"]))
            default:
                XCTFail("Expected ambiguousProjectName error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private let tasks: [TaskDefinition]
    private let fetchDelayMs: Int
    private let onFetch: (() -> Void)?

    init(tasks: [TaskDefinition], fetchDelayMs: Int = 0, onFetch: (() -> Void)? = nil) {
        self.tasks = tasks
        self.fetchDelayMs = fetchDelayMs
        self.onFetch = onFetch
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        onFetch?()
        var filtered = tasks
        if let projectID = query.projectID {
            filtered = filtered.filter { $0.projectID == projectID }
        }
        if query.includeCompleted == false {
            filtered = filtered.filter { !$0.isComplete }
        }
        if let dueDateStart = query.dueDateStart {
            filtered = filtered.filter { ($0.dueDate ?? .distantPast) >= dueDateStart }
        }
        if let dueDateEnd = query.dueDateEnd {
            filtered = filtered.filter { ($0.dueDate ?? .distantFuture) <= dueDateEnd }
        }
        filtered = filtered.sorted {
            ($0.dueDate ?? .distantFuture, $0.updatedAt) < ($1.dueDate ?? .distantFuture, $1.updatedAt)
        }
        let totalCount = filtered.count
        let boundedOffset = min(max(0, query.offset), filtered.count)
        let boundedLimit = max(0, query.limit)
        let sliceEnd = min(filtered.count, boundedOffset + boundedLimit)
        let pagedTasks = Array(filtered[boundedOffset..<sliceEnd])
        let result = TaskDefinitionSliceResult(
            tasks: pagedTasks,
            totalCount: totalCount,
            limit: query.limit,
            offset: query.offset
        )
        if fetchDelayMs > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(fetchDelayMs)) {
                completion(.success(result))
            }
            return
        }
        completion(.success(result))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    func fetchProjectTaskCounts(includeCompleted: Bool, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }

    func fetchProjectCompletionScoreTotals(from startDate: Date, to endDate: Date, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }
}

private final class MockTagRepository: TagRepositoryProtocol {
    private let tags: [TagDefinition]

    init(tags: [TagDefinition]) {
        self.tags = tags
    }

    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        completion(.success(tags))
    }

    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        completion(.success(tag))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [Project]

    init(projects: [Project] = [Project.createInbox()]) {
        self.projects = projects
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success(projects)) }
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(projects.first { $0.id == id })) }
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(projects.first { $0.name == name })) }
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(projects.first { $0.isInbox } ?? Project.createInbox())) }
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success(projects.filter { !$0.isInbox })) }
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { projects.append(project); completion(.success(project)) }
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(projects.first { $0.isInbox } ?? Project.createInbox())) }
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: projects.count, merged: 0, deleted: 0, inboxCandidates: projects.filter { $0.isInbox }.count, warnings: [])))
    }
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == id }) {
            var updated = projects[index]
            updated.name = newName
            projects[index] = updated
            completion(.success(updated))
            return
        }
        completion(.failure(NSError(domain: "mock", code: 404)))
    }
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) { completion(.success(0)) }
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}

private final class MockLifeAreaRepository: LifeAreaRepositoryProtocol {
    private let lifeAreas: [LifeArea]

    init(lifeAreas: [LifeArea]) {
        self.lifeAreas = lifeAreas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(lifeAreas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}
