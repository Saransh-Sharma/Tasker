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

    var body: some View {
        VStack(spacing: TaskerTheme.Spacing.sm) {
            TaskEditorSectionCard(
                section: .execution,
                summary: viewModel.executionSummary,
                isExpanded: viewModel.isSectionExpanded(.execution)
            ) {
                viewModel.toggleSection(.execution)
                if viewModel.isSectionExpanded(.execution) {
                    onExpand()
                }
            } content: {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    AddTaskEnumChipRow(
                        label: "Energy",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "bolt" : $0.emoji },
                        selected: $viewModel.selectedEnergy
                    )

                    AddTaskEnumChipRow(
                        label: "Category",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "tag" : $0.emoji },
                        selected: $viewModel.selectedCategory
                    )

                    AddTaskEnumChipRow(
                        label: "Context",
                        displayName: { $0.displayName },
                        icon: { $0.emoji.isEmpty ? "mappin" : $0.emoji },
                        selected: $viewModel.selectedContext
                    )

                    AddTaskDurationPicker(duration: $viewModel.estimatedDuration)
                    AddTaskRepeatEditor(repeatPattern: $viewModel.repeatPattern)
                }
            }

            TaskEditorSectionCard(
                section: .relationships,
                summary: viewModel.relationshipsSummary,
                isExpanded: viewModel.isSectionExpanded(.relationships)
            ) {
                viewModel.toggleSection(.relationships)
                if viewModel.isSectionExpanded(.relationships) {
                    onExpand()
                }
            } content: {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    if !viewModel.availableParentTasks.isEmpty {
                        AddTaskTaskPicker(
                            label: "Parent Task",
                            tasks: viewModel.availableParentTasks,
                            selectedTaskID: $viewModel.selectedParentTaskID
                        )
                    }

                    if !viewModel.availableDependencyTasks.isEmpty {
                        AddTaskDependenciesPicker(
                            tasks: viewModel.availableDependencyTasks,
                            selectedTaskIDs: $viewModel.selectedDependencyTaskIDs,
                            dependencyKind: $viewModel.selectedDependencyKind
                        )
                    }
                }
            }
        }
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
