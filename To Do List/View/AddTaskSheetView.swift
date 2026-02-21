//
//  AddTaskSheetView.swift
//  Tasker
//
//  V3-native Add Task sheet — Quick + Expand two-speed capture.
//  Opens as .medium detent for lightning capture, expands to .large for planning.
//

import SwiftUI

// MARK: - Add Task Sheet View

public struct AddTaskSheetView: View {
    /// Initializes a new instance.
    @StateObject private var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var selectedDetent: PresentationDetent = .medium

    public init(viewModel: AddTaskViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        AddTaskForedropView(
            viewModel: viewModel,
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
        withAnimation(TaskerAnimation.gentle) {
            selectedDetent = .large
        }
    }
}
