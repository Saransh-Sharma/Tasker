//
//  AddTaskTaskPicker.swift
//  Tasker
//
//  Reusable task search/select for parent task (single) and dependencies (multi).
//

import SwiftUI

// MARK: - Single Select Task Picker

struct AddTaskTaskPicker: View {
    let label: String?
    let tasks: [TaskDefinition]
    @Binding var selectedTaskID: UUID?

    @State private var searchText = ""

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var filteredTasks: [TaskDefinition] {
        if searchText.isEmpty { return Array(tasks.prefix(10)) }
        return tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }.prefix(10).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            if let label {
                Text(label)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
            }

            // Search field
            HStack(spacing: spacing.s8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(Color.tasker.textTertiary)

                TextField("Search tasks...", text: $searchText)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textPrimary)
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: corner.r2)
                    .fill(Color.tasker.surfaceTertiary)
            )

            // Selected indicator
            if let selectedTaskID, let task = tasks.first(where: { $0.id == selectedTaskID }) {
                HStack(spacing: spacing.s8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.tasker.accentPrimary)
                    Text(task.title)
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        TaskerFeedback.light()
                        withAnimation(TaskerAnimation.quick) {
                            self.selectedTaskID = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .fill(Color.tasker.accentWash)
                )
            }

            // Task list
            if !filteredTasks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(filteredTasks.prefix(5), id: \.id) { task in
                        Button {
                            TaskerFeedback.selection()
                            withAnimation(TaskerAnimation.snappy) {
                                selectedTaskID = task.id
                                searchText = ""
                            }
                        } label: {
                            HStack {
                                Text(task.title)
                                    .font(.tasker(.callout))
                                    .foregroundColor(Color.tasker.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if selectedTaskID == task.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.tasker.accentPrimary)
                                }
                            }
                            .padding(.horizontal, spacing.s12)
                            .padding(.vertical, spacing.s8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: corner.r2)
                        .fill(Color.tasker.surfaceTertiary)
                )
            }
        }
    }
}

// MARK: - Multi Select Task Picker (for dependencies)

extension AddTaskTaskPicker {
    /// Initializes a new instance.
    init(label: String?, tasks: [TaskDefinition], selectedTaskIDs: Binding<Set<UUID>>) {
        self.label = label
        self.tasks = tasks
        // Wrap multi-select as single-select that appends
        self._selectedTaskID = Binding(
            get: { nil },
            set: { newID in
                if let id = newID {
                    if selectedTaskIDs.wrappedValue.contains(id) {
                        selectedTaskIDs.wrappedValue.remove(id)
                    } else {
                        selectedTaskIDs.wrappedValue.insert(id)
                    }
                }
            }
        )
    }
}
