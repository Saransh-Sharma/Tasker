//
//  TaskGameificationUseCase.swift
//  Tasker
//
//  Use case for comprehensive gamification system - points, levels, badges, achievements
//

import Foundation

/// Use case for gamifying the task management experience
public final class TaskGameificationUseCase {
    
    // MARK: - Dependencies
    
    private let taskRepository: TaskRepositoryProtocol
    private let eventPublisher: DomainEventPublisher?
    
    // MARK: - Initialization
    
    public init(
        taskRepository: TaskRepositoryProtocol,
        eventPublisher: DomainEventPublisher? = nil
    ) {
        self.taskRepository = taskRepository
        self.eventPublisher = eventPublisher
    }
    
    // MARK: - Gamification Methods
    
    /// Calculate comprehensive user stats and level
    public func calculateUserProgress(
        completion: @escaping (Result<UserProgress, GameificationError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let progress = self?.computeUserProgress(from: allTasks) ?? UserProgress()
                completion(.success(progress))
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Process task completion and award points/achievements
    public func processTaskCompletion(
        task: Task,
        completionQuality: CompletionQuality = .standard,
        completion: @escaping (Result<GameificationReward, GameificationError>) -> Void
    ) {
        let basePoints = calculateTaskPoints(task: task, quality: completionQuality)
        let multipliers = calculateMultipliers(for: task)
        let totalPoints = Int(Double(basePoints) * multipliers.total)
        
        checkForNewAchievements(task: task) { [weak self] achievementResult in
            switch achievementResult {
            case .success(let newAchievements):
                let reward = GameificationReward(
                    pointsEarned: totalPoints,
                    bonusPoints: Int(Double(basePoints) * (multipliers.total - 1.0)),
                    newAchievements: newAchievements,
                    levelProgression: self?.checkLevelProgression(points: totalPoints),
                    streakBonus: self?.calculateStreakBonus(task: task) ?? 0,
                    multiplierBreakdown: multipliers
                )
                
                self?.eventPublisher?.publish(PointsEarned(points: totalPoints, task: task))
                for achievement in newAchievements {
                    self?.eventPublisher?.publish(AchievementUnlocked(achievement: achievement))
                }
                
                completion(.success(reward))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Get available achievements and progress toward them
    public func getAchievementProgress(
        completion: @escaping (Result<AchievementProgress, GameificationError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let progress = self?.calculateAchievementProgress(from: allTasks) ?? AchievementProgress()
                completion(.success(progress))
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    /// Get daily/weekly/monthly challenges
    public func getActiveChallenges(
        completion: @escaping (Result<[GameChallenge], GameificationError>) -> Void
    ) {
        let challenges = generateDynamicChallenges()
        completion(.success(challenges))
    }
    
    /// Calculate streak information
    public func calculateStreakInfo(
        completion: @escaping (Result<GameStreakInfo, GameificationError>) -> Void
    ) {
        taskRepository.fetchCompletedTasks { [weak self] result in
            switch result {
            case .success(let completedTasks):
                let streakInfo = self?.computeStreakInfo(from: completedTasks) ?? GameStreakInfo()
                completion(.success(streakInfo))
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func computeUserProgress(from tasks: [Task]) -> UserProgress {
        let completedTasks = tasks.filter { $0.isComplete }
        let totalPoints = completedTasks.reduce(0) { total, task in
            total + calculateTaskPoints(task: task, quality: .standard)
        }
        
        let level = calculateLevel(from: totalPoints)
        let achievements = computeEarnedAchievements(from: tasks)
        
        return UserProgress(
            totalPoints: totalPoints,
            currentLevel: level,
            completedTasks: completedTasks.count,
            totalTasks: tasks.count,
            achievements: achievements.map { $0.id },
            currentStreak: computeCurrentStreak(from: completedTasks),
            longestStreak: computeLongestStreak(from: completedTasks)
        )
    }
    
    private func calculateTaskPoints(task: Task, quality: CompletionQuality) -> Int {
        var basePoints = task.priority.scorePoints
        basePoints = Int(Double(basePoints) * quality.multiplier)
        
        // Category bonus
        switch task.category {
        case .health: basePoints += 2
        case .learning: basePoints += 3
        case .work: basePoints += 1
        default: break
        }
        
        // Energy bonus
        switch task.energy {
        case .high: basePoints += 2
        case .medium: basePoints += 1
        case .low: break
        }
        
        return max(basePoints, 1)
    }
    
    private func calculateMultipliers(for task: Task) -> MultiplierBreakdown {
        var timelyBonus: Double = 1.0
        let streakBonus: Double = 1.0
        let contextBonus: Double = 1.0
        
        // Timely completion bonus
        if let dueDate = task.dueDate {
            let hoursEarly = dueDate.timeIntervalSince(Date()) / 3600
            if hoursEarly > 0 {
                timelyBonus = 1.2
            } else if hoursEarly > -24 {
                timelyBonus = 1.1
            }
        }
        
        return MultiplierBreakdown(
            timelyBonus: timelyBonus,
            streakBonus: streakBonus,
            contextBonus: contextBonus,
            total: timelyBonus * streakBonus * contextBonus
        )
    }
    
    private func calculateLevel(from points: Int) -> UserLevel {
        let level = min(Int(sqrt(Double(points) / 100)), 50) + 1
        let pointsForCurrentLevel = (level - 1) * (level - 1) * 100
        let pointsForNextLevel = level * level * 100
        let progressToNext = Double(points - pointsForCurrentLevel) / Double(pointsForNextLevel - pointsForCurrentLevel)
        
        return UserLevel(
            level: level,
            title: getLevelTitle(for: level),
            currentLevelPoints: pointsForCurrentLevel,
            nextLevelPoints: pointsForNextLevel,
            progressToNext: min(max(progressToNext, 0), 1)
        )
    }
    
    private func getLevelTitle(for level: Int) -> String {
        switch level {
        case 1...5: return "Beginner"
        case 6...10: return "Apprentice"
        case 11...15: return "Skilled"
        case 16...20: return "Expert"
        case 21...30: return "Master"
        case 31...40: return "Grandmaster"
        case 41...50: return "Legend"
        default: return "Ultimate"
        }
    }
    
    private func checkForNewAchievements(
        task: Task,
        completion: @escaping (Result<[Achievement], GameificationError>) -> Void
    ) {
        taskRepository.fetchAllTasks { [weak self] result in
            switch result {
            case .success(let allTasks):
                let newAchievements = self?.evaluateAchievements(newTask: task, allTasks: allTasks) ?? []
                completion(.success(newAchievements))
            case .failure(let error):
                completion(.failure(.dataError(error)))
            }
        }
    }
    
    private func evaluateAchievements(newTask: Task, allTasks: [Task]) -> [Achievement] {
        var newAchievements: [Achievement] = []
        let completedTasks = allTasks.filter { $0.isComplete }
        
        // First task achievement
        if completedTasks.count == 1 {
            newAchievements.append(Achievement(
                id: "first_task",
                title: "Getting Started",
                description: "Complete your first task",
                icon: "🎯",
                rarity: .common,
                points: 10
            ))
        }
        
        // Streak achievements
        let currentStreak = computeCurrentStreak(from: completedTasks)
        if currentStreak == 7 {
            newAchievements.append(Achievement(
                id: "week_streak",
                title: "Week Warrior",
                description: "Complete tasks for 7 days in a row",
                icon: "🔥",
                rarity: .uncommon,
                points: 50
            ))
        }
        
        return newAchievements
    }
    
    private func calculateAchievementProgress(from tasks: [Task]) -> AchievementProgress {
        let earnedAchievements = computeEarnedAchievements(from: tasks)
        return AchievementProgress(
            totalAchievements: 10,
            earnedAchievements: earnedAchievements.count,
            inProgress: [],
            nextAchievement: nil
        )
    }
    
    private func computeEarnedAchievements(from tasks: [Task]) -> [Achievement] {
        let completedTasks = tasks.filter { $0.isComplete }
        var earned: [Achievement] = []
        
        if completedTasks.count >= 1 {
            earned.append(Achievement(id: "first_task", title: "Getting Started", description: "Complete your first task", icon: "🎯", rarity: .common, points: 10))
        }
        
        return earned
    }
    
    private func generateDynamicChallenges() -> [GameChallenge] {
        let today = Date()
        let calendar = Calendar.current
        
        return [
            GameChallenge(
                id: "daily_trio",
                title: "Daily Trio",
                description: "Complete 3 tasks today",
                type: .daily,
                targetValue: 3,
                currentProgress: 0,
                deadline: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)),
                rewardPoints: 15,
                rewardBadge: Badge(name: "Daily Achiever", icon: "⭐")
            )
        ]
    }
    
    private func computeCurrentStreak(from completedTasks: [Task]) -> Int {
        guard !completedTasks.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sortedTasks = completedTasks
            .compactMap { task -> Date? in
                guard let completionDate = task.dateCompleted else { return nil }
                return calendar.startOfDay(for: completionDate)
            }
            .sorted { $0 > $1 }
        
        var streak = 0
        var currentDate = today
        
        for taskDate in sortedTasks {
            if calendar.isDate(taskDate, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if taskDate < currentDate {
                break
            }
        }
        
        return streak
    }
    
    private func computeLongestStreak(from completedTasks: [Task]) -> Int {
        return max(computeCurrentStreak(from: completedTasks), 0)
    }
    
    private func computeStreakInfo(from completedTasks: [Task]) -> GameStreakInfo {
        let current = computeCurrentStreak(from: completedTasks)
        let longest = computeLongestStreak(from: completedTasks)
        
        return GameStreakInfo(
            currentStreak: current,
            longestStreak: longest,
            streakType: current >= 7 ? .week : .day,
            nextMilestone: getNextStreakMilestone(current: current),
            streakStartDate: getStreakStartDate(from: completedTasks, streakLength: current)
        )
    }
    
    private func getNextStreakMilestone(current: Int) -> Int {
        let milestones = [7, 14, 30, 60, 100, 365]
        return milestones.first { $0 > current } ?? (current + 365)
    }
    
    private func getStreakStartDate(from completedTasks: [Task], streakLength: Int) -> Date? {
        guard streakLength > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -(streakLength - 1), to: Date())
    }
    
    private func checkLevelProgression(points: Int) -> LevelProgression? {
        return nil // Simplified for now
    }
    
    private func calculateStreakBonus(task: Task) -> Int {
        return 5 // Base streak bonus
    }
}

// MARK: - Supporting Models

public enum CompletionQuality {
    case poor, standard, good, excellent
    
    var multiplier: Double {
        switch self {
        case .poor: return 0.5
        case .standard: return 1.0
        case .good: return 1.2
        case .excellent: return 1.5
        }
    }
}

public enum AchievementRarity: String, Codable {
    case common, uncommon, rare, epic, legendary
}

public enum ChallengeType {
    case daily, weekly, monthly, special
}

public enum StreakType {
    case day, week, month
}

public struct UserProgress: Codable {
    public let totalPoints: Int
    public let currentLevel: UserLevel
    public let completedTasks: Int
    public let totalTasks: Int
    public let achievements: [String]
    public let currentStreak: Int
    public let longestStreak: Int
    
    init(totalPoints: Int = 0, currentLevel: UserLevel = UserLevel(), completedTasks: Int = 0, totalTasks: Int = 0, achievements: [String] = [], currentStreak: Int = 0, longestStreak: Int = 0) {
        self.totalPoints = totalPoints
        self.currentLevel = currentLevel
        self.completedTasks = completedTasks
        self.totalTasks = totalTasks
        self.achievements = achievements
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
    }
}

public struct UserLevel: Codable {
    public let level: Int
    public let title: String
    public let currentLevelPoints: Int
    public let nextLevelPoints: Int
    public let progressToNext: Double
    
    init(level: Int = 1, title: String = "Beginner", currentLevelPoints: Int = 0, nextLevelPoints: Int = 100, progressToNext: Double = 0) {
        self.level = level
        self.title = title
        self.currentLevelPoints = currentLevelPoints
        self.nextLevelPoints = nextLevelPoints
        self.progressToNext = progressToNext
    }
}

public struct Achievement: Codable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let rarity: AchievementRarity
    public let points: Int
    public let unlockedDate: Date?
    
    init(id: String, title: String, description: String, icon: String, rarity: AchievementRarity, points: Int, unlockedDate: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.rarity = rarity
        self.points = points
        self.unlockedDate = unlockedDate
    }
}

public struct GameificationReward {
    public let pointsEarned: Int
    public let bonusPoints: Int
    public let newAchievements: [Achievement]
    public let levelProgression: LevelProgression?
    public let streakBonus: Int
    public let multiplierBreakdown: MultiplierBreakdown
}

public struct MultiplierBreakdown {
    public let timelyBonus: Double
    public let streakBonus: Double
    public let contextBonus: Double
    public let total: Double
}

public struct LevelProgression {
    public let fromLevel: Int
    public let toLevel: Int
    public let newTitle: String
}

public struct AchievementProgress {
    public let totalAchievements: Int
    public let earnedAchievements: Int
    public let inProgress: [AchievementProgressItem]
    public let nextAchievement: AchievementProgressItem?
    
    init(totalAchievements: Int = 0, earnedAchievements: Int = 0, inProgress: [AchievementProgressItem] = [], nextAchievement: AchievementProgressItem? = nil) {
        self.totalAchievements = totalAchievements
        self.earnedAchievements = earnedAchievements
        self.inProgress = inProgress
        self.nextAchievement = nextAchievement
    }
}

public struct AchievementProgressItem {
    public let achievement: Achievement?
    public let currentProgress: Int
    public let targetProgress: Int
    public let progressPercentage: Double
}

public struct GameChallenge {
    public let id: String
    public let title: String
    public let description: String
    public let type: ChallengeType
    public let targetValue: Int
    public let currentProgress: Int
    public let deadline: Date?
    public let rewardPoints: Int
    public let rewardBadge: Badge?
}

public struct Badge {
    public let name: String
    public let icon: String
}

public struct GameStreakInfo {
    public let currentStreak: Int
    public let longestStreak: Int
    public let streakType: StreakType
    public let nextMilestone: Int
    public let streakStartDate: Date?
    
    init(currentStreak: Int = 0, longestStreak: Int = 0, streakType: StreakType = .day, nextMilestone: Int = 7, streakStartDate: Date? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.streakType = streakType
        self.nextMilestone = nextMilestone
        self.streakStartDate = streakStartDate
    }
}

// MARK: - Events

public struct PointsEarned: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "PointsEarned"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    public let points: Int
    public let task: Task
    
    public init(points: Int, task: Task, userId: UUID? = nil) {
        self.points = points
        self.task = task
        self.aggregateId = task.id
        self.userId = userId
        self.metadata = [
            "taskId": task.id.uuidString,
            "points": points,
            "userId": userId?.uuidString ?? "anonymous"
        ]
    }
}

public struct AchievementUnlocked: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "AchievementUnlocked"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    public let achievement: Achievement
    
    public init(achievement: Achievement, userId: UUID? = nil) {
        self.achievement = achievement
        self.aggregateId = UUID() // Generate a UUID for the achievement event aggregate
        self.userId = userId
        self.metadata = [
            "achievementId": achievement.id,
            "achievementTitle": achievement.title,
            "userId": userId?.uuidString ?? "anonymous"
        ]
    }
}

// MARK: - Error Types

public enum GameificationError: LocalizedError {
    case dataError(Error)
    case invalidInput
    
    public var errorDescription: String? {
        switch self {
        case .dataError(let error):
            return "Data error: \(error.localizedDescription)"
        case .invalidInput:
            return "Invalid input provided"
        }
    }
}
