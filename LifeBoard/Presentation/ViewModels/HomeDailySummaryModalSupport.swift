//
//  HomeDailySummaryModalSupport.swift
//  LifeBoard
//
//  Move-only HomeViewModel decomposition.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

enum DailySummaryModalError: LocalizedError {
    case tasksUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .tasksUnavailable(let message):
            return message
        }
    }
}

final class GetDailySummaryModalUseCase {
    let getTasksUseCase: GetTasksUseCase
    let analyticsUseCase: CalculateAnalyticsUseCase
    let calendar: Calendar
    let now: () -> Date

    init(
        getTasksUseCase: GetTasksUseCase,
        analyticsUseCase: CalculateAnalyticsUseCase,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.getTasksUseCase = getTasksUseCase
        self.analyticsUseCase = analyticsUseCase
        self.calendar = calendar
        self.now = now
    }

    func execute(
        kind: LifeBoardDailySummaryKind,
        date: Date,
        completion: @escaping @Sendable (Result<DailySummaryModalData, Error>) -> Void
    ) {
        let group = DispatchGroup()
        let state = LockedResultAccumulator(DailySummaryLoadState())

        group.enter()
        getTasksUseCase.searchTasks(query: "", in: .all) { result in
            state.update { $0.allTasksResult = result }
            group.leave()
        }

        group.enter()
        analyticsUseCase.calculateDailyAnalytics(for: date) { result in
            if case .success(let value) = result {
                state.update { $0.analytics = value }
            }
            group.leave()
        }

        group.enter()
        analyticsUseCase.calculateStreak { result in
            if case .success(let value) = result {
                state.update { $0.streakCount = value.currentStreak }
            }
            group.leave()
        }

        group.enter()
        getTasksUseCase.getTasksForDate(date) { result in
            if case .success(let value) = result {
                state.update { $0.dateTasks = value }
            }
            group.leave()
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            let resolvedState = (try? state.result().get()) ?? DailySummaryLoadState()

            guard let resolvedTasksResult = resolvedState.allTasksResult else {
                completion(.failure(DailySummaryModalError.tasksUnavailable("Task data unavailable")))
                return
            }

            switch resolvedTasksResult {
            case .failure(let error):
                completion(.failure(DailySummaryModalError.tasksUnavailable(error.localizedDescription)))
            case .success(let allTasks):
                completion(.success(
                    self.buildSummary(
                        kind: kind,
                        date: date,
                        allTasks: allTasks,
                        analytics: resolvedState.analytics,
                        streakCount: resolvedState.streakCount,
                        dateTasks: resolvedState.dateTasks
                    )
                ))
            }
        }
    }

    func buildSummary(
        kind: LifeBoardDailySummaryKind,
        date: Date,
        allTasks: [TaskDefinition],
        analytics: DailyAnalytics?,
        streakCount: Int?,
        dateTasks: DateTasksResult? = nil
    ) -> DailySummaryModalData {
        switch kind {
        case .morning:
            return .morning(buildMorningSummary(date: date, allTasks: allTasks, dateTasks: dateTasks))
        case .nightly:
            return .nightly(
                buildNightlySummary(
                    date: date,
                    allTasks: allTasks,
                    analytics: analytics,
                    streakCount: streakCount,
                    dateTasks: dateTasks
                )
            )
        }
    }

