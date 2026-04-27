import Foundation

enum EvaDayOverviewSectionKind: String, Codable, Equatable, Hashable {
    case overdueTasks
    case todayTasks
    case focusCandidates
    case dueHabits
    case recoveryHabits
    case quietTracking
    case emptyState
}

enum EvaDayTaskAction: String, Codable, Equatable, Hashable {
    case done
    case reopen
    case tomorrow
    case open
}

enum EvaDayHabitAction: String, Codable, Equatable, Hashable {
    case done
    case skip
    case stayedClean
    case lapsed
    case logLapse
    case open
}

struct EvaDayStatusChip: Codable, Equatable, Hashable {
    let text: String
    let tone: String
}

struct EvaDayTaskCard: Codable, Equatable, Hashable, Identifiable {
    let taskID: UUID
    let taskSnapshot: TaskDefinition
    let title: String
    let projectName: String
    let dueLabel: String?
    let priorityLabel: String?
    let durationLabel: String?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let dueDate: Date?
    let isOverdue: Bool
    let statusChips: [EvaDayStatusChip]
    let actions: [EvaDayTaskAction]

    var id: UUID { taskID }
}

struct EvaDayHabitCard: Codable, Equatable, Hashable, Identifiable {
    let habitID: UUID
    let title: String
    let kind: HabitKind
    let trackingMode: HabitTrackingMode
    let lifeAreaName: String?
    let projectName: String?
    let iconSymbolName: String?
    let accentHex: String?
    let cadence: HabitCadenceDraft?
    let cadenceLabel: String
    let dueAt: Date?
    let dueLabel: String?
    let currentStreak: Int
    let bestStreak: Int
    let riskState: HabitRiskState
    let last14Days: [HabitDayMark]
    let statusChips: [EvaDayStatusChip]
    let actions: [EvaDayHabitAction]

    var id: UUID { habitID }
}

struct EvaDayOverviewSection: Codable, Equatable, Hashable, Identifiable {
    let kind: EvaDayOverviewSectionKind
    let title: String
    let subtitle: String?
    let taskCards: [EvaDayTaskCard]
    let habitCards: [EvaDayHabitCard]
    let message: String?

    var id: String { kind.rawValue }
}

struct EvaDayOverviewPayload: Codable, Equatable {
    let prompt: String
    let summaryMarkdown: String
    let contextReceipt: EvaContextReceipt
    let isPartialContext: Bool
    let sections: [EvaDayOverviewSection]
    let generatedAt: Date
}

typealias EvaDayTaskActionHandler = (
    _ action: EvaDayTaskAction,
    _ card: EvaDayTaskCard,
    _ completion: @escaping (Result<Void, Error>) -> Void
) -> Void

typealias EvaDayHabitActionHandler = (
    _ action: EvaDayHabitAction,
    _ card: EvaDayHabitCard,
    _ completion: @escaping (Result<Void, Error>) -> Void
) -> Void

enum EvaDayOverviewBuilder {
    struct Output: Equatable {
        let payload: EvaDayOverviewPayload
        let summary: String
    }

