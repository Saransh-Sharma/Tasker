//
//  AddTaskForedropView.swift
//  Tasker
//
//  Foredrop container for Add Task form with all input components.
//

import SwiftUI

// MARK: - Add Task Foredrop View

struct AddTaskForedropView: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let onCancel: () -> Void
    let onCreate: () -> Void

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            handleBar
                .padding(.top, spacing.s8)

            // Navigation bar
            AddTaskNavigationBar(
                title: "New Task",
                canSave: viewModel.viewState.canSubmit && !viewModel.isLoading
            ) {
                onCancel()
            } onSave: {
                onCreate()
            }
            .padding(.horizontal, spacing.s16)

            // Scrollable form content
            ScrollView {
                VStack(spacing: spacing.s16) {
                    // Title field
                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused
                    )
                    .staggeredAppearance(index: 0)

                    // Description field
                    AddTaskDescriptionField(
                        text: $viewModel.taskDetails,
                        isFocused: $descriptionFieldFocused
                    )
                    .staggeredAppearance(index: 1)

                    // Metadata row
                    AddTaskMetadataRow(
                        dueDate: $viewModel.dueDate,
                        reminderTime: Binding(
                            get: { viewModel.hasReminder ? viewModel.reminderTime : nil },
                            set: { newTime in
                                if let time = newTime {
                                    viewModel.hasReminder = true
                                    viewModel.reminderTime = time
                                } else {
                                    viewModel.hasReminder = false
                                }
                            }
                        ),
                        isEvening: Binding(
                            get: { viewModel.selectedType == .evening },
                            set: { viewModel.selectedType = $0 ? .evening : .morning }
                        )
                    )
                    .staggeredAppearance(index: 2)

                    // Project bar
                    AddTaskProjectBar(
                        selectedProject: $viewModel.selectedProject,
                        projects: viewModel.projects,
                        onCreateProject: { name in
                            viewModel.createProject(name: name)
                        }
                    )
                    .staggeredAppearance(index: 3)

                    // Priority picker
                    AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                        .staggeredAppearance(index: 4)

                    // XP preview
                    AddTaskXPPreview(priority: viewModel.selectedPriority)
                        .staggeredAppearance(index: 5)

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .staggeredAppearance(index: 6)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s20)
            }

            // Create button (sticky)
            AddTaskCreateButton(
                isEnabled: viewModel.viewState.canSubmit,
                isLoading: viewModel.isLoading,
                action: onCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
                .fill(Color.tasker.surfacePrimary)
                .taskerElevation(.e2, cornerRadius: corner.modal, includesBorder: false)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
        )
        .onAppear {
            // Auto-focus title field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                titleFieldFocused = true
            }
        }
    }

    // MARK: - Handle Bar

    private var handleBar: some View {
        Capsule()
            .fill(Color.tasker.textQuaternary.opacity(0.4))
            .frame(width: 44, height: 5)
    }

    // MARK: - Error Message

    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.tasker.statusWarning)

            Text(message)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.statusWarning)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.statusWarning.opacity(0.12))
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskForedropView_Previews: PreviewProvider {
    @StateObject static var viewModel = PresentationDependencyContainer.shared.makeAddTaskViewModel()

    static var previews: some View {
        AddTaskForedropView(
            viewModel: viewModel,
            onCancel: {},
            onCreate: {}
        )
        .previewLayout(.fixed(width: 375, height: 700))
    }
}
#endif
