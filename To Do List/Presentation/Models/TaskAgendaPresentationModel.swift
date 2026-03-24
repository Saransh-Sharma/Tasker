import Foundation

struct TaskAgendaPresentationModelBuilder {
    static func build(
        task: TaskDefinition,
        showTypeBadge: Bool,
        isInOverdueSection: Bool,
        tagNameByID: [UUID: String]
    ) -> AgendaRowPresentationModel {
        let displayModel = TaskRowDisplayModel.from(
            task: task,
            showTypeBadge: showTypeBadge,
            isInOverdueSection: isInOverdueSection,
            tagNameByID: tagNameByID
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
            primaryBadge: primaryBadge(for: task, displayModel: displayModel),
            primaryActionTitle: task.isComplete ? "Reopen" : "Done",
            secondaryActionTitle: task.isComplete ? nil : "Move"
        )
    }

    static func dueTimingText(for task: TaskDefinition) -> String? {
        guard task.isComplete == false, let dueDate = task.dueDate else { return nil }

        if task.isOverdue {
            return OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: Date()) ?? "Overdue"
        }

        if Calendar.current.isDateInToday(dueDate) {
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

        if let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
           projectName.isEmpty == false,
           projectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) != .orderedSame {
            parts.append(projectName)
        }

        if let metadataText = displayModel.metadataText?.trimmingCharacters(in: .whitespacesAndNewlines),
           metadataText.isEmpty == false {
            parts.append(metadataText)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func primaryBadge(
        for task: TaskDefinition,
        displayModel: TaskRowDisplayModel
    ) -> AgendaRowStateBadge {
        if task.isComplete {
            return AgendaRowStateBadge(text: "Done", systemImage: "checkmark.circle.fill", tone: .success)
        }

        if task.isOverdue {
            return AgendaRowStateBadge(text: "Overdue", systemImage: "exclamationmark.triangle.fill", tone: .danger)
        }

        if let statusChip = displayModel.statusChip {
            return AgendaRowStateBadge(text: statusChip.text, systemImage: "clock.badge.exclamationmark", tone: .warning)
        }

        if let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) {
            return AgendaRowStateBadge(text: "Today", systemImage: "calendar", tone: .accent)
        }

        if task.dueDate != nil {
            return AgendaRowStateBadge(text: "Scheduled", systemImage: "calendar.badge.clock", tone: .neutral)
        }

        return AgendaRowStateBadge(text: "Open", systemImage: "circle.dashed", tone: .quiet)
    }
}
