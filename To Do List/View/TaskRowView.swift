//
//  TaskRowView.swift
//  Tasker
//
//  Refined task row with jewel-toned priority stripe, multi-line support,
//  and restrained status badges. Part of the "Obsidian & Gems" design system.
//

import SwiftUI

// MARK: - Task Row View

struct TaskRowView: View {
    let task: DomainTask
    let showTypeBadge: Bool
    var onTap: (() -> Void)? = nil
    var onToggleComplete: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReschedule: (() -> Void)? = nil

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    var body: some View {
        rowContent
        .contentShape(Rectangle())
        .onTapGesture {
            print("HOME_TAP_UI row_tap id=\(task.id.uuidString)")
            onTap?()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if task.isComplete {
                Button {
                    onToggleComplete?()
                } label: {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                }
                .tint(Color.tasker.accentSecondary)
            } else {
                Button {
                    onReschedule?()
                } label: {
                    Label("Reschedule", systemImage: "calendar")
                }
                .tint(Color.tasker.accentPrimary)
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.md, includesBorder: false)
        .opacity(task.isComplete ? 0.7 : 1.0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.taskRow.\(task.id.uuidString)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityStateValue)
        .accessibilityHint(accessibilityHint)
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            priorityStripe

            HStack(spacing: TaskerTheme.Spacing.md) {
                CompletionCheckbox(isComplete: task.isComplete) {
                    onToggleComplete?()
                }
                .accessibilityIdentifier("home.taskCheckbox.\(task.id.uuidString)")
                .accessibilityValue(accessibilityStateValue)

                contentStack

                Spacer(minLength: 0)
            }
            .padding(.vertical, TaskerTheme.Spacing.md)
            .padding(.trailing, TaskerTheme.Spacing.lg)
            .padding(.leading, TaskerTheme.Spacing.md)
        }
        .background(Color.tasker.surfacePrimary)
    }

    // MARK: - Priority Stripe

    private var priorityStripe: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
        .fill(stripeColor)
        .frame(width: 3)
    }

    private var stripeColor: Color {
        if task.isComplete {
            return Color.tasker.textQuaternary.opacity(0.2)
        }
        if task.isOverdue {
            return Color(uiColor: themeColors.taskOverdue)
        }
        switch task.priority {
        case .max:  return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low:  return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone.opacity(0.3)
        }
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            // Title
            Text(task.name)
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(task.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                .strikethrough(task.isComplete, color: Color.tasker.textQuaternary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Description
            if let details = task.details, !details.isEmpty {
                Text(details)
                    .font(.tasker(.callout))
                    .foregroundColor(task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            // Badge row
            if hasBadges {
                badgeRow
            }
        }
    }

    // MARK: - Badge Row

    private var hasBadges: Bool {
        guard !task.isComplete else { return false }
        return task.isOverdue
            || task.dueDate != nil
            || (showTypeBadge && (task.type == .morning || task.type == .evening))
            || task.priority.isHighPriority
    }

    private var badgeRow: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            // Overdue badge (supersedes due date)
            if task.isOverdue {
                InfoPill(
                    icon: "clock.badge.exclamationmark",
                    text: "Overdue",
                    color: Color(uiColor: themeColors.taskOverdue)
                )
            }
            // Due date badge (only if not overdue)
            else if let dueDate = task.dueDate {
                InfoPill(
                    icon: "calendar",
                    text: dueDateText(for: dueDate),
                    color: dueDateColor(for: dueDate)
                )
            }

            // Type badge (only in mixed sections)
            if showTypeBadge {
                if task.type == .morning {
                    InfoPill(
                        icon: "sun.max",
                        text: "Morning",
                        color: Color.tasker.statusWarning
                    )
                } else if task.type == .evening {
                    InfoPill(
                        icon: "moon.fill",
                        text: "Evening",
                        color: Color.tasker.accentSecondary
                    )
                }
            }

            // Priority badge (high and max only)
            if task.priority.isHighPriority {
                PriorityBadge(priority: Int32(task.priority.rawValue))
            }
        }
    }

    // MARK: - Due Date Helpers

    private func dueDateText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return DateUtils.formatDate(date)
        }
    }

    private func dueDateColor(for date: Date) -> Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Color.tasker.statusWarning
        } else if calendar.isDateInTomorrow(date) {
            return Color.tasker.accentPrimary
        } else if date < Date() {
            return Color.tasker.statusDanger
        } else {
            return Color.tasker.textSecondary
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = ["Task: \(task.name)"]
        if task.isComplete { parts.append("completed") }
        if task.isOverdue { parts.append("overdue") }
        if let dueDate = task.dueDate {
            parts.append("due \(DateUtils.formatDate(dueDate))")
        }
        if task.priority.isHighPriority {
            parts.append("\(task.priority.displayName) priority")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        var hints: [String] = []
        if onToggleComplete != nil { hints.append("Double tap to toggle completion") }
        if onTap != nil { hints.append("Tap to view details") }
        if onDelete != nil || onReschedule != nil { hints.append("Swipe left for actions") }
        return hints.joined(separator: ", ")
    }

    private var accessibilityStateValue: String {
        task.isComplete ? "done" : "open"
    }
}

// MARK: - Preview

#if DEBUG
struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            TaskRowView(
                task: DomainTask(
                    name: "Review quarterly financial reports and prepare summary for the board meeting presentation",
                    details: "Include revenue projections and year-over-year comparisons with charts",
                    type: .morning,
                    priority: .max,
                    dueDate: Date()
                ),
                showTypeBadge: true,
                onTap: {},
                onToggleComplete: {}
            )

            TaskRowView(
                task: DomainTask(
                    name: "Morning meditation",
                    type: .morning,
                    priority: .high,
                    dueDate: Date().addingTimeInterval(86400)
                ),
                showTypeBadge: false,
                onTap: {},
                onToggleComplete: {}
            )

            TaskRowView(
                task: DomainTask(
                    name: "Buy groceries",
                    details: "Milk, eggs, bread, avocados",
                    type: .evening,
                    priority: .low,
                    dueDate: Date().addingTimeInterval(-86400),
                    isComplete: false
                ),
                showTypeBadge: true,
                onTap: {},
                onToggleComplete: {}
            )

            TaskRowView(
                task: DomainTask(
                    name: "Completed task example",
                    type: .morning,
                    priority: .high,
                    isComplete: true
                ),
                showTypeBadge: false,
                onTap: {},
                onToggleComplete: {}
            )

            TaskRowView(
                task: DomainTask(
                    name: "Simple low priority task",
                    type: .inbox,
                    priority: .none
                ),
                showTypeBadge: false,
                onTap: {},
                onToggleComplete: {}
            )
        }
        .padding(.horizontal, 20)
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
