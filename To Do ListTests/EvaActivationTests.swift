import MLXLMCommon
import XCTest
@testable import To_Do_List

@MainActor
final class EvaActivationTests: XCTestCase {
    func testActivationStarterPromptsLeadWithDayOverview() {
        XCTAssertEqual(EvaStarterPrompt.activationDefaults.first, EvaStarterPrompt.dayOverviewPrompt)
        XCTAssertEqual(EvaStarterPrompt.dayOverviewPrompt.submissionText, "How is my day looking today?")
    }

    func testThreadChangePolicyPreservesFirstThreadAttachDuringGeneration() {
        let firstThreadID = UUID()

        XCTAssertFalse(ChatThreadChangeCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: nil,
            newThreadID: firstThreadID,
            generatingThreadID: firstThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyCancelsRealSwitchDuringGeneration() {
        let originalThreadID = UUID()
        let switchedThreadID = UUID()

        XCTAssertTrue(ChatThreadChangeCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: originalThreadID,
            newThreadID: switchedThreadID,
            generatingThreadID: originalThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyCancelsClearDuringGeneration() {
        let originalThreadID = UUID()

        XCTAssertTrue(ChatThreadChangeCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: originalThreadID,
            newThreadID: nil,
            generatingThreadID: originalThreadID,
            hasActiveGeneration: true
        ))
    }

    func testThreadChangePolicyDoesNotCancelWhenNoGenerationIsActive() {
        XCTAssertFalse(ChatThreadChangeCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: UUID(),
            newThreadID: UUID(),
            generatingThreadID: nil,
            hasActiveGeneration: false
        ))
    }

    func testMemoryMapperPrependsNewUniqueEntriesAndRespectsLimits() {
        let existing = LLMPersonalMemoryStoreV1(
            preferences: [
                LLMPersonalMemoryEntry(text: "Keep plans realistic and scoped."),
                LLMPersonalMemoryEntry(text: "Prefer concise, direct help.")
            ],
            routines: [
                LLMPersonalMemoryEntry(text: "I lose momentum when context switching piles up.")
            ],
            currentGoals: [
                LLMPersonalMemoryEntry(text: "Ship onboarding redesign"),
                LLMPersonalMemoryEntry(text: "Prepare interview loop"),
                LLMPersonalMemoryEntry(text: "Rebuild workout consistency"),
                LLMPersonalMemoryEntry(text: "Protect focus time")
            ]
        )

        let draft = EvaProfileDraft(
            selectedWorkingStyleIDs: [
                EvaWorkingStyleID.prioritizeForMe.rawValue,
                EvaWorkingStyleID.concise.rawValue
            ],
            selectedMomentumBlockerIDs: [
                EvaMomentumBlockerID.contextSwitching.rawValue,
                EvaMomentumBlockerID.tooManyOpenTasks.rawValue
            ],
            customWorkingStyleNote: "  Keep plans realistic and scoped.  ",
            customMomentumNote: "I often avoid the hardest task until late",
            goals: [
                "Ship EVA activation",
                "Prepare interview loop",
                "Tighten weekly planning"
            ]
        )

        let merged = EvaMemoryMapper.mergeIntoLocalStore(draft: draft, existing: existing)

        XCTAssertEqual(
            merged.preferences.map(\.text),
            [
                "Help me choose what matters most.",
                "Prefer concise, direct help.",
                "Keep plans realistic and scoped."
            ]
        )
        XCTAssertEqual(
            merged.routines.map(\.text),
            [
                "I lose momentum when context switching piles up.",
                "I lose momentum when too many tasks stay open.",
                "I often avoid the hardest task until late"
            ]
        )
        XCTAssertEqual(
            merged.currentGoals.map(\.text),
            [
                "Ship EVA activation",
                "Prepare interview loop",
                "Tighten weekly planning",
                "Ship onboarding redesign"
            ]
        )
    }

    func testActivationDefaultsStoreRoundTripsState() throws {
        let suiteName = "EvaActivationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var state = EvaActivationState()
        state.stage = .modelChoice
        state.selectedWorkingStyleIDs = [EvaWorkingStyleID.focus.rawValue]
        state.goals = ["Ship EVA onboarding"]
        state.chosenModelName = ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name
        state.hasTriggeredInstall = true
        state.apply(profileDraft: EvaProfileDraft(
            selectedWorkingStyleIDs: [EvaWorkingStyleID.focus.rawValue],
            goals: ["Ship EVA onboarding"]
        ))

        EvaActivationDefaultsStore.save(state, defaults: defaults)

        let loaded = EvaActivationDefaultsStore.load(defaults: defaults)
        XCTAssertEqual(loaded, state)

        EvaActivationDefaultsStore.markCompleted(defaults: defaults)
        XCTAssertTrue(EvaActivationDefaultsStore.load(defaults: defaults).isComplete)
    }

    func testCoordinatorRequiresSameThreadForCompletion() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)
        let firstThreadID = UUID()
        coordinator.noteChatEvent(.threadAttached(firstThreadID))
        coordinator.noteChatEvent(.userMessagePersisted(threadID: firstThreadID))
        coordinator.noteChatEvent(.assistantReplyPersisted(threadID: UUID(), countsForCompletion: true))

        XCTAssertFalse(coordinator.state.isComplete)
        XCTAssertEqual(coordinator.state.stage, .intro)

        coordinator.noteChatEvent(.assistantReplyPersisted(threadID: firstThreadID, countsForCompletion: true))

        XCTAssertTrue(coordinator.state.isComplete)
        XCTAssertEqual(coordinator.state.stage, .completed)
    }

