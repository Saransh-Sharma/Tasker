//
//  CalculateAnalyticsUseCase.swift
//  Tasker
//
//  Use case for calculating task analytics and productivity metrics
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Use case for calculating analytics and productivity metrics
public final class CalculateAnalyticsUseCase {
    
    // MARK: - Dependencies
    
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol?
    private let scoringService: TaskScoringServiceProtocol
    private let cacheService: CacheServiceProtocol?
    private let analyticsWindowLimit = 2_000
    private let analyticsDayWindowLimit = 600
    private let dailyAnalyticsCacheLimit = 4
    private let periodAnalyticsCacheLimit = 3
    private let analyticsCacheLock = NSLock()
    private var dailyAnalyticsCache: [String: DailyAnalytics] = [:]
    private var periodAnalyticsCache: [String: PeriodAnalytics] = [:]
    private var dailyAnalyticsCacheOrder: [String] = []
    private var periodAnalyticsCacheOrder: [String] = []
    private var cachedProductivityScore: ProductivityScore?
    private var cachedStreakInfo: StreakInfo?
    private let analyticsComputeQueue = DispatchQueue(
        label: "tasker.analytics.compute",
        qos: .userInitiated
    )
#if canImport(UIKit)
    private var memoryWarningObserver: NSObjectProtocol?
#endif
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    public init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        habitRuntimeReadRepository: HabitRuntimeReadRepositoryProtocol? = nil,
        scoringService: TaskScoringServiceProtocol? = nil,
        cacheService: CacheServiceProtocol? = nil
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
        self.scoringService = scoringService ?? DefaultTaskScoringService()
        self.cacheService = cacheService
#if canImport(UIKit)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.invalidateCaches()
            TaskerMemoryDiagnostics.checkpoint(
                event: "analytics_cache_memory_warning",
                message: "Cleared analytics caches after memory warning"
            )
        }
