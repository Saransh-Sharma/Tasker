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
    @ViewBuilder
    var rescueLauncherOverlay: some View {
        switch overlaySnapshot.rescueLauncherState {
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
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
        case .idle, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    var rescueDeckOverlay: some View {
        if overlaySnapshot.rescuePresented {
            EvaOverdueRescueSheetV2(
                plan: overlaySnapshot.rescuePlan,
                tasksByID: rescueTasksByID,
                projectsByID: tasksSnapshot.projectsByID,
                referenceDate: overlaySnapshot.rescueReferenceDate ?? Date(),
                lastBatchRunID: overlaySnapshot.lastBatchRunID,
                bottomInset: layoutMetrics.taskListBottomInset,
                onClose: {
                    viewModel.setEvaRescuePresented(false)
                },
                onExit: {
                    viewModel.setEvaRescuePresented(false)
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
                onTrack: { action, metadata in
                    viewModel.trackHomeInteraction(action: action, metadata: metadata)
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .zIndex(46)
            .accessibilityIdentifier("home.rescue.overlay")
        }
    }
}
