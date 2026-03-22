import Foundation

public struct HabitDefinitionRecord: Codable, Equatable, Hashable {
    public let id: UUID
    public var lifeAreaID: UUID?
    public var projectID: UUID?
    public var title: String
    public var habitType: String
    public var kindRaw: String?
    public var trackingModeRaw: String?
    public var iconSymbolName: String?
    public var iconCategoryKey: String?
    public var targetConfigData: Data?
    public var metricConfigData: Data?
    public var notes: String?
    public var isPaused: Bool
    public var archivedAt: Date?
    public var lastGeneratedDate: Date?
    public var streakCurrent: Int
    public var streakBest: Int
    public var successMask14Raw: Int16
    public var failureMask14Raw: Int16
    public var lastHistoryRollDate: Date?
    public var createdAt: Date
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        lifeAreaID: UUID? = nil,
        projectID: UUID? = nil,
        title: String,
        habitType: String,
        kindRaw: String? = nil,
        trackingModeRaw: String? = nil,
        iconSymbolName: String? = nil,
        iconCategoryKey: String? = nil,
        targetConfigData: Data? = nil,
        metricConfigData: Data? = nil,
        notes: String? = nil,
        isPaused: Bool = false,
        archivedAt: Date? = nil,
        lastGeneratedDate: Date? = nil,
        streakCurrent: Int = 0,
        streakBest: Int = 0,
        successMask14Raw: Int16 = 0,
        failureMask14Raw: Int16 = 0,
        lastHistoryRollDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.title = title
        self.habitType = habitType
        self.kindRaw = kindRaw
        self.trackingModeRaw = trackingModeRaw
        self.iconSymbolName = iconSymbolName
        self.iconCategoryKey = iconCategoryKey
        self.targetConfigData = targetConfigData
        self.metricConfigData = metricConfigData
        self.notes = notes
        self.isPaused = isPaused
        self.archivedAt = archivedAt
        self.lastGeneratedDate = lastGeneratedDate
        self.streakCurrent = streakCurrent
        self.streakBest = streakBest
        self.successMask14Raw = successMask14Raw
        self.failureMask14Raw = failureMask14Raw
        self.lastHistoryRollDate = lastHistoryRollDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension HabitDefinitionRecord {
    var kind: HabitKind {
        get {
            if let kindRaw, let resolved = HabitKind(rawValue: kindRaw) {
                return resolved
            }
            return .positive
        }
        set {
            kindRaw = newValue.rawValue
        }
    }

    var trackingMode: HabitTrackingMode {
        get {
            if let trackingModeRaw, let resolved = HabitTrackingMode(rawValue: trackingModeRaw) {
                return resolved
            }
            return .dailyCheckIn
        }
        set {
            trackingModeRaw = newValue.rawValue
        }
    }

    var icon: HabitIconMetadata? {
        get {
            guard let iconSymbolName, let iconCategoryKey else { return nil }
            return HabitIconMetadata(symbolName: iconSymbolName, categoryKey: iconCategoryKey)
        }
        set {
            iconSymbolName = newValue?.symbolName
            iconCategoryKey = newValue?.categoryKey
        }
    }

    var targetConfig: HabitTargetConfig? {
        get {
            guard let targetConfigData else { return nil }
            return try? JSONDecoder().decode(HabitTargetConfig.self, from: targetConfigData)
        }
        set {
            targetConfigData = try? JSONEncoder().encode(newValue)
        }
    }

    var metricConfig: HabitMetricConfig? {
        get {
            guard let metricConfigData else { return nil }
            return try? JSONDecoder().decode(HabitMetricConfig.self, from: metricConfigData)
        }
        set {
            metricConfigData = try? JSONEncoder().encode(newValue)
        }
    }

    var successMask14: UInt16 {
        get { UInt16(bitPattern: successMask14Raw) }
        set { successMask14Raw = Int16(bitPattern: newValue) }
    }

    var failureMask14: UInt16 {
        get { UInt16(bitPattern: failureMask14Raw) }
        set { failureMask14Raw = Int16(bitPattern: newValue) }
    }

    var isArchived: Bool {
        archivedAt != nil
    }
}
