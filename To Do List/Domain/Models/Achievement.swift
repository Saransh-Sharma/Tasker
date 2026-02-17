import Foundation

public struct AchievementUnlockDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var achievementKey: String
    public var unlockedAt: Date
    public var sourceEventID: UUID?
}
