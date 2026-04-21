import Foundation

public protocol TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes searchTasks.
    func searchTasks(query: TaskRepositorySearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes fetchHomeProjection.
    func fetchHomeProjection(query: HomeProjectionQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void)
    /// Executes fetchInsightsTodayProjection.
    func fetchInsightsTodayProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    )
    /// Executes fetchInsightsTodayProjection.
    func fetchInsightsTodayProjection(
        query: InsightsTodayProjectionQuery,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    )
    /// Executes fetchInsightsWeekProjection.
    func fetchInsightsWeekProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    )
    /// Executes fetchInsightsWeekProjection.
    func fetchInsightsWeekProjection(
        query: InsightsWeekProjectionQuery,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    )
    /// Executes fetchDailyReflectionProjection.
    func fetchDailyReflectionProjection(
        query: DailyReflectionTaskProjectionQuery,
        completion: @escaping (Result<DailyReflectionTaskProjection, Error>) -> Void
    )
    /// Executes fetchWeekChartProjection.
    func fetchWeekChartProjection(
        referenceDate: Date,
        completion: @escaping (Result<WeekChartProjection, Error>) -> Void
    )
    /// Executes fetchProjectTaskCounts.
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
    /// Executes fetchProjectCompletionScoreTotals.
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    )
}

public extension TaskReadModelRepositoryProtocol {
    func searchTasks(query: TaskRepositorySearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        let searchQuery = TaskSearchQuery(
            text: query.text,
            projectID: query.projectIDs.count == 1 ? query.projectIDs.first : nil,
            includeCompleted: query.status != .overdue,
            planningBuckets: query.planningBuckets,
            weeklyOutcomeID: query.weeklyOutcomeID,
            needsTotalCount: query.needsTotalCount,
            limit: query.limit,
            offset: query.offset
        )
        searchTasks(query: searchQuery) { result in
            completion(
                result.map { slice in
                    let filtered = slice.tasks.filter { task in
                        if query.projectIDs.isEmpty == false && !query.projectIDs.contains(task.projectID) {
                            return false
                        }
                        if query.priorities.isEmpty == false && !query.priorities.contains(task.priority.rawValue) {
                            return false
                        }
                        switch query.status {
                        case .all:
                            return true
                        case .today:
                            let calendar = Calendar.current
                            let startOfToday = calendar.startOfDay(for: Date())
                            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
                            if task.isComplete {
                                guard let completionDate = task.dateCompleted else { return false }
                                return completionDate >= startOfToday && completionDate < startOfTomorrow
                            }
                            if task.type == .morning || task.type == .evening {
                                return true
                            }
                            guard let dueDate = task.dueDate else { return false }
                            return dueDate < startOfTomorrow
                        case .overdue:
                            guard !task.isComplete, let dueDate = task.dueDate else { return false }
                            return dueDate < Calendar.current.startOfDay(for: Date())
                        case .completed:
                            return task.isComplete
                        }
                    }
                    return TaskDefinitionSliceResult(
                        tasks: filtered,
                        totalCount: filtered.count,
                        limit: query.limit,
                        offset: query.offset
                    )
                }
            )
        }
    }

    func fetchHomeProjection(query: HomeProjectionQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        fetchTasks(
            query: TaskReadQuery(
                projectID: query.state.selectedProjectIDs.count == 1 ? query.state.selectedProjectIDs.first : nil,
                includeCompleted: true,
                sortBy: .dueDateAscending,
                limit: query.limit,
                offset: query.offset
            ),
            completion: completion
        )
    }