#endif
    }

    public func invalidateCaches() {
        analyticsCacheLock.lock()
        dailyAnalyticsCache.removeAll()
        periodAnalyticsCache.removeAll()
        dailyAnalyticsCacheOrder.removeAll()
        periodAnalyticsCacheOrder.removeAll()
        cachedProductivityScore = nil
        cachedStreakInfo = nil
        analyticsCacheLock.unlock()
    }

    deinit {
#if canImport(UIKit)
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
#endif
    }
    
    // MARK: - Daily Analytics
    
    /// Calculate analytics for today
    public func calculateTodayAnalytics(completion: @escaping (Result<DailyAnalytics, AnalyticsError>) -> Void) {
        calculateDailyAnalytics(for: Date(), completion: completion)
    }
    
    /// Calculate analytics for a specific date
    public func calculateDailyAnalytics(
        for date: Date,
        habitSignals: [TaskerHabitSignal] = [],
        completion: @escaping (Result<DailyAnalytics, AnalyticsError>) -> Void
    ) {
        resolveHabitSignalsForDay(date, suppliedSignals: habitSignals) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let resolvedSignals):
                self?.calculateDailyAnalyticsResolved(
                    for: date,
                    habitSignals: resolvedSignals,
                    completion: completion
                )
            }
        }
    }

    private func calculateDailyAnalyticsResolved(
        for date: Date,
        habitSignals: [TaskerHabitSignal],
        completion: @escaping (Result<DailyAnalytics, AnalyticsError>) -> Void
    ) {
        let cacheKey = dailyCacheKey(for: date, habitSignals: habitSignals)
        let canUseCache = habitSignals.isEmpty == false || habitRuntimeReadRepository != nil
        if canUseCache {
            analyticsCacheLock.lock()
            if let cached = dailyAnalyticsCache[cacheKey] {
                touchCacheKeyLocked(cacheKey, order: &dailyAnalyticsCacheOrder)
                analyticsCacheLock.unlock()
                completion(.success(cached))
                return
            }
            analyticsCacheLock.unlock()
        }

        let interval = TaskerPerformanceTrace.begin("AnalyticsDaily")
        fetchTasksForDay(date) { [weak self] result in
            switch result {
            case .success(let tasks):
                guard let self else {
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(DailyAnalytics(date: date)))
                    return
                }
                self.analyticsComputeQueue.async {
                    let analytics = self.computeDailyAnalytics(
                        tasks: tasks,
                        habitSignals: habitSignals,
                        date: date
                    )
                    if canUseCache {
                        self.analyticsCacheLock.lock()
                        self.storeDailyAnalyticsLocked(analytics, for: cacheKey)
                        self.analyticsCacheLock.unlock()
                    }
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(analytics))
                }
                
            case .failure(let error):
                TaskerPerformanceTrace.end(interval)
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Weekly Analytics
    
    /// Calculate analytics for the current week
    public func calculateWeeklyAnalytics(
        habitSignalsByDay: [String: [TaskerHabitSignal]] = [:],
        completion: @escaping (Result<WeeklyAnalytics, AnalyticsError>) -> Void
    ) {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            completion(.failure(.invalidDateRange))
            return
        }
        let inclusiveWeekEnd = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.start
        
        calculateAnalytics(
            from: weekInterval.start,
            to: inclusiveWeekEnd,
            habitSignalsByDay: habitSignalsByDay
        ) { result in
            switch result {
            case .success(let periodAnalytics):
                let weeklyAnalytics = WeeklyAnalytics(
                    weekStartDate: weekInterval.start,
                    weekEndDate: inclusiveWeekEnd,
                    dailyAnalytics: periodAnalytics.dailyBreakdown,
                    totalScore: periodAnalytics.totalScore,
                    totalTasksCompleted: periodAnalytics.totalTasksCompleted,
                    completionRate: periodAnalytics.completionRate,
                    averageTasksPerDay: periodAnalytics.averageTasksPerDay,
                    mostProductiveDay: periodAnalytics.mostProductiveDay,
                    leastProductiveDay: periodAnalytics.leastProductiveDay,
                    habitAnalytics: periodAnalytics.habitAnalytics
                )
                completion(.success(weeklyAnalytics))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Monthly Analytics
    
    /// Calculate analytics for the current month
    public func calculateMonthlyAnalytics(
        habitSignalsByDay: [String: [TaskerHabitSignal]] = [:],
        completion: @escaping (Result<MonthlyAnalytics, AnalyticsError>) -> Void
    ) {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else {
            completion(.failure(.invalidDateRange))
            return
        }
        let inclusiveMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.start
        
        calculateAnalytics(
            from: monthInterval.start,
            to: inclusiveMonthEnd,
            habitSignalsByDay: habitSignalsByDay
        ) { result in
            switch result {
            case .success(let periodAnalytics):
                // Calculate weekly breakdown
                var weeklyBreakdown: [WeeklyAnalytics] = []
                var currentWeekStart = monthInterval.start
                
                while currentWeekStart < monthInterval.end {
                    if let weekEnd = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) {
                        let weekAnalytics = WeeklyAnalytics(
                            weekStartDate: currentWeekStart,
                            weekEndDate: min(weekEnd, inclusiveMonthEnd),
                            dailyAnalytics: periodAnalytics.dailyBreakdown.filter { analytics in
                                analytics.date >= currentWeekStart && analytics.date <= weekEnd
                            },
                            totalScore: 0, // Will be calculated
                            totalTasksCompleted: 0,
                            completionRate: 0,
                            averageTasksPerDay: 0,
                            mostProductiveDay: nil,
                            leastProductiveDay: nil,
                            habitAnalytics: .init()
                        )
                        weeklyBreakdown.append(weekAnalytics)
                    }
                    
                    currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? monthInterval.end
                }
                
                let monthlyAnalytics = MonthlyAnalytics(
                    month: monthInterval.start,
                    weeklyBreakdown: weeklyBreakdown,
                    totalScore: periodAnalytics.totalScore,
                    totalTasksCompleted: periodAnalytics.totalTasksCompleted,
                    completionRate: periodAnalytics.completionRate,
                    averageTasksPerDay: periodAnalytics.averageTasksPerDay,
                    mostProductiveWeek: weeklyBreakdown.max { $0.totalScore < $1.totalScore },
                    projectBreakdown: periodAnalytics.projectBreakdown,
                    priorityBreakdown: periodAnalytics.priorityBreakdown,
                    habitAnalytics: periodAnalytics.habitAnalytics
                )
                completion(.success(monthlyAnalytics))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Period Analytics
    
    /// Calculate analytics for a custom date range
    public func calculateAnalytics(
        from startDate: Date,
        to endDate: Date,
        habitSignalsByDay: [String: [TaskerHabitSignal]] = [:],
        completion: @escaping (Result<PeriodAnalytics, AnalyticsError>) -> Void
    ) {
        resolveHabitSignalsByDay(
            from: startDate,
            to: endDate,
            suppliedSignalsByDay: habitSignalsByDay
        ) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let resolvedSignalsByDay):
                self?.calculateAnalyticsResolved(
                    from: startDate,
                    to: endDate,
                    habitSignalsByDay: resolvedSignalsByDay,
                    completion: completion
                )
            }
        }
    }

    private func calculateAnalyticsResolved(
        from startDate: Date,
        to endDate: Date,
        habitSignalsByDay: [String: [TaskerHabitSignal]],
        completion: @escaping (Result<PeriodAnalytics, AnalyticsError>) -> Void
    ) {
        // Validate date range
        guard startDate <= endDate else {
            completion(.failure(.invalidDateRange))
            return
        }
        
        let cacheKey = periodCacheKey(startDate: startDate, endDate: endDate)
        let canUseCache = habitSignalsByDay.isEmpty
        if canUseCache {
            analyticsCacheLock.lock()
            if let cached = periodAnalyticsCache[cacheKey] {
                touchCacheKeyLocked(cacheKey, order: &periodAnalyticsCacheOrder)
                analyticsCacheLock.unlock()
                completion(.success(cached))
                return
            }
            analyticsCacheLock.unlock()
        }

        let interval = TaskerPerformanceTrace.begin("AnalyticsPeriod")

        // Fetch all tasks in the date range
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: startDate,
                dueDateEnd: endDate,
                sortBy: .dueDateAscending,
                limit: analyticsWindowLimit,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasksInRange):
                guard let self else {
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(PeriodAnalytics(startDate: startDate, endDate: endDate)))
                    return
                }
                self.analyticsComputeQueue.async {
                    let analytics = self.computePeriodAnalytics(
                        tasks: tasksInRange,
                        habitSignalsByDay: habitSignalsByDay,
                        startDate: startDate,
                        endDate: endDate
                    )
                    if canUseCache {
                        self.analyticsCacheLock.lock()
                        self.storePeriodAnalyticsLocked(analytics, for: cacheKey)
                        self.analyticsCacheLock.unlock()
                    }
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(analytics))
                }
                
            case .failure(let error):
                TaskerPerformanceTrace.end(interval)
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Productivity Score
    
    /// Calculate overall productivity score
    public func calculateProductivityScore(completion: @escaping (Result<ProductivityScore, AnalyticsError>) -> Void) {
        analyticsCacheLock.lock()
        if let cachedProductivityScore {
            analyticsCacheLock.unlock()
            completion(.success(cachedProductivityScore))
            return
        }
        analyticsCacheLock.unlock()

        let interval = TaskerPerformanceTrace.begin("AnalyticsProductivity")
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: analyticsWindowLimit,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasks):
                guard let self else {
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(ProductivityScore()))
                    return
                }
                self.analyticsComputeQueue.async {
                    let score = self.computeProductivityScore(tasks: tasks)
                    self.analyticsCacheLock.lock()
                    self.cachedProductivityScore = score
                    self.analyticsCacheLock.unlock()
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(score))
                }
                
            case .failure(let error):
                TaskerPerformanceTrace.end(interval)
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Streak Calculation
    
    /// Calculate current completion streak
    public func calculateStreak(completion: @escaping (Result<StreakInfo, AnalyticsError>) -> Void) {
        analyticsCacheLock.lock()
        if let cachedStreakInfo {
            analyticsCacheLock.unlock()
            completion(.success(cachedStreakInfo))
            return
        }
        analyticsCacheLock.unlock()

        let interval = TaskerPerformanceTrace.begin("AnalyticsStreak")
        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                sortBy: .updatedAtDescending,
                limit: analyticsWindowLimit,
                offset: 0
            )
        ) { [weak self] result in
            switch result {
            case .success(let tasks):
                guard let self else {
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(StreakInfo()))
                    return
                }
                self.analyticsComputeQueue.async {
                    let completedTasks = tasks.filter(\.isComplete)
                    let streak = self.computeStreak(completedTasks: completedTasks)
                    self.analyticsCacheLock.lock()
                    self.cachedStreakInfo = streak
                    self.analyticsCacheLock.unlock()
                    TaskerPerformanceTrace.end(interval)
                    completion(.success(streak))
                }
                
            case .failure(let error):
                TaskerPerformanceTrace.end(interval)
                completion(.failure(.repositoryError(error)))
            }
        }
    }

    /// Executes fetchTasksForDay.
    private func fetchTasksForDay(
        _ date: Date,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: startOfDay,
                dueDateEnd: endOfDay,
                sortBy: .dueDateAscending,
                limit: analyticsDayWindowLimit,
                offset: 0
            ),
            completion: completion
        )
    }

    /// Executes fetchTasks.
    private func fetchTasks(
        query: TaskReadQuery,
        completion: @escaping (Result<[TaskDefinition], Error>) -> Void
    ) {
        guard let taskReadModelRepository else {
            completion(.failure(NSError(
                domain: "CalculateAnalyticsUseCase",
                code: 503,
                userInfo: [NSLocalizedDescriptionKey: "Task read-model repository is not configured"]
            )))
            return
        }

        taskReadModelRepository.fetchTasks(query: query) { result in
            completion(result.map(\.tasks))
        }
    }

    private func storeDailyAnalyticsLocked(_ analytics: DailyAnalytics, for key: String) {
        dailyAnalyticsCache[key] = analytics
        touchCacheKeyLocked(key, order: &dailyAnalyticsCacheOrder)
        trimCacheLocked(cache: &dailyAnalyticsCache, order: &dailyAnalyticsCacheOrder, limit: dailyAnalyticsCacheLimit)
    }

    private func storePeriodAnalyticsLocked(_ analytics: PeriodAnalytics, for key: String) {
        periodAnalyticsCache[key] = analytics
        touchCacheKeyLocked(key, order: &periodAnalyticsCacheOrder)
        trimCacheLocked(cache: &periodAnalyticsCache, order: &periodAnalyticsCacheOrder, limit: periodAnalyticsCacheLimit)
    }

    private func touchCacheKeyLocked(_ key: String, order: inout [String]) {
        if let existingIndex = order.firstIndex(of: key) {
            order.remove(at: existingIndex)
        }
        order.append(key)
    }

    private func trimCacheLocked<Value>(
        cache: inout [String: Value],
        order: inout [String],
        limit: Int
    ) {
        while order.count > limit {
            let evictedKey = order.removeFirst()
            cache.removeValue(forKey: evictedKey)
        }
    }

    private func resolveHabitSignalsForDay(
        _ date: Date,
        suppliedSignals: [TaskerHabitSignal],
        completion: @escaping (Result<[TaskerHabitSignal], AnalyticsError>) -> Void
    ) {
        guard suppliedSignals.isEmpty, let habitRuntimeReadRepository else {
            completion(.success(suppliedSignals))
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        habitRuntimeReadRepository.fetchSignals(start: startOfDay, end: endOfDay) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            case .success(let summaries):
                completion(.success(summaries.map { TaskerHabitSignal(summary: $0, referenceDate: date) }))
            }
        }
    }

    private func resolveHabitSignalsByDay(
        from startDate: Date,
        to endDate: Date,
        suppliedSignalsByDay: [String: [TaskerHabitSignal]],
        completion: @escaping (Result<[String: [TaskerHabitSignal]], AnalyticsError>) -> Void
    ) {
        guard suppliedSignalsByDay.isEmpty, let habitRuntimeReadRepository else {
            completion(.success(suppliedSignalsByDay))
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        habitRuntimeReadRepository.fetchSignals(start: start, end: endExclusive) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            case .success(let summaries):
                let grouped = Dictionary(grouping: summaries) { summary in
                    XPCalculationEngine.periodKey(for: calendar.startOfDay(for: summary.dueAt ?? start))
                }
                let mapped = grouped.mapValues { summaries in
                    summaries.map { TaskerHabitSignal(summary: $0, referenceDate: $0.dueAt ?? start) }
                }
                completion(.success(mapped))
            }
        }
    }
    
    // MARK: - Private Computation Methods
    
    /// Executes computeDailyAnalytics.
    private func computeDailyAnalytics(
        tasks: [TaskDefinition],
        habitSignals: [TaskerHabitSignal],
        date: Date
    ) -> DailyAnalytics {
        let completedTasks = tasks.filter { $0.isComplete }
        let totalTasks = tasks.count
        let completionRate = totalTasks > 0 ? Double(completedTasks.count) / Double(totalTasks) : 0
        
        // Calculate score
        let totalScore = completedTasks.reduce(0) { sum, task in
            sum + scoringService.calculateScore(for: task)
        }
        
        // Group by priority
        var priorityBreakdown: [TaskPriority: Int] = [:]
        for task in completedTasks {
            priorityBreakdown[task.priority, default: 0] += 1
        }
        
        let habitAnalytics = computeHabitAnalytics(signals: habitSignals, date: date)

        // Group by type
        var typeBreakdown: [TaskType: Int] = [:]
        for task in completedTasks {
            typeBreakdown[task.type, default: 0] += 1
        }
        
        return DailyAnalytics(
            date: date,
            totalTasks: totalTasks,
            completedTasks: completedTasks.count,
            completionRate: completionRate,
            totalScore: totalScore,
            morningTasksCompleted: typeBreakdown[.morning] ?? 0,
            eveningTasksCompleted: typeBreakdown[.evening] ?? 0,
            priorityBreakdown: priorityBreakdown,
            habitAnalytics: habitAnalytics
        )
    }
    
    /// Executes computePeriodAnalytics.
    private func computePeriodAnalytics(
        tasks: [TaskDefinition],
        habitSignalsByDay: [String: [TaskerHabitSignal]],
        startDate: Date,
        endDate: Date
    ) -> PeriodAnalytics {
        let calendar = Calendar.current
        var dailyBreakdown: [DailyAnalytics] = []
        var currentDate = startDate

        var tasksByDay: [Date: [TaskDefinition]] = [:]
        tasksByDay.reserveCapacity(tasks.count)
        for task in tasks {
            guard let dueDate = task.dueDate else { continue }
            let day = calendar.startOfDay(for: dueDate)
            tasksByDay[day, default: []].append(task)
        }

        while currentDate <= endDate {
            let day = calendar.startOfDay(for: currentDate)
            let dayTasks = tasksByDay[day] ?? []
            let key = XPCalculationEngine.periodKey(for: day)
            let habitSignals = habitSignalsByDay[key] ?? []
            dailyBreakdown.append(
                computeDailyAnalytics(
                    tasks: dayTasks,
                    habitSignals: habitSignals,
                    date: currentDate
                )
            )
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        // Calculate totals
        let totalScore = dailyBreakdown.reduce(0) { $0 + $1.totalScore }
        let totalTasksCompleted = dailyBreakdown.reduce(0) { $0 + $1.completedTasks }
        let totalTasks = dailyBreakdown.reduce(0) { $0 + $1.totalTasks }
        let completionRate = totalTasks > 0 ? Double(totalTasksCompleted) / Double(totalTasks) : 0
        let habitAnalytics = dailyBreakdown.reduce(HabitAnalyticsSnapshot()) { partial, daily in
            partial.combining(daily.habitAnalytics)
        }
        
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let averageTasksPerDay = dayCount > 0 ? Double(totalTasksCompleted) / Double(dayCount) : 0
        
        // Find most and least productive days
        let mostProductiveDay = dailyBreakdown.max { $0.totalScore < $1.totalScore }
        let leastProductiveDay = dailyBreakdown.min { $0.totalScore < $1.totalScore }
        
        // Calculate project breakdown
        var projectBreakdown: [String: Int] = [:]
        for task in tasks.filter({ $0.isComplete }) {
            let projectName = task.projectName ?? "Inbox"
            projectBreakdown[projectName, default: 0] += 1
        }
        
        // Calculate priority breakdown
        var priorityBreakdown: [TaskPriority: Int] = [:]
        for task in tasks.filter({ $0.isComplete }) {
            priorityBreakdown[task.priority, default: 0] += 1
        }
        
        return PeriodAnalytics(
            startDate: startDate,
            endDate: endDate,
            dailyBreakdown: dailyBreakdown,
            totalScore: totalScore,
            totalTasksCompleted: totalTasksCompleted,
            completionRate: completionRate,
            averageTasksPerDay: averageTasksPerDay,
            mostProductiveDay: mostProductiveDay,
            leastProductiveDay: leastProductiveDay,
            projectBreakdown: projectBreakdown,
            priorityBreakdown: priorityBreakdown,
            habitAnalytics: habitAnalytics
        )
    }
    
    /// Executes computeProductivityScore.
    private func computeProductivityScore(tasks: [TaskDefinition]) -> ProductivityScore {
        let completedTasks = tasks.filter { $0.isComplete }
        let totalScore = completedTasks.reduce(0) { sum, task in
            sum + scoringService.calculateScore(for: task)
        }
        
        // Calculate level based on score
        let level = totalScore / 100
        let currentLevelProgress = totalScore % 100
        let nextLevelRequirement = 100
        
        return ProductivityScore(
            totalScore: totalScore,
            level: level,
            currentLevelProgress: currentLevelProgress,
            nextLevelRequirement: nextLevelRequirement,
            rank: determineRank(level: level)
        )
    }
    
    /// Executes computeStreak.
    private func computeStreak(completedTasks: [TaskDefinition]) -> StreakInfo {
        let calendar = Calendar.current
        let sortedTasks = completedTasks
            .compactMap { task -> (task: TaskDefinition, date: Date)? in
                guard let completedDate = task.dateCompleted else { return nil }
                return (task, completedDate)
            }
            .sorted { $0.date > $1.date }
        
        var currentStreak = 0
        var longestStreak = 0
        var lastDate: Date?
        
        for (_, completedDate) in sortedTasks {
            let date = calendar.startOfDay(for: completedDate)
            
            if let last = lastDate {
                let daysDifference = calendar.dateComponents([.day], from: date, to: last).day ?? 0
                
                if daysDifference == 1 {
                    currentStreak += 1
                } else if daysDifference > 1 {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = date
        }
        
        longestStreak = max(longestStreak, currentStreak)
        
        // Check if streak is still active (completed task today or yesterday)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let isActive = sortedTasks.contains { _, date in
            let taskDate = calendar.startOfDay(for: date)
            return taskDate == today || taskDate == yesterday
        }
        
        if !isActive {
            currentStreak = 0
        }
        
        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastCompletionDate: sortedTasks.first?.date
        )
    }
    
    /// Executes determineRank.
    private func determineRank(level: Int) -> String {
        switch level {
        case 0..<5: return "Beginner"
        case 5..<10: return "Novice"
        case 10..<20: return "Intermediate"
        case 20..<30: return "Advanced"
        case 30..<50: return "Expert"
        case 50..<75: return "Master"
        case 75..<100: return "Grandmaster"
        default: return "Legend"
        }
    }

    private func dailyCacheKey(for date: Date, habitSignals: [TaskerHabitSignal] = []) -> String {
        let base = String(Calendar.current.startOfDay(for: date).timeIntervalSinceReferenceDate)
        guard !habitSignals.isEmpty else { return base }
        let fingerprint = habitSignals
            .sorted { lhs, rhs in
                if lhs.habitID != rhs.habitID {
                    return lhs.habitID.uuidString < rhs.habitID.uuidString
                }
                let lhsDueAt = lhs.dueAt?.timeIntervalSinceReferenceDate ?? -.infinity
                let rhsDueAt = rhs.dueAt?.timeIntervalSinceReferenceDate ?? -.infinity
                return lhsDueAt < rhsDueAt
            }
            .map { signal in
                [
                    signal.habitID.uuidString,
                    signal.dueAt.map { String($0.timeIntervalSinceReferenceDate) } ?? "nil",
                    signal.outcomeRaw ?? "nil",
                    signal.riskStateRaw ?? "nil",
                    String(signal.currentStreak),
                    String(signal.bestStreak)
                ].joined(separator: "|")
            }
            .joined(separator: "||")
        return "\(base)::\(fingerprint)"
    }

    private func periodCacheKey(startDate: Date, endDate: Date) -> String {
        "\(Calendar.current.startOfDay(for: startDate).timeIntervalSinceReferenceDate):\(Calendar.current.startOfDay(for: endDate).timeIntervalSinceReferenceDate)"
    }

    private func computeHabitAnalytics(signals: [TaskerHabitSignal], date: Date) -> HabitAnalyticsSnapshot {
        guard signals.isEmpty == false else {
            return HabitAnalyticsSnapshot(date: date)
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let dueSignals = signals.filter { signal in
            if signal.isDueToday { return true }
            guard let dueAt = signal.dueAt else { return false }
            return dueAt >= startOfDay && dueAt < endOfDay
        }
        let positiveHabitCount = signals.filter(\.isPositive).count
        let negativeHabitCount = signals.filter { !$0.isPositive }.count
        let completedPositiveHabits = dueSignals.filter {
            $0.isPositive && Self.isSuccessfulHabitOutcome($0.outcomeRaw)
        }.count
        let successfulNegativeCheckIns = dueSignals.filter {
            !$0.isPositive && Self.isSuccessfulHabitOutcome($0.outcomeRaw)
        }.count
        let lapseCount = dueSignals.filter {
            Self.isLapseHabitOutcome($0.outcomeRaw)
        }.count
        let missedHabits = dueSignals.filter {
            Self.isMissedHabitOutcome($0.outcomeRaw)
        }.count
        let skippedHabits = dueSignals.filter {
            Self.isSkippedHabitOutcome($0.outcomeRaw)
        }.count
        let successCount = completedPositiveHabits + successfulNegativeCheckIns
        let adherenceRate = dueSignals.isEmpty ? 0 : Double(successCount) / Double(dueSignals.count)

        return HabitAnalyticsSnapshot(
            date: date,
            dueHabits: dueSignals.count,
            completedPositiveHabits: completedPositiveHabits,
            successfulNegativeCheckIns: successfulNegativeCheckIns,
            lapseCount: lapseCount,
            missedHabits: missedHabits,
            skippedHabits: skippedHabits,
            adherenceRate: adherenceRate,
            positiveHabitCount: positiveHabitCount,
            negativeHabitCount: negativeHabitCount
        )
    }

    private static func isSuccessfulHabitOutcome(_ outcomeRaw: String?) -> Bool {
        guard let value = outcomeRaw?.lowercased() else { return false }
        return ["completed", "abstained", "success", "successful"].contains(value)
    }

    private static func isLapseHabitOutcome(_ outcomeRaw: String?) -> Bool {
        guard let value = outcomeRaw?.lowercased() else { return false }
        return ["lapsed", "lapse"].contains(value)
    }

    private static func isMissedHabitOutcome(_ outcomeRaw: String?) -> Bool {
        guard let value = outcomeRaw?.lowercased() else { return false }
        return value == "missed"
    }

    private static func isSkippedHabitOutcome(_ outcomeRaw: String?) -> Bool {
        guard let value = outcomeRaw?.lowercased() else { return false }
        return ["skipped", "skip"].contains(value)
    }
}

// MARK: - Analytics Models

public struct HabitAnalyticsSnapshot: Equatable, Sendable {
    public let date: Date
    public let dueHabits: Int
    public let completedPositiveHabits: Int
    public let successfulNegativeCheckIns: Int
    public let lapseCount: Int
    public let missedHabits: Int
    public let skippedHabits: Int
    public let adherenceRate: Double
    public let positiveHabitCount: Int
    public let negativeHabitCount: Int

    public init(
        date: Date = .now,
        dueHabits: Int = 0,
        completedPositiveHabits: Int = 0,
        successfulNegativeCheckIns: Int = 0,
        lapseCount: Int = 0,
        missedHabits: Int = 0,
        skippedHabits: Int = 0,
        adherenceRate: Double = 0,
        positiveHabitCount: Int = 0,
        negativeHabitCount: Int = 0
    ) {
        self.date = date
        self.dueHabits = dueHabits
        self.completedPositiveHabits = completedPositiveHabits
        self.successfulNegativeCheckIns = successfulNegativeCheckIns
        self.lapseCount = lapseCount
        self.missedHabits = missedHabits
        self.skippedHabits = skippedHabits
        self.adherenceRate = adherenceRate
        self.positiveHabitCount = positiveHabitCount
        self.negativeHabitCount = negativeHabitCount
    }

    public func combining(_ other: HabitAnalyticsSnapshot) -> HabitAnalyticsSnapshot {
        let due = dueHabits + other.dueHabits
        let success = completedPositiveHabits + successfulNegativeCheckIns
        let otherSuccess = other.completedPositiveHabits + other.successfulNegativeCheckIns
        let totalSuccess = success + otherSuccess
        return HabitAnalyticsSnapshot(
            date: max(date, other.date),
            dueHabits: due,
            completedPositiveHabits: completedPositiveHabits + other.completedPositiveHabits,
            successfulNegativeCheckIns: successfulNegativeCheckIns + other.successfulNegativeCheckIns,
            lapseCount: lapseCount + other.lapseCount,
            missedHabits: missedHabits + other.missedHabits,
            skippedHabits: skippedHabits + other.skippedHabits,
            adherenceRate: due > 0 ? Double(totalSuccess) / Double(due) : 0,
            positiveHabitCount: positiveHabitCount + other.positiveHabitCount,
            negativeHabitCount: negativeHabitCount + other.negativeHabitCount
        )
    }
}

public struct TaskerHabitSignal: Equatable, Sendable {
    public let habitID: UUID
    public let title: String
    public let isPositive: Bool
    public let trackingModeRaw: String?
    public let lifeAreaName: String?
    public let projectName: String?
    public let iconSymbolName: String?
    public let iconCategoryKey: String?
    public let dueAt: Date?
    public let isDueToday: Bool
    public let isOverdue: Bool
    public let currentStreak: Int
    public let bestStreak: Int
    public let riskStateRaw: String?
    public let outcomeRaw: String?
    public let occurredAt: Date?
    public let keywords: [String]
    public let last14Days: [HabitDayMark]
    public let colorHex: String?
    public let cadence: HabitCadenceDraft?

    public init(
        habitID: UUID,
        title: String,
        isPositive: Bool,
        trackingModeRaw: String?,
        lifeAreaName: String?,
        projectName: String?,
        iconSymbolName: String?,
        iconCategoryKey: String?,
        dueAt: Date?,
        isDueToday: Bool,
        isOverdue: Bool,
        currentStreak: Int,
        bestStreak: Int,
        riskStateRaw: String?,
        outcomeRaw: String?,
        occurredAt: Date?,
        keywords: [String],
        last14Days: [HabitDayMark] = [],
        colorHex: String? = nil,
        cadence: HabitCadenceDraft? = nil
    ) {
        self.habitID = habitID
        self.title = title
        self.isPositive = isPositive
        self.trackingModeRaw = trackingModeRaw
        self.lifeAreaName = lifeAreaName
        self.projectName = projectName
        self.iconSymbolName = iconSymbolName
        self.iconCategoryKey = iconCategoryKey
        self.dueAt = dueAt
        self.isDueToday = isDueToday
        self.isOverdue = isOverdue
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.riskStateRaw = riskStateRaw
        self.outcomeRaw = outcomeRaw
        self.occurredAt = occurredAt
        self.keywords = keywords
        self.last14Days = last14Days
        self.colorHex = colorHex
        self.cadence = cadence
    }

    public init(summary: HabitOccurrenceSummary, referenceDate: Date = Date()) {
        let startOfReferenceDay = Calendar.current.startOfDay(for: referenceDate)
        let dueAt = summary.dueAt
        let isOverdue = {
            guard let dueAt else { return false }
            switch summary.state {
            case .completed, .skipped, .failed:
                return false
            case .pending, .missed:
                return dueAt < startOfReferenceDay
            }
        }()
        self.init(
            habitID: summary.habitID,
            title: summary.title,
            isPositive: summary.kind == .positive,
            trackingModeRaw: summary.trackingMode.rawValue,
            lifeAreaName: summary.lifeAreaName,
            projectName: summary.projectName,
            iconSymbolName: summary.icon?.symbolName,
            iconCategoryKey: summary.icon?.categoryKey,
            dueAt: dueAt,
            isDueToday: dueAt.map { Calendar.current.isDate($0, inSameDayAs: referenceDate) } ?? false,
            isOverdue: isOverdue,
            currentStreak: summary.currentStreak,
            bestStreak: summary.bestStreak,
            riskStateRaw: summary.riskState.rawValue,
            outcomeRaw: Self.outcomeRaw(for: summary.state),
            occurredAt: dueAt,
            keywords: [summary.title, summary.lifeAreaName, summary.projectName, summary.icon?.categoryKey].compactMap { $0 },
            last14Days: summary.last14Days,
            colorHex: summary.colorHex,
            cadence: summary.cadence
        )
    }

    private static func outcomeRaw(for state: OccurrenceState) -> String? {
        switch state {
        case .completed:
            return "completed"
        case .failed:
            return "lapsed"
        case .missed:
            return "missed"
        case .skipped:
            return "skipped"
        case .pending:
            return nil
        }
    }
}

public struct DailyAnalytics {
    public let date: Date
    public let totalTasks: Int
    public let completedTasks: Int
    public let completionRate: Double
    public let totalScore: Int
    public let morningTasksCompleted: Int
    public let eveningTasksCompleted: Int
    public let priorityBreakdown: [TaskPriority: Int]
    public let habitAnalytics: HabitAnalyticsSnapshot
    
    /// Initializes a new instance.
    init(
        date: Date,
        totalTasks: Int = 0,
        completedTasks: Int = 0,
        completionRate: Double = 0,
        totalScore: Int = 0,
        morningTasksCompleted: Int = 0,
        eveningTasksCompleted: Int = 0,
        priorityBreakdown: [TaskPriority: Int] = [:],
        habitAnalytics: HabitAnalyticsSnapshot = .init()
    ) {
        self.date = date
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
        self.completionRate = completionRate
        self.totalScore = totalScore
        self.morningTasksCompleted = morningTasksCompleted
        self.eveningTasksCompleted = eveningTasksCompleted
        self.priorityBreakdown = priorityBreakdown
        self.habitAnalytics = habitAnalytics
    }
}

public struct WeeklyAnalytics {
    public let weekStartDate: Date
    public let weekEndDate: Date
    public let dailyAnalytics: [DailyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveDay: DailyAnalytics?
    public let leastProductiveDay: DailyAnalytics?
    public let habitAnalytics: HabitAnalyticsSnapshot
}

public struct MonthlyAnalytics {
    public let month: Date
    public let weeklyBreakdown: [WeeklyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveWeek: WeeklyAnalytics?
    public let projectBreakdown: [String: Int]
    public let priorityBreakdown: [TaskPriority: Int]
    public let habitAnalytics: HabitAnalyticsSnapshot
}

public struct PeriodAnalytics {
    public let startDate: Date
    public let endDate: Date
    public let dailyBreakdown: [DailyAnalytics]
    public let totalScore: Int
    public let totalTasksCompleted: Int
    public let completionRate: Double
    public let averageTasksPerDay: Double
    public let mostProductiveDay: DailyAnalytics?
    public let leastProductiveDay: DailyAnalytics?
    public let projectBreakdown: [String: Int]
    public let priorityBreakdown: [TaskPriority: Int]
    public let habitAnalytics: HabitAnalyticsSnapshot
    
    /// Initializes a new instance.
    init(
        startDate: Date,
        endDate: Date,
        dailyBreakdown: [DailyAnalytics] = [],
        totalScore: Int = 0,
        totalTasksCompleted: Int = 0,
        completionRate: Double = 0,
        averageTasksPerDay: Double = 0,
        mostProductiveDay: DailyAnalytics? = nil,
        leastProductiveDay: DailyAnalytics? = nil,
        projectBreakdown: [String: Int] = [:],
        priorityBreakdown: [TaskPriority: Int] = [:],
        habitAnalytics: HabitAnalyticsSnapshot = .init()
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.dailyBreakdown = dailyBreakdown
        self.totalScore = totalScore
        self.totalTasksCompleted = totalTasksCompleted
        self.completionRate = completionRate
        self.averageTasksPerDay = averageTasksPerDay
        self.mostProductiveDay = mostProductiveDay
        self.leastProductiveDay = leastProductiveDay
        self.projectBreakdown = projectBreakdown
        self.priorityBreakdown = priorityBreakdown
        self.habitAnalytics = habitAnalytics
    }
}

public struct ProductivityScore {
    public let totalScore: Int
    public let level: Int
    public let currentLevelProgress: Int
    public let nextLevelRequirement: Int
    public let rank: String
    
    /// Initializes a new instance.
    init(
        totalScore: Int = 0,
        level: Int = 0,
        currentLevelProgress: Int = 0,
        nextLevelRequirement: Int = 100,
        rank: String = "Beginner"
    ) {
        self.totalScore = totalScore
        self.level = level
        self.currentLevelProgress = currentLevelProgress
        self.nextLevelRequirement = nextLevelRequirement
        self.rank = rank
    }
}

public struct StreakInfo {
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastCompletionDate: Date?
    
    /// Initializes a new instance.
    init(currentStreak: Int = 0, longestStreak: Int = 0, lastCompletionDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletionDate = lastCompletionDate
    }
}

// MARK: - Error Types

public enum AnalyticsError: LocalizedError {
    case repositoryError(Error)
    case invalidDateRange
    case insufficientData
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidDateRange:
            return "Invalid date range specified"
        case .insufficientData:
            return "Insufficient data for analytics calculation"
        }
    }
}

// MARK: - Scoring Service Protocol

public protocol TaskScoringServiceProtocol {
    /// Executes calculateScore.
    func calculateScore(for task: TaskDefinition) -> Int
    /// Executes getTotalScore.
    func getTotalScore(completion: @escaping (Int) -> Void)
    /// Executes getScoreHistory.
    func getScoreHistory(days: Int, completion: @escaping ([DailyScore]) -> Void)
}

public struct DailyScore {
    public let date: Date
    public let score: Int
    
    /// Initializes a new instance.
    public init(date: Date, score: Int) {
        self.date = date
        self.score = score
    }
}

// MARK: - Default Scoring Service

public class DefaultTaskScoringService: TaskScoringServiceProtocol {
    
    /// Initializes a new instance.
    public init() {}
    
    /// Executes calculateScore.
    public func calculateScore(for task: TaskDefinition) -> Int {
        guard task.isComplete else { return 0 }
        return task.priority.scorePoints
    }
    
    /// Executes getTotalScore.
    public func getTotalScore(completion: @escaping (Int) -> Void) {
        // This would typically fetch from a persistent store
        completion(0)
    }
    
    /// Executes getScoreHistory.
    public func getScoreHistory(days: Int, completion: @escaping ([DailyScore]) -> Void) {
        // This would typically fetch from a persistent store
        completion([])
    }
}
