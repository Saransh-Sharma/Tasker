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

struct HomeHeaderPresentationModel: Equatable {
    let viewLabel: String
    let dateText: String
    let showsBackToToday: Bool
    let metadataItems: [HomeHeaderMetadataItem]
    let showsReflectionCTA: Bool
    let reflectionCTATitle: String
    let hasActiveFilters: Bool
}

extension HomeChromeSnapshot {
    func homeHeaderPresentation(tasks: HomeTasksSnapshot) -> HomeHeaderPresentationModel {
        HomeHeaderPresentationModel(
            viewLabel: activeScope.quickView.title,
            dateText: homeHeaderDateText,
            showsBackToToday: shouldShowBackToToday,
            metadataItems: headerMetadataItems(tasks: tasks),
            showsReflectionCTA: shouldShowReflectionCTA,
            reflectionCTATitle: "Reflection ready",
            hasActiveFilters: homeActiveFilterCount > 0
        )
    }

    var homeHeaderDateText: String {
        switch activeScope {
        case .today:
            return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .customDate(let date):
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .upcoming, .overdue, .done, .morning, .evening:
            return Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    var shouldShowBackToToday: Bool {
        if case .today = activeScope {
            return false
        }
        return true
    }

    private var shouldShowReflectionCTA: Bool {
        if case .today = activeScope {
            return reflectionEligible
        }
        return false
    }

    private func headerMetadataItems(tasks: HomeTasksSnapshot) -> [HomeHeaderMetadataItem] {
        switch activeScope {
        case .today:
            return todayMetadataItems
        case .customDate:
            return selectedDateMetadataItems(tasks: tasks)
        case .upcoming:
            return [scopedCountItem(id: "upcoming", count: quickViewCounts[.upcoming] ?? 0, noun: "upcoming task", iconSystemName: "calendar.badge.clock", tone: .accent)]
        case .overdue:
            return [scopedCountItem(id: "overdue", count: tasks.overdueTasks.count, noun: "overdue task", iconSystemName: "flame.fill", tone: .warning)]
        case .done:
            return [scopedCountItem(id: "done", count: tasks.doneTimelineTasks.count, noun: "completed task", iconSystemName: "checkmark.circle.fill", tone: .success)]
        case .morning:
            return [scopedCountItem(id: "morning", count: tasks.morningTasks.count, noun: "morning task", iconSystemName: "sunrise.fill", tone: .accent)]
        case .evening:
            return [scopedCountItem(id: "evening", count: tasks.eveningTasks.count, noun: "evening task", iconSystemName: "moon.stars.fill", tone: .accent)]
        }
    }

    private var todayMetadataItems: [HomeHeaderMetadataItem] {
        let completionPercent = Int((completionRate * 100).rounded())
        let xpText: String
        if progressState.todayTargetXP > 0 {
            xpText = "\(progressState.earnedXP)/\(progressState.todayTargetXP) XP"
        } else {
            xpText = "\(dailyScore) XP"
        }

        return [
            HomeHeaderMetadataItem(
                id: "xp",
                text: xpText,
                iconSystemName: nil,
                tone: .accent
            ),
            HomeHeaderMetadataItem(
                id: "completion",
                text: "\(completionPercent)%",
                iconSystemName: "checkmark.circle.fill",
                tone: .success
            ),
            HomeHeaderMetadataItem(
                id: "streak",
                text: "\(progressState.streakDays)d",
                iconSystemName: "flame.fill",
                tone: progressState.isStreakSafeToday ? .accent : .warning
            )
        ]
    }

    private func selectedDateMetadataItems(tasks: HomeTasksSnapshot) -> [HomeHeaderMetadataItem] {
        let counts = tasks.selectedDateMixedCounts
        return [
            HomeHeaderMetadataItem(
                id: "selected-date-tasks",
                text: quantified(counts.taskCount, singular: "task", plural: "tasks"),
                iconSystemName: "checklist",
                tone: .neutral
            ),
            HomeHeaderMetadataItem(
                id: "selected-date-habits",
                text: quantified(counts.habitCount, singular: "habit", plural: "habits"),
                iconSystemName: "repeat",
                tone: .neutral
            )
        ]
    }

    private func scopedCountItem(
        id: String,
        count: Int,
        noun: String,
        iconSystemName: String,
        tone: HomeHeaderMetadataItem.Tone
    ) -> HomeHeaderMetadataItem {
        HomeHeaderMetadataItem(
            id: id,
            text: quantified(count, singular: noun, plural: noun + "s"),
            iconSystemName: iconSystemName,
            tone: tone
        )
    }

    private func quantified(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
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

private extension HomeTasksSnapshot {
    var selectedDateMixedCounts: (taskCount: Int, habitCount: Int) {
        let rows = todaySections.flatMap(\.rows).isEmpty
            ? (dueTodaySection?.rows ?? [])
            : todaySections.flatMap(\.rows)

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