    static func build(
        prompt: String,
        contextPayload: String,
        contextReceipt: EvaContextReceipt,
        generatedAt: Date = Date()
    ) -> Output {
        let envelope = ParsedContextEnvelope.parse(from: contextPayload)
        let promptIntent = PromptIntent(prompt: prompt)
        let overdueTasks = buildTaskCards(
            from: envelope.overdueTasks.filter { $0.isCompleted == false },
            defaultActions: [.done, .tomorrow, .open],
            generatedAt: generatedAt
        )
        let todayTasks = buildTaskCards(
            from: envelope.todayTasks.filter { $0.isCompleted == false && $0.isOverdue(referenceDate: generatedAt) == false },
            defaultActions: [.done, .tomorrow, .open],
            generatedAt: generatedAt
        )

        let focusCards: [EvaDayTaskCard]
        if promptIntent.isFocusPrompt {
            let focusSource = prioritizeFocusCards(
                overdue: overdueTasks,
                today: todayTasks,
                upcoming: buildTaskCards(
                    from: envelope.upcomingTasks.filter { $0.isCompleted == false },
                    defaultActions: [.done, .tomorrow, .open],
                    generatedAt: generatedAt
                )
            )
            focusCards = Array(focusSource.prefix(3))
        } else {
            focusCards = []
        }

        let activeHabits = coalesceHabits(envelope.habits, referenceDate: generatedAt)
        let dueHabits = buildHabitCards(
            from: activeHabits.filter {
                !$0.isRecoveryHabit && !$0.isQuietTracking
            },
            referenceDate: generatedAt
        )
        let recoveryHabits = buildHabitCards(
            from: activeHabits.filter(\.isRecoveryHabit),
            referenceDate: generatedAt
        )
        let quietTracking = buildHabitCards(
            from: activeHabits.filter(\.isQuietTracking),
            referenceDate: generatedAt
        )

        var sections: [EvaDayOverviewSection] = []
        if overdueTasks.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .overdueTasks,
                    title: "Overdue tasks",
                    subtitle: "\(overdueTasks.count) need attention first",
                    taskCards: overdueTasks,
                    habitCards: [],
                    message: nil
                )
            )
        }
        if todayTasks.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .todayTasks,
                    title: "Today’s tasks",
                    subtitle: "\(todayTasks.count) open for today",
                    taskCards: todayTasks,
                    habitCards: [],
                    message: nil
                )
            )
        }
        if focusCards.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .focusCandidates,
                    title: "Best focus next",
                    subtitle: "Highest-leverage work from the current context",
                    taskCards: focusCards,
                    habitCards: [],
                    message: nil
                )
            )
        }
        if dueHabits.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .dueHabits,
                    title: "Habit streaks",
                    subtitle: "\(dueHabits.count) active habit\(dueHabits.count == 1 ? "" : "s")",
                    taskCards: [],
                    habitCards: dueHabits,
                    message: nil
                )
            )
        }
        if recoveryHabits.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .recoveryHabits,
                    title: "Recovery habits",
                    subtitle: "\(recoveryHabits.count) need a reset or rescue",
                    taskCards: [],
                    habitCards: recoveryHabits,
                    message: nil
                )
            )
        }
        if quietTracking.isEmpty == false {
            sections.append(
                EvaDayOverviewSection(
                    kind: .quietTracking,
                    title: "Quiet tracking",
                    subtitle: "\(quietTracking.count) stable habits staying out of the main queue",
                    taskCards: [],
                    habitCards: quietTracking,
                    message: nil
                )
            )
        }

        if sections.isEmpty {
            sections = [
                EvaDayOverviewSection(
                    kind: .emptyState,
                    title: "Day overview",
                    subtitle: nil,
                    taskCards: [],
                    habitCards: [],
                    message: emptyStateMessage(
                        promptIntent: promptIntent,
                        envelope: envelope
                    )
                )
            ]
        }

        let summary = buildSummary(
            promptIntent: promptIntent,
            overdueTasks: overdueTasks,
            todayTasks: todayTasks,
            focusCards: focusCards,
            dueHabits: dueHabits,
            recoveryHabits: recoveryHabits,
            isPartialContext: envelope.isPartialContext
        )
        let payload = EvaDayOverviewPayload(
            prompt: prompt,
            summaryMarkdown: summary,
            contextReceipt: contextReceipt,
            isPartialContext: envelope.isPartialContext,
            sections: sections,
            generatedAt: generatedAt
        )
        return Output(payload: payload, summary: summary)
    }

    private static func buildSummary(
        promptIntent: PromptIntent,
        overdueTasks: [EvaDayTaskCard],
        todayTasks: [EvaDayTaskCard],
        focusCards: [EvaDayTaskCard],
        dueHabits: [EvaDayHabitCard],
        recoveryHabits: [EvaDayHabitCard],
        isPartialContext: Bool
    ) -> String {
        var lines: [String] = ["### Today’s brief"]
        if overdueTasks.isEmpty && todayTasks.isEmpty && dueHabits.isEmpty && recoveryHabits.isEmpty {
            lines.append("- Your day is clear right now.")
        } else {
            if overdueTasks.isEmpty == false {
                lines.append("- \(overdueTasks.count) overdue task\(overdueTasks.count == 1 ? "" : "s") need attention.")
            }
            if todayTasks.isEmpty == false {
                lines.append("- \(todayTasks.count) open task\(todayTasks.count == 1 ? "" : "s") are queued for today.")
            }
            if let firstFocus = (focusCards.first ?? overdueTasks.first ?? todayTasks.first) {
                lines.append("- Next focus: **\(firstFocus.title)**.")
            }
            if recoveryHabits.isEmpty == false {
                lines.append("- \(recoveryHabits.count) habit\(recoveryHabits.count == 1 ? "" : "s") need recovery attention.")
            } else if dueHabits.isEmpty == false {
                lines.append("- \(dueHabits.count) active habit streak\(dueHabits.count == 1 ? "" : "s") are visible.")
            }
        }
        if isPartialContext {
            lines.append("- Context is partial, so this brief is conservative.")
        }
        if promptIntent.isFocusPrompt && focusCards.isEmpty && (overdueTasks.isEmpty == false || todayTasks.isEmpty == false) {
            lines.append("- I used the visible due work as the best current focus set.")
        }
        return lines.joined(separator: "\n")
    }

    private static func emptyStateMessage(
        promptIntent: PromptIntent,
        envelope: ParsedContextEnvelope
    ) -> String {
        if envelope.isPartialContext {
            if envelope.hasAnyTaskContext == false && envelope.hasAnyHabitContext {
                return "Task context is unavailable right now, but habit context is still loaded."
            }
            if envelope.hasAnyHabitContext == false && envelope.hasAnyTaskContext {
                return "Habit context is unavailable right now, but task context is still loaded."
            }
            return "I couldn’t load a complete day view right now, so I’m avoiding guesswork."
        }
        if promptIntent.mentionsHabits {
            return "Your day is clear right now. I didn’t find open tasks or due habits in the available context."
        }
        return "Your day is clear right now. I didn’t find open work in today’s context."
    }

    private static func prioritizeFocusCards(
        overdue: [EvaDayTaskCard],
        today: [EvaDayTaskCard],
        upcoming: [EvaDayTaskCard]
    ) -> [EvaDayTaskCard] {
        let ordered = overdue + today + upcoming
        var seen = Set<UUID>()
        return ordered.filter { seen.insert($0.taskID).inserted }
    }

    private static func buildTaskCards(
        from tasks: [ParsedTask],
        defaultActions: [EvaDayTaskAction],
        generatedAt: Date
    ) -> [EvaDayTaskCard] {
        tasks.map { task in
            var chips: [EvaDayStatusChip] = []
            if task.isOverdue(referenceDate: generatedAt) {
                chips.append(EvaDayStatusChip(text: "Overdue", tone: "danger"))
            } else if task.isDueToday(referenceDate: generatedAt) {
                chips.append(EvaDayStatusChip(text: "Today", tone: "accent"))
            }
            if let priorityLabel = task.priorityLabel, priorityLabel != "None" {
                chips.append(EvaDayStatusChip(text: priorityLabel, tone: "warning"))
            }
            return EvaDayTaskCard(
                taskID: task.taskID,
                taskSnapshot: task.makeTaskDefinition(referenceDate: generatedAt),
                title: task.title,
                projectName: task.projectName,
                dueLabel: task.dueLabel(referenceDate: generatedAt),
                priorityLabel: task.priorityLabel,
                durationLabel: task.durationLabel,
                scheduledStartAt: task.scheduledStartAt,
                scheduledEndAt: task.scheduledEndAt,
                dueDate: task.dueDate,
                isOverdue: task.isOverdue(referenceDate: generatedAt),
                statusChips: chips,
                actions: defaultActions
            )
        }
    }

    private static func buildHabitCards(from habits: [ParsedHabit], referenceDate: Date) -> [EvaDayHabitCard] {
        habits.map { habit in
            EvaDayHabitCard(
                habitID: habit.habitID,
                title: habit.title,
                kind: habit.kind,
                trackingMode: habit.trackingMode,
                lifeAreaName: habit.lifeAreaName,
                projectName: habit.projectName,
                iconSymbolName: habit.iconSymbolName,
                accentHex: habit.accentHex,
                cadence: habit.cadence,
                cadenceLabel: habit.cadenceLabel,
                dueAt: habit.dueAt,
                dueLabel: habit.dueLabel(referenceDate: referenceDate),
                currentStreak: habit.currentStreak,
                bestStreak: habit.bestStreak,
                riskState: habit.riskState,
                last14Days: habit.last14Days,
                statusChips: habit.statusChips,
                actions: habit.actions
            )
        }
    }

    private static func coalesceHabits(_ habits: [ParsedHabit], referenceDate: Date) -> [ParsedHabit] {
        let grouped = Dictionary(grouping: habits, by: \.habitID)
        return grouped.values.compactMap { group in
            guard let representative = group.sorted(by: { lhs, rhs in
                habitRepresentativeScore(lhs, referenceDate: referenceDate) > habitRepresentativeScore(rhs, referenceDate: referenceDate)
            }).first else {
                return nil
            }
            return representative.withMergedHistory(from: group)
        }
        .sorted { lhs, rhs in
            let lhsDue = lhs.dueAt ?? .distantFuture
            let rhsDue = rhs.dueAt ?? .distantFuture
            if lhs.isRecoveryHabit != rhs.isRecoveryHabit {
                return lhs.isRecoveryHabit && !rhs.isRecoveryHabit
            }
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private static func habitRepresentativeScore(_ habit: ParsedHabit, referenceDate: Date) -> Int {
        var score = 0
        if habit.isDueToday { score += 10_000 }
        if habit.isRecoveryHabit { score += 5_000 }
        if let dueAt = habit.dueAt {
            let delta = abs(Int(dueAt.timeIntervalSince(referenceDate) / 60))
            score += max(0, 2_000 - min(delta, 2_000))
            if dueAt <= referenceDate { score += 500 }
        }
        score += min(habit.last14Days.count, 14) * 10
        score += habit.currentStreak
        return score
    }
}

private extension EvaDayOverviewBuilder {
    struct PromptIntent {
        let normalized: String

        init(prompt: String) {
            normalized = prompt
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var isFocusPrompt: Bool {
            [
                "focus",
                "what should i work on",
                "what should i focus on",
                "what needs attention",
                "brief me on today",
                "walk me through today"
            ].contains { normalized.contains($0) }
        }

        var mentionsHabits: Bool {
            normalized.contains("habit") || normalized.contains("habits") || normalized.contains("routine")
        }
    }

    struct ParsedContextEnvelope {
        let todayTasks: [ParsedTask]
        let overdueTasks: [ParsedTask]
        let upcomingTasks: [ParsedTask]
        let habits: [ParsedHabit]
        let isPartialContext: Bool
        let hasAnyTaskContext: Bool
        let hasAnyHabitContext: Bool

        static func parse(from payload: String) -> ParsedContextEnvelope {
            guard
                let start = payload.firstIndex(of: "{"),
                let end = payload.lastIndex(of: "}"),
                start <= end,
                let dictionary = ContextJSON.decodeDictionary(from: String(payload[start...end]))
            else {
                return ParsedContextEnvelope(
                    todayTasks: [],
                    overdueTasks: [],
                    upcomingTasks: [],
                    habits: [],
                    isPartialContext: true,
                    hasAnyTaskContext: false,
                    hasAnyHabitContext: false
                )
            }

            let today = (dictionary["today"] as? [String: Any]) ?? [:]
            let overdue = (dictionary["overdue"] as? [String: Any]) ?? [:]
            let upcoming = (dictionary["upcoming"] as? [String: Any]) ?? [:]
            let habitsRoot = (dictionary["habits"] as? [String: Any]) ?? today
            let metadata = (dictionary["metadata"] as? [String: Any]) ?? [:]
            let partialFlags = (dictionary["partial_flags"] as? [String: Any]) ?? [:]
            let partial = (metadata["context_partial"] as? Bool) ?? (partialFlags["context_partial"] as? Bool) ?? false

            let todayTasks = ParsedTask.list(from: today)
            let overdueTasks = ParsedTask.list(from: overdue)
            let upcomingTasks = ParsedTask.list(from: upcoming)
            let habits = ParsedHabit.list(from: habitsRoot)

            return ParsedContextEnvelope(
                todayTasks: todayTasks,
                overdueTasks: overdueTasks,
                upcomingTasks: upcomingTasks,
                habits: habits,
                isPartialContext: partial,
                hasAnyTaskContext: today.isEmpty == false || overdue.isEmpty == false || upcoming.isEmpty == false,
                hasAnyHabitContext: ParsedHabit.hasPayload(in: habitsRoot)
            )
        }
    }

    struct ParsedTask {
        let taskID: UUID
        let title: String
        let projectID: UUID
        let projectName: String
        let dueDate: Date?
        let priorityRawValue: Int?
        let estimatedDurationMinutes: Int?
        let isCompleted: Bool
        let scheduledStartAt: Date?
        let scheduledEndAt: Date?

        static func list(from dictionary: [String: Any]) -> [ParsedTask] {
            guard let tasks = dictionary["tasks"] as? [[String: Any]] else { return [] }
            return tasks.compactMap(ParsedTask.init(dictionary:))
        }

        init?(dictionary: [String: Any]) {
            guard
                let idRaw = dictionary["id"] as? String,
                let taskID = UUID(uuidString: idRaw),
                let title = dictionary["title"] as? String
            else {
                return nil
            }
            self.taskID = taskID
            self.title = title
            if let projectIDRaw = dictionary["project_id"] as? String,
               let projectID = UUID(uuidString: projectIDRaw) {
                self.projectID = projectID
            } else {
                self.projectID = ProjectConstants.inboxProjectID
            }
            self.projectName = (dictionary["project"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Inbox"
            self.dueDate = Self.date(from: dictionary["due_date"])
            self.priorityRawValue = (dictionary["priority"] as? NSNumber)?.intValue
                ?? dictionary["priority"] as? Int
            self.estimatedDurationMinutes = (dictionary["estimated_duration_minutes"] as? NSNumber)?.intValue
                ?? dictionary["estimated_duration_minutes"] as? Int
            self.isCompleted = (dictionary["is_completed"] as? Bool) ?? false
            self.scheduledStartAt = Self.date(from: dictionary["scheduled_start_at"])
            self.scheduledEndAt = Self.date(from: dictionary["scheduled_end_at"])
        }

        static func date(from value: Any?) -> Date? {
            guard let value = value as? String else { return nil }
            return ISO8601DateFormatter().date(from: value)
        }

        func isOverdue(referenceDate: Date) -> Bool {
            guard let dueDate else { return false }
            return dueDate < Calendar.current.startOfDay(for: referenceDate)
        }

        func isDueToday(referenceDate: Date) -> Bool {
            guard let dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: referenceDate)
        }

        func dueLabel(referenceDate: Date) -> String? {
            guard let dueDate else { return nil }
            if isOverdue(referenceDate: referenceDate) {
                return OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: referenceDate) ?? "Overdue"
            }
            if Calendar.current.isDate(dueDate, inSameDayAs: referenceDate) {
                return dueDate.formatted(date: .omitted, time: .shortened)
            }
            return dueDate.formatted(date: .abbreviated, time: .shortened)
        }

        var durationLabel: String? {
            guard let estimatedDurationMinutes, estimatedDurationMinutes > 0 else { return nil }
            return "\(estimatedDurationMinutes) min"
        }

        var priorityLabel: String? {
            guard let priorityRawValue else { return nil }
            switch priorityRawValue {
            case 3: return "Max"
            case 2: return "High"
            case 1: return "Low"
            default: return "None"
            }
        }

        func makeTaskDefinition(referenceDate: Date) -> TaskDefinition {
            let task = TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: projectName,
                title: title,
                priority: priority(from: priorityRawValue),
                dueDate: dueDate,
                scheduledStartAt: scheduledStartAt,
                scheduledEndAt: scheduledEndAt,
                isComplete: isCompleted,
                estimatedDuration: estimatedDurationMinutes.map { TimeInterval($0 * 60) },
                updatedAt: referenceDate
            )
            return task
        }

        private func priority(from rawValue: Int?) -> TaskPriority {
            switch rawValue {
            case 3: return .max
            case 2: return .high
            case 1: return .low
            default: return .none
            }
        }
    }

    struct ParsedHabit {
        let habitID: UUID
        let title: String
        let kind: HabitKind
        let trackingMode: HabitTrackingMode
        let lifeAreaName: String?
        let projectName: String?
        let iconSymbolName: String?
        let accentHex: String?
        let cadence: HabitCadenceDraft
        let dueAt: Date?
        let isDueToday: Bool
        let isOverdue: Bool
        let currentStreak: Int
        let bestStreak: Int
        let riskState: HabitRiskState
        let outcomeRaw: String?
        let last14Days: [HabitDayMark]

        static func hasPayload(in dictionary: [String: Any]) -> Bool {
            guard let habits = dictionary["habits"] as? [[String: Any]] else { return false }
            return habits.isEmpty == false
        }

        static func list(from dictionary: [String: Any]) -> [ParsedHabit] {
            guard let habits = dictionary["habits"] as? [[String: Any]] else { return [] }
            return habits.compactMap(ParsedHabit.init(dictionary:))
        }

        init?(dictionary: [String: Any]) {
            guard
                let idRaw = dictionary["id"] as? String,
                let habitID = UUID(uuidString: idRaw),
                let title = dictionary["title"] as? String
            else {
                return nil
            }
            self.habitID = habitID
            self.title = title
            self.kind = ((dictionary["is_positive"] as? Bool) ?? true) ? .positive : .negative
            let trackingModeRaw = dictionary["tracking_mode"] as? String
            self.trackingMode = HabitTrackingMode(rawValue: trackingModeRaw ?? "") ?? .dailyCheckIn
            self.lifeAreaName = dictionary["life_area"] as? String
            self.projectName = dictionary["project"] as? String
            self.iconSymbolName = dictionary["icon_symbol"] as? String
            self.accentHex = dictionary["color_hex"] as? String
            self.cadence = Self.cadence(from: dictionary["cadence"]) ?? .daily()
            self.dueAt = ParsedTask.date(from: dictionary["due_at"])
            self.isDueToday = (dictionary["is_due_today"] as? Bool) ?? false
            self.isOverdue = (dictionary["is_overdue"] as? Bool) ?? false
            self.currentStreak = (dictionary["current_streak"] as? NSNumber)?.intValue ?? 0
            self.bestStreak = (dictionary["best_streak"] as? NSNumber)?.intValue ?? 0
            self.riskState = HabitRiskState(rawValue: (dictionary["risk_state"] as? String) ?? "") ?? .stable
            self.outcomeRaw = dictionary["outcome"] as? String
            self.last14Days = Self.last14Days(from: dictionary["last_14_days"])
        }

        private init(
            habitID: UUID,
            title: String,
            kind: HabitKind,
            trackingMode: HabitTrackingMode,
            lifeAreaName: String?,
            projectName: String?,
            iconSymbolName: String?,
            accentHex: String?,
            cadence: HabitCadenceDraft,
            dueAt: Date?,
            isDueToday: Bool,
            isOverdue: Bool,
            currentStreak: Int,
            bestStreak: Int,
            riskState: HabitRiskState,
            outcomeRaw: String?,
            last14Days: [HabitDayMark]
        ) {
            self.habitID = habitID
            self.title = title
            self.kind = kind
            self.trackingMode = trackingMode
            self.lifeAreaName = lifeAreaName
            self.projectName = projectName
            self.iconSymbolName = iconSymbolName
            self.accentHex = accentHex
            self.cadence = cadence
            self.dueAt = dueAt
            self.isDueToday = isDueToday
            self.isOverdue = isOverdue
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.riskState = riskState
            self.outcomeRaw = outcomeRaw
            self.last14Days = last14Days
        }

        func withMergedHistory(from habits: [ParsedHabit]) -> ParsedHabit {
            let mergedHistory = Self.mergeHistory(habits.flatMap(\.last14Days))
            return ParsedHabit(
                habitID: habitID,
                title: title,
                kind: kind,
                trackingMode: trackingMode,
                lifeAreaName: lifeAreaName,
                projectName: projectName,
                iconSymbolName: iconSymbolName,
                accentHex: accentHex,
                cadence: cadence,
                dueAt: dueAt,
                isDueToday: isDueToday,
                isOverdue: isOverdue,
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                riskState: riskState,
                outcomeRaw: outcomeRaw,
                last14Days: mergedHistory.isEmpty ? last14Days : mergedHistory
            )
        }

        func dueLabel(referenceDate: Date) -> String? {
            guard let dueAt else { return nil }
            if isOverdue { return "Overdue" }
            if Calendar.current.isDate(dueAt, inSameDayAs: referenceDate) {
                return dueAt.formatted(date: .omitted, time: .shortened)
            }
            return dueAt.formatted(date: .abbreviated, time: .shortened)
        }

        var cadenceLabel: String {
            HabitBoardPresentationBuilder.cadenceLabel(for: cadence)
        }

        var isRecoveryHabit: Bool {
            isOverdue || riskState != .stable || outcomeRaw == "lapsed" || outcomeRaw == "missed"
        }

        var isQuietTracking: Bool {
            trackingMode == .lapseOnly && isRecoveryHabit == false
        }

        var statusChips: [EvaDayStatusChip] {
            var chips: [EvaDayStatusChip] = []
            if isOverdue {
                chips.append(EvaDayStatusChip(text: "Overdue", tone: "danger"))
            } else if isDueToday {
                chips.append(EvaDayStatusChip(text: "Due today", tone: "accent"))
            }
            if riskState != .stable {
                chips.append(EvaDayStatusChip(text: riskState == .broken ? "Broken" : "At risk", tone: "warning"))
            }
            return chips
        }

        var actions: [EvaDayHabitAction] {
            switch (kind, trackingMode) {
            case (.positive, _):
                return [.done, .skip, .open]
            case (.negative, .dailyCheckIn):
                return [.stayedClean, .lapsed, .open]
            case (.negative, .lapseOnly):
                return [.logLapse, .open]
            }
        }

        private static func last14Days(from value: Any?) -> [HabitDayMark] {
            guard let rows = value as? [[String: Any]] else { return [] }
            return rows.compactMap { row in
                guard
                    let date = ParsedTask.date(from: row["date"]),
                    let stateRaw = row["state"] as? String
                else { return nil }
                return HabitDayMark(date: date, state: habitDayState(from: stateRaw))
            }
        }

        private static func mergeHistory(_ marks: [HabitDayMark]) -> [HabitDayMark] {
            let calendar = Calendar.current
            var byDay: [Date: HabitDayMark] = [:]
            for mark in marks {
                let day = calendar.startOfDay(for: mark.date)
                if let existing = byDay[day] {
                    byDay[day] = preferredMark(existing, mark)
                } else {
                    byDay[day] = HabitDayMark(date: day, state: mark.state)
                }
            }
            return Array(byDay.values.sorted { $0.date < $1.date }.suffix(14))
        }

        private static func preferredMark(_ lhs: HabitDayMark, _ rhs: HabitDayMark) -> HabitDayMark {
            rank(rhs.state) > rank(lhs.state) ? rhs : lhs
        }

        private static func rank(_ state: HabitDayState) -> Int {
            switch state {
            case .success: return 5
            case .failure: return 4
            case .skipped: return 3
            case .none: return 2
            case .future: return 1
            }
        }

        private static func cadence(from value: Any?) -> HabitCadenceDraft? {
            guard let dictionary = value as? [String: Any] else { return nil }
            let ruleType = dictionary["rule_type"] as? String
            let hour = (dictionary["hour"] as? NSNumber)?.intValue ?? dictionary["hour"] as? Int
            let minute = (dictionary["minute"] as? NSNumber)?.intValue ?? dictionary["minute"] as? Int
            switch ruleType {
            case "weekly":
                let days = (dictionary["days_of_week"] as? [NSNumber])?.map(\.intValue)
                    ?? dictionary["days_of_week"] as? [Int]
                    ?? []
                return .weekly(daysOfWeek: days, hour: hour, minute: minute)
            case "daily":
                return .daily(hour: hour, minute: minute)
            default:
                return nil
            }
        }

        private static func habitDayState(from raw: String) -> HabitDayState {
            switch raw {
            case "success": return .success
            case "failure": return .failure
            case "skipped": return .skipped
            case "future": return .future
            default: return .none
            }
        }
    }

    enum ContextJSON {
        static func decodeDictionary(from raw: String) -> [String: Any]? {
            guard let data = raw.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data, options: []),
                  let dictionary = object as? [String: Any] else {
                return nil
            }
            return dictionary
        }
    }
}
