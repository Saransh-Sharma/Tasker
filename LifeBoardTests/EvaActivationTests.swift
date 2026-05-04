import MLXLMCommon
import XCTest
@testable import To_Do_List
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class EvaActivationTests: XCTestCase {
    private let defaultAssistantIdentity = AssistantIdentitySnapshot(mascotID: .eva)

    func testAssistantIdentityTextFormatsDefaultAndSelectedPersona() {
        let eva = AssistantIdentitySnapshot(mascotID: .eva)
        let sato = AssistantIdentitySnapshot(mascotID: .sato)

        XCTAssertEqual(AssistantIdentityText.displayName(for: eva), "Eva")
        XCTAssertEqual(AssistantIdentityText.uppercaseName(for: eva), "EVA")
        XCTAssertEqual(AssistantIdentityText.askAction(for: sato), "Ask Sato")
        XCTAssertEqual(AssistantIdentityText.openAction(for: sato), "Open Sato")
        XCTAssertEqual(AssistantIdentityText.readyStatus(for: sato), "Sato is ready")
    }

    func testActivationStarterPromptsLeadWithDayOverview() {
        XCTAssertEqual(EvaStarterPrompt.activationDefaults.first, EvaStarterPrompt.dayOverviewPrompt)
        XCTAssertEqual(EvaStarterPrompt.dayOverviewPrompt.submissionText, "How is my day looking today?")
    }

    func testChiefOfStaffGuideIncludesReschedulePromptSection() throws {
        let section = try XCTUnwrap(EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).first { $0.id == "reschedule_open_tasks" })

        XCTAssertEqual(section.title, "Reschedule open tasks")
        XCTAssertEqual(section.icon, "calendar.badge.clock")
        XCTAssertTrue(section.body.contains("review cards"))
        XCTAssertEqual(section.prompts.map(\.style), Array(repeating: .naturalLanguage, count: 5))
        XCTAssertEqual(section.prompts.map(\.title), [
            "Reschedule unfinished tasks",
            "Carry today to tomorrow",
            "Push by 20 minutes",
            "Start tomorrow morning",
            "Overdue to today"
        ])
        XCTAssertEqual(section.prompts.map(\.submissionText), [
            "Reschedule my unfinished tasks",
            "Move all my unfinished tasks from today to tomorrow",
            "Move all my unfinished tasks from today forward by 20 minutes",
            "Move my open tasks to tomorrow morning",
            "Move overdue tasks to today"
        ])
    }

    func testHomePromptChipsLeadWithCuratedOrderThenRemainingGuidePrompts() {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)

        XCTAssertEqual(chips.prefix(5).map(\.prompt.title), [
            "How is my day?",
            "Plan today",
            "Recover overdue",
            "Carry today's overdues to tomorrow",
            "Overdue today first and then the rest"
        ])
        XCTAssertEqual(chips.prefix(5).map(\.prompt.submissionText), [
            "How is my day looking today?",
            "Help me plan today around my existing tasks and habits.",
            "Show me what is overdue and what I should recover first.",
            "Move today's overdue tasks to tomorrow.",
            "Plan today with overdue tasks first, then the rest."
        ])

        XCTAssertEqual(chips[5].prompt.title, "Focus first")
        XCTAssertEqual(chips[6].prompt.title, "Reschedule unfinished tasks")
    }

    func testHomePromptChipsAppendGuidePromptsWithoutDuplicateIDsOrSubmissions() {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)
        let ids = chips.map(\.prompt.id)
        let submissionTexts = chips.map(\.prompt.submissionText)
        let guidePromptCount = EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).flatMap(\.prompts).count
        let skippedGuideDuplicateSubmissionCount = 4
        let curatedPromptCount = 5

        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(submissionTexts).count, submissionTexts.count)
        XCTAssertEqual(chips.count, guidePromptCount - skippedGuideDuplicateSubmissionCount + curatedPromptCount)
    }

    func testHomePromptChipsUseCuratedAndInheritedGuideIcons() throws {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)

        XCTAssertEqual(chips[0].icon, "sparkles")
        XCTAssertEqual(chips[1].icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(chips[2].icon, "sun.max")
        XCTAssertEqual(chips[3].icon, "calendar.badge.clock")
        XCTAssertEqual(chips[4].icon, "calendar.badge.clock")

        let guideSection = try XCTUnwrap(EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).first { $0.id == "break_work_down" })
        let guidePrompt = try XCTUnwrap(guideSection.prompts.first)
        let homeChip = try XCTUnwrap(chips.first { $0.prompt.id == guidePrompt.id })
        XCTAssertEqual(homeChip.icon, guideSection.icon)
    }

    func testChiefOfStaffGuideUsesSelectedPersonaCopy() throws {
        let satoIdentity = AssistantIdentitySnapshot(mascotID: .sato)
        let sections = EvaChiefOfStaffGuideContent.sections(for: satoIdentity)
        let visibleCopy = sections.flatMap { [$0.title, $0.body] }.joined(separator: "\n")

        XCTAssertTrue(visibleCopy.contains("Sato"))
        XCTAssertFalse(visibleCopy.contains("Bring Eva"))
        XCTAssertFalse(visibleCopy.contains("Eva should"))
        XCTAssertFalse(visibleCopy.contains("when you want Eva"))
    }

    func testEvaMascotPlacementResolverMapsCoreProductStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatEmptyHeader), .neutral)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatHelp), .peek)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatThinking), .thinking)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .dayOverview), .idea)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .proposalReview), .clipboard)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .proposalApplied), .celebration)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarPlanning), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarConflict), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .taskCapture), .pencil)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitEmpty), .sitting)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .restReminder), .sleepy)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .weeklyReflection), .meditate)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .focusStart), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .settingsIdentity), .neutral)
    }

    func testEvaMascotPlacementResolverMapsOnboardingAndCoachingStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingWelcome), .sitting)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingNextStep), .pointRight)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingEvaValue), .clipboard)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingCaptureSetup), .pencil)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingProcessing), .thinking)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingCalendarPermission), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingNotificationPermission), .peek)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingSuccess), .excited)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .featureDiscovery), .pointLeft)
    }

    func testEvaMascotPlacementResolverMapsRiskTimelineAndMilestoneStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineEmptySchedule), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineConflict), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineFreeSlot), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineStartPlan), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .taskDeadlineRisk), .worried)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitStreakWin), .celebration)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitMilestone), .excited)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarRescheduleThinking), .thinking)
    }

    func testMascotPlacementResolverMapsSpriteAnimations() {
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .settingsIdentity), .idle)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .onboardingNextStep), .runRight)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .featureDiscovery), .runLeft)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .chatHelp), .waving)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .onboardingSuccess), .jumping)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .taskDeadlineRisk), .failed)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .chatThinking), .waiting)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .focusStart), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .proposalReview), .review)
    }

    func testEvaMascotSizeTiersStayInExpectedRanges() {
        XCTAssertEqual(EvaMascotSize.avatar.points, 40)
        XCTAssertEqual(EvaMascotSize.chip.points, 32)
        XCTAssertEqual(EvaMascotSize.inline.points, 56)
        XCTAssertEqual(EvaMascotSize.card.points, 104)
        XCTAssertEqual(EvaMascotSize.hero.points, 184)
        XCTAssertEqual(EvaMascotSize.custom(46).points, 46)
    }

    func testMascotPersonaCatalogContainsEvaAndSpritePersonas() {
        XCTAssertEqual(AssistantMascotPersona.all.map(\.id), AssistantMascotID.allCases)
        XCTAssertFalse(AssistantMascotPersona.persona(for: .eva).usesSprites)

        let spritePersonas = AssistantMascotPersona.all.filter(\.usesSprites)
        XCTAssertEqual(spritePersonas.map(\.id), [.cloudlet, .dude, .elon, .friday, .johnny, .maddie, .paperclip, .punch, .retriever, .sato, .steve, .theo, .yesman])
        XCTAssertTrue(spritePersonas.allSatisfy { $0.resourceFolderName?.isEmpty == false })
    }

    func testMascotSpriteSheetContract() {
        XCTAssertEqual(MascotSpriteFrameProvider.sheetPixelWidth, 1536)
        XCTAssertEqual(MascotSpriteFrameProvider.sheetPixelHeight, 1872)
        XCTAssertEqual(MascotSpriteFrameProvider.columns, 8)
        XCTAssertEqual(MascotSpriteFrameProvider.rows, 9)
        XCTAssertEqual(MascotSpriteFrameProvider.cellWidth, 192)
        XCTAssertEqual(MascotSpriteFrameProvider.cellHeight, 208)

        XCTAssertEqual(MascotAnimation.idle.frameCount, 6)
        XCTAssertEqual(MascotAnimation.runRight.frameCount, 8)
        XCTAssertEqual(MascotAnimation.runLeft.frameCount, 8)
        XCTAssertEqual(MascotAnimation.waving.frameCount, 4)
        XCTAssertEqual(MascotAnimation.jumping.frameCount, 5)
        XCTAssertEqual(MascotAnimation.failed.frameCount, 8)
        XCTAssertEqual(MascotAnimation.waiting.frameCount, 6)
        XCTAssertEqual(MascotAnimation.running.frameCount, 6)
        XCTAssertEqual(MascotAnimation.review.frameCount, 6)
    }

    #if canImport(UIKit)
    func testEvaMascotAssetsAreBundled() throws {
        let appBundle = Bundle(for: AppDelegate.self)

        for asset in EvaMascotAsset.allCases {
            XCTAssertNotNil(
                UIImage(named: asset.rawValue, in: appBundle, compatibleWith: nil),
                "Missing Eva mascot asset named \(asset.rawValue)"
            )
        }
    }

    func testMascotSpriteAssetsAreBundled() throws {
        let spritePersonas = AssistantMascotPersona.all.filter(\.usesSprites)

        for persona in spritePersonas {
            XCTAssertNotNil(
                MascotSpriteFrameProvider.shared.metadataURL(for: persona),
                "Missing mascot metadata for \(persona.displayName)"
            )
            XCTAssertNotNil(
                MascotSpriteFrameProvider.shared.spritesheetURL(for: persona),
                "Missing mascot spritesheet for \(persona.displayName)"
            )
            XCTAssertNotNil(
                MascotSpriteFrameProvider.shared.frame(persona: persona, animation: .idle, index: 0),
                "Could not crop idle frame for \(persona.displayName)"
            )
        }
    }
    #endif

    func testThreadChangePolicyPreservesFirstThreadAttachDuringGeneration() {
        let firstThreadID = UUID()

        XCTAssertFalse(ChatThreadChangeCancellationPolicy.shouldCancelActiveGeneration(
            oldThreadID: nil,
            newThreadID: firstThreadID,
            generatingThreadID: firstThreadID,
            hasActiveGeneration: true
        ))
    }

    func testChatViewGenerateFirstThreadAttachPreservesGenerationLifecycle() {
        let internallyCreatedThreadID = UUID()

        let decision = ChatThreadChangeCancellationPolicy.decision(
            oldThreadID: nil,
            newThreadID: internallyCreatedThreadID,
            generatingThreadID: internallyCreatedThreadID,
            hasActiveGeneration: true
        )

        XCTAssertEqual(decision, .preserveFirstGeneratedThreadAttach)
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

    func testNavigationChromeUsesSelectedMascotTitle() throws {
        let defaults = try makeDefaults()
        let workspaceStore = TaskerWorkspacePreferencesStore(defaults: defaults)
        workspaceStore.update { preferences in
            preferences.chiefOfStaffMascotID = .sato
        }
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Meet Sato")

        coordinator.continueFromIntro()
        coordinator.continueFromAboutYou()
        coordinator.continueFromGoals()
        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Choose Sato's Mode")
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
            workspacePreferencesStore: TaskerWorkspacePreferencesStore(defaults: defaults),
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
