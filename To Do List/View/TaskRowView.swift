//
//  TaskRowView.swift
//  Tasker
//
//  Compact Home row optimized for scan speed and low-friction completion.
//

import SwiftUI

struct TaskRowDisplayModel: Equatable {
    let rowMetaText: String
    let trailingMetaText: String
    let xpValue: Int
    let urgencyLabel: String?
    let noteText: String?

    /// Compact trailing text for focus rows: just urgency/time, no XP.
    var focusTrailingText: String {
        if let urgency = urgencyLabel {
            return urgency
        }
        return trailingMetaText
    }

    var focusTrailingIsUrgent: Bool {
        urgencyLabel == "Overdue"
    }

    static func from(task: DomainTask, showTypeBadge: Bool, now: Date = Date()) -> TaskRowDisplayModel {
        let xpValue = task.priority.scorePoints
        let projectName = resolvedProjectName(for: task)

        var metaParts = [projectName, "+\(xpValue) XP"]
        if showTypeBadge {
            if task.type == .morning {
                metaParts.append("Morning")
            } else if task.type == .evening {
                metaParts.append("Evening")
            }
        }

        let trailingMetaText = trailingMetaText(for: task, xpValue: xpValue)
        let urgencyLabel = urgencyLabel(for: task, now: now)
        let noteText = task.details?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        return TaskRowDisplayModel(
            rowMetaText: metaParts.joined(separator: " • "),
            trailingMetaText: trailingMetaText,
            xpValue: xpValue,
            urgencyLabel: urgencyLabel,
            noteText: noteText
        )
    }

    private static func resolvedProjectName(for task: DomainTask) -> String {
        if let project = task.project?.trimmingCharacters(in: .whitespacesAndNewlines), !project.isEmpty {
            return project
        }
        if task.projectID == ProjectConstants.inboxProjectID {
            return ProjectConstants.inboxProjectName
        }
        return "Project"
    }

    private static func trailingMetaText(for task: DomainTask, xpValue: Int) -> String {
        guard let dueDate = task.dueDate else {
            return "+\(xpValue) XP"
        }

        let calendar = Calendar.current
        if dueDate < Date(), !task.isComplete {
            return "Overdue"
        }
        if calendar.isDateInToday(dueDate) {
            return timeFormatter.string(from: dueDate)
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        }
        return DateUtils.formatDate(dueDate)
    }

