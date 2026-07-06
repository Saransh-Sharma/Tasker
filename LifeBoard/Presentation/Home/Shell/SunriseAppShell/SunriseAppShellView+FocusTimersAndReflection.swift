//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension SunriseAppShellView {
    func startNextActionFocusTimer() {
        guard isNextActionFocusRequestInFlight == false else { return }
        activeFocusTimerSource = "next_action_module_15min_focus"
        isNextActionFocusRequestInFlight = true
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "home_next_action_focus_start_tapped",
            metadata: [
                "source": "next_action_module_15min_focus",
                "target_duration_seconds": Self.nextActionFocusDurationSeconds
            ]
        )
        viewModel.startFocusSession(taskID: nil, targetDurationSeconds: Self.nextActionFocusDurationSeconds) { result in
            Task { @MainActor in
                isNextActionFocusRequestInFlight = false
                switch result {
                case .success(let session):
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        resumeNextActionFocusSession(source: "next_action_module_15min_focus")
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session from next action module",
                            fields: [
                                "source": "next_action_module_15min_focus",
                                "error": error.localizedDescription
                            ]
                        )
                        snackbar = SnackbarData(message: "Couldn't start focus timer")
                    }
                }
            }
        }
    }

    func startFocusNowTimer(
        draftTasks: [TaskDefinition],
        task: TaskDefinition,
        durationSeconds: Int
    ) {
        guard isNextActionFocusRequestInFlight == false else { return }
        activeFocusTimerSource = "focus_now"
        isNextActionFocusRequestInFlight = true
        LifeBoardFeedback.selection()
        viewModel.trackHomeInteraction(
            action: "focus_now_timer_start_tapped",
            metadata: [
                "task_id": task.id.uuidString,
                "target_duration_seconds": durationSeconds
            ]
        )

        viewModel.startFocusSession(taskID: task.id, targetDurationSeconds: durationSeconds) { result in
            Task { @MainActor in
                isNextActionFocusRequestInFlight = false
                switch result {
                case .success(let session):
                    guard viewModel.commitFocusNowSet(taskIDs: draftTasks.map(\.id), source: "focus_now_timer_start") else {
                        snackbar = SnackbarData(message: "Couldn't start focus. Try again.")
                        return
                    }
                    viewModel.setEvaFocusWhyPresented(false)
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        viewModel.setEvaFocusWhyPresented(false)
                        resumeNextActionFocusSession(source: "focus_now")
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session from Focus Now",
                            fields: [
                                "source": "focus_now",
                                "error": error.localizedDescription
                            ]
                        )
                        snackbar = SnackbarData(message: "Couldn't start focus. Try again.")
                    }
                }
            }
        }
    }

    func resumeNextActionFocusSession(source: String) {
        activeFocusTimerSource = source
        viewModel.fetchActiveFocusSession { result in
            Task { @MainActor in
                switch result {
                case .success(let session):
                    guard let session else {
                        viewModel.setQuickView(.today)
                        logWarning(
                            event: "focus_session_resume_missing",
                            message: "Expected an active focus session to resume, but none was found",
                            fields: ["source": source]
                        )
                        snackbar = SnackbarData(message: "No active focus timer was found")
                        return
                    }
                    activeNextActionFocusSession = session
                    showNextActionFocusTimer = true
                case .failure(let error):
                    logWarning(
                        event: "focus_session_resume_failed",
                        message: "Failed to resume active focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                    snackbar = SnackbarData(message: "Couldn't resume focus timer")
                }
            }
        }
    }

    func finishNextActionFocusSession(sessionID: UUID, source: String) {
        guard isNextActionFocusEnding == false else { return }
        isNextActionFocusEnding = true
        viewModel.endFocusSession(sessionID: sessionID) { result in
            Task { @MainActor in
                isNextActionFocusEnding = false
                switch result {
                case .success(let focusResult):
                    showNextActionFocusTimer = false
                    activeNextActionFocusSession = nil
                    viewModel.trackHomeInteraction(
                        action: "focus_session_finished",
                        metadata: [
                            "source": source,
                            "duration_seconds": focusResult.session.durationSeconds,
                            "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                        ]
                    )
                    nextActionFocusSummaryResult = focusResult
                    showNextActionFocusSummary = true
                case .failure(let error):
                    logWarning(
                        event: "focus_session_end_failed",
                        message: "Failed to end focus session from next action module",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                    snackbar = SnackbarData(message: "Couldn't finish focus timer")
                    showNextActionFocusTimer = false
                    activeNextActionFocusSession = nil
                }
            }
        }
    }

    func dismissNextActionFocusSummary() {
        showNextActionFocusSummary = false
        nextActionFocusSummaryResult = nil
    }

    func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel.focusTasks)
        candidates.append(contentsOf: viewModel.morningTasks)
        candidates.append(contentsOf: viewModel.eveningTasks)
        candidates.append(contentsOf: viewModel.overdueTasks)
        return candidates.first(where: { $0.id == taskID })
    }

    @ViewBuilder
    var reflectPlanPresentation: some View {
        if let dailyReflectPlanViewModel {
            SunriseReflectPlanScreen(
                viewModel: dailyReflectPlanViewModel,
                onClose: {
                    showDailyReflectPlan = false
                    activeDayCompassFlow = nil
                }
            )
        } else {
            Color.clear
                .ignoresSafeArea()
                .onAppear {
                    showDailyReflectPlan = false
                }
        }
    }

    func openDailyReflectPlan(preferredReflectionDate: Date? = nil) {
        dailyReflectPlanViewModel = PresentationDependencyContainer.shared.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { action, metadata in
                viewModel.trackHomeInteraction(action: action, metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                    partialResult[item.key] = item.value
                })
            },
            onComplete: { result in
                viewModel.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                if let flow = activeDayCompassFlow {
                    viewModel.showDayCompassAllClear(after: flow)
                    activeDayCompassFlow = nil
                }
                showDailyReflectPlan = false
            }
        )
        showDailyReflectPlan = true
    }
}
