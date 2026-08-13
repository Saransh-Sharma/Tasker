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
            return OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) ?? "Overdue"
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
            return AgendaRowStateBadge(text: "Overdue", systemImage: "exclamationmark.triangle.fill", tone: .danger)
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
