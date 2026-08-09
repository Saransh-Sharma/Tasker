import Foundation

public struct AchievementUnlockDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var achievementKey: String
    public var unlockedAt: Date
    public var sourceEventID: UUID?

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(id: UUID, achievementKey: String, unlockedAt: Date, sourceEventID: UUID? = nil) {
        self.id = id
        self.achievementKey = achievementKey
        self.unlockedAt = unlockedAt
        self.sourceEventID = sourceEventID
    }
}

public struct AchievementProgressState: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { key }
    public let key: String
    public let name: String
    public let description: String
    public let unlocked: Bool
    public let progressCurrent: Int
    public let progressTarget: Int
    public let unlockDate: Date?

    public var progressFraction: Double {
        guard progressTarget > 0 else { return unlocked ? 1 : 0 }
        let ratio = Double(max(0, progressCurrent)) / Double(progressTarget)
        return min(1, ratio)
    }

    public var progressLabel: String {
        if unlocked {
            return "Unlocked"
        }
        return "\(min(progressCurrent, progressTarget))/\(progressTarget)"
    }

    public init(
        key: String,
        name: String,
        description: String,
        unlocked: Bool,
        progressCurrent: Int,
        progressTarget: Int,
        unlockDate: Date?
    ) {
        self.key = key
        self.name = name
        self.description = description
        self.unlocked = unlocked
        self.progressCurrent = max(0, progressCurrent)
        self.progressTarget = max(1, progressTarget)
        self.unlockDate = unlockDate
    }
}
