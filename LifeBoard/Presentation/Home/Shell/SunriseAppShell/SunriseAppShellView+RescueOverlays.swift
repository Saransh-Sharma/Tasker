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
    @ObservedObject var viewModel: HomeViewModel
    let tasksByID: [UUID: TaskDefinition]
    let projectsByID: [UUID: Project]
    let bottomInset: CGFloat
    let launchContext: OverdueRescueLaunchContext
    let planningRepository: CoreDataPlanningRepository?
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack {
            launcherOverlay
            deckOverlay
        }
    }

    @ViewBuilder
    private var launcherOverlay: some View {
        switch viewModel.evaRescueLauncherState {
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
                onPrimary: {
                    viewModel.openRescue()
                },
                onSecondary: {
                    viewModel.setEvaRescuePresented(false)
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
        if viewModel.evaRescueSheetPresented {
            EvaOverdueRescueSheetV2(
                plan: viewModel.evaRescuePlan,
                tasksByID: effectiveTasksByID,
                projectsByID: projectsByID,
                referenceDate: viewModel.evaRescueReferenceDate ?? launchContext.referenceDate,
                lastBatchRunID: viewModel.evaLastBatchRunID,
                bottomInset: bottomInset,
                launchContext: launchContext,
                onClose: {
                    viewModel.setEvaRescuePresented(false)
                    onDismiss()
                },
                onExit: {
                    viewModel.setEvaRescuePresented(false)
                    onDismiss()
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
                    Task { @MainActor in
                        viewModel.applyRescuePlan(mutations: mutations, completion: completion)
                    }
                },
                onUndo: { completion in
                    Task { @MainActor in
                        viewModel.undoRescueRun(completion: completion)
                    }
                },
                onSavePlanningMetadata: { metadata, completion in
                    guard let planningRepository else {
                        completion(.success(()))
                        return
                    }
                    Task {
                        do {
                            try await planningRepository.saveTaskMetadata(metadata)
                            completion(.success(()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                },
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .zIndex(46)
        }
    }

    private var effectiveTasksByID: [UUID: TaskDefinition] {
        tasksByID.merging(viewModel.evaRescueTasksByID) { _, launchedTask in launchedTask }
    }
}

extension SunriseAppShellView {
    var rescuePresentationHost: some View {
        OverdueRescuePresentationHost(
            viewModel: viewModel,
            tasksByID: rescueTasksByID,
            projectsByID: tasksSnapshot.projectsByID,
            bottomInset: layoutMetrics.taskListBottomInset,
            launchContext: .home(referenceDate: overlaySnapshot.rescueReferenceDate ?? Date()),
            planningRepository: nil
        )
    }
}
