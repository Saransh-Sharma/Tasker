//
//  TaskRowView.swift
//  Tasker
//
//  Compact Home row optimized for scan speed and low-friction completion.
//

import SwiftUI

struct TaskRowDisplayModel: Equatable {
    let xpValue: Int
    let descriptionText: String?
    let metadataText: String?
    let statusChip: TaskRowStatusChip?

    var hasDescription: Bool {
        descriptionText != nil
    }

    var hasSecondaryContent: Bool {
        descriptionText != nil || metadataText != nil
    }

    /// Executes from.
    static func from(
        task: TaskDefinition,
        showTypeBadge: Bool,
        now: Date = Date(),
        isInOverdueSection: Bool = false,
        tagNameByID: [UUID: String] = [:]
    ) -> TaskRowDisplayModel {
        let _ = showTypeBadge
        let descriptionText = smartDescription(for: task)
        let metadataText = metadataText(
            for: task,
            now: now,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID
        )
        let statusChip: TaskRowStatusChip? = dueSoonStatus(for: task, now: now)

        return TaskRowDisplayModel(
            xpValue: task.priority.scorePoints,
            descriptionText: descriptionText,
            metadataText: metadataText,
            statusChip: statusChip
        )
    }

    /// Executes dueSoonStatus.
    private static func dueSoonStatus(for task: TaskDefinition, now: Date) -> TaskRowStatusChip? {
        guard !task.isComplete, !task.isOverdue, let dueDate = task.dueDate else { return nil }
        let remaining = dueDate.timeIntervalSince(now)
        guard remaining > 0, remaining <= (2 * 60 * 60) else { return nil }
        return .dueSoon
    }

    /// Executes metadataText.
    private static func metadataText(
        for task: TaskDefinition,
        now: Date,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String]
    ) -> String? {
        var tokens: [String] = []

        if !task.isComplete, let dueDate = task.dueDate, let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
            tokens.append(lateLabel)
            if isInOverdueSection {
                if let recurrence = compactRecurrenceToken(for: task.repeatPattern) {
                    tokens.append(recurrence)
                }
                if let tagName = firstTagName(for: task, tagNameByID: tagNameByID) {
                    tokens.append(tagName)
                }
            }
            return tokens.joined(separator: " • ").nilIfEmpty
        }

        if let recurrence = compactRecurrenceToken(for: task.repeatPattern) {
            tokens.append(recurrence)
        }

        return tokens.joined(separator: " • ").nilIfEmpty
    }

    /// Executes firstTagName.
    private static func firstTagName(for task: TaskDefinition, tagNameByID: [UUID: String]) -> String? {
        guard let firstTagID = task.tagIDs.first else { return nil }
        let tagName = tagNameByID[firstTagID]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return tagName?.nilIfEmpty
    }

    /// Executes compactRecurrenceToken.
    private static func compactRecurrenceToken(for pattern: TaskRepeatPattern?) -> String? {
        guard let pattern else { return nil }
        switch pattern {
        case .daily:
            return "Daily"
        case .weekdays:
            return "Weekdays"
        case .weekly:
            return "Weekly"
        case .biweekly:
            return "Biweekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .custom(let custom):
            return "Every \(custom.intervalDays)d"
        }
    }

    /// Executes smartDescription.
    private static func smartDescription(for task: TaskDefinition) -> String? {
        guard !task.isComplete else { return nil }
        guard let description = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if normalizedForDedup(description) == normalizedForDedup(task.title) {
            return nil
        }

        let hasStrongSignal = task.isOverdue
            || task.priority.isHighPriority
            || !task.dependencies.isEmpty
            || !task.subtasks.isEmpty
        if hasStrongSignal {
            return description
        }

        return isContextRich(description) ? description : nil
    }

    /// Executes isContextRich.
    private static func isContextRich(_ text: String) -> Bool {
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        let hasLongStructuredText = wordCount >= 6 && text.count >= 24
        let hasStructure = text.rangeOfCharacter(from: CharacterSet(charactersIn: ":;,-/()")) != nil
        return hasLongStructuredText || hasStructure
    }

    /// Executes normalizedForDedup.
    private static func normalizedForDedup(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return " "
        }
        return String(stripped)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

enum TaskRowStatusChip: Equatable {
    case dueSoon

    var text: String {
        switch self {
        case .dueSoon: return "Due soon"
        }
    }
}

struct TaskRowView: View {
    let task: TaskDefinition
    let showTypeBadge: Bool
    let isInOverdueSection: Bool
    let tagNameByID: [UUID: String]
    let isTaskDragEnabled: Bool
    var onTap: (() -> Void)? = nil
    var onToggleComplete: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onReschedule: (() -> Void)? = nil
    var onTaskDragStarted: ((TaskDefinition) -> Void)? = nil

