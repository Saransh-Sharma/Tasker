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
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges && !viewModel.isSubmitting)
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
        let tapAt = Date()
        _ = viewModel.submitTask(
            onAccepted: { _ in
                let dismissMS = Int(Date().timeIntervalSince(tapAt) * 1_000)
                logWarning(
                    event: "task_create_tap_to_dismiss_ms",
                    message: "Add-task sheet dismissed after accepted submission",
                    fields: [
                        "duration_ms": String(dismissMS),
                        "flow": "add_and_close"
                    ]
                )
                TaskerFeedback.success()
                dismiss()
            },
            completion: { result in
                guard case .failure(let error) = result else { return }
                logWarning(
                    event: "task_create_submit_failed",
                    message: "Add-task submission failed after sheet dismissal",
                    fields: [
                        "flow": "add_and_close",
                        "error": error.localizedDescription
                    ]
                )
            }
        )
    }

    /// Executes handleAddAnother.
    private func handleAddAnother() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        _ = viewModel.submitTask(completion: { result in
            switch result {
            case .success:
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
            case .failure(let error):
                logWarning(
                    event: "task_create_submit_failed",
                    message: "Add-task submission failed in add-another flow",
                    fields: [
                        "flow": "add_another",
                        "error": error.localizedDescription
                    ]
                )
            }
        })
    }

    /// Executes expandToLarge.
    private func expandToLarge() {
        withAnimation(TaskerAnimation.gentle) {
            selectedDetent = .large
        }
    }
}
