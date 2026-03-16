import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMModelRegistryTests: XCTestCase {
    private let unsupportedModelName = "unsupported/legacy-model"
    private let unsupportedModelNameTwo = "unsupported/legacy-model-2"
    private let qwenPointSixName = "mlx-community/Qwen3-0.6B-4bit"
    private let qwenOptiQName = "mlx-community/Qwen3.5-0.8B-OptiQ-4bit"
    private var originalContextStrategy: LLMChatContextStrategy = .bounded

    override func setUp() {
        super.setUp()
        originalContextStrategy = V2FeatureFlags.llmChatContextStrategy
    }

    override func tearDown() {
        V2FeatureFlags.llmChatContextStrategy = originalContextStrategy
        super.tearDown()
    }

    func testAvailableModelsContainsExactlyTwoSupportedQwenModels() {
        let modelNames = ModelConfiguration.availableModels.map(\.name)
        XCTAssertEqual(modelNames, [qwenPointSixName, qwenOptiQName])
    }

    func testDefaultModelIsQwenPointSix() {
        XCTAssertEqual(ModelConfiguration.defaultModel.name, qwenPointSixName)
    }

    func testOptiQModelMetadataIsExposed() {
        let model = tryUnwrap(ModelConfiguration.getModelByName(qwenOptiQName))
        XCTAssertEqual(model.displayName, "Qwen3.5 0.8B OptiQ 4bit")
        XCTAssertEqual(model.onboardingBadgeTitle, "Smarter")
        XCTAssertEqual(model.modelType, .reasoning)
        XCTAssertGreaterThan(model.tokenBudget.taskContextTokens, ModelConfiguration.defaultModel.tokenBudget.taskContextTokens)
    }

    func testPreferredActiveModelNamePrefersDefaultModelWhenBothAreInstalled() {
        XCTAssertEqual(
            AppManager.preferredActiveModelName(from: [qwenOptiQName, qwenPointSixName]),
            qwenPointSixName
        )
    }

    func testResolvedBudgetUsesProvidedModelRatherThanDefaultModel() {
        let optiQBudget = LLMChatBudgets.active.resolved(for: tryUnwrap(ModelConfiguration.getModelByName(qwenOptiQName)))

        XCTAssertEqual(optiQBudget.maxPromptTokens, 1_920)
        XCTAssertEqual(optiQBudget.maxContextTokens, 700)
        XCTAssertGreaterThan(optiQBudget.maxPromptTokens, ModelConfiguration.defaultModel.tokenBudget.inputTokens)
    }

    func testInstallCatalogSurfacesBothModelsWhenMemoryAllows() {
        let catalog = TwoQwenModelInstallCatalog.make(
            installedModelNames: [],
            availableMemory: 8
        )

        XCTAssertEqual(catalog.installableModels.map(\.name), [qwenPointSixName, qwenOptiQName])
    }

    func testInstallCatalogFiltersHeavierModelOnSmallMemoryDevices() {
        let catalog = TwoQwenModelInstallCatalog.make(
            installedModelNames: [],
            availableMemory: 3
        )

        XCTAssertEqual(catalog.installableModels.map(\.name), [qwenPointSixName])
    }

    func testPersistedModelNormalizationRemovesUnsupportedLegacyModels() throws {
        let suiteName = "LLMModelRegistryTests.Legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let applicationSupportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMModelRegistryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: applicationSupportDirectory) }

        for modelName in [unsupportedModelName, unsupportedModelNameTwo] {
            let folderURL = try XCTUnwrap(
                LLMPersistedModelSelection.modelFolderURL(
                    for: modelName,
                    applicationSupportDirectory: applicationSupportDirectory
                )
            )
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }

        LLMPersistedModelSelection.persistInstalledModels(
            [unsupportedModelName, qwenPointSixName, unsupportedModelNameTwo],
            defaults: defaults
        )
        defaults.set(unsupportedModelName, forKey: LLMPersistedModelSelection.currentModelKey)

        let state = LLMPersistedModelSelection.normalize(
            defaults: defaults,
            fileManager: .default,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(state, .init(installedModels: [qwenPointSixName], currentModelName: qwenPointSixName))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: LLMPersistedModelSelection.modelFolderURL(
                    for: unsupportedModelName,
                    applicationSupportDirectory: applicationSupportDirectory
                )?.path ?? ""
            )
        )
    }

    func testPromptHistoryRespectsTokenBudgetAndKeepsLatestSuffix() {
        V2FeatureFlags.llmChatContextStrategy = .bounded
        let thread = To_Do_List.Thread()
        let suffix = "LATEST_SUFFIX_SHOULD_SURVIVE"
        let oversizedContent = String(repeating: "x", count: 12_000) + suffix
        thread.messages.append(Message(role: .user, content: oversizedContent, thread: thread))

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        let totalTokens = history.reduce(0) { partial, item in
            partial + LLMTokenBudgetEstimator.estimatedTokenCount(for: item["content"] ?? "")
        }

        XCTAssertLessThanOrEqual(totalTokens, ModelConfiguration.defaultModel.tokenBudget.inputTokens)
        XCTAssertEqual(history.last?["role"], "user")
        XCTAssertTrue((history.last?["content"] ?? "").hasSuffix(suffix))
    }

    func testPromptHistoryDropsTemplateGarbage() {
        let thread = To_Do_List.Thread()
        thread.messages.append(Message(role: .assistant, content: "<end_of_turn><|im_end|>", thread: thread))

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        XCTAssertEqual(history.count, 1)
    }

    func testPromptHistoryIncludesSlashCommandSummary() {
        let thread = To_Do_List.Thread()
        let result = SlashCommandExecutionResult(
            commandID: .today,
            commandLabel: "/today",
            summary: "2 tasks need attention.",
            sections: [
                SlashCommandTaskSection(
                    id: "today",
                    title: "Due Today",
                    tasks: [
                        SlashCommandTaskItem(
                            taskID: UUID(),
                            title: "Review roadmap",
                            projectName: "Work",
                            dueDateISO: nil,
                            dueLabel: "today",
                            taskSnapshot: TaskDefinition(title: "Review roadmap", dueDate: Date(), isComplete: false)
                        )
                    ],
                    totalCount: 1
                )
            ],
            totalTaskCount: 1,
            generatedAtISO: Date().ISO8601Format()
        )
        let payload = AssistantCardPayload(
            cardType: .commandResult,
            threadID: thread.id.uuidString,
            status: .confirmed,
            commandResult: result
        )
        thread.messages.append(Message(role: .assistant, content: AssistantCardCodec.encode(payload), thread: thread))

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        let content = history.last?["content"] ?? ""
        XCTAssertTrue(content.contains("Slash command: /today"))
        XCTAssertTrue(content.contains("Review roadmap"))
    }

    func testSystemPromptComposerPreservesTaskContextUnderOverflow() {
        let model = ModelConfiguration.defaultModel
        let prompt = LLMSystemPromptComposer.compose(
            basePrompt: String(repeating: "base ", count: 400),
            model: model,
            additionalInstruction: String(repeating: "instruction ", count: 400),
            personalMemory: String(repeating: "memory ", count: 400),
            slashContext: "Slash marker survives",
            taskContext: "Task marker survives"
        )

        XCTAssertTrue(prompt.contains("Task marker survives"))
        XCTAssertTrue(prompt.contains("Slash marker survives"))
        XCTAssertLessThanOrEqual(
            LLMTokenBudgetEstimator.estimatedTokenCount(for: prompt),
            model.tokenBudget.inputTokens
        )
    }

    func testPromptMigrationUpdatesLegacyBuiltInPromptOnly() {
        let migrated = AppManager.migratedBuiltInSystemPrompt(
            "You are Eva, a clever personal assistant. Keep tasks and priorities aligned. Be brief, clear, and helpful. Use simple markdown, short lists, and casual dates. Use only provided context. Do not invent details."
        )

        XCTAssertEqual(migrated, AppManager.defaultSystemPrompt)
    }

    func testPromptMigrationPreservesCustomPrompt() {
        XCTAssertNil(AppManager.migratedBuiltInSystemPrompt("Custom prompt"))
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("unreachable")
        }
        return value
    }
}
