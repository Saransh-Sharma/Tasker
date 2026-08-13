import MLXLMCommon
import SwiftUI

struct EvaActivationRootView: View {
    @ObservedObject private var coordinator: EvaActivationCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onDismiss: () -> Void
    private let onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)?
    private let onComposerFocusChange: ((Bool) -> Void)?
    private let onOpenTaskDetail: (TaskDefinition) -> Void
    private let onOpenHabitDetail: ((UUID) -> Void)?
    private let onPerformDayTaskAction: EvaDayTaskActionHandler?
    private let onPerformDayHabitAction: EvaDayHabitActionHandler?

    init(
        coordinator: EvaActivationCoordinator,
        onDismiss: @escaping () -> Void,
        onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)? = nil,
        onComposerFocusChange: ((Bool) -> Void)? = nil,
        onOpenTaskDetail: @escaping (TaskDefinition) -> Void,
        onOpenHabitDetail: ((UUID) -> Void)? = nil,
        onPerformDayTaskAction: EvaDayTaskActionHandler? = nil,
        onPerformDayHabitAction: EvaDayHabitActionHandler? = nil
    ) {
        self.coordinator = coordinator
        self.onDismiss = onDismiss
        self.onNavigationChromeChange = onNavigationChromeChange
        self.onComposerFocusChange = onComposerFocusChange
        self.onOpenTaskDetail = onOpenTaskDetail
        self.onOpenHabitDetail = onOpenHabitDetail
        self.onPerformDayTaskAction = onPerformDayTaskAction
        self.onPerformDayHabitAction = onPerformDayHabitAction
    }

    var body: some View {
        currentStageView
            .animation(reduceMotion ? nil : LifeBoardAnimation.gatewayReveal, value: coordinator.state.stage)
            .onAppear {
                markCurrentStageInteractiveIfNeeded()
            }
            .onChange(of: coordinator.state.stage) { _, _ in
                markCurrentStageInteractiveIfNeeded()
            }
    }

    /// Keep each activation stage behind a concrete type-erasure boundary.
    ///
    /// `ChatContainerView` is deliberately large. Allowing the stage switch to
    /// synthesize one nested `_ConditionalContent` type makes Swift instantiate
    /// metadata for every onboarding stage before Eva can appear.
    private var currentStageView: AnyView {
        switch coordinator.state.stage {
        case .intro:
            AnyView(EvaActivationIntroView(
                onContinue: coordinator.continueFromIntro,
                onDismiss: onDismiss
            ))
        case .aboutYou:
            AnyView(EvaAboutYouView(
                draft: $coordinator.profileDraft,
                onBack: coordinator.backToIntro,
                onContinue: coordinator.continueFromAboutYou
            ))
        case .goals:
            AnyView(EvaGoalsView(
                draft: $coordinator.profileDraft,
                onBack: coordinator.backToAboutYou,
                onContinue: coordinator.continueFromGoals
            ))
        case .modelChoice:
            AnyView(EvaModelChoiceView(
                selectedModelName: coordinator.state.chosenModelName,
                onBack: coordinator.backToGoals,
                onSelect: coordinator.selectModel,
                onContinue: coordinator.continueFromModelChoice
            ))
        case .installRecovery:
            AnyView(EvaActivationRecoveryView(
                failedModelTitle: coordinator.failedModelDisplayTitle,
                onRetry: coordinator.retryInstallFromRecovery,
                onSwitchToFast: coordinator.switchRecoveryToFast,
                onOpenModels: coordinator.openModelsFromRecovery
            ))
        case .modelDownload:
            if let model = coordinator.selectedModel {
                AnyView(EvaWakeEvaInstallView(
                    model: model,
                    selectionTitle: coordinator.selectedModelDisplayTitle,
                    onChooseAnotherModel: coordinator.backToModelChoice,
                    onInstallComplete: coordinator.completeInstall
                ))
            } else {
                AnyView(EvaModelChoiceView(
                    selectedModelName: coordinator.state.chosenModelName,
                    onBack: coordinator.backToGoals,
                    onSelect: coordinator.selectModel,
                    onContinue: coordinator.continueFromModelChoice
                ))
            }
        case .firstChat, .completed:
            AnyView(ChatContainerView(
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
                onNavigationChromeChange: onNavigationChromeChange,
                onComposerFocusChange: onComposerFocusChange,
                onOpenTaskDetail: onOpenTaskDetail,
                onOpenHabitDetail: onOpenHabitDetail,
                onPerformDayTaskAction: onPerformDayTaskAction,
                onPerformDayHabitAction: onPerformDayHabitAction
            ))
        case .unsupportedDevice:
            AnyView(DeviceNotSupportedView(onDismiss: onDismiss))
        }
    }

    private func markCurrentStageInteractiveIfNeeded() {
        switch coordinator.state.stage {
        case .firstChat, .completed:
            // Chat ends the navigation interval after its first transcript
            // snapshot, so the metric includes composer/transcript readiness.
            break
        default:
            EvaNavigationPerformanceTrace.markInteractive()
        }
    }
}
