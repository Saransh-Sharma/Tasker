import Foundation

public enum AddTaskPrefillDueIntent: Equatable, Sendable {
    case none
    case today
    case exact(Date)

    func resolvedDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:
            return nil
        case .today:
            return DatePreset.today.resolvedDueDate(anchorDate: now, calendar: calendar)
        case .exact(let date):
            return date
        }
    }
}

public struct AddTaskPrefillTemplate: Equatable {
    public let title: String
    public let details: String?
    public let projectID: UUID?
    public let projectName: String?
    public let lifeAreaID: UUID?
    public let priority: TaskPriority
    public let type: TaskType
    public let dueDateIntent: AddTaskPrefillDueIntent
    public let estimatedDuration: TimeInterval?
    public let energy: TaskEnergy
    public let category: TaskCategory
    public let context: TaskContext
    public let expandedSections: Set<TaskEditorSection>?
    public let showMoreDetails: Bool
    public let showAdvancedPlanning: Bool

    /// Initializes a new instance.
    public init(
        title: String,
        details: String? = nil,
        projectID: UUID? = nil,
        projectName: String? = nil,
        lifeAreaID: UUID? = nil,
        priority: TaskPriority = .low,
        type: TaskType = .morning,
        dueDateIntent: AddTaskPrefillDueIntent? = nil,
        dueDate: Date? = Date(),
        estimatedDuration: TimeInterval? = nil,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        expandedSections: Set<TaskEditorSection>? = nil,
        showMoreDetails: Bool = false,
        showAdvancedPlanning: Bool = false
    ) {
        self.title = title
        self.details = details
        self.projectID = projectID
        self.projectName = projectName
        self.lifeAreaID = lifeAreaID
        self.priority = priority
        self.type = type
        if let dueDateIntent {
            self.dueDateIntent = dueDateIntent
        } else if let dueDate {
            self.dueDateIntent = .exact(dueDate)
        } else {
            self.dueDateIntent = .none
        }
        self.estimatedDuration = estimatedDuration
        self.energy = energy
        self.category = category
        self.context = context
        self.expandedSections = expandedSections
        self.showMoreDetails = showMoreDetails
        self.showAdvancedPlanning = showAdvancedPlanning
    }

    public var dueDate: Date? {
        dueDateIntent.resolvedDate()
    }
}

extension AddTaskViewModel {
    func resolvedExpandedSections(for template: AddTaskPrefillTemplate) -> Set<TaskEditorSection> {
        var sections = template.expandedSections ?? []
        if template.showMoreDetails {
            sections.insert(.organize)
        }
        if template.showAdvancedPlanning {
            sections.formUnion([.schedule, .execution, .relationships])
        }
        sections.formUnion(derivedExpandedSections())
        return sections
    }

    private func derivedExpandedSections() -> Set<TaskEditorSection> {
        var sections = Set<TaskEditorSection>()

        if hasReminder || repeatPattern != nil || selectedType != .morning {
            sections.insert(.schedule)
        }

        if selectedProjectID != ProjectConstants.inboxProjectID
            || selectedLifeAreaID != nil
            || selectedSectionID != nil
            || selectedTagIDs.isEmpty == false {
            sections.insert(.organize)
        }

        if selectedEnergy != .medium
            || selectedCategory != .general
            || selectedContext != .anywhere
            || areDurationsDifferent(estimatedDuration, Self.defaultEstimatedDuration) {
            sections.insert(.execution)
        }

        if selectedParentTaskID != nil || selectedDependencyTaskIDs.isEmpty == false {
            sections.insert(.relationships)
        }

        return sections
    }

    func applyDefaultScheduleAsPristine(calendar: Calendar = .current) {
        let start = Self.defaultScheduledStart(now: nowProvider(), calendar: calendar)
        scheduledStartAt = start
        plannedDate = start
        estimatedDuration = Self.defaultEstimatedDuration
        pristineScheduledStartAt = start
        pristineEstimatedDuration = Self.defaultEstimatedDuration
    }

    func applyPrefillDueDate(_ date: Date?, calendar: Calendar = .current) {
        guard let date else {
            clearSchedule()
            return
        }
        if TaskScheduleNormalizer.isDateOnly(date, calendar: calendar) {
            setScheduledDate(date, calendar: calendar)
        } else {
            let start = Self.clearingSubminuteComponents(date, calendar: calendar)
            scheduledStartAt = start
            plannedDate = start
        }
    }

    public static func defaultScheduledStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.date(byAdding: .minute, value: 20, to: now) ?? now.addingTimeInterval(20 * 60)
        return clearingSubminuteComponents(start, calendar: calendar)
    }

    /// "Anytime" or "Anytime · Fri 19 Sep" for a task planned on a day without a time.
    public static func anytimeLabel(day: Date?, calendar: Calendar = .current) -> String {
        guard let day else { return "Anytime" }
        if calendar.isDateInToday(day) { return "Today · Anytime" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow · Anytime" }
        return "\(day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · Anytime"
    }

    public static func scheduleRangeLabel(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        guard let end else {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    public static func scheduleDateTimeSummary(start: Date, end: Date?) -> String {
        let dateText = DateUtils.formatDate(start)
        let rangeText = scheduleRangeLabel(start: start, end: end)
        return "\(dateText), \(rangeText)"
    }

    static func clearingSubminuteComponents(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    func areDatesDifferent(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return false
        case let (.some(lhs), .some(rhs)):
            return abs(lhs.timeIntervalSince(rhs)) >= 1
        default:
            return true
        }
    }

    func areDurationsDifferent(_ lhs: TimeInterval?, _ rhs: TimeInterval?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return false
        case let (.some(lhs), .some(rhs)):
            return abs(lhs - rhs) >= 1
        default:
            return true
        }
    }

    static func durationLabel(for duration: TimeInterval) -> String {
        let minutes = max(1, Int(duration / 60))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainder) min"
    }

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Executes resolveProjectForPrefill.
    func resolveProjectForPrefill(_ template: AddTaskPrefillTemplate) -> Project? {
        if let projectID = template.projectID,
           let project = projects.first(where: { $0.id == projectID }) {
            return project
        }

        guard let projectName = template.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
              projectName.isEmpty == false else {
            return nil
        }

        let normalizedProjectName = projectName.lowercased()
        return projects.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedProjectName
        })
    }

    func hasNonEmptyProjectName(_ template: AddTaskPrefillTemplate) -> Bool {
        guard let projectName = template.projectName else { return false }
        return projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
