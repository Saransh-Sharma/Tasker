//
//  AddTaskSheetView.swift
//  Tasker
//
//  V3-native Add Task sheet — Quick + Expand two-speed capture.
//  Opens as .medium detent for lightning capture, expands to .large for planning.
//

import SwiftUI

// MARK: - Add Task Sheet View

public enum AddTaskContainerMode: Equatable {
    case sheet
    case inspector
}

public struct AddTaskSheetView: View {
    /// Initializes a new instance.
    @StateObject private var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss
    private let onTaskCreated: ((UUID) -> Void)?
    private let onDismissWithoutTask: (() -> Void)?

    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var didCreateTask = false

    public init(
        viewModel: AddTaskViewModel,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onTaskCreated = onTaskCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public var body: some View {
        AddTaskForedropView(
            viewModel: viewModel,
            containerMode: .sheet,
            showAddAnother: showAddAnother,
            successFlash: $successFlash,
            onCancel: handleCancel,
            onCreate: handleCreate,
            onAddAnother: handleAddAnother,
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
            if didCreateTask == false {
                onDismissWithoutTask?()
            }
        }
    }

    // MARK: - Actions

    /// Executes handleCancel.
    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            TaskerFeedback.medium()
            showDiscardConfirmation = true
        } else {
            TaskerFeedback.light()
            dismiss()
        }
    }

    /// Executes handleCreate.
    private func handleCreate() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        viewModel.createTask()

        // Observe success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewModel.isTaskCreated {
                TaskerFeedback.success()
                didCreateTask = true
                if let taskID = viewModel.lastCreatedTaskID {
                    onTaskCreated?(taskID)
                }
                dismiss()
            }
        }
    }

    /// Executes handleAddAnother.
    private func handleAddAnother() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        viewModel.createTask()

        // Observe success, then reset for another
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if viewModel.isTaskCreated {
                TaskerFeedback.success()
                didCreateTask = true
                if let taskID = viewModel.lastCreatedTaskID {
                    onTaskCreated?(taskID)
                }
                withAnimation(TaskerAnimation.snappy) {
                    successFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(TaskerAnimation.snappy) {
                        successFlash = false
                        viewModel.resetForm()
                        showAddAnother = true
                        selectedDetent = .medium
                    }
                }
            }
        }
    }

    /// Executes expandToLarge.
    private func expandToLarge() {
        TaskerFeedback.light()
        withAnimation(TaskerAnimation.gentle) {
            selectedDetent = .large
        }
    }
}

struct AddTaskInspectorContainer: View {
    @StateObject private var viewModel: AddTaskViewModel
    @State private var successFlash = false
    let onClose: () -> Void

    init(viewModel: AddTaskViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        AddTaskForedropView(
            viewModel: viewModel,
            containerMode: .inspector,
            showAddAnother: false,
            successFlash: $successFlash,
            onCancel: onClose,
            onCreate: handleCreate,
            onAddAnother: handleCreate,
            onExpandToLarge: {}
        )
        .accessibilityIdentifier("home.ipad.detail.addTask")
    }

    private func handleCreate() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        viewModel.createTask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard viewModel.isTaskCreated else { return }
            TaskerFeedback.success()
            successFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                successFlash = false
                viewModel.resetForm()
            }
        }
    }
}
