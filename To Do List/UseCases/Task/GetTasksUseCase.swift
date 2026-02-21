//
//  GetTasksUseCase.swift
//  Tasker
//
//  Use case for retrieving tasks with various filters and sorting
//

import Foundation

/// Use case for retrieving tasks with complex filtering
/// Handles all task query operations with business logic
public final class GetTasksUseCase {

    // MARK: - Dependencies

    private let readModelRepository: TaskReadModelRepositoryProtocol?
    private let cacheService: CacheServiceProtocol?

    // MARK: - Initialization

    /// Initializes a new instance.
    public init(
        readModelRepository: TaskReadModelRepositoryProtocol? = nil,
        cacheService: CacheServiceProtocol? = nil
    ) {
        self.readModelRepository = readModelRepository
        self.cacheService = cacheService
    }

    // MARK: - Task Retrieval Methods

    /// Get tasks for today's schedule
    public func getTodayTasks(completion: @escaping (Result<TodayTasksResult, GetTasksError>) -> Void) {
        if let cached = cacheService?.getCachedTasks(forDate: Date()) {
            completion(.success(categorizeTodayTasks(cached)))
            return
        }

        fetchReadSlice(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasks):
                self?.cacheService?.cacheTasks(tasks, forDate: Date())
                completion(.success(self?.categorizeTodayTasks(tasks) ?? TodayTasksResult()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get tasks for a specific date
    public func getTasksForDate(
        _ date: Date,
        completion: @escaping (Result<DateTasksResult, GetTasksError>) -> Void
    ) {
        if Calendar.current.isDateInToday(date) {
            getTodayTasks { result in
                switch result {
                case .success(let todayResult):
                    completion(.success(DateTasksResult(
                        date: date,
                        morningTasks: todayResult.morningTasks,
                        eveningTasks: todayResult.eveningTasks,
                        overdueTasks: todayResult.overdueTasks,
                        completedTasks: todayResult.completedTasks,
                        totalCount: todayResult.totalCount
                    )))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        fetchReadSlice(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateEnd: endOfDay,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasks):
                completion(.success(self?.categorizeTasksForDate(tasks, date: date) ?? DateTasksResult(date: date)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get tasks for a specific project
    public func getTasksForProject(
        _ projectID: UUID,
        includeCompleted: Bool = true,
        completion: @escaping (Result<ProjectTasksResult, GetTasksError>) -> Void
    ) {
        if let cached = cacheService?.getCachedTasks(forProjectID: projectID) {
            let filtered = includeCompleted ? cached : cached.filter { !$0.isComplete }
            completion(.success(ProjectTasksResult(
                projectID: projectID,
                tasks: filtered,
                openCount: cached.filter { !$0.isComplete }.count,
                completedCount: cached.filter { $0.isComplete }.count
            )))
            return
        }

        fetchReadSlice(
            query: TaskReadQuery(
                projectID: projectID,
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { [weak self] sliceResult in
            switch sliceResult {
            case .success(let definitions):
                self?.cacheService?.cacheTasks(definitions, forProjectID: projectID)
                let filtered = includeCompleted ? definitions : definitions.filter { !$0.isComplete }
                completion(.success(ProjectTasksResult(
                    projectID: projectID,
                    tasks: filtered,
                    openCount: definitions.filter { !$0.isComplete }.count,
                    completedCount: definitions.filter { $0.isComplete }.count
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get overdue tasks
    public func getOverdueTasks(completion: @escaping (Result<[TaskDefinition], GetTasksError>) -> Void) {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        fetchReadSlice(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateEnd: startOfToday,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            switch result {
            case .success(let tasks):
                let overdue = tasks
                    .filter { !$0.isComplete && ($0.dueDate.map { $0 < startOfToday } ?? false) }
                    .sorted(by: self.sortByPriorityThenDue)
                completion(.success(overdue))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get upcoming tasks (future tasks beyond today)
    public func getUpcomingTasks(completion: @escaping (Result<UpcomingTasksResult, GetTasksError>) -> Void) {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()

        fetchReadSlice(
            query: TaskReadQuery(
                includeCompleted: false,
                dueDateStart: startOfTomorrow,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasks):
                completion(.success(self?.categorizeUpcomingTasks(tasks) ?? UpcomingTasksResult(thisWeek: [], nextWeek: [], thisMonth: [], later: [])))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Get tasks by type (morning, evening, upcoming)
    public func getTasksByType(
        _ type: TaskType,
        for date: Date? = nil,
        completion: @escaping (Result<[TaskDefinition], GetTasksError>) -> Void
    ) {
        if let date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

            fetchReadSlice(
                query: TaskReadQuery(
                    includeCompleted: true,
                    dueDateStart: startOfDay,
                    dueDateEnd: endOfDay,
                    sortBy: .dueDateAscending,
                    limit: 5_000,
                    offset: 0
                )
            ) { result in
                switch result {
                case .success(let tasks):
                    completion(.success(tasks.filter { $0.type == type }))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }

        fetchReadSlice(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            switch result {
            case .success(let tasks):
                completion(.success(tasks.filter { $0.type == type }))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Search tasks by title or details
    public func searchTasks(
        query: String,
        in scope: GetTasksScope = .all,
        completion: @escaping (Result<[TaskDefinition], GetTasksError>) -> Void
    ) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        switch scope {
        case .all:
            if trimmed.isEmpty {
                fetchReadSlice(
                    query: TaskReadQuery(
                        includeCompleted: true,
                        sortBy: .dueDateAscending,
                        limit: 5_000,
                        offset: 0
                    ),
                    completion: completion
                )
            } else {
                searchReadSlice(
                    query: TaskSearchQuery(
                        text: trimmed,
                        includeCompleted: true,
                        limit: 5_000,
                        offset: 0
                    ),
                    completion: completion
                )
            }

        case .today:
            getTodayTasks { result in
                switch result {
                case .success(let today):
                    let allTasks = today.morningTasks + today.eveningTasks + today.overdueTasks + today.completedTasks
                    completion(.success(self.applySearchFilter(query: trimmed, in: allTasks)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }

        case .upcoming:
            getUpcomingTasks { result in
                switch result {
                case .success(let upcoming):
                    let allTasks = upcoming.thisWeek + upcoming.nextWeek + upcoming.thisMonth + upcoming.later
                    completion(.success(self.applySearchFilter(query: trimmed, in: allTasks)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }

        case .project(let projectID):
            if trimmed.isEmpty {
                fetchReadSlice(
                    query: TaskReadQuery(
                        projectID: projectID,
                        includeCompleted: true,
                        sortBy: .dueDateAscending,
                        limit: 5_000,
                        offset: 0
                    ),
                    completion: completion
                )
            } else {
                searchReadSlice(
                    query: TaskSearchQuery(
                        text: trimmed,
                        projectID: projectID,
                        includeCompleted: true,
                        limit: 5_000,
                        offset: 0
                    ),
                    completion: completion
                )
            }
        }
    }

    // MARK: - Private Helpers

    /// Executes fetchReadSlice.
    private func fetchReadSlice(
        query: TaskReadQuery,
        completion: @escaping (Result<[TaskDefinition], GetTasksError>) -> Void
    ) {
        guard let readModelRepository else {
            completion(.failure(.repositoryError(NSError(
                domain: "GetTasksUseCase",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Task read-model repository is not configured"]
            ))))
            return
        }

        readModelRepository.fetchTasks(query: query) { result in
            completion(result.map(\.tasks).mapError { GetTasksError.repositoryError($0) })
        }
    }

    /// Executes searchReadSlice.
    private func searchReadSlice(
        query: TaskSearchQuery,
        completion: @escaping (Result<[TaskDefinition], GetTasksError>) -> Void
    ) {
        guard let readModelRepository else {
            completion(.failure(.repositoryError(NSError(
                domain: "GetTasksUseCase",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Task read-model repository is not configured"]
            ))))
            return
        }

        readModelRepository.searchTasks(query: query) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            case .success(let slice):
                var tasks = slice.tasks
                if V2FeatureFlags.assistantSemanticRetrievalEnabled,
                   query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    tasks = self.applySemanticRerank(to: tasks, query: query.text)
                }
                completion(.success(tasks))
            }
        }
    }

    /// Executes applySemanticRerank.
    private func applySemanticRerank(to tasks: [TaskDefinition], query: String) -> [TaskDefinition] {
        guard tasks.isEmpty == false else { return [] }
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let rerankedIDs = TaskSemanticRetrievalService.shared.rerank(taskIDs: tasks.map(\.id), query: query)
        var reranked: [TaskDefinition] = rerankedIDs.compactMap { taskByID[$0] }
        if reranked.count < tasks.count {
            let included = Set(reranked.map(\.id))
            reranked.append(contentsOf: tasks.filter { !included.contains($0.id) })
        }
        return reranked
    }

    /// Executes applySearchFilter.
    private func applySearchFilter(query: String, in tasks: [TaskDefinition]) -> [TaskDefinition] {
        guard !query.isEmpty else { return tasks }
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query) ||
                (task.details?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Executes categorizeTodayTasks.
    private func categorizeTodayTasks(_ tasks: [TaskDefinition]) -> TodayTasksResult {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        var morningTasks: [TaskDefinition] = []
        var eveningTasks: [TaskDefinition] = []
        var overdueTasks: [TaskDefinition] = []
        var completedTasks: [TaskDefinition] = []

        for task in tasks {
            if task.isComplete {
                completedTasks.append(task)
            } else if let dueDate = task.dueDate, dueDate < startOfDay {
                overdueTasks.append(task)
            } else if task.type == .morning {
                morningTasks.append(task)
            } else if task.type == .evening {
                eveningTasks.append(task)
            }
        }

        return TodayTasksResult(
            morningTasks: morningTasks.sorted(by: sortByPriorityThenDue),
            eveningTasks: eveningTasks.sorted(by: sortByPriorityThenDue),
            overdueTasks: overdueTasks.sorted(by: sortByPriorityThenDue),
            completedTasks: completedTasks.sorted { ($0.dateCompleted ?? .distantPast) > ($1.dateCompleted ?? .distantPast) },
            totalCount: tasks.count
        )
    }

    /// Executes categorizeTasksForDate.
    private func categorizeTasksForDate(_ tasks: [TaskDefinition], date: Date) -> DateTasksResult {
        var morningTasks: [TaskDefinition] = []
        var eveningTasks: [TaskDefinition] = []
        var overdueTasks: [TaskDefinition] = []
        var completedTasks: [TaskDefinition] = []

        let startOfDate = Calendar.current.startOfDay(for: date)

        for task in tasks {
            if task.isComplete {
                completedTasks.append(task)
            } else if let dueDate = task.dueDate, dueDate < startOfDate {
                overdueTasks.append(task)
            } else if task.type == .morning {
                morningTasks.append(task)
            } else if task.type == .evening {
                eveningTasks.append(task)
            }
        }

        return DateTasksResult(
            date: date,
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            completedTasks: completedTasks,
            totalCount: tasks.count
        )
    }

    /// Executes categorizeUpcomingTasks.
    private func categorizeUpcomingTasks(_ tasks: [TaskDefinition]) -> UpcomingTasksResult {
        var thisWeek: [TaskDefinition] = []
        var nextWeek: [TaskDefinition] = []
        var thisMonth: [TaskDefinition] = []
        var later: [TaskDefinition] = []

        let calendar = Calendar.current
        let now = Date()

        guard let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end,
              let endOfNextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: endOfWeek),
              let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end else {
            return UpcomingTasksResult(thisWeek: tasks, nextWeek: [], thisMonth: [], later: [])
        }

        for task in tasks {
            guard let dueDate = task.dueDate else { continue }

            if dueDate <= endOfWeek {
                thisWeek.append(task)
            } else if dueDate <= endOfNextWeek {
                nextWeek.append(task)
            } else if dueDate <= endOfMonth {
                thisMonth.append(task)
            } else {
                later.append(task)
            }
        }

        return UpcomingTasksResult(
            thisWeek: thisWeek,
            nextWeek: nextWeek,
            thisMonth: thisMonth,
            later: later
        )
    }

    /// Executes sortByPriorityThenDue.
    private func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.rawValue != rhs.priority.rawValue {
            return lhs.priority.rawValue < rhs.priority.rawValue
        }
        return (lhs.dueDate ?? Date()) < (rhs.dueDate ?? Date())
    }
}

// MARK: - Result Models

public struct TodayTasksResult {
    public let morningTasks: [TaskDefinition]
    public let eveningTasks: [TaskDefinition]
    public let overdueTasks: [TaskDefinition]
    public let completedTasks: [TaskDefinition]
    public let totalCount: Int

    /// Initializes a new instance.
    init(
        morningTasks: [TaskDefinition] = [],
        eveningTasks: [TaskDefinition] = [],
        overdueTasks: [TaskDefinition] = [],
        completedTasks: [TaskDefinition] = [],
        totalCount: Int = 0
    ) {
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.completedTasks = completedTasks
        self.totalCount = totalCount
    }
}

public struct DateTasksResult {
    public let date: Date
    public let morningTasks: [TaskDefinition]
    public let eveningTasks: [TaskDefinition]
    public let overdueTasks: [TaskDefinition]
    public let completedTasks: [TaskDefinition]
    public let totalCount: Int

    /// Initializes a new instance.
    init(
        date: Date,
        morningTasks: [TaskDefinition] = [],
        eveningTasks: [TaskDefinition] = [],
        overdueTasks: [TaskDefinition] = [],
        completedTasks: [TaskDefinition] = [],
        totalCount: Int = 0
    ) {
        self.date = date
        self.morningTasks = morningTasks
        self.eveningTasks = eveningTasks
        self.overdueTasks = overdueTasks
        self.completedTasks = completedTasks
        self.totalCount = totalCount
    }
}

public struct ProjectTasksResult {
    public let projectID: UUID
    public let tasks: [TaskDefinition]
    public let openCount: Int
    public let completedCount: Int
}

public struct UpcomingTasksResult {
    public let thisWeek: [TaskDefinition]
    public let nextWeek: [TaskDefinition]
    public let thisMonth: [TaskDefinition]
    public let later: [TaskDefinition]
}

// MARK: - Supporting Types

public enum GetTasksScope {
    case all
    case today
    case upcoming
    case project(UUID)
}

public enum GetTasksError: LocalizedError {
    case repositoryError(Error)
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range specified"
        }
    }
}
