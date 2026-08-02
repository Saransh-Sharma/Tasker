//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct OverdueRescuePresentationHost: View {
    @Bindable var coordinator: OverdueRescueLaunchCoordinator
    let projectsByID: [UUID: Project]
    let bottomInset: CGFloat
    let onRetry: () -> Void
    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onSavePlanningMetadata: @Sendable ([PlanningTaskMetadata], @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack {
            launcherOverlay
            deckOverlay
        }
    }

    @ViewBuilder
    private var launcherOverlay: some View {
        switch coordinator.launcherState {
        case .loading:
            OverdueRescueLauncherOverlayView(
                title: "Preparing rescue",
                message: "Finding tasks that still need a decision.",
                showsProgress: true,
                primaryTitle: nil,
                secondaryTitle: nil,
                onPrimary: nil,
                onSecondary: nil
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
            .accessibilityIdentifier("home.rescue.launcher.loading")
        case .failed(let message):
            OverdueRescueLauncherOverlayView(
                title: "Rescue could not start",
                message: message,
                showsProgress: false,
                primaryTitle: "Try again",
                secondaryTitle: "Dismiss",
                onPrimary: onRetry,
                onSecondary: {
                    onDismiss()
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
            .accessibilityIdentifier("home.rescue.launcher.failed")
        case .idle, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var deckOverlay: some View {
        if coordinator.isPresented, let launchContext = coordinator.presentation {
            EvaOverdueRescueSheetV2(
                plan: coordinator.plan,
                tasksByID: coordinator.presentedTasksByID,
                projectsByID: projectsByID,
                referenceDate: coordinator.referenceDate ?? launchContext.referenceDate,
                lastBatchRunID: coordinator.lastBatchRunID,
                bottomInset: bottomInset,
                launchContext: launchContext,
                onClose: {
                    onDismiss()
                },
                onExit: {
                    onDismiss()
                },
                onUpdate: onUpdate,
                onDelete: onDelete,
                onRestore: onRestore,
                onApply: onApply,
                onUndo: onUndo,
                onSavePlanningMetadata: onSavePlanningMetadata,
                onTrack: onTrack
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .zIndex(46)
        }
    }

}

extension SunriseAppShellView {
    var rescuePresentationHost: some View {
        OverdueRescuePresentationHost(
            coordinator: viewModel.overdueRescueLaunchCoordinator,
            projectsByID: tasksSnapshot.projectsByID,
            bottomInset: layoutMetrics.taskListBottomInset,
            onRetry: {
                let context = viewModel.overdueRescueLaunchCoordinator.presentation
                    ?? .home(referenceDate: Date())
                viewModel.launchOverdueRescue(context)
            },
            onUpdate: { request, completion in
                Task { @MainActor in
                    viewModel.updateTask(taskID: request.id, request: request, completion: completion)
                }
            },
            onDelete: { taskID, completion in
                Task { @MainActor in
                    viewModel.deleteTask(taskID: taskID, scope: .single, completion: completion)
                }
            },
            onRestore: { task, completion in
                Task { @MainActor in
                    viewModel.restoreDeletedTaskSnapshot(task, completion: completion)
                }
            },
            onApply: { mutations, completion in
                Task { @MainActor in viewModel.applyRescuePlan(mutations: mutations, completion: completion) }
            },
            onUndo: { completion in
                Task { @MainActor in viewModel.undoRescueRun(completion: completion) }
            },
            onSavePlanningMetadata: { _, completion in completion(.success(())) },
            onTrack: { action, metadata in
                viewModel.trackHomeInteraction(action: action, metadata: metadata)
            },
            onDismiss: { viewModel.setEvaRescuePresented(false) }
        )
    }
}