    func buildMorningSummary(
        date: Date,
        allTasks: [TaskDefinition],
        dateTasks: DateTasksResult?
    ) -> MorningPlanSummary {
        let dayRange = dateRange(for: date)
        let openTasks = allTasks.filter { !$0.isComplete }
        let dueTodayOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }
        let overdueOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < dayRange.start
        }
        let actionable = sortByUrgency(tasks: dueTodayOpen + overdueOpen)
        let focusTasks = Array(actionable.prefix(3)).map(makeSummaryRow)
        let highPriorityCount = actionable.filter { $0.priority.isHighPriority }.count
        let potentialXP = actionable.reduce(0) { $0 + $1.priority.scorePoints }
        let blockedCount = actionable.filter { !$0.dependencies.isEmpty }.count
        let longTaskCount = actionable.filter { ($0.estimatedDuration ?? 0) >= 3600 }.count
        let morningPlannedCount: Int
        let eveningPlannedCount: Int
        if let dateTasks {
            morningPlannedCount = dateTasks.morningTasks.filter { !$0.isComplete }.count
            eveningPlannedCount = dateTasks.eveningTasks.filter { !$0.isComplete }.count
        } else {
            eveningPlannedCount = dueTodayOpen.filter(isEveningTask).count
            morningPlannedCount = max(0, dueTodayOpen.count - eveningPlannedCount)
        }

        return MorningPlanSummary(
            date: dayRange.start,
            openTodayCount: actionable.count,
            highPriorityCount: highPriorityCount,
            overdueCount: overdueOpen.count,
            potentialXP: potentialXP,
            focusTasks: focusTasks,
            blockedCount: blockedCount,
            longTaskCount: longTaskCount,
            morningPlannedCount: morningPlannedCount,
            eveningPlannedCount: eveningPlannedCount
        )
    }

    func buildNightlySummary(
        date: Date,
        allTasks: [TaskDefinition],
        analytics: DailyAnalytics?,
        streakCount: Int?,
        dateTasks: DateTasksResult?
    ) -> NightlyRetrospectiveSummary {
        let dayRange = dateRange(for: date)
        let tomorrowStart = dayRange.end
        let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart

        let completedToday = sortByUrgency(tasks: allTasks.filter { task in
            guard task.isComplete, let dateCompleted = task.dateCompleted else { return false }
            return dateCompleted >= dayRange.start && dateCompleted < dayRange.end
        })

        let openTasks = allTasks.filter { !$0.isComplete }
        let dueTodayOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }
        let overdueOpen = openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < dayRange.start
        }
        let tomorrowPreview = sortByUrgency(tasks: openTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= tomorrowStart && dueDate < tomorrowEnd
        })

        let dueTodayCount = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= dayRange.start && dueDate < dayRange.end
        }.count
        let calendarTotalCount = dateTasks.map {
            $0.morningTasks.count + $0.eveningTasks.count + $0.completedTasks.count
        } ?? 0
        let analyticsTotalCount = analytics?.totalTasks ?? 0
        let baselineTotalCount = max(dueTodayCount, max(calendarTotalCount, analyticsTotalCount))
        let totalCount = max(completedToday.count, baselineTotalCount)
        let xpEarned = completedToday.reduce(0) { $0 + $1.priority.scorePoints }
        let fallbackCompletionRate = totalCount > 0 ? Double(completedToday.count) / Double(totalCount) : 0
        let completionRate = analytics?.completionRate ?? fallbackCompletionRate
        let morningCompletedCount = analytics?.morningTasksCompleted
            ?? completedToday.filter { !$0.isEveningTask && $0.type != .evening }.count
        let eveningCompletedCount = analytics?.eveningTasksCompleted
            ?? completedToday.filter(isEveningTask).count

        return NightlyRetrospectiveSummary(
            date: dayRange.start,
            completedCount: completedToday.count,
            totalCount: totalCount,
            xpEarned: xpEarned,
            completionRate: completionRate,
            streakCount: max(0, streakCount ?? 0),
            biggestWins: Array(completedToday.prefix(3)).map(makeSummaryRow),
            carryOverDueTodayCount: dueTodayOpen.count,
            carryOverOverdueCount: overdueOpen.count,
            tomorrowPreview: Array(tomorrowPreview.prefix(3)).map(makeSummaryRow),
            morningCompletedCount: morningCompletedCount,
            eveningCompletedCount: eveningCompletedCount
        )
    }

    func makeSummaryRow(_ task: TaskDefinition) -> SummaryTaskRow {
        let startOfToday = calendar.startOfDay(for: now())
        let overdue = (task.dueDate.map { $0 < startOfToday } ?? false) && !task.isComplete
        return SummaryTaskRow(
            taskID: task.id,
            title: task.title,
            priority: task.priority,
            dueDate: task.dueDate,
            isOverdue: overdue,
            estimatedDuration: task.estimatedDuration,
            isBlocked: !task.dependencies.isEmpty,
            projectName: task.projectName
        )
    }

    func sortByUrgency(tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            if lhs.priority.scorePoints != rhs.priority.scorePoints {
                return lhs.priority.scorePoints > rhs.priority.scorePoints
            }
            let lhsDue = lhs.dueDate ?? Date.distantFuture
            let rhsDue = rhs.dueDate ?? Date.distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func dateRange(for date: Date) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    func isEveningTask(_ task: TaskDefinition) -> Bool {
        task.isEveningTask || task.type == .evening
    }
}
