import Foundation

extension HomeSearchViewModel {
    final class SearchComputationWorker: @unchecked Sendable {
        private let queue = DispatchQueue(label: "lifeboard.search.computation", qos: .userInitiated)
        private let lock = NSLock()
        private var latestRequest = 0

        func supersede(with request: Int) {
            lock.lock()
            latestRequest = request
            lock.unlock()
        }

        private func isCurrent(_ request: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return latestRequest == request
        }

        func prepare(_ tasks: [TaskDefinition], request: Int,
                     completion: @escaping @MainActor @Sendable ([PreparedTask]) -> Void) {
            queue.async { [self] in
                guard isCurrent(request) else { return }
                let prepared = HomeSearchViewModel.prepareTasks(tasks)
                guard isCurrent(request) else { return }
                Task { @MainActor in completion(prepared) }
            }
        }

        func compute(
            request: Int,
            preparedTasks: [PreparedTask],
            cacheKey: SearchCacheKey,
            filter: @escaping @Sendable ([PreparedTask], SearchCacheKey) -> [PreparedTask],
            group: @escaping @Sendable ([PreparedTask]) -> [(project: String, tasks: [TaskDefinition])],
            completion: @escaping @MainActor @Sendable ([PreparedTask], [(project: String, tasks: [TaskDefinition])]) -> Void
        ) {
            queue.async { [self] in
                guard isCurrent(request) else { return }
                let filteredPreparedTasks = filter(preparedTasks, cacheKey)
                let groupedResults = group(filteredPreparedTasks)
                guard isCurrent(request) else { return }
                Task { @MainActor in
                    completion(filteredPreparedTasks, groupedResults)
                }
            }
        }
    }

    nonisolated private static func prepareTasks(_ tasks: [TaskDefinition]) -> [PreparedTask] {
        tasks.map { task in
            PreparedTask(
                task: task,
                normalizedTitle: task.title.lowercased(),
                normalizedDetails: (task.details ?? "").lowercased(),
                normalizedProjectName: (task.projectName ?? ProjectConstants.inboxProjectName).lowercased(),
                mappedPriority: Int32(task.priority.rawValue)
            )
        }
    }

    nonisolated static func groupPreparedTasksByProject(_ preparedTasks: [PreparedTask]) -> [(project: String, tasks: [TaskDefinition])] {
        let grouped = Dictionary(grouping: preparedTasks) {
            $0.task.projectName ?? ProjectConstants.inboxProjectName
        }

        return grouped
            .map { key, value in
                (project: key, tasks: value.map(\.task))
            }
            .sorted { $0.project < $1.project }
    }

    /// Executes applyInMemoryFilters.
    nonisolated static func applyInMemoryFilters(
        tasks: [PreparedTask],
        cacheKey: SearchCacheKey
    ) -> [PreparedTask] {
        let normalizedQuery = cacheKey.normalizedQuery
        let normalizedProjects = Set(cacheKey.normalizedProjects)
        let priorities = Set(cacheKey.priorities)

        return tasks.filter { preparedTask in
            if normalizedQuery.isEmpty == false {
                let haystacks = [
                    preparedTask.normalizedTitle,
                    preparedTask.normalizedDetails,
                    preparedTask.normalizedProjectName
                ]
                guard haystacks.contains(where: { $0.contains(normalizedQuery) }) else {
                    return false
                }
            }

            if normalizedProjects.isEmpty == false {
                guard normalizedProjects.contains(preparedTask.normalizedProjectName) else {
                    return false
                }
            }

            if priorities.isEmpty == false {
                guard priorities.contains(preparedTask.mappedPriority) else {
                    return false
                }
            }

            return true
        }
        .sorted(by: { lhs, rhs in
            if lhs.task.isComplete != rhs.task.isComplete {
                return lhs.task.isComplete == false
            }
            switch (lhs.task.dueDate, rhs.task.dueDate) {
            case let (l?, r?):
                return l < r
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case (nil, nil):
                return lhs.task.dateAdded < rhs.task.dateAdded
            }
        })
    }
}
