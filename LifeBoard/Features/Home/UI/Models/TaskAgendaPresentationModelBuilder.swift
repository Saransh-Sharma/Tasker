import Foundation

struct TaskAgendaPresentationModelBuilder {
    static func build(
        task: TaskDefinition,
        showTypeBadge: Bool,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String],
        now: Date = Date()
    ) -> AgendaRowPresentationModel {
        let displayModel = TaskRowDisplayModel.from(
            task: task,
            showTypeBadge: showTypeBadge,
            now: now,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID,
            metadataPolicy: TaskRowMetadataPolicy(showDueTodayTime: true, showInboxProject: false)
        )

        return AgendaRowPresentationModel(
            title: task.title,
            leadingSystemImage: task.type == .evening ? "moon.stars.fill" : "sun.max.fill",
            metadataLine: metadataLine(
                task: task,
                displayModel: displayModel,
                showTypeBadge: showTypeBadge
            ),
            secondaryLine: displayModel.descriptionText,
            primaryBadge: primaryBadge(for: task, displayModel: displayModel, now: now),
            primaryActionTitle: task.isComplete ? "Reopen" : "Done",
            secondaryActionTitle: task.isComplete ? nil : "Move"
        )
    }

    static func dueTimingText(for task: TaskDefinition, now: Date = Date()) -> String? {
        guard task.isComplete == false, let dueDate = task.dueDate else { return nil }

        if isOverdue(task, now: now) {
            return OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) ?? String(localized: "From earlier")
        }

        if Calendar.current.isDate(dueDate, inSameDayAs: now) {
            return dueDate.formatted(date: .omitted, time: .shortened)
        }

        return dueDate.formatted(date: .abbreviated, time: .shortened)
    }

    private static func metadataLine(
        task: TaskDefinition,
        displayModel: TaskRowDisplayModel,
        showTypeBadge: Bool
    ) -> String? {
        var parts: [String] = []

        if showTypeBadge {
            parts.append(task.type.displayName)
        }

        if let metadataText = displayModel.metadataText?.trimmingCharacters(in: .whitespacesAndNewlines),
           metadataText.isEmpty == false {
            parts.append(metadataText)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func primaryBadge(
        for task: TaskDefinition,
        displayModel: TaskRowDisplayModel,
        now: Date
    ) -> AgendaRowStateBadge {
        if task.isComplete {
            return AgendaRowStateBadge(text: "Done", systemImage: "checkmark.circle.fill", tone: .success)
        }

        if isOverdue(task, now: now) {
            return AgendaRowStateBadge(text: String(localized: "From earlier"), systemImage: "exclamationmark.triangle.fill", tone: .danger)
        }

        if let statusChip = displayModel.statusChip {
            return AgendaRowStateBadge(text: statusChip.text, systemImage: "clock.badge.exclamationmark", tone: .warning)
        }

        if let dueDate = task.dueDate, Calendar.current.isDate(dueDate, inSameDayAs: now) {
            return AgendaRowStateBadge(text: "Today", systemImage: "calendar", tone: .accent)
        }

        if task.dueDate != nil {
            return AgendaRowStateBadge(text: "Scheduled", systemImage: "calendar.badge.clock", tone: .neutral)
        }

        return AgendaRowStateBadge(text: "Open", systemImage: "circle.dashed", tone: .quiet)
    }

    private static func isOverdue(_ task: TaskDefinition, now: Date) -> Bool {
        guard let dueDate = task.dueDate, task.isComplete == false else { return false }
        return dueDate < Calendar.current.startOfDay(for: now)
    }
}

// MARK: - Row display model
//
// Moved from the deleted `TaskRowView.swift`: the Home agenda builder is the
// live user of this model; the row view that also drew it was dead UI.

struct TaskRowMetadataPolicy: Equatable {
    let showDueTodayTime: Bool
    let showInboxProject: Bool

    static let `default` = TaskRowMetadataPolicy(
        showDueTodayTime: true,
        showInboxProject: true
    )

    static let homeUnifiedList = TaskRowMetadataPolicy(
        showDueTodayTime: false,
        showInboxProject: false
    )
}

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
        tagNameByID: [UUID: String] = [:],
        metadataPolicy: TaskRowMetadataPolicy = .default
    ) -> TaskRowDisplayModel {
        let _ = showTypeBadge
        let descriptionText = smartDescription(for: task, now: now)
        let metadataText = metadataText(
            for: task,
            now: now,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID,
            metadataPolicy: metadataPolicy
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
        guard !task.isComplete, let dueDate = task.dueDate else { return nil }
        guard OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) == nil else { return nil }
        let remaining = dueDate.timeIntervalSince(now)
        guard remaining > 0, remaining <= (2 * 60 * 60) else { return nil }
        return .dueSoon
    }

    /// Executes metadataText.
    private static func metadataText(
        for task: TaskDefinition,
        now: Date,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String],
        metadataPolicy: TaskRowMetadataPolicy
    ) -> String? {
        var tokens: [String] = []
        let calendar = Calendar.current

        if !task.isComplete, let dueDate = task.dueDate {
            if let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
                tokens.append(lateLabel)
            } else if metadataPolicy.showDueTodayTime && calendar.isDate(dueDate, inSameDayAs: now) {
                tokens.append(dueDate.formatted(date: .omitted, time: .shortened))
            }
        }

        if let projectToken = projectToken(for: task, metadataPolicy: metadataPolicy) {
            tokens.append(projectToken)
        }

        if let recurrence = compactRecurrenceToken(for: task.repeatPattern) {
            tokens.append(recurrence)
        }

        if isInOverdueSection, let tagName = firstTagName(for: task, tagNameByID: tagNameByID) {
            tokens.append(tagName)
        }

        return tokens.joined(separator: " • ").nilIfEmpty
    }

    /// Executes projectToken.
    private static func projectToken(for task: TaskDefinition, metadataPolicy: TaskRowMetadataPolicy) -> String? {
        let trimmedProjectName = task.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        if let trimmedProjectName {
            if !metadataPolicy.showInboxProject,
               trimmedProjectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame {
                return nil
            }
            return trimmedProjectName
        }

        if metadataPolicy.showInboxProject, task.projectID == ProjectConstants.inboxProjectID {
            return ProjectConstants.inboxProjectName
        }

        return nil
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
            return String(localized: "Every \(custom.intervalDays) days")
        }
    }

    /// Executes smartDescription.
    private static func smartDescription(for task: TaskDefinition, now: Date) -> String? {
        guard !task.isComplete else { return nil }
        guard let description = task.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if normalizedForDedup(description) == normalizedForDedup(task.title) {
            return nil
        }

        let isOverdueRelativeToNow = task.dueDate.map {
            OverdueAgeFormatter.lateLabel(dueDate: $0, now: now) != nil
        } ?? false
        let hasStrongSignal = isOverdueRelativeToNow
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
