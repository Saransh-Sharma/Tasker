import MLXLMCommon
import SwiftUI

struct EvaActivationRootView: View {
    @ObservedObject private var coordinator: EvaActivationCoordinator

    private let onDismiss: () -> Void
    private let onOpenTaskDetail: (TaskDefinition) -> Void

    init(
        coordinator: EvaActivationCoordinator,
        onDismiss: @escaping () -> Void,
        onOpenTaskDetail: @escaping (TaskDefinition) -> Void
    ) {
        self.coordinator = coordinator
        self.onDismiss = onDismiss
        self.onOpenTaskDetail = onOpenTaskDetail
    }

    var body: some View {
        currentStageView
        .animation(TaskerAnimation.gatewayReveal, value: coordinator.state.stage)
    }

    @ViewBuilder
    private var currentStageView: some View {
        switch coordinator.state.stage {
        case .intro:
            EvaActivationIntroView(
                onContinue: coordinator.continueFromIntro,
                onDismiss: onDismiss
            )
        case .aboutYou:
            EvaAboutYouView(
                draft: $coordinator.profileDraft,
                onBack: coordinator.backToIntro,
                onContinue: coordinator.continueFromAboutYou
            )
        case .goals:
            EvaGoalsView(
                draft: $coordinator.profileDraft,
                onBack: coordinator.backToAboutYou,
                onContinue: coordinator.continueFromGoals
            )
        case .modelChoice:
            EvaModelChoiceView(
                selectedModelName: coordinator.state.chosenModelName,
                onBack: coordinator.backToGoals,
                onSelect: coordinator.selectModel,
                onContinue: coordinator.continueFromModelChoice
            )
        case .installRecovery:
            EvaActivationRecoveryView(
                failedModelTitle: coordinator.failedModelDisplayTitle,
                onRetry: coordinator.retryInstallFromRecovery,
                onSwitchToFast: coordinator.switchRecoveryToFast,
                onOpenModels: coordinator.openModelsFromRecovery
            )
        case .modelDownload:
            if let model = coordinator.selectedModel {
                EvaWakeEvaInstallView(
                    model: model,
                    selectionTitle: coordinator.selectedModelDisplayTitle,
                    onChooseAnotherModel: coordinator.backToModelChoice,
                    onInstallComplete: coordinator.completeInstall
                )
            } else {
                EvaModelChoiceView(
                    selectedModelName: coordinator.state.chosenModelName,
                    onBack: coordinator.backToGoals,
                    onSelect: coordinator.selectModel,
                    onContinue: coordinator.continueFromModelChoice
                )
            }
        case .firstChat, .completed:
            ChatContainerView(
                presentationMode: coordinator.isComplete
                    ? .normal
                    : .activation(
                        config: EvaActivationChatConfiguration(
                            starterPrompts: EvaStarterPrompt.activationDefaults,
                            showsCompletionObserver: true,
                            progressTitle: "First Win",
                            progressStep: 6,
                            totalSteps: 6,
                            hideUtilityActions: true,
                            recommendedStarterID: EvaStarterPrompt.activationDefaults.first(where: \.isRecommended)?.id,
                            visibleStarterLimit: 4,
                            helperCopy: "Type / for structured help like today, week, or project.",
                            collapsesCoachingAfterFirstAssistantReply: true
                        )
                    ),
                onActivationChatEvent: { event in
                    coordinator.noteChatEvent(event)
                },
                onOpenTaskDetail: onOpenTaskDetail
            )
        case .unsupportedDevice:
            DeviceNotSupportedView(onDismiss: onDismiss)
        }
    }
}
