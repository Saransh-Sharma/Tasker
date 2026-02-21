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
                    .staggeredAppearance(index: 0)

                    if viewModel.isGeneratingSuggestion {
                        HStack(spacing: spacing.s8) {
                            ProgressView()
                            Text("Eva is suggesting fields...")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    } else if let suggestion = viewModel.aiSuggestion {
                        aiSuggestionCard(suggestion)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Date preset row
                    AddTaskDatePresetRow(dueDate: $viewModel.dueDate)
                        .staggeredAppearance(index: 1)

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
                    .staggeredAppearance(index: 2)

                    // Priority pills
                    AddTaskPriorityPicker(selectedPriority: $viewModel.selectedPriority)
                        .staggeredAppearance(index: 3)

                    // Project bar
                    AddTaskProjectBar(
                        selectedProject: $viewModel.selectedProject,
                        projects: viewModel.projects,
                        onCreateProject: { name in
                            viewModel.createProject(name: name)
                        }
                    )
                    .staggeredAppearance(index: 4)

                    // ─── SECONDARY DETAILS (collapsed) ───

                    AddTaskSecondaryDetailsSection(
                        viewModel: viewModel,
                        descriptionFocused: $descriptionFieldFocused,
                        onExpand: onExpandToLarge
                    )
                    .staggeredAppearance(index: 5)

                    // ─── ADVANCED PLANNING (collapsed) ───

                    AddTaskAdvancedPlanningSection(
                        viewModel: viewModel,
                        onExpand: onExpandToLarge
                    )
                    .staggeredAppearance(index: 6)

                    // ─── FOOTER ───

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
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

    /// Executes aiSuggestionCard.
    private func aiSuggestionCard(_ suggestion: TaskFieldSuggestion) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if let routeBanner = suggestion.routeBanner, routeBanner.isEmpty == false {
                HStack(alignment: .top, spacing: spacing.s8) {
                    Image(systemName: "cpu")
                        .foregroundColor(Color.tasker.accentPrimary)
                    Text(routeBanner)
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textTertiary)
                    Spacer(minLength: 0)
                }
            }
            HStack {
                Text("AI suggestion")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                Spacer()
                Button("Accept all") {
                    viewModel.applyAISuggestion(suggestion)
                    TaskerFeedback.selection()
                }
                .font(.tasker(.caption1))
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    suggestionChip("⚡ \(suggestion.priority.displayName)") {
                        viewModel.selectedPriority = suggestion.priority
                    }
                    suggestionChip("🔋 \(suggestion.energy.displayName)") {
                        viewModel.selectedEnergy = suggestion.energy
                    }
                    suggestionChip("📍 \(suggestion.context.displayName)") {
                        viewModel.selectedContext = suggestion.context
                    }
                    suggestionChip("🕒 \(suggestion.type.displayName)") {
                        viewModel.selectedType = suggestion.type
                    }
                }
            }

            Text("Eva: \"\(suggestion.rationale)\"")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .stroke(Color.tasker.accentMuted.opacity(0.35), lineWidth: 1)
                )
        )
    }

    /// Executes suggestionChip.
    private func suggestionChip(_ text: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(text)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.accentPrimary)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(Color.tasker.accentWash)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
