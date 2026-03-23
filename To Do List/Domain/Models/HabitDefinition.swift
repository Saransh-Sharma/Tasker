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

    private enum CodingKeys: String, CodingKey {
        case id
        case lifeAreaID
        case projectID
        case title
        case habitType
        case kindRaw
        case trackingModeRaw
        case iconSymbolName
        case iconCategoryKey
        case targetConfigData
        case metricConfigData
        case notes
        case isPaused
        case archivedAt
        case lastGeneratedDate
        case streakCurrent
        case streakBest
        case successMask14Raw
        case failureMask14Raw
        case lastHistoryRollDate
        case createdAt
        case updatedAt
    }

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        lifeAreaID: UUID? = nil,
        projectID: UUID? = nil,
        title: String,
        habitType: String,
        kindRaw: String? = HabitKind.positive.rawValue,
        trackingModeRaw: String? = HabitTrackingMode.dailyCheckIn.rawValue,
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
        self.kindRaw = Self.canonicalKindRaw(kindRaw)
        self.trackingModeRaw = Self.canonicalTrackingModeRaw(trackingModeRaw)
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            lifeAreaID: try container.decodeIfPresent(UUID.self, forKey: .lifeAreaID),
            projectID: try container.decodeIfPresent(UUID.self, forKey: .projectID),
            title: try container.decode(String.self, forKey: .title),
            habitType: try container.decode(String.self, forKey: .habitType),
            kindRaw: Self.canonicalKindRaw(try container.decodeIfPresent(String.self, forKey: .kindRaw)),
            trackingModeRaw: Self.canonicalTrackingModeRaw(try container.decodeIfPresent(String.self, forKey: .trackingModeRaw)),
            iconSymbolName: try container.decodeIfPresent(String.self, forKey: .iconSymbolName),
            iconCategoryKey: try container.decodeIfPresent(String.self, forKey: .iconCategoryKey),
            targetConfigData: try container.decodeIfPresent(Data.self, forKey: .targetConfigData),
            metricConfigData: try container.decodeIfPresent(Data.self, forKey: .metricConfigData),
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            isPaused: try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false,
            archivedAt: try container.decodeIfPresent(Date.self, forKey: .archivedAt),
            lastGeneratedDate: try container.decodeIfPresent(Date.self, forKey: .lastGeneratedDate),
            streakCurrent: try container.decodeIfPresent(Int.self, forKey: .streakCurrent) ?? 0,
            streakBest: try container.decodeIfPresent(Int.self, forKey: .streakBest) ?? 0,
            successMask14Raw: try container.decodeIfPresent(Int16.self, forKey: .successMask14Raw) ?? 0,
            failureMask14Raw: try container.decodeIfPresent(Int16.self, forKey: .failureMask14Raw) ?? 0,
            lastHistoryRollDate: try container.decodeIfPresent(Date.self, forKey: .lastHistoryRollDate),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(lifeAreaID, forKey: .lifeAreaID)
        try container.encodeIfPresent(projectID, forKey: .projectID)
        try container.encode(title, forKey: .title)
        try container.encode(habitType, forKey: .habitType)
        try container.encode(Self.canonicalKindRaw(kindRaw), forKey: .kindRaw)
        try container.encode(Self.canonicalTrackingModeRaw(trackingModeRaw), forKey: .trackingModeRaw)
        try container.encodeIfPresent(iconSymbolName, forKey: .iconSymbolName)
        try container.encodeIfPresent(iconCategoryKey, forKey: .iconCategoryKey)
        try container.encodeIfPresent(targetConfigData, forKey: .targetConfigData)
        try container.encodeIfPresent(metricConfigData, forKey: .metricConfigData)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try container.encodeIfPresent(lastGeneratedDate, forKey: .lastGeneratedDate)
        try container.encode(streakCurrent, forKey: .streakCurrent)
        try container.encode(streakBest, forKey: .streakBest)
        try container.encode(successMask14Raw, forKey: .successMask14Raw)
        try container.encode(failureMask14Raw, forKey: .failureMask14Raw)
        try container.encodeIfPresent(lastHistoryRollDate, forKey: .lastHistoryRollDate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private static func canonicalKindRaw(_ value: String?) -> String {
        if let value, value.isEmpty == false {
            return value
        }
        return HabitKind.positive.rawValue
    }

    private static func canonicalTrackingModeRaw(_ value: String?) -> String {
        if let value, value.isEmpty == false {
            return value
        }
        return HabitTrackingMode.dailyCheckIn.rawValue
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
            guard let newValue else {
                targetConfigData = nil
                return
            }
            targetConfigData = try? JSONEncoder().encode(newValue)
        }
    }

    var metricConfig: HabitMetricConfig? {
        get {
            guard let metricConfigData else { return nil }
            return try? JSONDecoder().decode(HabitMetricConfig.self, from: metricConfigData)
        }
        set {
            guard let newValue else {
                metricConfigData = nil
                return
            }
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
