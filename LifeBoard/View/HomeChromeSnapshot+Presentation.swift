import Foundation

struct HomeHeaderMetadataItem: Equatable, Identifiable {
    enum Tone: Equatable {
        case neutral
        case accent
        case success
        case warning
    }

    let id: String
    let text: String
    let iconSystemName: String?
    let tone: Tone
}

struct HomeHeaderDayProgressModel: Equatable {
    let completedCount: Int
    let totalCount: Int
    let remainingCount: Int
    let progressFraction: Double
    let isComplete: Bool
    let accessibilityLabel: String
}

struct HomeHeaderTodayStatusModel: Equatable {
    let completionText: String
    let streakText: String
    let streakAccessibilityLabel: String

    var displayText: String {
        [completionText, streakText].joined(separator: " · ")
    }

    var accessibilityLabel: String {
        "\(completionText), \(streakAccessibilityLabel)"
    }
}

struct HomeHeaderPresentationModel: Equatable {
    let viewLabel: String
    let compactDateText: String?
    let backgroundDateText: String?
    let foregroundRelativeLabel: String?
    let dateAccessibilityLabel: String?
    let showsBackToToday: Bool
    let statusText: String?
    let todayStatus: HomeHeaderTodayStatusModel?
    let showsReflectionCTA: Bool
    let reflectionCTATitle: String
    let dayProgress: HomeHeaderDayProgressModel?
    let hasActiveFilters: Bool
}

extension HomeChromeSnapshot {
    func homeHeaderPresentation(
        tasks: HomeTasksSnapshot,
        habits: HomeHabitsSnapshot = .empty
    ) -> HomeHeaderPresentationModel {
        let datePresentation = homeHeaderDatePresentation
        let dayProgress = headerDayProgress(tasks: tasks, habits: habits)
        let todayStatus = headerTodayStatus(progress: dayProgress)
        return HomeHeaderPresentationModel(
            viewLabel: activeScope.quickView.title,
            compactDateText: datePresentation?.compactDateText,
            backgroundDateText: datePresentation?.backgroundDateText,
            foregroundRelativeLabel: datePresentation?.foregroundRelativeLabel,
            dateAccessibilityLabel: datePresentation?.dateAccessibilityLabel,
            showsBackToToday: shouldShowBackToToday,
            statusText: headerStatusText(tasks: tasks, todayStatus: todayStatus),
            todayStatus: todayStatus,
            showsReflectionCTA: shouldShowReflectionCTA,
            reflectionCTATitle: "Reflect",
            dayProgress: dayProgress,
            hasActiveFilters: homeActiveFilterCount > 0
        )
    }

    private var homeHeaderDatePresentation: HomeHeaderDatePresentation? {
        switch activeScope {
        case .today:
            return makeHomeHeaderDatePresentation(for: selectedDate)
        case .customDate(let date):
            return makeHomeHeaderDatePresentation(for: date)
        case .upcoming, .overdue, .done, .morning, .evening:
            return nil
        }
    }

    var shouldShowBackToToday: Bool {
        if case .today = activeScope {
            return false
        }
        if case .customDate(let date) = activeScope,
           Calendar.current.isDateInToday(date) {
            return false
        }
        return true
    }

    private var shouldShowReflectionCTA: Bool {
        return false
    }

    private func headerDayProgress(
        tasks: HomeTasksSnapshot,
        habits: HomeHabitsSnapshot
    ) -> HomeHeaderDayProgressModel? {
        guard case .today = activeScope else {
            return nil
        }

        let taskCounts = tasks.dueTodayTaskProgress(on: selectedDate)
        let habitCounts = habits.dueTodayHabitProgress(on: selectedDate)
        let completedCount = taskCounts.completed + habitCounts.completed
        let totalCount = taskCounts.total + habitCounts.total
        let remainingCount = max(0, totalCount - completedCount)
        let progressFraction = totalCount > 0
            ? min(1, Double(completedCount) / Double(totalCount))
            : 1

        return HomeHeaderDayProgressModel(
            completedCount: completedCount,
            totalCount: totalCount,
            remainingCount: remainingCount,
            progressFraction: progressFraction,
            isComplete: remainingCount == 0,
            accessibilityLabel: dayProgressAccessibilityLabel(
                completedCount: completedCount,
                totalCount: totalCount,
                remainingCount: remainingCount
            )
        )
    }

    private func headerStatusText(
        tasks: HomeTasksSnapshot,
        todayStatus: HomeHeaderTodayStatusModel?
    ) -> String? {
        switch activeScope {
        case .today:
            return todayStatus?.displayText
        case .customDate:
            return selectedDateStatusText(tasks: tasks)
        case .upcoming:
            return quantified(quickViewCounts[.upcoming] ?? 0, singular: "upcoming task", plural: "upcoming tasks")
        case .overdue:
            return quantified(tasks.overdueTasks.count, singular: "overdue task", plural: "overdue tasks")
        case .done:
            return quantified(tasks.doneTimelineTasks.count, singular: "completed task", plural: "completed tasks")
        case .morning:
            return quantified(tasks.morningTasks.count, singular: "morning task", plural: "morning tasks")
        case .evening:
            return quantified(tasks.eveningTasks.count, singular: "evening task", plural: "evening tasks")
        }
    }