    func fetchInsightsTodayProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        fetchInsightsTodayProjection(
            query: InsightsTodayProjectionQuery(referenceDate: referenceDate),
            completion: completion
        )
    }

    func fetchInsightsTodayProjection(
        query: InsightsTodayProjectionQuery,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: query.referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? query.referenceDate
        let group = DispatchGroup()
        let lock = NSLock()
        var dueWindowTasks: [TaskDefinition] = []
        var recentTasks: [TaskDefinition] = []
        var firstError: Error?

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateEnd: startOfTomorrow,
                sortBy: .dueDateAscending,
                limit: query.dueWindowLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            if case .success(let slice) = result {
                dueWindowTasks = slice.tasks
            } else if case .failure(let error) = result, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: query.recentLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            if case .success(let slice) = result {
                recentTasks = slice.tasks
            } else if case .failure(let error) = result, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(InsightsTodayTaskProjection(dueWindowTasks: dueWindowTasks, recentTasks: recentTasks)))
        }
    }

    func fetchInsightsWeekProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        fetchInsightsWeekProjection(
            query: InsightsWeekProjectionQuery(referenceDate: referenceDate),
            completion: completion
        )
    }

    func fetchInsightsWeekProjection(
        query: InsightsWeekProjectionQuery,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: query.referenceDate)
        let weekEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let group = DispatchGroup()
        let lock = NSLock()
        var recentTasks: [TaskDefinition] = []
        var dueWindowTasks: [TaskDefinition] = []
        var projectScores: [UUID: Int] = [:]
        var firstError: Error?

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: query.recentLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            if case .success(let slice) = result {
                recentTasks = slice.tasks
            } else if case .failure(let error) = result, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateEnd: weekEnd,
                sortBy: .dueDateAscending,
                limit: query.dueWindowLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            if case .success(let slice) = result {
                dueWindowTasks = slice.tasks
            } else if case .failure(let error) = result, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.enter()
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        fetchProjectCompletionScoreTotals(from: weekStart, to: today) { result in
            lock.lock()
            defer { lock.unlock() }
            if case .success(let scores) = result {
                projectScores = scores
            } else if case .failure(let error) = result, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(.success(InsightsWeekTaskProjection(
                recentTasks: recentTasks,
                dueWindowTasks: dueWindowTasks,
                projectScores: projectScores
            )))
        }
    }

    func fetchDailyReflectionProjection(
        query: DailyReflectionTaskProjectionQuery,
        completion: @escaping (Result<DailyReflectionTaskProjection, Error>) -> Void
    ) {
        let calendar = Calendar.current
        let reflectionDayStart = calendar.startOfDay(for: query.reflectionDate)
        let reflectionDayEnd = calendar.date(byAdding: .day, value: 1, to: reflectionDayStart) ?? reflectionDayStart
        let planningDayStart = calendar.startOfDay(for: query.planningDate)
        let planningDayEnd = calendar.date(byAdding: .day, value: 1, to: planningDayStart) ?? planningDayStart
        let group = DispatchGroup()
        let lock = NSLock()

        var completedTasks: [TaskDefinition] = []
        var reflectionOpenTasks: [TaskDefinition] = []
        var planningOpenTasks: [TaskDefinition] = []
        var firstError: Error?

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: query.completedLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .failure(let error):
                firstError = firstError ?? error
            case .success(let slice):
                completedTasks = slice.tasks.filter { task in
                    guard task.isComplete, let completedAt = task.dateCompleted else { return false }
                    return completedAt >= reflectionDayStart && completedAt < reflectionDayEnd
                }
            }
            group.leave()
        }

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateEnd: reflectionDayEnd,
                sortBy: .dueDateAscending,
                limit: query.openTaskLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .failure(let error):
                firstError = firstError ?? error
            case .success(let slice):
                reflectionOpenTasks = slice.tasks.filter { task in
                    guard task.isComplete == false else { return false }
                    if task.type == .morning || task.type == .evening {
                        return true
                    }
                    guard let dueDate = task.dueDate else { return false }
                    return dueDate < reflectionDayEnd
                }
            }
            group.leave()
        }

        group.enter()
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateEnd: planningDayEnd,
                sortBy: .dueDateAscending,
                limit: query.openTaskLimit,
                offset: 0
            )
        ) { result in
            lock.lock()
            defer { lock.unlock() }
            switch result {
            case .failure(let error):
                firstError = firstError ?? error
            case .success(let slice):
                planningOpenTasks = slice.tasks.filter { task in
                    guard task.isComplete == false else { return false }
                    if task.type == .morning || task.type == .evening {
                        return true
                    }
                    guard let dueDate = task.dueDate else { return false }
                    return dueDate < planningDayEnd
                }
            }
            group.leave()
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            if let firstError {
                completion(.failure(firstError))
                return
            }
            completion(
                .success(
                    DailyReflectionTaskProjection(
                        reflectionCompletedTasks: completedTasks,
                        reflectionOpenTasks: reflectionOpenTasks,
                        planningOpenTasks: planningOpenTasks
                    )
                )
            )
        }
    }

    func fetchWeekChartProjection(
        referenceDate: Date,
        completion: @escaping (Result<WeekChartProjection, Error>) -> Void
    ) {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let week = calendar.daysWithSameWeekOfYear(as: referenceDate)
        guard let weekStart = week.first?.startOfDay,
              let weekEnd = week.last?.endOfDay else {
            completion(.success(WeekChartProjection(weekStart: referenceDate.startOfDay, dayScores: [:], projectScores: [:])))
            return
        }

        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: weekStart,
                dueDateEnd: weekEnd,
                sortBy: .dueDateAscending,
                limit: 2_000,
                offset: 0
            )
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let slice):
                var dayScores: [Date: Int] = [:]
                var projectScores: [UUID: Int] = [:]
                for task in slice.tasks where task.isComplete {
                    guard let completedDay = task.dateCompleted?.startOfDay else { continue }
                    dayScores[completedDay, default: 0] += task.priority.scorePoints
                    projectScores[task.projectID, default: 0] += task.priority.scorePoints
                }
                completion(.success(WeekChartProjection(
                    weekStart: weekStart,
                    dayScores: dayScores,
                    projectScores: projectScores
                )))
            }
        }
    }
}
