import Foundation

public struct GamificationSnapshot: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var xpTotal: Int64
    public var level: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var lastActiveDate: Date?
    public var updatedAt: Date
    public var gamificationV2ActivatedAt: Date?
    public var nextLevelXP: Int64
    public var returnStreak: Int
    public var bestReturnStreak: Int

    public init(
        id: UUID = UUID(),
        xpTotal: Int64 = 0,
        level: Int = 1,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastActiveDate: Date? = nil,
        updatedAt: Date = Date(),
        gamificationV2ActivatedAt: Date? = nil,
        nextLevelXP: Int64 = 0,
        returnStreak: Int = 0,
        bestReturnStreak: Int = 0
    ) {
        self.id = id
        self.xpTotal = xpTotal
        self.level = level
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastActiveDate = lastActiveDate
        self.updatedAt = updatedAt
        self.gamificationV2ActivatedAt = gamificationV2ActivatedAt
        self.nextLevelXP = nextLevelXP
        self.returnStreak = returnStreak
        self.bestReturnStreak = bestReturnStreak
    }
}
