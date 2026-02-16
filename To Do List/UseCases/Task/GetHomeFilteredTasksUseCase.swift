//
//  GetHomeFilteredTasksUseCase.swift
//  Tasker
//
//  Unified filtering for Home "Focus Engine" quick views + facets + advanced filters
//

import Foundation

public struct HomeFilteredTasksResult {
    public let openTasks: [Task]
    public let doneTimelineTasks: [Task]
    public let quickViewCounts: [HomeQuickView: Int]
    public let pointsPotential: Int
}

public enum GetHomeFilteredTasksError: LocalizedError {
    case repositoryError(Error)

    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Failed to load home filters: \(error.localizedDescription)"
        }
    }
}

public final class GetHomeFilteredTasksUseCase {

    private let taskRepository: TaskRepositoryProtocol

    public init(taskRepository: TaskRepositoryProtocol) {
        self.taskRepository = taskRepository
    }

    public func execute(
        state: HomeFilterState,
        scope: HomeListScope,
        completion: @escaping (Result<HomeFilteredTasksResult, GetHomeFilteredTasksError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let tasks):
                let facetedTasks = self.applyProjectAndAdvancedFacets(tasks, state: state)
                let quickCounts = self.computeQuickViewCounts(from: facetedTasks, scope: scope)
                let filtered = self.applyScope(scope, to: facetedTasks)

                let pointsPotential = filtered
                    .filter { !$0.isComplete }
                    .reduce(0) { $0 + $1.priority.scorePoints }

                let openTasks = filtered
                    .filter { !$0.isComplete }
                    .sorted(by: self.sortByPriorityThenDue)

                let doneTimelineTasks = filtered
                    .filter { $0.isComplete }
                    .sorted(by: self.sortDoneTimeline)

                completion(.success(HomeFilteredTasksResult(
                    openTasks: openTasks,
                    doneTimelineTasks: doneTimelineTasks,
                    quickViewCounts: quickCounts,
                    pointsPotential: pointsPotential
                )))

            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }

    public func execute(
        state: HomeFilterState,
        completion: @escaping (Result<HomeFilteredTasksResult, GetHomeFilteredTasksError>) -> Void
    ) {
        execute(state: state, scope: .fromQuickView(state.quickView), completion: completion)
    }

    private func computeQuickViewCounts(from tasks: [Task], scope: HomeListScope) -> [HomeQuickView: Int] {
        var counts: [HomeQuickView: Int] = [:]
        let anchorDate = scope.referenceDate

        for view in HomeQuickView.allCases {
            let filtered = applyQuickView(view, to: tasks, anchorDate: anchorDate)
            counts[view] = filtered.count
        }

        return counts
    }

    private func applyProjectAndAdvancedFacets(_ tasks: [Task], state: HomeFilterState) -> [Task] {
        let projectScoped: [Task]
        if state.selectedProjectIDs.isEmpty {
            projectScoped = tasks
        } else {
            let selectedSet = state.selectedProjectIDSet
            projectScoped = tasks.filter { selectedSet.contains($0.projectID) }
        }

        guard let advanced = state.advancedFilter, !advanced.isEmpty else {
            return projectScoped
        }

        return projectScoped.filter { task in
            if !advanced.priorities.isEmpty && !advanced.priorities.contains(task.priority) {
                return false
            }

            if !advanced.categories.isEmpty && !advanced.categories.contains(task.category) {
                return false
            }

            if !advanced.contexts.isEmpty && !advanced.contexts.contains(task.context) {
                return false
            }

            if !advanced.energyLevels.isEmpty && !advanced.energyLevels.contains(task.energy) {
                return false
            }

            if let dateRange = advanced.dateRange {
                guard let dueDate = task.dueDate else {
                    return !advanced.requireDueDate
                }

                if dueDate < dateRange.start || dueDate > dateRange.end {
                    return false
                }
            } else if advanced.requireDueDate && task.dueDate == nil {
                return false
            }

            if !advanced.tags.isEmpty {
                switch advanced.tagMatchMode {
                case .any:
                    if !advanced.tags.contains(where: { task.tags.contains($0) }) {
                        return false
                    }
                case .all:
                    if !advanced.tags.allSatisfy({ task.tags.contains($0) }) {
                        return false
                    }
                }
            }

            if let hasEstimate = advanced.hasEstimate {
                if hasEstimate && task.estimatedDuration == nil {
                    return false
                }
                if !hasEstimate && task.estimatedDuration != nil {
                    return false
                }
            }

            if let hasDependencies = advanced.hasDependencies {
                if hasDependencies && task.dependencies.isEmpty {
                    return false
                }
                if !hasDependencies && !task.dependencies.isEmpty {
                    return false
                }
            }

            return true
        }
    }

