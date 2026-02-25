//
//  AddTaskAdvancedPlanningSection.swift
//  Tasker
//
//  Collapsible "Advanced" section: Parent task, Dependencies, Energy, Category,
//  Context, Duration, Repeat schedule.
//

import SwiftUI

// MARK: - Advanced Planning Section

struct AddTaskAdvancedPlanningSection: View {
    @ObservedObject var viewModel: AddTaskViewModel
    let onExpand: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                TaskerFeedback.light()
                withAnimation(TaskerAnimation.gentle) {
                    viewModel.showAdvancedPlanning.toggle()
                }
                if viewModel.showAdvancedPlanning {
                    onExpand()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                    Text("Advanced")
                        .font(.tasker(.callout))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .rotationEffect(.degrees(viewModel.showAdvancedPlanning ? 90 : 0))
                        .scaleEffect(viewModel.showAdvancedPlanning ? 1.0 : 0.9)
                        .animation(TaskerAnimation.snappy, value: viewModel.showAdvancedPlanning)
                }
                .foregroundColor(Color.tasker.textSecondary)
                .padding(.vertical, spacing.s12)
            }
            .buttonStyle(.plain)

            // Content
            if viewModel.showAdvancedPlanning {
                VStack(spacing: spacing.s12) {
                    // Parent task selector
                    if !viewModel.availableParentTasks.isEmpty {
                        AddTaskTaskPicker(
                            label: "Parent Task",
                            tasks: viewModel.availableParentTasks,
                            selectedTaskID: $viewModel.selectedParentTaskID
                        )
                        .enhancedStaggeredAppearance(index: 0)
                    }

                    // Dependencies selector
                    if !viewModel.availableDependencyTasks.isEmpty {
                        AddTaskDependenciesPicker(
                            tasks: viewModel.availableDependencyTasks,
                            selectedTaskIDs: $viewModel.selectedDependencyTaskIDs,
                            dependencyKind: $viewModel.selectedDependencyKind
                        )
                        .enhancedStaggeredAppearance(index: 1)
                    }

                    // Energy selector
                    AddTaskEnumChipRow(
                        label: "Energy",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji },
                        selected: $viewModel.selectedEnergy
                    )
                    .enhancedStaggeredAppearance(index: 2)

                    // Category selector
                    AddTaskEnumChipRow(
                        label: "Category",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "tag" : $0.emoji },
                        selected: $viewModel.selectedCategory
                    )
                    .enhancedStaggeredAppearance(index: 3)

                    // Context selector
                    AddTaskEnumChipRow(
                        label: "Context",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "mappin" : $0.emoji },
                        selected: $viewModel.selectedContext
                    )
                    .enhancedStaggeredAppearance(index: 4)

                    // Estimated duration
                    AddTaskDurationPicker(duration: $viewModel.estimatedDuration)
                        .enhancedStaggeredAppearance(index: 5)

                    // Repeat schedule
                    AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                        .enhancedStaggeredAppearance(index: 6)
                }
                .padding(.top, spacing.s8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, spacing.s4)
        .padding(.vertical, spacing.s4)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.surfaceSecondary.opacity(0.5))
        )
    }
}

// MARK: - Dependencies Picker

struct AddTaskDependenciesPicker: View {
    let tasks: [TaskDefinition]
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var dependencyKind: TaskDependencyKind

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Dependencies")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            // Kind selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(TaskDependencyKind.allCases, id: \.self) { kind in
                        AddTaskMetadataChip(
                            icon: kind == .blocks ? "arrow.triangle.branch" : "link",
                            text: kind == .blocks ? "Blocks" : "Related",
                            isActive: dependencyKind == kind
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                dependencyKind = kind
                            }
                        }
                    }
                }
            }

            // Task multi-select
            AddTaskTaskPicker(
                label: nil,
                tasks: tasks,
                selectedTaskIDs: $selectedTaskIDs
            )
        }
    }
}
