import Foundation
import Metal
import MLXLMCommon
import SwiftUI

enum EvaActivationNavigationLeadingActionStyle: Equatable {
    case close
    case back

    var iconName: String {
        switch self {
        case .close:
            return "xmark"
        case .back:
            return "chevron.backward"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .close:
            return "Close"
        case .back:
            return "Back"
        }
    }
}

struct EvaActivationNavigationChrome: Equatable {
    let screenTitle: String
    let stepIndex: Int
    let stepCount: Int
    let showsProgress: Bool
    let showsTrailingHistoryButton: Bool
    let leadingActionStyle: EvaActivationNavigationLeadingActionStyle

    var progressFraction: CGFloat {
        guard showsProgress, stepCount > 0 else { return 0 }
        return CGFloat(stepIndex) / CGFloat(stepCount)
    }

    var progressAccessibilityValue: String? {
        guard showsProgress else { return nil }
        return "Step \(stepIndex) of \(stepCount)"
    }
}

@MainActor
final class EvaActivationCoordinator: ObservableObject {
    @Published private(set) var state: EvaActivationState
    @Published var profileDraft: EvaProfileDraft

    private let appManager: AppManager
    private let defaults: UserDefaults
    private let deviceSupportsLocalEvaProvider: () -> Bool

    init(
        appManager: AppManager,
        defaults: UserDefaults = .standard,
        deviceSupportsLocalEvaProvider: @escaping () -> Bool = {
            #if os(iOS)
            guard let device = MTLCreateSystemDefaultDevice() else { return false }
            return device.supportsFamily(.metal3)
            #else
            return true
            #endif
        }
    ) {
        self.appManager = appManager
        self.defaults = defaults
        self.deviceSupportsLocalEvaProvider = deviceSupportsLocalEvaProvider
        let loadedState = EvaActivationDefaultsStore.load(defaults: defaults)
        self.state = loadedState
        self.profileDraft = loadedState.profileDraft
        bootstrap()
    }

    var isComplete: Bool {
        state.isComplete
    }

    var selectedModel: ModelConfiguration? {
        guard let chosenModelName = state.chosenModelName else { return nil }
        return ModelConfiguration.getModelByName(chosenModelName)
    }

    var selectedModelDisplayTitle: String {
        guard let modelName = state.chosenModelName else { return "Fast" }
        return modelName == ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name ? "Smarter" : "Fast"
    }

    var failedModelDisplayTitle: String {
        guard let modelName = state.failedModelName else { return selectedModelDisplayTitle }
        return modelName == ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name ? "Smarter" : "Fast"
    }

