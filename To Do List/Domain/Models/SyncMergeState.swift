import Foundation

public enum ReminderScalarField: String, Codable, CaseIterable {
    case title
    case notes
    case dueDate
    case completionDate
    case isCompleted
    case priority
    case urlString
}

public struct SyncClock: Codable, Equatable, Hashable, Comparable {
    public var physicalMillis: Int64
    public var logicalCounter: Int64
    public var nodeID: String

    public init(physicalMillis: Int64, logicalCounter: Int64, nodeID: String) {
        self.physicalMillis = physicalMillis
        self.logicalCounter = logicalCounter
        self.nodeID = nodeID
    }

    public static func now(nodeID: String, base: SyncClock? = nil, date: Date = Date()) -> SyncClock {
        next(
            nodeID: nodeID,
            base: base,
            observedMillis: Int64(date.timeIntervalSince1970 * 1_000)
        )
    }

    public static func next(
        nodeID: String,
        base: SyncClock?,
        observedMillis: Int64
    ) -> SyncClock {
        guard let base else {
            return SyncClock(
                physicalMillis: observedMillis,
                logicalCounter: 0,
                nodeID: nodeID
            )
        }
        if observedMillis > base.physicalMillis {
            return SyncClock(
                physicalMillis: observedMillis,
                logicalCounter: 0,
                nodeID: nodeID
            )
        }
        return SyncClock(
            physicalMillis: base.physicalMillis,
            logicalCounter: base.logicalCounter + 1,
            nodeID: nodeID
        )
    }

    public static func < (lhs: SyncClock, rhs: SyncClock) -> Bool {
        if lhs.physicalMillis != rhs.physicalMillis {
            return lhs.physicalMillis < rhs.physicalMillis
        }
        if lhs.logicalCounter != rhs.logicalCounter {
            return lhs.logicalCounter < rhs.logicalCounter
        }
        return lhs.nodeID < rhs.nodeID
    }
}

public struct ReminderFieldClock: Codable, Equatable, Hashable {
    public var title: SyncClock?
    public var notes: SyncClock?
    public var dueDate: SyncClock?
    public var completionDate: SyncClock?
    public var isCompleted: SyncClock?
    public var priority: SyncClock?
    public var urlString: SyncClock?

    public init(
        title: SyncClock? = nil,
        notes: SyncClock? = nil,
        dueDate: SyncClock? = nil,
        completionDate: SyncClock? = nil,
        isCompleted: SyncClock? = nil,
        priority: SyncClock? = nil,
        urlString: SyncClock? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.completionDate = completionDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.urlString = urlString
    }

    public subscript(field: ReminderScalarField) -> SyncClock? {
        get {
            switch field {
            case .title:
                return title
            case .notes:
                return notes
            case .dueDate:
                return dueDate
            case .completionDate:
                return completionDate
            case .isCompleted:
                return isCompleted
            case .priority:
                return priority
            case .urlString:
                return urlString
            }
        }
        set {
            switch field {
            case .title:
                title = newValue
            case .notes:
                notes = newValue
            case .dueDate:
                dueDate = newValue
            case .completionDate:
                completionDate = newValue
            case .isCompleted:
                isCompleted = newValue
            case .priority:
                priority = newValue
            case .urlString:
                urlString = newValue
            }
        }
    }
}

public struct ReminderMergeState: Codable, Equatable, Hashable {
    public var fieldClocks: ReminderFieldClock
    public var alarmAddSet: [String: SyncClock]
    public var alarmRemoveSet: [String: SyncClock]
    public var tombstoneClock: SyncClock?
    public var lastWriteClock: SyncClock?

    public init(
        fieldClocks: ReminderFieldClock = ReminderFieldClock(),
        alarmAddSet: [String: SyncClock] = [:],
        alarmRemoveSet: [String: SyncClock] = [:],
        tombstoneClock: SyncClock? = nil,
        lastWriteClock: SyncClock? = nil
    ) {
        self.fieldClocks = fieldClocks
        self.alarmAddSet = alarmAddSet
        self.alarmRemoveSet = alarmRemoveSet
        self.tombstoneClock = tombstoneClock
        self.lastWriteClock = lastWriteClock
    }

    public static func decode(from data: Data?) -> ReminderMergeState {
        guard let data else {
            return ReminderMergeState()
        }
        let decoder = JSONDecoder()
        return (try? decoder.decode(ReminderMergeState.self, from: data)) ?? ReminderMergeState()
    }

    public func encodedData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(self)
    }
}

public struct ReminderMergeEnvelope: Codable, Equatable, Hashable {
    public struct KnownFields: Codable, Equatable, Hashable {
        public var title: String
        public var notes: String?
        public var dueDate: Date?
        public var completionDate: Date?
        public var isCompleted: Bool
        public var priority: Int
        public var urlString: String?
        public var alarmDates: [Date]

        public init(
            title: String,
            notes: String? = nil,
            dueDate: Date? = nil,
            completionDate: Date? = nil,
            isCompleted: Bool = false,
            priority: Int = 0,
            urlString: String? = nil,
            alarmDates: [Date] = []
        ) {
            self.title = title
            self.notes = notes
            self.dueDate = dueDate
            self.completionDate = completionDate
            self.isCompleted = isCompleted
            self.priority = priority
            self.urlString = urlString
            self.alarmDates = alarmDates
        }
    }

    public var schemaVersion: Int
    public var known: KnownFields
    public var passthroughData: Data?

    public init(
        schemaVersion: Int = 1,
        known: KnownFields,
        passthroughData: Data? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.known = known
        self.passthroughData = passthroughData
    }
}
