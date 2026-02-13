//
//  TaskSectionView.swift
//  Tasker
//
//  Collapsible project section with refined header, accent threading,
//  and spring-physics collapse animation. Obsidian & Gems design system.
//

import SwiftUI

// MARK: - Task Section View

struct TaskSectionView: View {
    let project: Project
    let tasks: [DomainTask]
    let isOverdueSection: Bool
    var onTaskTap: ((DomainTask) -> Void)?
    var onToggleComplete: ((DomainTask) -> Void)?
    var onDeleteTask: ((DomainTask) -> Void)?
    var onRescheduleTask: ((DomainTask) -> Void)?

    @State private var isExpanded: Bool = true

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    init(
        project: Project,
        tasks: [DomainTask],
        isOverdueSection: Bool = false,
        onTaskTap: ((DomainTask) -> Void)? = nil,
        onToggleComplete: ((DomainTask) -> Void)? = nil,
        onDeleteTask: ((DomainTask) -> Void)? = nil,
        onRescheduleTask: ((DomainTask) -> Void)? = nil
    ) {
        self.project = project
        self.tasks = tasks
        self.isOverdueSection = isOverdueSection
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onDeleteTask = onDeleteTask
        self.onRescheduleTask = onRescheduleTask
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader

            if isExpanded {
                taskList
                    .padding(.top, TaskerTheme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Button {
            withAnimation(TaskerAnimation.snappy) {
                isExpanded.toggle()
            }
            TaskerHaptic.selection()
        } label: {
            HStack(spacing: TaskerTheme.Spacing.md) {
                // Accent dot — the visual thread
                Circle()
                    .fill(accentColor)
                    .frame(width: 4, height: 4)

                // Project icon
                Image(systemName: sectionIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                    .frame(width: 20, alignment: .center)

                // Project name
                Text(sectionTitle)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)

                // Task count
                Text("\(tasks.count)")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundColor(Color.tasker.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Capsule())

                Spacer()

                // Collapse chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(TaskerAnimation.snappy, value: isExpanded)
            }
            .padding(.vertical, TaskerTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: TaskerTheme.Spacing.sm) {
            ForEach(renderItems, id: \.renderKey) { item in
                TaskRowView(
                    task: item.task,
                    showTypeBadge: hasMixedTypes,
                    onTap: { onTaskTap?(item.task) },
                    onToggleComplete: { onToggleComplete?(item.task) },
                    onDelete: { onDeleteTask?(item.task) },
                    onReschedule: { onRescheduleTask?(item.task) }
                )
                .staggeredAppearance(index: item.index)
            }
        }
    }

    private struct TaskRowRenderItem {
        let index: Int
        let task: DomainTask
        let renderKey: String
    }

    private var renderItems: [TaskRowRenderItem] {
        tasks.enumerated().map { index, task in
            TaskRowRenderItem(
                index: index,
                task: task,
                renderKey: taskRenderKey(for: task)
            )
        }
    }

    private func taskRenderKey(for task: DomainTask) -> String {
        let completedAt = task.dateCompleted?.timeIntervalSince1970 ?? 0
        return "\(task.id.uuidString)-\(task.isComplete)-\(completedAt)"
    }

    // MARK: - Computed Properties

    private var accentColor: Color {
        if isOverdueSection {
            return Color(uiColor: themeColors.taskOverdue)
        }
        return Color.tasker.accentPrimary
    }

    private var sectionIcon: String {
        if isOverdueSection {
            return "exclamationmark.triangle.fill"
        }
        return project.icon.systemImageName
    }

    private var sectionTitle: String {
        if isOverdueSection {
            return "Overdue"
        }
        return project.name
    }

    /// Whether this section contains both morning and evening tasks
    private var hasMixedTypes: Bool {
        let types = Set(tasks.map(\.type))
        return types.contains(.morning) && types.contains(.evening)
    }
}

// MARK: - Preview

#if DEBUG
struct TaskSectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 28) {
            // Overdue section
            TaskSectionView(
                project: Project.createInbox(),
                tasks: [
                    DomainTask(
                        name: "Overdue report",
                        type: .morning,
                        priority: .max,
                        dueDate: Date().addingTimeInterval(-172800)
                    ),
                    DomainTask(
                        name: "Fix critical bug in checkout flow",
                        details: "Users are seeing a blank screen after payment",
                        type: .morning,
                        priority: .high,
                        dueDate: Date().addingTimeInterval(-86400)
                    )
                ],
                isOverdueSection: true
            )

            // Inbox section
            TaskSectionView(
                project: Project.createInbox(),
                tasks: [
                    DomainTask(
                        name: "Morning meditation and journaling",
                        type: .morning,
                        priority: .low,
                        dueDate: Date()
                    ),
                    DomainTask(
                        name: "Review pull requests",
                        details: "Check the API refactor PR from the team",
                        type: .morning,
                        priority: .high,
                        dueDate: Date()
                    ),
                    DomainTask(
                        name: "Evening reading",
                        type: .evening,
                        priority: .none
                    )
                ]
            )

            // Custom project
            TaskSectionView(
                project: Project(name: "Side Project", icon: .creative),
                tasks: [
                    DomainTask(
                        name: "Design landing page wireframes",
                        details: "Focus on mobile-first layout with clear CTA hierarchy",
                        type: .morning,
                        priority: .high,
                        dueDate: Date().addingTimeInterval(86400)
                    )
                ]
            )
        }
        .padding(.horizontal, 20)
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
