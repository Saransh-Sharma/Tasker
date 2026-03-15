//
//  LLMModelRegistryTests.swift
//  To Do ListTests
//

import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMModelRegistryTests: XCTestCase {
    private let gemmaModelName = "mlx-community/gemma-3-270m-it-4bit"
    private let nexVeridianQwenModelName = "NexVeridian/Qwen3.5-0.8B-4bit"
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

    func testAvailableModelsExcludesRetiredModels() {
        let modelNames = ModelConfiguration.availableModels.map(\.name)
        XCTAssertFalse(modelNames.contains(gemmaModelName))
        XCTAssertFalse(modelNames.contains(nexVeridianQwenModelName))
    }

    func testGetModelByNameReturnsQwenPointSixB() {
        let model = ModelConfiguration.getModelByName(qwenModelName)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.name, qwenModelName)
    }

    func testGetModelByNameReturnsNilForRetiredModels() {
        XCTAssertNil(ModelConfiguration.getModelByName(gemmaModelName))
        XCTAssertNil(ModelConfiguration.getModelByName(nexVeridianQwenModelName))
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

    func testModelInstallPickerSectionsSurfaceDefaultModelAsRecommended() {
        let sections = ModelInstallPickerSections.make(
            installedModelNames: [],
            availableMemory: 100,
            memoryThreshold: 1
        )

        XCTAssertEqual(sections.recommendedModel?.name, qwenModelName)
    }

    func testModelInstallPickerSectionsExcludeRecommendedModelFromOtherModels() {
        let sections = ModelInstallPickerSections.make(
            installedModelNames: [],
            availableMemory: 100,
            memoryThreshold: 1
        )

        XCTAssertFalse(sections.otherModels.contains(where: { $0.name == qwenModelName }))
    }

    func testModelInstallPickerSectionsKeepRecommendedVisibleWhenOtherModelsInstalled() {
        let sections = ModelInstallPickerSections.make(
            installedModelNames: [ModelConfiguration.llama_3_2_1b_4bit.name],
            availableMemory: 100,
            memoryThreshold: 1
        )

        XCTAssertEqual(sections.installedModels, [ModelConfiguration.llama_3_2_1b_4bit.name])
        XCTAssertEqual(sections.recommendedModel?.name, qwenModelName)
    }

    func testModelInstallPickerSectionsHideRecommendedWhenAlreadyInstalled() {
        let sections = ModelInstallPickerSections.make(
            installedModelNames: [qwenModelName],
            availableMemory: 100,
            memoryThreshold: 1
        )

        XCTAssertNil(sections.recommendedModel)
    }

    func testModelInstallPickerSectionsHideRecommendedWhenMemoryFilterExcludesIt() {
        let sections = ModelInstallPickerSections.make(
            installedModelNames: [],
            availableMemory: 0,
            memoryThreshold: 1
        )

        XCTAssertNil(sections.recommendedModel)
        XCTAssertTrue(sections.otherModels.isEmpty)
    }

    func testRetiredModelsAreNotDefaultModel() {
        XCTAssertNotEqual(ModelConfiguration.defaultModel.name, gemmaModelName)
        XCTAssertNotEqual(ModelConfiguration.defaultModel.name, nexVeridianQwenModelName)
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

    func testPersistedModelNormalizationRetiresOnlyInstalledModelsAndDeletesCachedFiles() throws {
        let suiteName = "LLMModelRegistryTests.RetiredOnly.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let applicationSupportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMModelRegistryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: applicationSupportDirectory) }

        for modelName in [gemmaModelName, nexVeridianQwenModelName] {
            let folderURL = try XCTUnwrap(
                LLMPersistedModelSelection.modelFolderURL(
                    for: modelName,
                    applicationSupportDirectory: applicationSupportDirectory
                )
            )
            try FileManager.default.createDirectory(
                at: folderURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        LLMPersistedModelSelection.persistInstalledModels(
            [gemmaModelName, nexVeridianQwenModelName],
            defaults: defaults
        )
        defaults.set(gemmaModelName, forKey: LLMPersistedModelSelection.currentModelKey)

        let state = LLMPersistedModelSelection.normalize(
            defaults: defaults,
            fileManager: .default,
            applicationSupportDirectory: applicationSupportDirectory
        )

        XCTAssertEqual(state, .init(installedModels: [], currentModelName: nil))
        XCTAssertEqual(LLMPersistedModelSelection.loadInstalledModels(defaults: defaults), [])
        XCTAssertNil(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey))
        for modelName in [gemmaModelName, nexVeridianQwenModelName] {
            let folderURL = LLMPersistedModelSelection.modelFolderURL(
                for: modelName,
                applicationSupportDirectory: applicationSupportDirectory
            )
            XCTAssertFalse(FileManager.default.fileExists(atPath: folderURL?.path ?? ""))
        }
    }

    func testPersistedModelNormalizationPromotesFirstSupportedInstalledModel() {
        let suiteName = "LLMModelRegistryTests.Mixed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        LLMPersistedModelSelection.persistInstalledModels(
            [
                nexVeridianQwenModelName,
                qwenModelName,
                qwenModelName,
                "mlx-community/Unknown-Model",
                ModelConfiguration.llama_3_2_1b_4bit.name,
                gemmaModelName
            ],
            defaults: defaults
        )
        defaults.set(gemmaModelName, forKey: LLMPersistedModelSelection.currentModelKey)

        let state = LLMPersistedModelSelection.normalize(defaults: defaults)

        XCTAssertEqual(
            state,
            .init(
                installedModels: [qwenModelName, ModelConfiguration.llama_3_2_1b_4bit.name],
                currentModelName: qwenModelName
            )
        )
        XCTAssertEqual(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey), qwenModelName)
    }

    func testPersistedModelNormalizationLeavesValidSelectionsUnchanged() {
        let suiteName = "LLMModelRegistryTests.Valid.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let installedModels = [
            ModelConfiguration.llama_3_2_1b_4bit.name,
            qwenModelName
        ]
        LLMPersistedModelSelection.persistInstalledModels(installedModels, defaults: defaults)
        defaults.set(qwenModelName, forKey: LLMPersistedModelSelection.currentModelKey)

        let state = LLMPersistedModelSelection.normalize(defaults: defaults)

        XCTAssertEqual(
            state,
            .init(installedModels: installedModels, currentModelName: qwenModelName)
        )
        XCTAssertEqual(LLMPersistedModelSelection.loadInstalledModels(defaults: defaults), installedModels)
        XCTAssertEqual(defaults.string(forKey: LLMPersistedModelSelection.currentModelKey), qwenModelName)
    }

    func testShippedModelsExposeChatStopTokens() {
        for model in ModelConfiguration.availableModels {
            XCTAssertFalse(
                model.extraEOSTokens.isEmpty,
                "Expected stop tokens for \(model.name)"
            )
        }
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

        XCTAssertLessThanOrEqual(history.count, LLMChatBudgets.bounded.maxThreadMessages + 1)
        XCTAssertEqual(history.first?["role"], "system")
        XCTAssertFalse((history.dropFirst().first?["content"] ?? "").contains("Earlier context recap"))
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

    func testPromptHistorySanitizesCorruptedAssistantMessages() {
        let thread = To_Do_List.Thread()
        thread.messages.append(Message(role: .assistant, content: "Plan\n<end_of_turn>\n<|im_start|>user", thread: thread))

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        XCTAssertEqual(
            history.last?["content"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            "Plan"
        )
    }

    func testPromptHistoryDropsPureTemplateGarbage() {
        let thread = To_Do_List.Thread()
        thread.messages.append(Message(role: .assistant, content: "<end_of_turn><|im_end|>", thread: thread))

        let history = ModelConfiguration.defaultModel.getPromptHistory(
            thread: thread,
            systemPrompt: "System"
        )

        XCTAssertEqual(history.count, 1)
    }

    func testPromptHistoryDropsLowUtilityAssistantDegeneration() {
        let thread = To_Do_List.Thread()
        thread.messages.append(
            Message(
                role: .assistant,
                content: "Okay, I'm ready to be your proactive personal assistant. Career, Career, Career, Career, Career, Career, Career, Career.",
                thread: thread
            )
        )

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

    func testPromptMigrationUpdatesLegacyBuiltInPromptOnly() {
        let migrated = AppManager.migratedBuiltInSystemPrompt(
            "You are Eva, a clever personal assistant. Keep tasks and priorities aligned. Be brief, clear, and helpful. Use simple markdown, short lists, and casual dates. Use only provided context. Do not invent details."
        )

        XCTAssertEqual(migrated, AppManager.defaultSystemPrompt)
    }

    func testPromptMigrationPreservesCustomPrompt() {
        let migrated = AppManager.migratedBuiltInSystemPrompt("Custom prompt")
        XCTAssertNil(migrated)
    }
}
