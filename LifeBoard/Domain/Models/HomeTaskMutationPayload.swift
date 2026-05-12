import Foundation

public struct HomeTaskMutationPayload: Equatable {
    public let reason: HomeTaskMutationEvent
    public let source: String
    public let taskID: UUID?
    public let affectedProjectID: UUID?
    public let previousIsComplete: Bool?
    public let newIsComplete: Bool?
    public let previousDueDate: Date?
    public let newDueDate: Date?
    public let previousCompletionDate: Date?
    public let newCompletionDate: Date?
    public let previousProjectID: UUID?
    public let newProjectID: UUID?
    public let previousPriorityRawValue: Int32?
    public let newPriorityRawValue: Int32?

    public init(
        reason: HomeTaskMutationEvent,
        source: String,
        taskID: UUID? = nil,
        affectedProjectID: UUID? = nil,
        previousIsComplete: Bool? = nil,
        newIsComplete: Bool? = nil,
        previousDueDate: Date? = nil,
        newDueDate: Date? = nil,
        previousCompletionDate: Date? = nil,
        newCompletionDate: Date? = nil,
        previousProjectID: UUID? = nil,
        newProjectID: UUID? = nil,
        previousPriorityRawValue: Int32? = nil,
        newPriorityRawValue: Int32? = nil
    ) {
        self.reason = reason
        self.source = source
        self.taskID = taskID
        self.affectedProjectID = affectedProjectID
        self.previousIsComplete = previousIsComplete
        self.newIsComplete = newIsComplete
        self.previousDueDate = previousDueDate
        self.newDueDate = newDueDate
        self.previousCompletionDate = previousCompletionDate
        self.newCompletionDate = newCompletionDate
        self.previousProjectID = previousProjectID
        self.newProjectID = newProjectID
        self.previousPriorityRawValue = previousPriorityRawValue
        self.newPriorityRawValue = newPriorityRawValue
    }

    public init?(notification: Notification) {
        guard let reasonRaw = notification.userInfo?["reason"] as? String,
              let reason = HomeTaskMutationEvent(rawValue: reasonRaw) else {
            return nil
        }

        self.init(
            reason: reason,
            source: notification.userInfo?["source"] as? String ?? "unknown",
            taskID: Self.uuidValue(for: "taskID", in: notification.userInfo),
            affectedProjectID: Self.uuidValue(for: "projectID", in: notification.userInfo),
            previousIsComplete: notification.userInfo?["previousIsComplete"] as? Bool,
            newIsComplete: notification.userInfo?["newIsComplete"] as? Bool
                ?? notification.userInfo?["isComplete"] as? Bool,
            previousDueDate: notification.userInfo?["previousDueDate"] as? Date,
            newDueDate: notification.userInfo?["newDueDate"] as? Date,
            previousCompletionDate: notification.userInfo?["previousCompletionDate"] as? Date,
            newCompletionDate: notification.userInfo?["newCompletionDate"] as? Date,
            previousProjectID: Self.uuidValue(for: "previousProjectID", in: notification.userInfo),
            newProjectID: Self.uuidValue(for: "newProjectID", in: notification.userInfo),
            previousPriorityRawValue: Self.int32Value(for: "previousPriority", in: notification.userInfo),
            newPriorityRawValue: Self.int32Value(for: "newPriority", in: notification.userInfo)
        )
    }

    public var userInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "reason": reason.rawValue,
            "source": source
        ]
        if let taskID {
            userInfo["taskID"] = taskID.uuidString
        }
        if let affectedProjectID {
            userInfo["projectID"] = affectedProjectID.uuidString
        }
        if let previousIsComplete {
            userInfo["previousIsComplete"] = previousIsComplete
        }
        if let newIsComplete {
            userInfo["newIsComplete"] = newIsComplete
            userInfo["isComplete"] = newIsComplete
        }
        if let previousDueDate {
            userInfo["previousDueDate"] = previousDueDate
        }
        if let newDueDate {
            userInfo["newDueDate"] = newDueDate
        }
        if let previousCompletionDate {
            userInfo["previousCompletionDate"] = previousCompletionDate
        }
        if let newCompletionDate {
            userInfo["newCompletionDate"] = newCompletionDate
        }
        if let previousProjectID {
            userInfo["previousProjectID"] = previousProjectID.uuidString
        }
        if let newProjectID {
            userInfo["newProjectID"] = newProjectID.uuidString
        }
        if let previousPriorityRawValue {
            userInfo["previousPriority"] = previousPriorityRawValue
        }
        if let newPriorityRawValue {
            userInfo["newPriority"] = newPriorityRawValue
        }
        return userInfo
    }

    private static func uuidValue(for key: String, in userInfo: [AnyHashable: Any]?) -> UUID? {
        if let uuid = userInfo?[key] as? UUID {
            return uuid
        }
        if let raw = userInfo?[key] as? String {
            return UUID(uuidString: raw)
        }
        return nil
    }

    private static func int32Value(for key: String, in userInfo: [AnyHashable: Any]?) -> Int32? {
        if let value = userInfo?[key] as? Int32 {
            return value
        }
        if let value = userInfo?[key] as? NSNumber {
            return value.int32Value
        }
        return nil
    }
}

