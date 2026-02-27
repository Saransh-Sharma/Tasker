import Foundation

/// Data snapshot written by the app and read by widgets.
/// Serialized as JSON to the App Group container.
public struct GamificationWidgetSnapshot: Codable {
    public var dailyXP: Int
    public var dailyCap: Int
    public var level: Int
    public var totalXP: Int64
    public var nextLevelXP: Int64
    public var currentLevelThreshold: Int64
    public var streakDays: Int
    public var bestStreak: Int
    public var tasksCompletedToday: Int
    public var focusMinutesToday: Int

    // Weekly bars (7 entries, Mon-Sun)
    public var weeklyXP: [Int]  // 7 elements
    public var weeklyTotalXP: Int

    // Next milestone
    public var nextMilestoneName: String?
    public var nextMilestoneXP: Int64?
    public var milestoneProgress: Double  // 0.0-1.0

    public var updatedAt: Date

    public init(
        dailyXP: Int = 0,
        dailyCap: Int = 250,
        level: Int = 1,
        totalXP: Int64 = 0,
        nextLevelXP: Int64 = 0,
        currentLevelThreshold: Int64 = 0,
        streakDays: Int = 0,
        bestStreak: Int = 0,
        tasksCompletedToday: Int = 0,
        focusMinutesToday: Int = 0,
        weeklyXP: [Int] = Array(repeating: 0, count: 7),
        weeklyTotalXP: Int = 0,
        nextMilestoneName: String? = nil,
        nextMilestoneXP: Int64? = nil,
        milestoneProgress: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.dailyXP = dailyXP
        self.dailyCap = dailyCap
        self.level = level
        self.totalXP = totalXP
        self.nextLevelXP = nextLevelXP
        self.currentLevelThreshold = currentLevelThreshold
        self.streakDays = streakDays
        self.bestStreak = bestStreak
        self.tasksCompletedToday = tasksCompletedToday
        self.focusMinutesToday = focusMinutesToday
        self.weeklyXP = weeklyXP
        self.weeklyTotalXP = weeklyTotalXP
        self.nextMilestoneName = nextMilestoneName
        self.nextMilestoneXP = nextMilestoneXP
        self.milestoneProgress = milestoneProgress
        self.updatedAt = updatedAt
    }

    // MARK: - Read / Write

    public static func load() -> GamificationWidgetSnapshot {
        guard let url = AppGroupConstants.snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(GamificationWidgetSnapshot.self, from: data) else {
            return GamificationWidgetSnapshot()
        }
        return snapshot
    }

    public func save() {
        guard let url = AppGroupConstants.snapshotURL,
              let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