    func testCoordinatorIgnoresNonCompletionAssistantArtifacts() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)
        let threadID = UUID()

        coordinator.noteChatEvent(.threadAttached(threadID))
        coordinator.noteChatEvent(.userMessagePersisted(threadID: threadID))
        coordinator.noteChatEvent(.assistantReplyPersisted(threadID: threadID, countsForCompletion: false))

        XCTAssertFalse(coordinator.state.isComplete)

        coordinator.noteChatEvent(.assistantReplyPersisted(threadID: threadID, countsForCompletion: true))

        XCTAssertTrue(coordinator.state.isComplete)
    }

    func testCoordinatorMigratesExistingInstalledModels() throws {
        let defaults = try makeDefaults()
        let appManager = AppManager()
        appManager.installedModels = [ModelConfiguration.qwen_3_0_6b_4bit.name]

        let coordinator = EvaActivationCoordinator(
            appManager: appManager,
            defaults: defaults,
            deviceSupportsLocalEvaProvider: { true }
        )

        XCTAssertTrue(coordinator.state.isComplete)
        XCTAssertEqual(coordinator.state.stage, .completed)
    }

    func testCoordinatorMovesIntoRecoveryAfterInstallFailure() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.continueFromModelChoice()
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        XCTAssertEqual(coordinator.state.stage, .installRecovery)
        XCTAssertEqual(coordinator.state.failedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.selectedModelRetryCount, 1)
        XCTAssertTrue(coordinator.state.hasAttemptedFastFallback)
        XCTAssertTrue(coordinator.state.recoveryPresented)
    }

    func testCoordinatorSwitchRecoveryToFastUpdatesChosenModelAndReentersInstall() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        coordinator.switchRecoveryToFast()

        XCTAssertEqual(coordinator.state.stage, .modelDownload)
        XCTAssertEqual(coordinator.state.chosenModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.preparedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertNil(coordinator.state.failedModelName)
    }

    func testCoordinatorSuccessfulInstallPersistsPreparedModelAndOpensFirstWin() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .success(
                preparedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        XCTAssertEqual(coordinator.state.stage, .firstChat)
        XCTAssertTrue(coordinator.state.installedChosenModel)
        XCTAssertEqual(coordinator.state.chosenModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.preparedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertTrue(coordinator.state.hasAttemptedFastFallback)
    }

    func testCoordinatorMapsModelSelectionToDisplayTitles() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.selectedModelDisplayTitle, "Fast")

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        XCTAssertEqual(coordinator.selectedModelDisplayTitle, "Smarter")

        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )
        XCTAssertEqual(coordinator.failedModelDisplayTitle, "Fast")
    }

    func testNavigationChromeMapsStagesToTitlesAndProgress() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(
            coordinator.navigationChrome,
            EvaActivationNavigationChrome(
                screenTitle: "Meet Eva",
                stepIndex: 1,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .close
            )
        )

        coordinator.continueFromIntro()
        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Quick Sync")
        XCTAssertEqual(coordinator.navigationChrome.stepIndex, 2)

        coordinator.continueFromAboutYou()
        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Current Goals")
        XCTAssertEqual(coordinator.navigationChrome.stepIndex, 3)

        coordinator.continueFromGoals()
        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Choose Eva's Mode")
        XCTAssertEqual(coordinator.navigationChrome.stepIndex, 4)
    }

    func testLeadingNavigationRoutesBackThroughActivationStages() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)
        var dismissed = false

        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertTrue(dismissed)

        dismissed = false
        coordinator.continueFromIntro()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertFalse(dismissed)
        XCTAssertEqual(coordinator.state.stage, .intro)

        coordinator.continueFromIntro()
        coordinator.continueFromAboutYou()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertEqual(coordinator.state.stage, .aboutYou)

        coordinator.continueFromAboutYou()
        coordinator.selectModel(ModelConfiguration.qwen_3_0_6b_4bit.name)
        coordinator.continueFromGoals()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertEqual(coordinator.state.stage, .goals)
    }

    func testLeadingNavigationRoutesRecoveryToModelChoice() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        coordinator.handleLeadingNavigation {}

        XCTAssertEqual(coordinator.state.stage, .modelChoice)
        XCTAssertNil(coordinator.state.failedModelName)
    }

    func testInstallEstimatorKeepsEtaCalculatingUntilProgressStabilizes() {
        let samples = [
            EvaActivationInstallSample(timestamp: 0, progress: 0.03),
            EvaActivationInstallSample(timestamp: 0.7, progress: 0.06)
        ]

        let eta = EvaActivationInstallEstimator.etaState(
            for: samples,
            latestProgress: 0.06
        )

        XCTAssertEqual(eta, .calculating)
    }

    func testInstallEstimatorProducesStableEtaWhenProgressSamplesAdvance() {
        let samples = [
            EvaActivationInstallSample(timestamp: 0, progress: 0.10),
            EvaActivationInstallSample(timestamp: 3, progress: 0.28)
        ]

        let eta = EvaActivationInstallEstimator.etaState(
            for: samples,
            latestProgress: 0.28
        )

        XCTAssertEqual(eta, .ready(secondsRemaining: 12))
    }

    func testInstallEstimatorFormatsTransferProgressFromModelSize() {
        let transferText = EvaActivationInstallEstimator.transferText(
            for: Decimal(string: "0.41"),
            progress: 0.25
        )

        XCTAssertEqual(transferText, "105 MB of 420 MB")
    }

    func testChatRenderModelHidesVisibleThinkingButKeepsAnswer() {
        let renderModel = ChatMessageRenderModel(
            role: .assistant,
            originalContent: "<think>Reviewing tradeoffs</think>\nFinal answer: Focus on the highest-leverage task first.",
            displayContent: "<think>Reviewing tradeoffs</think>\nFinal answer: Focus on the highest-leverage task first.",
            sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        )

        XCTAssertNil(renderModel.thinkingText)
        XCTAssertEqual(renderModel.answerText, "Final answer: Focus on the highest-leverage task first.")
    }

    private func makeCoordinator(defaults: UserDefaults) -> EvaActivationCoordinator {
        let appManager = AppManager()
        appManager.installedModels = []
        return EvaActivationCoordinator(
            appManager: appManager,
            defaults: defaults,
            deviceSupportsLocalEvaProvider: { true }
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "EvaActivationCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
