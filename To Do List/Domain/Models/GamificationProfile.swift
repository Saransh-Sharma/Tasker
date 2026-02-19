import Foundation

public struct GamificationSnapshot: Codable, Equatable, Hashable {
    public let id: UUID
    public var xpTotal: Int64
    public var level: Int
    public var currentStreak: Int
    public var bestStreak: Int
    public var lastActiveDate: Date?
    public var updatedAt: Date
}