public enum HomeTaskMutationReasonResolver {
    public static func reason(for request: UpdateTaskDefinitionRequest) -> HomeTaskMutationEvent {
        if request.projectID != nil {
            return .projectChanged
        }
        if request.priority != nil {
            return .priorityChanged
        }
        if request.type != nil {
            return .typeChanged
        }
        if request.dueDate != nil || request.clearDueDate {
            return .dueDateChanged
        }
        return .updated
    }
}

public enum ChartInvalidationPolicy {
    public static func shouldRefreshLineChart(
        for payload: HomeTaskMutationPayload,
        referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        switch payload.reason {
        case .updated, .typeChanged:
            return false
        case .bulkChanged:
            return true
        case .projectChanged:
            return false
        case .created, .deleted, .completed, .reopened, .rescheduled, .dueDateChanged, .priorityChanged:
            return taskAffectsLineChart(payload, referenceDate: referenceDate, calendar: calendar)
        }
    }

    public static func shouldRefreshRadarChart(
        for payload: HomeTaskMutationPayload,
        referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        switch payload.reason {
        case .updated, .typeChanged, .rescheduled, .dueDateChanged:
            return false
        case .bulkChanged:
            return true
        case .projectChanged:
            if payload.taskID == nil, payload.affectedProjectID != nil {
                return true
            }
            return taskAffectsRadarChart(payload, referenceDate: referenceDate, calendar: calendar)
        case .created, .deleted, .completed, .reopened, .priorityChanged:
            return taskAffectsRadarChart(payload, referenceDate: referenceDate, calendar: calendar)
        }
    }

    private static func taskAffectsLineChart(
        _ payload: HomeTaskMutationPayload,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        if payload.reason == .created {
            return payload.newIsComplete == true && anyDate([payload.newDueDate, payload.newCompletionDate], inSameWeekAs: referenceDate, calendar: calendar)
        }
        if payload.reason == .deleted {
            return payload.previousIsComplete == true && anyDate([payload.previousDueDate, payload.previousCompletionDate], inSameWeekAs: referenceDate, calendar: calendar)
        }
        let wasComplete = payload.previousIsComplete == true
        let isComplete = payload.newIsComplete == true
        guard wasComplete || isComplete else { return false }
        return anyDate(
            [payload.previousDueDate, payload.newDueDate, payload.previousCompletionDate, payload.newCompletionDate],
            inSameWeekAs: referenceDate,
            calendar: calendar
        )
    }

    private static func taskAffectsRadarChart(
        _ payload: HomeTaskMutationPayload,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        if payload.reason == .created {
            return payload.newIsComplete == true && anyDate([payload.newCompletionDate], inSameWeekAs: referenceDate, calendar: calendar)
        }
        if payload.reason == .deleted {
            return payload.previousIsComplete == true && anyDate([payload.previousCompletionDate], inSameWeekAs: referenceDate, calendar: calendar)
        }
        let wasComplete = payload.previousIsComplete == true
        let isComplete = payload.newIsComplete == true
        guard wasComplete || isComplete else { return false }
        return anyDate(
            [payload.previousCompletionDate, payload.newCompletionDate],
            inSameWeekAs: referenceDate,
            calendar: calendar
        )
    }

    private static func anyDate(
        _ dates: [Date?],
        inSameWeekAs referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        dates.contains { date in
            guard let date else { return false }
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .weekOfYear)
        }
    }
}

public enum HomeSearchInvalidationPolicy {
    public static func shouldRefreshSearch(for payload: HomeTaskMutationPayload) -> Bool {
        switch payload.reason {
        case .bulkChanged:
            return true
        case .projectChanged:
            return payload.taskID != nil || payload.affectedProjectID != nil
        case .created,
             .updated,
             .deleted,
             .completed,
             .reopened,
             .rescheduled,
             .priorityChanged,
             .typeChanged,
             .dueDateChanged:
            return payload.taskID != nil
        }
    }
}