    private func headerTodayStatus(progress: HomeHeaderDayProgressModel?) -> HomeHeaderTodayStatusModel? {
        guard case .today = activeScope else { return nil }
        guard let progress else { return nil }

        let completionText: String
        if progress.totalCount == 0 {
            completionText = "All clear"
        } else {
            let completionPercent = Int((progress.progressFraction * 100).rounded())
            completionText = "\(completionPercent)% done"
        }

        return HomeHeaderTodayStatusModel(
            completionText: completionText,
            streakText: "\(progressState.streakDays)d",
            streakAccessibilityLabel: "\(progressState.streakDays) day streak"
        )
    }

    private func dayProgressAccessibilityLabel(
        completedCount: Int,
        totalCount: Int,
        remainingCount: Int
    ) -> String {
        guard totalCount > 0 else {
            return "Today progress, nothing due today"
        }

        return "Today progress, \(completedCount) of \(totalCount) due items done, \(remainingCount) left"
    }

    private func selectedDateStatusText(tasks: HomeTasksSnapshot) -> String {
        let counts = tasks.selectedDateMixedCounts
        return [
            quantified(counts.taskCount, singular: "task", plural: "tasks"),
            quantified(counts.habitCount, singular: "habit", plural: "habits")
        ].joined(separator: " · ")
    }

    private func quantified(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    private func makeHomeHeaderDatePresentation(for date: Date) -> HomeHeaderDatePresentation {
        let calendar = Calendar.current
        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        return HomeHeaderDatePresentation(
            compactDateText: date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
            backgroundDateText: date.formatted(.dateTime.month(.wide).day()),
            foregroundRelativeLabel: relativeDateHeaderLabel(for: dayOffset),
            dateAccessibilityLabel: "\(relativeDateAccessibilityLabel(for: dayOffset)), \(date.formatted(.dateTime.month(.wide).day()))"
        )
    }

    private func relativeDateHeaderLabel(for dayOffset: Int) -> String {
        switch dayOffset {
        case ..<(-1):
            return "\(-dayOffset) DAYS AGO"
        case -1:
            return "YESTERDAY"
        case 0:
            return "TODAY"
        case 1:
            return "TOMORROW"
        default:
            return "IN \(dayOffset) DAYS"
        }
    }

    private func relativeDateAccessibilityLabel(for dayOffset: Int) -> String {
        switch dayOffset {
        case ..<(-1):
            return "\(-dayOffset) days ago"
        case -1:
            return "Yesterday"
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        default:
            return "In \(dayOffset) days"
        }
    }

    private var homeActiveFilterCount: Int {
        var count = 0
        if activeFilterState.selectedProjectIDs.isEmpty == false {
            count += 1
        }
        if let advancedFilter = activeFilterState.advancedFilter, advancedFilter.isEmpty == false {
            count += 1
        }
        if activeFilterState.showCompletedInline {
            count += 1
        }
        return count
    }
}

private struct HomeHeaderDatePresentation: Equatable {
    let compactDateText: String
    let backgroundDateText: String
    let foregroundRelativeLabel: String
    let dateAccessibilityLabel: String
}

private extension HomeTasksSnapshot {
    func dueTodayTaskProgress(on date: Date) -> (completed: Int, total: Int) {
        var tasksByID: [UUID: TaskDefinition] = [:]

        let sectionRows = todayAgendaSectionState.sections.flatMap(\.rows)
        let fallbackRows = dueTodaySection?.rows ?? []
        let taskRows = (sectionRows + fallbackRows + focusRows).compactMap { row -> TaskDefinition? in
            guard case .task(let task) = row else { return nil }
            return task
        }

        for task in morningTasks + eveningTasks + taskRows + inlineCompletedTasks {
            tasksByID[task.id] = task
        }

        let dueTodayTasks = tasksByID.values.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }

        return (
            completed: dueTodayTasks.filter(\.isComplete).count,
            total: dueTodayTasks.count
        )
    }

    var selectedDateMixedCounts: (taskCount: Int, habitCount: Int) {
        let todayRows = todayAgendaSectionState.sections.flatMap(\.rows)
        let rows = todayRows.isEmpty
            ? (dueTodaySection?.rows ?? [])
            : todayRows

        return rows.reduce(into: (taskCount: 0, habitCount: 0)) { result, row in
            switch row {
            case .task:
                result.taskCount += 1
            case .habit:
                result.habitCount += 1
            }
        }
    }
}

private extension HomeHabitsSnapshot {
    func dueTodayHabitProgress(on date: Date) -> (completed: Int, total: Int) {
        var rowsByHabitID: [UUID: HomeHabitRow] = [:]
        let rows = habitHomeSectionState.primaryRows
            + habitHomeSectionState.recoveryRows
            + quietTrackingSummaryState.stableRows

        for row in rows {
            rowsByHabitID[row.habitID] = row
        }

        let dueTodayRows = rowsByHabitID.values.filter { row in
            guard row.isHeaderDueTodayCandidate else { return false }
            guard let dueAt = row.dueAt else { return true }
            return Calendar.current.isDate(dueAt, inSameDayAs: date)
        }

        return (
            completed: dueTodayRows.filter { $0.state == .completedToday }.count,
            total: dueTodayRows.count
        )
    }
}

private extension HomeHabitRow {
    var isHeaderDueTodayCandidate: Bool {
        switch state {
        case .due, .completedToday, .lapsedToday, .skippedToday:
            return true
        case .overdue, .tracking:
            return false
        }
    }
}
