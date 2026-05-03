import Foundation
import CoreData

public final class CoreDataTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private let context: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.context = container.newBackgroundContext()
        self.context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchTasks.
    public func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        context.perform {
            do {
                let predicate = self.predicate(for: query)
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: query.sortBy),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                let totalCount = try self.totalCount(
                    needsTotalCount: query.needsTotalCount,
                    predicate: predicate,
                    loadedCount: definitions.count,
                    limit: query.limit,
                    offset: query.offset
                )
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes searchTasks.
    public func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        context.perform {
            do {
                let predicate = self.searchPredicate(for: query)
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: .updatedAtDescending),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                let totalCount = try self.totalCount(
                    needsTotalCount: query.needsTotalCount,
                    predicate: predicate,
                    loadedCount: definitions.count,
                    limit: query.limit,
                    offset: query.offset
                )
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func searchTasks(query: TaskRepositorySearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        context.perform {
            do {
                let predicate = self.searchPredicate(for: query, referenceDate: Date())
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                let totalCount = try self.totalCount(
                    needsTotalCount: query.needsTotalCount,
                    predicate: predicate,
                    loadedCount: definitions.count,
                    limit: query.limit,
                    offset: query.offset
                )
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchHomeProjection(
        query: HomeProjectionQuery,
        completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void
    ) {
        context.perform {
            do {
                let predicate = self.homeProjectionPredicate(for: query)
                let entities = try self.fetchTaskEntities(
                    predicate: predicate,
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.limit,
                    offset: query.offset
                )
                let definitions = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(entities, context: self.context)
                let totalCount = try self.totalCount(
                    needsTotalCount: false,
                    predicate: predicate,
                    loadedCount: definitions.count,
                    limit: query.limit,
                    offset: query.offset
                )
                completion(.success(TaskDefinitionSliceResult(
                    tasks: definitions,
                    totalCount: totalCount,
                    limit: query.limit,
                    offset: query.offset
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchInsightsTodayProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        fetchInsightsTodayProjection(
            query: InsightsTodayProjectionQuery(referenceDate: referenceDate),
            completion: completion
        )
    }

    public func fetchInsightsTodayProjection(
        query: InsightsTodayProjectionQuery,
        completion: @escaping (Result<InsightsTodayTaskProjection, Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                let startOfToday = calendar.startOfDay(for: query.referenceDate)
                let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? query.referenceDate

                let dueWindowEntities = try self.fetchTaskEntities(
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "dueDate <= %@", startOfTomorrow as NSDate)
                    ]),
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.dueWindowLimit,
                    offset: 0
                )
                let recentEntities = try self.fetchTaskEntities(
                    predicate: nil,
                    sortDescriptors: self.sortDescriptors(for: .updatedAtDescending),
                    limit: query.recentLimit,
                    offset: 0
                )

                let dueWindowTasks = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(dueWindowEntities, context: self.context)
                let recentTasks = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(recentEntities, context: self.context)
                completion(.success(InsightsTodayTaskProjection(dueWindowTasks: dueWindowTasks, recentTasks: recentTasks)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchInsightsWeekProjection(
        referenceDate: Date,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        fetchInsightsWeekProjection(
            query: InsightsWeekProjectionQuery(referenceDate: referenceDate),
            completion: completion
        )
    }

    public func fetchInsightsWeekProjection(
        query: InsightsWeekProjectionQuery,
        completion: @escaping (Result<InsightsWeekTaskProjection, Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = XPCalculationEngine.mondayCalendar()
                let today = calendar.startOfDay(for: query.referenceDate)
                let weekStart = XPCalculationEngine.mondayStartOfWeek(for: today, calendar: calendar)
                let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

                let recentEntities = try self.fetchTaskEntities(
                    predicate: nil,
                    sortDescriptors: self.sortDescriptors(for: .updatedAtDescending),
                    limit: query.recentLimit,
                    offset: 0
                )
                let dueWindowEntities = try self.fetchTaskEntities(
                    predicate: NSPredicate(format: "dueDate <= %@", startOfTomorrow as NSDate),
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.dueWindowLimit,
                    offset: 0
                )
                let recentTasks = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(recentEntities, context: self.context)
                let dueWindowTasks = try CoreDataTaskDefinitionRepository.mapTaskDefinitions(dueWindowEntities, context: self.context)
                let projectScores = try self.projectCompletionScoreTotals(from: weekStart, to: weekEnd)
                completion(.success(InsightsWeekTaskProjection(
                    recentTasks: recentTasks,
                    dueWindowTasks: dueWindowTasks,
                    projectScores: projectScores
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchDailyReflectionProjection(
        query: DailyReflectionTaskProjectionQuery,
        completion: @escaping (Result<DailyReflectionTaskProjection, Error>) -> Void
    ) {
        context.perform {
            do {
                let calendar = Calendar.current
                let reflectionDayStart = calendar.startOfDay(for: query.reflectionDate)
                let reflectionDayEnd = calendar.date(byAdding: .day, value: 1, to: reflectionDayStart) ?? reflectionDayStart
                let planningDayStart = calendar.startOfDay(for: query.planningDate)
                let planningDayEnd = calendar.date(byAdding: .day, value: 1, to: planningDayStart) ?? planningDayStart

                let completedEntities = try self.fetchTaskEntities(
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "isComplete == YES"),
                        NSPredicate(format: "dateCompleted >= %@", reflectionDayStart as NSDate),
                        NSPredicate(format: "dateCompleted < %@", reflectionDayEnd as NSDate)
                    ]),
                    sortDescriptors: [
                        NSSortDescriptor(key: "dateCompleted", ascending: false),
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "taskID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ],
                    limit: query.completedLimit,
                    offset: 0
                )

                let reflectionOpenEntities = try self.fetchTaskEntities(
                    predicate: self.dailyReflectionOpenPredicate(dayEnd: reflectionDayEnd),
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.openTaskLimit,
                    offset: 0
                )

                let planningOpenEntities = try self.fetchTaskEntities(
                    predicate: self.dailyReflectionOpenPredicate(dayEnd: planningDayEnd),
                    sortDescriptors: self.sortDescriptors(for: .dueDateAscending),
                    limit: query.openTaskLimit,
                    offset: 0
                )

                completion(
                    .success(
                        DailyReflectionTaskProjection(
                            reflectionCompletedTasks: try CoreDataTaskDefinitionRepository.mapTaskDefinitions(completedEntities, context: self.context),
                            reflectionOpenTasks: try CoreDataTaskDefinitionRepository.mapTaskDefinitions(reflectionOpenEntities, context: self.context),
                            planningOpenTasks: try CoreDataTaskDefinitionRepository.mapTaskDefinitions(planningOpenEntities, context: self.context)
                        )
                    )
                )
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchWeekChartProjection(
        referenceDate: Date,
        completion: @escaping (Result<WeekChartProjection, Error>) -> Void
    ) {
        context.perform {
            do {
                var calendar = Calendar.autoupdatingCurrent
                calendar.firstWeekday = 1
                let week = calendar.daysWithSameWeekOfYear(as: referenceDate)
                guard let weekStart = week.first?.startOfDay,
                      let weekEnd = week.last?.endOfDay else {
                    completion(.success(WeekChartProjection(weekStart: referenceDate.startOfDay, dayScores: [:], projectScores: [:])))
                    return
                }

                let dayScoreRequest = NSFetchRequest<NSDictionary>(entityName: "TaskDefinition")
                dayScoreRequest.resultType = .dictionaryResultType
                dayScoreRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "isComplete == YES"),
                    NSPredicate(format: "dateCompleted >= %@", weekStart as NSDate),
                    NSPredicate(format: "dateCompleted <= %@", weekEnd as NSDate)
                ])
                dayScoreRequest.propertiesToFetch = ["dateCompleted", "priority"]

                let rows = try self.context.fetch(dayScoreRequest)
                var dayScores: [Date: Int] = [:]
                var projectScores: [UUID: Int] = [:]
                for row in rows {
                    guard let completedAt = row["dateCompleted"] as? Date else { continue }
                    let day = completedAt.startOfDay
                    let priorityRaw = (row["priority"] as? NSNumber)?.int32Value
                        ?? (row["priority"] as? Int32)
                        ?? Int32(TaskPriority.low.rawValue)
                    let priority = TaskPriority(rawValue: priorityRaw)
                    dayScores[day, default: 0] += priority.scorePoints
                }

                let projectScoresResult = try self.projectCompletionScoreTotals(from: weekStart, to: weekEnd)
                projectScores = projectScoresResult
                completion(.success(WeekChartProjection(
                    weekStart: weekStart,
                    dayScores: dayScores,
                    projectScores: projectScores
                )))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchProjectTaskCounts.
    public func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        context.perform {
            do {
                let countExpr = NSExpressionDescription()
                countExpr.name = "taskCount"
                countExpr.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "taskID")])
                countExpr.expressionResultType = .integer64AttributeType

                let request = NSFetchRequest<NSDictionary>(entityName: "TaskDefinition")
                request.resultType = .dictionaryResultType
                request.propertiesToGroupBy = ["projectID"]
                request.propertiesToFetch = ["projectID", countExpr]
                if includeCompleted == false {
                    request.predicate = NSPredicate(format: "isComplete == NO")
                }

                let rows = try self.context.fetch(request)
                var counts: [UUID: Int] = [:]
                for row in rows {
                    guard let projectID = row["projectID"] as? UUID else { continue }
                    let countValue = (row["taskCount"] as? NSNumber)?.intValue ?? 0
                    counts[projectID] = countValue
                }
                completion(.success(counts))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchProjectCompletionScoreTotals.
    public func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID: Int], Error>) -> Void
    ) {
        context.perform {
            do {
                completion(.success(try self.projectCompletionScoreTotals(from: startDate, to: endDate)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes countTasks.
    private func countTasks(predicate: NSPredicate?) throws -> Int {
        let countRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TaskDefinition")
        countRequest.predicate = predicate
        let count = try context.count(for: countRequest)
        return max(0, count)
    }

    private func totalCount(
        needsTotalCount: Bool,
        predicate: NSPredicate?,
        loadedCount: Int,
        limit: Int,
        offset: Int
    ) throws -> Int {
        guard needsTotalCount else {
            // Preserve pagination semantics without paying for a full count() query.
            if loadedCount < limit {
                return offset + loadedCount
            }
            return offset + loadedCount + 1
        }
        return try countTasks(predicate: predicate)
    }

    /// Executes fetchTaskEntities.
    private func fetchTaskEntities(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        limit: Int,
        offset: Int
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchLimit = max(1, limit)
        request.fetchOffset = max(0, offset)
        request.fetchBatchSize = min(max(50, limit), 200)
        return try context.fetch(request)
    }

    /// Executes predicate.
    private func predicate(for query: TaskReadQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let projectID = query.projectID {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        }
        if query.includeCompleted == false {
            predicates.append(NSPredicate(format: "isComplete == NO"))
        }
        if let dueDateStart = query.dueDateStart {
            predicates.append(NSPredicate(format: "dueDate >= %@", dueDateStart as NSDate))
        }
        if let dueDateEnd = query.dueDateEnd {
            predicates.append(NSPredicate(format: "dueDate <= %@", dueDateEnd as NSDate))
        }
        if let updatedAfter = query.updatedAfter {
            predicates.append(NSPredicate(format: "updatedAt >= %@", updatedAfter as NSDate))
        }
        if query.planningBuckets.isEmpty == false {
            predicates.append(NSPredicate(
                format: "planningBucketRaw IN %@",
                query.planningBuckets.map(\.rawValue)
            ))
        }
        if let weeklyOutcomeID = query.weeklyOutcomeID {
            predicates.append(NSPredicate(format: "weeklyOutcomeID == %@", weeklyOutcomeID as CVarArg))
        }
        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    /// Executes searchPredicate.
    private func searchPredicate(for query: TaskSearchQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let projectID = query.projectID {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        }
        if query.includeCompleted == false {
            predicates.append(NSPredicate(format: "isComplete == NO"))
        }
        if query.planningBuckets.isEmpty == false {
            predicates.append(NSPredicate(
                format: "planningBucketRaw IN %@",
                query.planningBuckets.map(\.rawValue)
            ))
        }
        if let weeklyOutcomeID = query.weeklyOutcomeID {
            predicates.append(NSPredicate(format: "weeklyOutcomeID == %@", weeklyOutcomeID as CVarArg))
        }
        let trimmed = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "title CONTAINS[cd] %@", trimmed),
                    NSPredicate(format: "notes CONTAINS[cd] %@", trimmed)
                ])
            )
        }
        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func searchPredicate(for query: TaskRepositorySearchQuery, referenceDate: Date) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        let trimmed = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "title CONTAINS[cd] %@", trimmed),
                    NSPredicate(format: "notes CONTAINS[cd] %@", trimmed)
                ])
            )
        }
        if query.projectIDs.count == 1, let projectID = query.projectIDs.first {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        } else if query.projectIDs.isEmpty == false {
            predicates.append(NSPredicate(format: "projectID IN %@", query.projectIDs))
        }
        if query.priorities.isEmpty == false {
            predicates.append(NSPredicate(format: "priority IN %@", query.priorities))
        }
        if query.planningBuckets.isEmpty == false {
            predicates.append(NSPredicate(
                format: "planningBucketRaw IN %@",
                query.planningBuckets.map(\.rawValue)
            ))
        }
        if let weeklyOutcomeID = query.weeklyOutcomeID {
            predicates.append(NSPredicate(format: "weeklyOutcomeID == %@", weeklyOutcomeID as CVarArg))
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? referenceDate
        switch query.status {
        case .all:
            break
        case .today:
            predicates.append(
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "isComplete == YES AND dateCompleted >= %@ AND dateCompleted < %@", startOfToday as NSDate, startOfTomorrow as NSDate),
                    NSPredicate(
                        format: "isComplete == NO AND (taskType == %d OR taskType == %d OR dueDate < %@)",
                        TaskType.morning.rawValue,
                        TaskType.evening.rawValue,
                        startOfTomorrow as NSDate
                    )
                ])
            )
        case .overdue:
            predicates.append(NSPredicate(format: "isComplete == NO"))
            predicates.append(NSPredicate(format: "dueDate < %@", startOfToday as NSDate))
        case .completed:
            predicates.append(NSPredicate(format: "isComplete == YES"))
        }

        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func homeProjectionPredicate(for query: HomeProjectionQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        let state = query.state

        if state.selectedProjectIDs.count == 1, let projectID = state.selectedProjectIDs.first {
            predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
        } else if state.selectedProjectIDs.isEmpty == false {
            predicates.append(NSPredicate(format: "projectID IN %@", state.selectedProjectIDs))
        }

        if let advanced = state.advancedFilter, !advanced.isEmpty {
            if advanced.priorities.isEmpty == false {
                predicates.append(NSPredicate(format: "priority IN %@", advanced.priorities.map(\.rawValue)))
            }
            if advanced.categories.isEmpty == false {
                predicates.append(NSPredicate(format: "category IN %@", advanced.categories.map(\.rawValue)))
            }
            if advanced.contexts.isEmpty == false {
                predicates.append(NSPredicate(format: "context IN %@", advanced.contexts.map(\.rawValue)))
            }
            if advanced.energyLevels.isEmpty == false {
                predicates.append(NSPredicate(format: "energy IN %@", advanced.energyLevels.map(\.rawValue)))
            }
            if let dateRange = advanced.dateRange {
                predicates.append(NSPredicate(format: "dueDate >= %@", dateRange.start as NSDate))
                predicates.append(NSPredicate(format: "dueDate <= %@", dateRange.end as NSDate))
            } else if advanced.requireDueDate {
                predicates.append(NSPredicate(format: "dueDate != nil"))
            }
            if let hasEstimate = advanced.hasEstimate {
                predicates.append(NSPredicate(format: hasEstimate ? "estimatedDuration != nil" : "estimatedDuration == nil"))
            }
        }

        guard predicates.isEmpty == false else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func projectCompletionScoreTotals(from startDate: Date, to endDate: Date) throws -> [UUID: Int] {
        let countExpr = NSExpressionDescription()
        countExpr.name = "taskCount"
        countExpr.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "taskID")])
        countExpr.expressionResultType = .integer64AttributeType

        let request = NSFetchRequest<NSDictionary>(entityName: "TaskDefinition")
        request.resultType = .dictionaryResultType
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isComplete == YES"),
            NSPredicate(format: "dateCompleted >= %@", startDate as NSDate),
            NSPredicate(format: "dateCompleted <= %@", endDate as NSDate)
        ])
        request.propertiesToGroupBy = ["projectID", "priority"]
        request.propertiesToFetch = ["projectID", "priority", countExpr]

        let rows = try self.context.fetch(request)
        var totals: [UUID: Int] = [:]
        for row in rows {
            guard let projectID = row["projectID"] as? UUID else { continue }
            let countValue = (row["taskCount"] as? NSNumber)?.intValue ?? 0
            let priorityRaw = (row["priority"] as? NSNumber)?.int32Value
                ?? (row["priority"] as? Int32)
                ?? Int32(TaskPriority.low.rawValue)
            let priority = TaskPriority(rawValue: priorityRaw)
            totals[projectID, default: 0] += countValue * priority.scorePoints
        }
        return totals
    }

    private func dailyReflectionOpenPredicate(dayEnd: Date) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isComplete == NO"),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "taskType == %d", TaskType.morning.rawValue),
                NSPredicate(format: "taskType == %d", TaskType.evening.rawValue),
                NSPredicate(format: "dueDate < %@", dayEnd as NSDate)
            ])
        ])
    }

    /// Executes sortDescriptors.
    private func sortDescriptors(for sort: TaskReadSort) -> [NSSortDescriptor] {
        switch sort {
        case .dueDateAscending:
            return [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        case .dueDateDescending:
            return [
                NSSortDescriptor(key: "dueDate", ascending: false),
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        case .updatedAtDescending:
            return [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        }
    }
}
