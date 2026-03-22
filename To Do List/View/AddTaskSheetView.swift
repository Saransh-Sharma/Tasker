//
//  AddTaskSheetView.swift
//  Tasker
//
//  V3-native Add sheet. Backward compatible with task-only callers, but now
//  scaffolded as a unified Task / Habit composer.
//

import SwiftUI

public enum AddTaskContainerMode: Equatable {
    case sheet
    case inspector
}

public struct AddTaskSheetView: View {
    @StateObject private var viewModel: AddItemViewModel
    @Environment(\.dismiss) private var dismiss
    private let onTaskCreated: ((UUID) -> Void)?
    private let onDismissWithoutTask: (() -> Void)?

    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var didCreateItem = false

    public init(
        viewModel: AddTaskViewModel,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: AddItemViewModel(
                taskViewModel: viewModel,
                habitViewModel: PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
            )
        )
        self.onTaskCreated = onTaskCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public init(
        itemViewModel: AddItemViewModel,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: itemViewModel)
        self.onTaskCreated = onTaskCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public var body: some View {
        AddItemComposerView(
            viewModel: viewModel,
            containerMode: .sheet,
            showAddAnother: showAddAnother,
            successFlash: $successFlash,
            onCancel: handleCancel,
            onTaskCreate: handleTaskCreate,
            onTaskAddAnother: handleTaskAddAnother,
            onHabitCreate: handleHabitCreate,
            onHabitAddAnother: handleHabitAddAnother,
            onExpandToLarge: expandToLarge
        )
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
        .onDisappear {
            if didCreateItem == false {
                onDismissWithoutTask?()
            }
        }
    }

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            TaskerFeedback.medium()
            showDiscardConfirmation = true
        } else {
            TaskerFeedback.light()
            dismiss()
        }
    }

    private func handleTaskCreate() {
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        viewModel.taskViewModel.createTask()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewModel.taskViewModel.isTaskCreated {
                TaskerFeedback.success()
                didCreateItem = true
                if let taskID = viewModel.taskViewModel.lastCreatedTaskID {
                    onTaskCreated?(taskID)
                }
                dismiss()
            }
        }
    }

    private func handleTaskAddAnother() {
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        viewModel.taskViewModel.createTask()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewModel.taskViewModel.isTaskCreated {
                TaskerFeedback.success()
                didCreateItem = true
                if let taskID = viewModel.taskViewModel.lastCreatedTaskID {
                    onTaskCreated?(taskID)
                }
                withAnimation(TaskerAnimation.snappy) {
                    successFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(TaskerAnimation.snappy) {
                        successFlash = false
                        viewModel.taskViewModel.resetForm()
                        showAddAnother = true
                        selectedDetent = .medium
                    }
                }
            }
        }
    }

    private func handleHabitCreate() {
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            guard case .success = result else { return }
            TaskerFeedback.success()
            didCreateItem = true
            withAnimation(TaskerAnimation.snappy) {
                successFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }

    private func handleHabitAddAnother() {
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            guard case .success = result else { return }
            TaskerFeedback.success()
            didCreateItem = true
            withAnimation(TaskerAnimation.snappy) {
                successFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(TaskerAnimation.snappy) {
                    successFlash = false
                    viewModel.habitViewModel.resetForm()
                    showAddAnother = true
                    selectedDetent = .medium
                }
            }
        }
    }

    private func expandToLarge() {
        TaskerFeedback.light()
        withAnimation(TaskerAnimation.gentle) {
            selectedDetent = .large
        }
    }
}

struct AddTaskInspectorContainer: View {
    @StateObject private var viewModel: AddItemViewModel
    @State private var successFlash = false
    let onClose: () -> Void

    init(viewModel: AddTaskViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: AddItemViewModel(
                taskViewModel: viewModel,
                habitViewModel: PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
            )
        )
        self.onClose = onClose
    }

    var body: some View {
        AddItemComposerView(
            viewModel: viewModel,
            containerMode: .inspector,
            showAddAnother: false,
            successFlash: $successFlash,
            onCancel: onClose,
            onTaskCreate: handleTaskCreate,
            onTaskAddAnother: handleTaskCreate,
            onHabitCreate: handleHabitCreate,
            onHabitAddAnother: handleHabitCreate,
            onExpandToLarge: {}
        )
        .accessibilityIdentifier("home.ipad.detail.addTask")
    }

    private func handleTaskCreate() {
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        viewModel.taskViewModel.createTask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard viewModel.taskViewModel.isTaskCreated else { return }
            TaskerFeedback.success()
            successFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                successFlash = false
                viewModel.taskViewModel.resetForm()
            }
        }
    }

    private func handleHabitCreate() {
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            guard case .success = result else { return }
            TaskerFeedback.success()
            successFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                successFlash = false
                viewModel.habitViewModel.resetForm()
            }
        }
    }
}
