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

struct HomeHeaderXPProgressModel: Equatable {
    let earnedXP: Int
    let targetXP: Int
    let progressFraction: Double
    let isStreakSafeToday: Bool
    let accessibilityLabel: String
}

struct HomeHeaderTodayStatusModel: Equatable {
    let xpText: String
    let completionText: String
    let streakText: String
    let streakAccessibilityLabel: String

    var displayText: String {
        [xpText, completionText, streakText].joined(separator: " · ")
    }

    var accessibilityLabel: String {
        "\(xpText), \(completionText), \(streakAccessibilityLabel)"
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
    let xpProgress: HomeHeaderXPProgressModel?
    let hasActiveFilters: Bool
}

extension HomeChromeSnapshot {
    func homeHeaderPresentation(tasks: HomeTasksSnapshot) -> HomeHeaderPresentationModel {
        let datePresentation = homeHeaderDatePresentation
        return HomeHeaderPresentationModel(
            viewLabel: activeScope.quickView.title,
            compactDateText: datePresentation?.compactDateText,
            backgroundDateText: datePresentation?.backgroundDateText,
            foregroundRelativeLabel: datePresentation?.foregroundRelativeLabel,
            dateAccessibilityLabel: datePresentation?.dateAccessibilityLabel,
            showsBackToToday: shouldShowBackToToday,
            statusText: headerStatusText(tasks: tasks),
            todayStatus: headerTodayStatus,
            showsReflectionCTA: shouldShowReflectionCTA,
            reflectionCTATitle: "Reflect",
            xpProgress: headerXPProgress,
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
        return true
    }

    private var shouldShowReflectionCTA: Bool {
        // Reflection stays tied to the default Today scope, not custom-date views.
        if case .today = activeScope {
            return reflectionEligible
        }
        return false
    }

    private var headerXPProgress: HomeHeaderXPProgressModel? {
        guard case .today = activeScope else {
            return nil
        }

        let targetXP = resolvedTodayTargetXP
        guard targetXP > 0 else { return nil }

        return HomeHeaderXPProgressModel(
            earnedXP: progressState.earnedXP,
            targetXP: targetXP,
            progressFraction: min(1, Double(progressState.earnedXP) / Double(max(targetXP, 1))),
            isStreakSafeToday: progressState.isStreakSafeToday,
            accessibilityLabel: "XP progress, \(progressState.earnedXP) of \(targetXP) XP"
        )
    }

    private func headerStatusText(tasks: HomeTasksSnapshot) -> String? {
        switch activeScope {
        case .today:
            return headerTodayStatus?.displayText
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

    private var headerTodayStatus: HomeHeaderTodayStatusModel? {
        guard case .today = activeScope else { return nil }

        let completionPercent = Int((completionRate * 100).rounded())
        let xpTarget = resolvedTodayTargetXP
        let xpText = xpTarget > 0
            ? "\(progressState.earnedXP)/\(xpTarget) XP"
            : "\(dailyScore) XP"

        return HomeHeaderTodayStatusModel(
            xpText: xpText,
            completionText: "\(completionPercent)%",
            streakText: "\(progressState.streakDays)d",
            streakAccessibilityLabel: "\(progressState.streakDays) day streak"
        )
    }

    private var resolvedTodayTargetXP: Int {
        if progressState.todayTargetXP > 0 {
            return progressState.todayTargetXP
        }
        if V2FeatureFlags.gamificationV2Enabled {
            return GamificationTokens.dailyXPCap
        }
        return 0
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
