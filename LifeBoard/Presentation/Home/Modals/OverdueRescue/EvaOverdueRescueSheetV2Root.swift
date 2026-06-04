//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct EvaOverdueRescueSheetV2: View {


    let plan: EvaRescuePlan?

    let tasksByID: [UUID: TaskDefinition]

    let projectsByID: [UUID: Project]

    let referenceDate: Date

    let lastBatchRunID: UUID?

    let bottomInset: CGFloat

    let onClose: () -> Void

    let onExit: () -> Void

    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void

    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onTrack: (String, [String: Any]) -> Void

    @StateObject var viewModel: OverdueRescueViewModel

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        lastBatchRunID: UUID?,
        bottomInset: CGFloat = 0,
        onClose: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {},
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApply: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndo: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        self.plan = plan
        self.tasksByID = tasksByID
        self.projectsByID = projectsByID
        self.referenceDate = referenceDate
        self.lastBatchRunID = lastBatchRunID
        self.bottomInset = bottomInset
        self.onClose = onClose
        self.onExit = onExit
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApply = onApply
        self.onUndo = onUndo
        self.onTrack = onTrack
        _viewModel = StateObject(wrappedValue: OverdueRescueViewModel(
            plan: plan,
            tasksByID: tasksByID,
            projectsByID: projectsByID,
            referenceDate: referenceDate,
            onUpdate: onUpdate,
            onDelete: onDelete,
            onRestore: onRestore,
            onApplyBulk: onApply,
            onUndoBulk: onUndo,
            onTrack: onTrack
        ))
    }

    var body: some View {
        ZStack {
            OverdueRescueBackground()

            switch viewModel.state {
            case .paused:
                OverdueRescuePauseView(viewModel: viewModel, bottomInset: bottomInset, onDismiss: onClose)
            case .completed:
                OverdueRescueCompletionView(summary: viewModel.summary, remaining: viewModel.totalRemainingCount, bottomInset: bottomInset) {
                    viewModel.finishAndClearSession()
                    onExit()
                } reviewRemaining: {
                    viewModel.startManualReview()
                }
            case .error:
                OverdueRescueErrorView(message: viewModel.errorMessage ?? "Something went wrong while updating the rescue deck.") {
                    viewModel.startManualReview()
                } close: {
                    onExit()
                }
            default:
                OverdueRescueDeckView(viewModel: viewModel, bottomInset: bottomInset, close: {
                    viewModel.pause()
                    onClose()
                })
            }
        }
        .overlay {
            if viewModel.state == .confirmingDelete {
                OverdueRescueDeleteOverlay(
                    taskTitle: viewModel.currentCard?.task.title,
                    onConfirm: { viewModel.confirmDelete() },
                    onCancel: { viewModel.cancelDelete() }
                )
                .transition(.opacity)
                .zIndex(60)
            }
        }
        .animation(reduceMotion ? nil : LifeBoardAnimation.snappy, value: viewModel.state == .confirmingDelete)
        .lifeboardSnackbar($viewModel.snackbar, bottomPadding: bottomInset + 20)
        .sheet(isPresented: Binding(
            get: { viewModel.state == .editing },
            set: { if !$0 { viewModel.cancelEdit() } }
        )) {
            if let card = viewModel.currentCard {
                OverdueRescueQuickEditSheet(
                    card: card,
                    projects: Array(projectsByID.values).sorted { $0.name < $1.name },
                    save: { viewModel.saveEdit(draft: $0) },
                    cancel: { viewModel.cancelEdit() }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSafeFixesConfirmation) {
            OverdueRescueSafeFixesView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLargeStackPreflight) {
            OverdueRescueLargeStackView(
                count: viewModel.allCount,
                safeCount: viewModel.safeFixes.count,
                applySafeFixes: {
                    viewModel.showLargeStackPreflight = false
                    viewModel.showSafeFixesConfirmation = true
                },
                startManualReview: viewModel.startManualReview
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.pause()
        }
        .accessibilityIdentifier("home.rescue.sheet")
    }
}