    /// Initializes a new instance.
    init(
        task: TaskDefinition,
        showTypeBadge: Bool,
        isInOverdueSection: Bool = false,
        tagNameByID: [UUID: String] = [:],
        isTaskDragEnabled: Bool,
        onTap: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onReschedule: (() -> Void)? = nil,
        onTaskDragStarted: ((TaskDefinition) -> Void)? = nil
    ) {
        self.task = task
        self.showTypeBadge = showTypeBadge
        self.isInOverdueSection = isInOverdueSection
        self.tagNameByID = tagNameByID
        self.isTaskDragEnabled = isTaskDragEnabled
        self.onTap = onTap
        self.onToggleComplete = onToggleComplete
        self.onDelete = onDelete
        self.onReschedule = onReschedule
        self.onTaskDragStarted = onTaskDragStarted
    }

    private var displayModel: TaskRowDisplayModel {
        TaskRowDisplayModel.from(
            task: task,
            showTypeBadge: showTypeBadge,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID
        )
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
            .taskCompletionTransition(isComplete: task.isComplete)
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

            HStack(alignment: .center, spacing: TaskerTheme.Spacing.xs) {
                CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                    onToggleComplete?()
                }
                .accessibilityIdentifier("home.taskCheckbox.\(task.id.uuidString)")
                .accessibilityLabel("Toggle completion for \(task.title)")
                .accessibilityHint(task.isComplete ? "Double tap to mark as open" : "Double tap to mark as completed")
                .accessibilityValue(accessibilityStateValue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .font(.tasker(.body))
                        .foregroundColor(task.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                        .lineLimit(displayModel.hasDescription ? 1 : 2)
                        .multilineTextAlignment(.leading)

                    if let descriptionText = displayModel.descriptionText {
                        Text(descriptionText)
                            .font(.tasker(.caption2))
                            .foregroundColor(task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textTertiary)
                            .lineLimit(1)
                    }

                    if let metadataText = displayModel.metadataText {
                        Text(metadataText)
                            .font(.tasker(.caption2))
                            .foregroundColor(task.isComplete ? Color.tasker.textQuaternary : Color.tasker.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if let statusChip = displayModel.statusChip {
                        statusChipView(statusChip)
                    }

                    compactXPBadge
                }
            }
            .padding(.vertical, displayModel.hasSecondaryContent ? 6 : 4)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.leading, TaskerTheme.Spacing.xs)
            .frame(minHeight: displayModel.hasDescription ? 56 : 50)
        }
        .background(rowBackground)
        .animation(TaskerAnimation.quick, value: task.isComplete)
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

    @ViewBuilder
    private var priorityStripe: some View {
        let stripe = UnevenRoundedRectangle(
            topLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomLeadingRadius: TaskerTheme.CornerRadius.md,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
        .fill(stripeFill)
        .frame(width: 4)

        if !task.isComplete && !task.isOverdue && task.priority == .max {
            stripe.breathingPulse(min: 0.75, max: 1.0)
        } else {
            stripe
        }
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

    private var accessibilityLabel: String {
        var parts: [String] = ["Task: \(task.title)"]
        if task.isComplete { parts.append("completed") }
        if let descriptionText = displayModel.descriptionText {
            parts.append(descriptionText)
        }
        if let metadataText = displayModel.metadataText {
            parts.append(metadataText)
        }
        if let statusChip = displayModel.statusChip {
            parts.append(statusChip.text.lowercased())
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

    /// Executes statusChipView.
    @ViewBuilder
    private func statusChipView(_ statusChip: TaskRowStatusChip) -> some View {
        Text(statusChip.text)
            .font(.tasker(.caption2))
            .fontWeight(.medium)
            .foregroundColor(Color.tasker.statusWarning)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.tasker.statusWarning.opacity(0.15)))
            .fixedSize()
            .transition(.scale.combined(with: .opacity))
            .animation(TaskerAnimation.bouncy, value: displayModel.statusChip)
    }

    private var compactXPBadge: some View {
        let estimate = XPCalculationEngine.completionEstimate(
            priorityRaw: task.priority.rawValue,
            estimatedDuration: task.estimatedDuration
        )
        return Text(estimate.compactLabel)
            .font(.tasker(.caption2))
            .fontWeight(task.priority == .max || task.priority == .high ? .bold : .medium)
            .foregroundColor(task.priority == .max || task.priority == .high ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(task.priority == .max || task.priority == .high ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(task.priority == .max || task.priority == .high ? Color.tasker.accentPrimary.opacity(0.3) : .clear, lineWidth: 1)
            )
            .fixedSize()
            .scaleEffect(task.isComplete ? 1.15 : 1.0)
            .animation(TaskerAnimation.bouncy, value: task.isComplete)
            .accessibilityLabel("Estimated XP \(estimate.shortLabel)")
            .accessibilityHint(
                "Estimate factors: \(XPCalculationEngine.estimateReasonHints(estimatedDuration: task.estimatedDuration, isFocusSessionActive: false, isPinnedInFocusStrip: false))"
            )
    }
}

#if DEBUG
struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 6) {
            TaskRowView(
                task: TaskDefinition(
                    title: "Review pull requests",
                    details: "Prioritize API migration and checkout fixes",
                    priority: .high,
                    type: .morning,
                    dueDate: Date()
                ),
                showTypeBadge: true,
                isTaskDragEnabled: true
            )

            TaskRowView(
                task: TaskDefinition(
                    title: "Completed task example",
                    priority: .low,
                    type: .morning,
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
