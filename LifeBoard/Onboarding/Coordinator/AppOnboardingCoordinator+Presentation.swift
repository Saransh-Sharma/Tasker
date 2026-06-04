import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingCoordinator {
    func evaluateLaunchIfNeeded() {
        guard hasEvaluatedLaunch == false else { return }
        hasEvaluatedLaunch = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            let state = self.stateStore.load()
            if state.hasHandledCurrentVersion == false, state.journeySnapshot != nil {
                self.enqueuePresentation(.fullFlow(source: "resume"))
                return
            }
            switch await self.eligibilityService.evaluate() {
            case .fullFlow:
                self.enqueuePresentation(.fullFlow(source: "launch_auto"))
            case .promptOnly(let snapshot):
                self.enqueuePresentation(.prompt(snapshot: snapshot))
            case .suppressed:
                break
            }
        }
    }

    func restartOnboarding() {
        stateStore.clear()
        viewModel.resetForReplay()
        guidanceModel.clear()
        presentationQueue = OnboardingPresentationQueue()
        enqueuePresentation(.fullFlow(source: "settings_replay"))
    }

    func drainPendingPresentationIfPossible() {
        guard let pending = presentationQueue.pending else { return }
        if attemptPresentation(pending, source: "drain") {
            presentationQueue.markPresented(pending)
        }
    }

    func enqueuePresentation(_ presentation: PendingOnboardingPresentation) {
        let previousPending = presentationQueue.pending
        presentationQueue.enqueue(presentation)
        let currentPending = presentationQueue.pending

        if currentPending == presentation,
           previousPending != presentation,
           isPresentationBlocked() {
            pendingPresentationWasBlocked = true
            logOnboardingInfo(
                event: "onboarding_presentation_queued",
                message: "Queued onboarding presentation until the host is free",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "blocked_by_presented_controller": String(hostAdapter?.presentedViewController != nil)
                ]
            )
        }

        drainPendingPresentationIfPossible()
    }

    @discardableResult
    func attemptPresentation(_ presentation: PendingOnboardingPresentation, source: String) -> Bool {
        let presented: Bool
        switch presentation {
        case .prompt(let snapshot):
            presented = presentPromptIfPossible(snapshot: snapshot)
        case .fullFlow(let sourceLabel):
            presented = presentFullFlowIfPossible(source: sourceLabel)
        }

        if presented, pendingPresentationWasBlocked {
            pendingPresentationWasBlocked = false
            logOnboardingInfo(
                event: "onboarding_presentation_drained",
                message: "Presented queued onboarding surface",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "source": source
                ]
            )
        }
        return presented
    }

    func presentPromptIfPossible(snapshot: OnboardingWorkspaceSnapshot) -> Bool {
        guard promptHost == nil else { return false }
        guard let hostAdapter, hostAdapter.presentedViewController == nil else { return false }

        let controller = UIHostingController(
            rootView: AnyView(
                AppOnboardingPromptSheetView(
                    snapshot: snapshot,
                    onStart: { [weak self] in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            await self.viewModel.prepareEstablishedWorkspaceEntry()
                            self.dismissPrompt(animated: true) {
                                self.enqueuePresentation(.fullFlow(source: "prompt_opt_in"))
                            }
                        }
                    },
                    onNotNow: { [weak self] in
                        self?.stateStore.markEstablishedWorkspacePromptDismissed()
                        self?.dismissPrompt(animated: true, completion: nil)
                    }
                )
                .lifeboardLayoutClass(hostAdapter.currentOnboardingLayoutClass)
            )
        )
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 30
        }
        promptHost = controller
        hostAdapter.present(controller, animated: true, completion: nil)
        return true
    }

    func dismissPrompt(animated: Bool, completion: (() -> Void)?) {
        guard let promptHost else {
            completion?()
            return
        }
        self.promptHost = nil
        promptHost.dismiss(animated: animated, completion: completion)
    }

    func presentFullFlowIfPossible(source: String) -> Bool {
        dismissPrompt(animated: false, completion: nil)
        guard onboardingHost == nil else { return false }
        guard let hostAdapter, hostAdapter.presentedViewController == nil else { return false }

        feedbackController.prepare()
        viewModel.prepareForPresentation(snapshot: stateStore.load().journeySnapshot)
        logOnboardingInfo(
            event: "onboarding_started",
            message: "Started ADHD-first onboarding flow",
            fields: ["source": source]
        )

        let rootView = AppOnboardingJourneyView(
            viewModel: viewModel,
            feedbackController: feedbackController,
            onOpenCustomTaskComposer: { [weak self] prefill in
                self?.presentCustomTaskComposer(prefill: prefill) ?? false
            },
            onOpenCustomHabitComposer: { [weak self] prefill in
                self?.presentCustomHabitComposer(prefill: prefill) ?? false
            },
            onEditTask: { [weak self] task in
                self?.presentTaskEditor(task: task) ?? false
            },
            onDismissFlow: { [weak self] in
                guard let self else { return }
                if self.viewModel.successSummary != nil,
                   let createdHabit = self.viewModel.createdHabits.first {
                    self.guidanceModel.showHabitGuide(habit: createdHabit)
                }
                self.dismissFullFlow(animated: true)
            }
        )
        .lifeboardLayoutClass(hostAdapter.currentOnboardingLayoutClass)

        let controller = UIHostingController(rootView: AnyView(rootView))
        controller.modalPresentationStyle = .fullScreen
        onboardingHost = controller
        hostAdapter.present(controller, animated: true, completion: nil)
        return true
    }

    func dismissFullFlow(animated: Bool, completion: (() -> Void)? = nil) {
        guard let onboardingHost else {
            completion?()
            return
        }
        self.onboardingHost = nil
        onboardingHost.dismiss(animated: animated, completion: completion)
    }

    func presentCustomTaskComposer(prefill: AddTaskPrefillTemplate) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingAddTaskController(
            prefill: prefill,
            onTaskCreated: { [weak self] taskID in
                Task { @MainActor [weak self] in
                    await self?.viewModel.registerCustomCreatedTask(taskID: taskID)
                }
            },
            onDismissWithoutTask: nil
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    func presentCustomHabitComposer(prefill: AddHabitPrefillTemplate) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingAddHabitController(
            prefill: prefill,
            onHabitCreated: { [weak self] habitID in
                Task { @MainActor [weak self] in
                    await self?.viewModel.registerCustomCreatedHabit(habitID: habitID)
                }
            },
            onDismissWithoutTask: nil
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    func presentTaskEditor(task: TaskDefinition) -> Bool {
        guard let onboardingHost, onboardingHost.presentedViewController == nil else { return false }
        guard let controller = hostAdapter?.makeOnboardingTaskDetailController(
            task: task,
            onDismiss: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.viewModel.refreshCreatedTask(taskID: task.id)
                }
            }
        ) else { return false }
        onboardingHost.present(controller, animated: true)
        return true
    }

    func isPresentationBlocked() -> Bool {
        hostAdapter?.presentedViewController != nil
    }
}
