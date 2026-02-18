//
//  AddTaskSheetView.swift
//  Tasker
//
//  Main Add Task sheet container with backdrop/foredrop pattern.
//  Pure SwiftUI implementation matching homescreen's "Obsidian & Gems" design.
//

import SwiftUI

// MARK: - Add Task Sheet View

public struct AddTaskSheetView: View {
    @StateObject private var viewModel: AddTaskViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()

    public init(viewModel: AddTaskViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ZStack {
            // Backdrop layer
            AddTaskBackdropView(selectedDate: $selectedDate)

            // Foredrop layer
            AddTaskForedropView(
                viewModel: viewModel,
                onCancel: {
                    dismiss()
                },
                onCreate: {
                    viewModel.createTask()
                }
            )
        }
        .background(Color.tasker.bgCanvas)
        .onChange(of: viewModel.isTaskCreated) { _, created in
            if created {
                // Success haptic and dismiss
                TaskerFeedback.success()
                dismiss()
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            // Sync backdrop date with ViewModel
            viewModel.dueDate = newDate
        }
    }
}