    private func applyScope(_ scope: HomeListScope, to tasks: [Task]) -> [Task] {
        switch scope {
        case .today:
            return applyQuickView(.today, to: tasks, anchorDate: Date())
        case .customDate(let date):
            return applyQuickView(.today, to: tasks, anchorDate: date)
        case .upcoming:
            return applyQuickView(.upcoming, to: tasks, anchorDate: Date())
        case .done:
            return applyQuickView(.done, to: tasks, anchorDate: Date())
        case .morning:
            return applyQuickView(.morning, to: tasks, anchorDate: Date())
        case .evening:
            return applyQuickView(.evening, to: tasks, anchorDate: Date())
        }
    }

    private func applyQuickView(_ view: HomeQuickView, to tasks: [Task], anchorDate: Date) -> [Task] {
        let calendar = Calendar.current
        let startOfAnchorDay = calendar.startOfDay(for: anchorDate)
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate
        let endOfUpcomingWindow = calendar.date(byAdding: .day, value: 14, to: startOfAnchorDay) ?? anchorDate
        let doneWindowStart = calendar.date(byAdding: .day, value: -30, to: startOfAnchorDay) ?? Date.distantPast
        let doneWindowEnd = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay) ?? anchorDate

        switch view {
        case .today:
            return tasks.filter { task in
                let dueDate = task.dueDate
                let dueOnAnchorDay = dueDate.map { $0 >= startOfAnchorDay && $0 < startOfNextDay } ?? false
                let overdue = dueDate.map { $0 < startOfAnchorDay } ?? false
                let completedOnAnchorDay: Bool
                if task.isComplete, let completionDate = task.dateCompleted {
                    completedOnAnchorDay = completionDate >= startOfAnchorDay && completionDate < startOfNextDay
                } else {
                    completedOnAnchorDay = false
                }

                guard dueOnAnchorDay || overdue || completedOnAnchorDay else { return false }
                return true
            }

        case .upcoming:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfNextDay && dueDate <= endOfUpcomingWindow
            }

        case .done:
            return tasks.filter { task in
                guard task.isComplete, let completionDate = task.dateCompleted else { return false }
                return completionDate >= doneWindowStart && completionDate < doneWindowEnd
            }

        case .morning:
            return tasks.filter { task in
                return isMorningTaskHybrid(task)
            }

        case .evening:
            return tasks.filter { task in
                return isEveningTaskHybrid(task)
            }
        }
    }

    private func isMorningTaskHybrid(_ task: Task) -> Bool {
        if task.type == .morning { return true }
        if task.type == .evening { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 4 && hour <= 11
    }

    private func isEveningTaskHybrid(_ task: Task) -> Bool {
        if task.type == .evening { return true }
        if task.type == .morning { return false }

        guard let dueDate = task.dueDate else { return false }
        let hour = Calendar.current.component(.hour, from: dueDate)
        return hour >= 17 && hour <= 23
    }

    private func sortByPriorityThenDue(lhs: Task, rhs: Task) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        return lhsDate < rhsDate
    }

    private func sortDoneTimeline(lhs: Task, rhs: Task) -> Bool {
        let calendar = Calendar.current
        let lhsDay = lhs.dateCompleted.map { calendar.startOfDay(for: $0) } ?? Date.distantPast
        let rhsDay = rhs.dateCompleted.map { calendar.startOfDay(for: $0) } ?? Date.distantPast

        if lhsDay != rhsDay {
            return lhsDay > rhsDay
        }

        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }

        let lhsCompletion = lhs.dateCompleted ?? Date.distantPast
        let rhsCompletion = rhs.dateCompleted ?? Date.distantPast
        return lhsCompletion > rhsCompletion
    }
}