    private static func urgencyLabel(for task: DomainTask, now: Date) -> String? {
        guard !task.isComplete else { return nil }
        if task.isOverdue {
            return "Overdue"
        }
        guard let dueDate = task.dueDate else { return nil }
        let timeRemaining = dueDate.timeIntervalSince(now)
        if timeRemaining > 0, timeRemaining <= (2 * 60 * 60) {
            return "Due soon"
        }
        return nil
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

struct TaskRowView: View {
    let task: DomainTask
    let showTypeBadge: Bool
    let isTaskDragEnabled: Bool
    var onTap: (() -> Void)? = nil
    var onToggleComplete: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReschedule: (() -> Void)? = nil
    var onTaskDragStarted: ((DomainTask) -> Void)? = nil

    private var displayModel: TaskRowDisplayModel {
        TaskRowDisplayModel.from(task: task, showTypeBadge: showTypeBadge)
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    private var rowBase: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                logDebug("HOME_TAP_UI row_tap id=\(task.id.uuidString)")
                onTap?()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    onToggleComplete?()
                } label: {
                    Label(task.isComplete ? "Reopen" : "Complete", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(task.isComplete ? Color.tasker.accentSecondary : Color.tasker.statusSuccess)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !task.isComplete {
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
            .opacity(task.isComplete ? 0.58 : 1.0)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.taskRow.\(task.id.uuidString)")
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityStateValue)
            .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    var body: some View {
        if isTaskDragEnabled {
            rowBase.onDrag {
                onTaskDragStarted?(task)
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
        } else {
            rowBase
        }
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            priorityStripe

            HStack(alignment: .center, spacing: TaskerTheme.Spacing.sm) {
                CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                    onToggleComplete?()
                }
                .accessibilityIdentifier("home.taskCheckbox.\(task.id.uuidString)")
                .accessibilityValue(accessibilityStateValue)

                // Left column: name + note
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.name)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textPrimary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)

                    if let note = displayModel.noteText {
                        Text(note)
                            .font(.tasker(.caption2))
                            .foregroundColor(task.isComplete ? Color.tasker.textQuaternary.opacity(0.7) : Color.tasker.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Right column: urgency badge + XP badge
                HStack(spacing: 6) {
                    // Urgency badge (only for incomplete tasks with urgency)
                    if !task.isComplete {
                        UrgencyBadge(level: UrgencyLevel.from(task: task), isCompact: true)
                    }

                    // Time display (when no urgency)
                    if task.isComplete || UrgencyLevel.from(task: task) == .none {
                        Text(displayModel.trailingMetaText)
                            .font(.tasker(.caption2))
                            .foregroundColor(trailingMetaColor)
                            .lineLimit(1)
                    }

                    // XP badge
                    XPBadge(xpValue: displayModel.xpValue, priority: task.priority, isCompact: true, showLabel: false)
                }
            }
            .padding(.vertical, 8)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.leading, TaskerTheme.Spacing.sm)
            .frame(minHeight: 60)
        }
        .background(rowBackground)
    }

    private var rowBackground: Color {
        if task.isComplete {
            return Color.tasker.surfacePrimary.opacity(0.7)
        }
        if task.isOverdue {
            return Color.tasker.statusDanger.opacity(0.03)
        }
        return Color.tasker.surfacePrimary
    }

    private var priorityStripe: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
        .fill(stripeFill)
        .frame(width: 4)
    }

    private var stripeFill: some ShapeStyle {
        if task.isComplete {
            return AnyShapeStyle(Color.tasker.textQuaternary.opacity(0.3))
        }
        if task.isOverdue {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(uiColor: themeColors.taskOverdue), Color(uiColor: themeColors.taskOverdue).opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        switch task.priority {
        case .max:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.tasker.priorityMax, Color.tasker.priorityMax.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .high:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.tasker.priorityHigh, Color.tasker.priorityHigh.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .low:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.tasker.priorityLow, Color.tasker.priorityLow.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .none:
            return AnyShapeStyle(Color.tasker.priorityNone.opacity(0.5))
        }
    }

    private var stripeColor: Color {
        if task.isComplete {
            return Color.tasker.textQuaternary.opacity(0.3)
        }
        if task.isOverdue {
            return Color(uiColor: themeColors.taskOverdue)
        }
        switch task.priority {
        case .max:  return Color.tasker.priorityMax
        case .high: return Color.tasker.priorityHigh
        case .low:  return Color.tasker.priorityLow
        case .none: return Color.tasker.priorityNone.opacity(0.5)
        }
    }

    private var trailingMetaColor: Color {
        guard let dueDate = task.dueDate else {
            return task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textSecondary
        }
        if dueDate < Date(), !task.isComplete {
            return Color(uiColor: themeColors.taskOverdue)
        }
        if Calendar.current.isDateInToday(dueDate) {
            return Color.tasker.statusWarning
        }
        return task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textSecondary
    }

    // contentStack replaced by inline two-column layout in rowContent

    private var accessibilityLabel: String {
        var parts: [String] = ["Task: \(task.name)"]
        if task.isComplete { parts.append("completed") }
        parts.append(displayModel.rowMetaText)
        if let urgencyLabel = displayModel.urgencyLabel {
            parts.append(urgencyLabel.lowercased())
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        var hints: [String] = []
        if onToggleComplete != nil { hints.append("Double tap to toggle completion") }
        if onTap != nil { hints.append("Tap to view details") }
        if onDelete != nil || onReschedule != nil { hints.append("Swipe for actions") }
        if isTaskDragEnabled { hints.append("Long press and drag to move task to Focus") }
        return hints.joined(separator: ", ")
    }

    private var accessibilityStateValue: String {
        task.isComplete ? "done" : "open"
    }
}

#if DEBUG
struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 6) {
            TaskRowView(
                task: DomainTask(
                    name: "Review pull requests",
                    details: "Prioritize API migration and checkout fixes",
                    type: .morning,
                    priority: .high,
                    dueDate: Date()
                ),
                showTypeBadge: true,
                isTaskDragEnabled: true
            )

            TaskRowView(
                task: DomainTask(
                    name: "Completed task example",
                    type: .morning,
                    priority: .low,
                    isComplete: true,
                    dateCompleted: Date()
                ),
                showTypeBadge: false,
                isTaskDragEnabled: false
            )
        }
        .padding(.horizontal, 20)
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
