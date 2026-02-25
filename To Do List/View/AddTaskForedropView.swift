//
//  AddTaskForedropView.swift
//  Tasker
//
//  Three-tier form: Primary Capture → Secondary Details → Advanced Planning.
//  Quick + Expand pattern optimized for ADHD execution.
//

import SwiftUI

// MARK: - Add Task Foredrop View

struct AddTaskForedropView: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let showAddAnother: Bool
    @Binding var successFlash: Bool
    let onCancel: () -> Void
    let onCreate: () -> Void
    let onAddAnother: () -> Void
    let onExpandToLarge: () -> Void

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    @State private var errorShakeTrigger = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            AddTaskNavigationBar(
                canSave: viewModel.viewState.canSubmit && !viewModel.isLoading
            ) {
                onCancel()
            } onSave: {
                submitTask()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            // Scrollable form content
            ScrollView {
                VStack(spacing: spacing.s16) {

                    // ─── PRIMARY CAPTURE (always visible) ───

                    // Title field
                    AddTaskTitleField(
                        text: $viewModel.taskName,
                        isFocused: $titleFieldFocused,
                        onSubmit: submitTask
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    // Date preset row
                    AddTaskDatePresetRow(dueDate: $viewModel.dueDate)
                        .enhancedStaggeredAppearance(index: 1)

                    // Quick attributes row: Task type chips + Reminder
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.chipSpacing) {
                            AddTaskTypeChips(selectedType: $viewModel.selectedType)
                            AddTaskReminderChip(
                                hasReminder: $viewModel.hasReminder,
                                reminderTime: $viewModel.reminderTime
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    // Priority pills
                    AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                        .enhancedStaggeredAppearance(index: 3)

                    // Project bar
                    AddTaskProjectBar(
                        selectedProject: $viewModel.selectedProject,
                        projects: viewModel.projects,
                        onCreateProject: { name in
                            viewModel.createProject(name: name)
                        }
                    )
                    .enhancedStaggeredAppearance(index: 4)

                    // ─── SECONDARY DETAILS (collapsed) ───

                    AddTaskSecondaryDetailsSection(
                        viewModel: viewModel,
                        descriptionFocused: $descriptionFieldFocused,
                        onExpand: onExpandToLarge
                    )
                    .enhancedStaggeredAppearance(index: 5)

                    // ─── ADVANCED PLANNING (collapsed) ───

                    AddTaskAdvancedPlanningSection(
                        viewModel: viewModel,
                        onExpand: onExpandToLarge
                    )
                    .enhancedStaggeredAppearance(index: 6)

                    // ─── FOOTER ───

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .bellShake(trigger: $errorShakeTrigger)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // XP preview
                    AddTaskXPPreview(priority: viewModel.selectedPriority)
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s20)
            }

            // ─── CTA FOOTER (sticky) ───

            AddTaskCreateButton(
                isEnabled: viewModel.viewState.canSubmit,
                isLoading: viewModel.isLoading,
                successFlash: successFlash,
                showAddAnother: showAddAnother,
                onCreateAction: submitTask,
                onAddAnotherAction: onAddAnother
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.surfacePrimary)
        .overlay(
            Color.tasker.statusSuccess
                .opacity(successFlash ? 0.05 : 0)
                .animation(TaskerAnimation.gentle, value: successFlash)
                .allowsHitTesting(false)
        )
        .onChange(of: viewModel.errorMessage) { _ in
            if viewModel.errorMessage != nil {
                errorShakeTrigger.toggle()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                titleFieldFocused = true
            }
        }
    }

    // MARK: - Helpers

    /// Executes submitTask.
    private func submitTask() {
        guard viewModel.viewState.canSubmit, !viewModel.isLoading else { return }
        onCreate()
    }

    /// Executes errorMessageView.
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
        .animation(TaskerAnimation.bouncy, value: viewModel.errorMessage != nil)
    }
}

// MARK: - Task Type Chips

struct AddTaskTypeChips: View {
    @Binding var selectedType: TaskType

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private let types: [(type: TaskType, icon: String, label: String)] = [
        (.morning, "sun.max", "Morning"),
        (.evening, "moon.stars", "Evening"),
        (.upcoming, "arrow.right.circle", "Upcoming"),
    ]

    var body: some View {
        HStack(spacing: spacing.chipSpacing) {
            ForEach(types, id: \.type) { item in
                AddTaskMetadataChip(
                    icon: item.icon,
                    text: item.label,
                    isActive: selectedType == item.type
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedType = item.type
                    }
                }
            }
        }
    }
}