    var navigationChrome: EvaActivationNavigationChrome {
        switch state.stage {
        case .intro:
            EvaActivationNavigationChrome(
                screenTitle: "Meet Eva",
                stepIndex: 1,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .close
            )
        case .aboutYou:
            EvaActivationNavigationChrome(
                screenTitle: "Quick Sync",
                stepIndex: 2,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .goals:
            EvaActivationNavigationChrome(
                screenTitle: "Current Goals",
                stepIndex: 3,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .modelChoice:
            EvaActivationNavigationChrome(
                screenTitle: "Choose Eva's Mode",
                stepIndex: 4,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .modelDownload:
            EvaActivationNavigationChrome(
                screenTitle: "Getting Eva Ready",
                stepIndex: 5,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .installRecovery:
            EvaActivationNavigationChrome(
                screenTitle: "Recovery",
                stepIndex: 5,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .firstChat:
            EvaActivationNavigationChrome(
                screenTitle: "First Win",
                stepIndex: 6,
                stepCount: 6,
                showsProgress: true,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .back
            )
        case .completed:
            EvaActivationNavigationChrome(
                screenTitle: "Eva",
                stepIndex: 0,
                stepCount: 6,
                showsProgress: false,
                showsTrailingHistoryButton: true,
                leadingActionStyle: .back
            )
        case .unsupportedDevice:
            EvaActivationNavigationChrome(
                screenTitle: "Eva",
                stepIndex: 0,
                stepCount: 6,
                showsProgress: false,
                showsTrailingHistoryButton: false,
                leadingActionStyle: .close
            )
        }
    }

    func bootstrap() {
        if deviceSupportsLocalEva == false {
            updateStage(.unsupportedDevice)
            return
        }

        if shouldAutoCompleteForExistingUser {
            markCompletedFromMigration()
            return
        }

        if state.isComplete {
            updateStage(.completed)
        }
    }

    func continueFromIntro() {
        updateStage(.aboutYou)
    }

    func backToIntro() {
        updateStage(.intro)
    }

    func continueFromAboutYou() {
        state.apply(profileDraft: profileDraft)
        updateStage(.goals)
    }

    func backToAboutYou() {
        updateStage(.aboutYou)
    }

    func continueFromGoals() {
        state.apply(profileDraft: profileDraft)
        saveDraftIntoMemory()
        updateStage(.modelChoice)
    }

    func backToGoals() {
        updateStage(.goals)
    }

    func selectModel(_ modelName: String) {
        state.chosenModelName = modelName
        state.preparedModelName = modelName
        state.failedModelName = nil
        state.selectedModelRetryCount = 0
        state.hasAttemptedFastFallback = false
        state.recoveryPresented = false
        persist()
    }

    func continueFromModelChoice() {
        guard state.chosenModelName != nil else { return }
        state.hasTriggeredInstall = true
        state.preparedModelName = state.chosenModelName
        state.failedModelName = nil
        state.recoveryPresented = false
        updateStage(.modelDownload)
    }

    func backToModelChoice() {
        state.recoveryPresented = false
        updateStage(.modelChoice)
    }

    func completeInstall(_ result: EvaActivationInstallResult) {
        switch result {
        case .success(let preparedModelName, let retryCount, let attemptedFastFallback):
            state.installedChosenModel = true
            state.preparedModelName = preparedModelName
            state.chosenModelName = preparedModelName
            state.failedModelName = nil
            state.selectedModelRetryCount = retryCount
            state.hasAttemptedFastFallback = attemptedFastFallback
            state.recoveryPresented = false
            updateStage(.firstChat)
        case .failed(let failedModelName, let retryCount, let attemptedFastFallback):
            state.installedChosenModel = false
            state.failedModelName = failedModelName
            state.selectedModelRetryCount = retryCount
            state.hasAttemptedFastFallback = attemptedFastFallback
            state.recoveryPresented = true
            updateStage(.installRecovery)
        }
    }

    func retryInstallFromRecovery() {
        state.failedModelName = nil
        state.recoveryPresented = false
        state.preparedModelName = state.chosenModelName
        updateStage(.modelDownload)
    }

    func switchRecoveryToFast() {
        let fastModelName = ModelConfiguration.qwen_3_0_6b_4bit.name
        state.chosenModelName = fastModelName
        state.preparedModelName = fastModelName
        state.failedModelName = nil
        state.hasAttemptedFastFallback = true
        state.recoveryPresented = false
        updateStage(.modelDownload)
    }

    func openModelsFromRecovery() {
        state.failedModelName = nil
        state.recoveryPresented = false
        updateStage(.modelChoice)
    }

    func handleLeadingNavigation(onDismiss: () -> Void) {
        switch state.stage {
        case .intro, .firstChat, .completed, .unsupportedDevice:
            onDismiss()
        case .aboutYou:
            backToIntro()
        case .goals:
            backToAboutYou()
        case .modelChoice:
            backToGoals()
        case .modelDownload:
            backToModelChoice()
        case .installRecovery:
            openModelsFromRecovery()
        }
    }

    func noteChatEvent(_ event: EvaActivationChatEvent) {
        switch event {
        case .threadAttached(let threadID):
            attachActivationThreadIfNeeded(threadID)
        case .userMessagePersisted(let threadID):
            attachActivationThreadIfNeeded(threadID)
            guard state.firstThreadID == threadID else {
                persist()
                return
            }
            state.hasPersistedUserMessage = true
        case .assistantReplyPersisted(let threadID, let countsForCompletion):
            attachActivationThreadIfNeeded(threadID)
            guard state.firstThreadID == threadID else {
                persist()
                return
            }
            if countsForCompletion {
                state.hasPersistedAssistantReply = true
            }
        }

        updateCompletionStateIfNeeded()
        persist()
    }

    func resetForDebug() {
        state = EvaActivationState()
        profileDraft = EvaProfileDraft()
        EvaActivationDefaultsStore.clear(defaults: defaults)
    }

    private var deviceSupportsLocalEva: Bool {
        deviceSupportsLocalEvaProvider()
    }

    private var shouldAutoCompleteForExistingUser: Bool {
        let isFreshState = state.stage == .intro
            && state.chosenModelName == nil
            && state.firstThreadID == nil
            && state.hasTriggeredInstall == false
            && state.goals.isEmpty
            && state.selectedWorkingStyleIDs.isEmpty
            && state.selectedMomentumBlockerIDs.isEmpty
        return isFreshState && appManager.installedModels.isEmpty == false
    }

    private func markCompletedFromMigration() {
        state.isComplete = true
        state.stage = .completed
        persist()
    }

    private func updateStage(_ stage: EvaActivationStage) {
        state.stage = stage
        persist()
    }

    private func attachActivationThreadIfNeeded(_ threadID: UUID) {
        if state.firstThreadID == nil {
            state.firstThreadID = threadID
        }
    }

    private func updateCompletionStateIfNeeded() {
        guard state.firstThreadID != nil else { return }
        guard state.hasPersistedUserMessage, state.hasPersistedAssistantReply else { return }
        state.isComplete = true
        state.stage = .completed
    }

    private func saveDraftIntoMemory() {
        let existing = LLMPersonalMemoryDefaultsStore.load(defaults: defaults)
        let merged = EvaMemoryMapper.mergeIntoLocalStore(
            draft: profileDraft,
            existing: existing
        )
        LLMPersonalMemoryDefaultsStore.save(merged, defaults: defaults)
    }

    private func persist() {
        state.lastUpdatedAt = .now
        state.apply(profileDraft: profileDraft)
        EvaActivationDefaultsStore.save(state, defaults: defaults)
    }
}
