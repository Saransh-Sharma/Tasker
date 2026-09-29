import Foundation

public enum FastingWatchAction: String, Codable, Equatable, Sendable {
    case finish
    case cancel
}

public struct FastingWatchCommand: Codable, Equatable, Sendable {
    public static let transportPayloadKey = "lifeboard.fasting.command"
    public static let transportSchemaKey = "lifeboard.fasting.schema"
    public static let transportSchemaVersion = 1

    public var commandID: UUID
    public var sessionID: UUID
    public var action: FastingWatchAction
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        commandID: UUID = UUID(),
        sessionID: UUID,
        action: FastingWatchAction,
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(15 * 60)
    ) {
        self.commandID = commandID
        self.sessionID = sessionID
        self.action = action
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public func watchUserInfoPayload() throws -> [String: Any] {
        [
            Self.transportSchemaKey: Self.transportSchemaVersion,
            Self.transportPayloadKey: try JSONEncoder().encode(self)
        ]
    }

    public static func decodeWatchUserInfo(_ userInfo: [String: Any]) -> Self? {
        guard
            (userInfo[transportSchemaKey] as? Int) == transportSchemaVersion,
            let data = userInfo[transportPayloadKey] as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

public enum RoutineWatchAction: String, Codable, Equatable, Sendable {
    case pause
    case resume
    case stop
}

public struct RoutineWatchCommand: Codable, Equatable, Sendable {
    public static let transportPayloadKey = "lifeboard.routine.command"
    public static let transportSchemaKey = "lifeboard.routine.schema"
    public static let transportSchemaVersion = 1

    public var commandID: UUID
    public var runID: UUID
    public var action: RoutineWatchAction
    public var createdAt: Date
    public var expiresAt: Date

    public init(
        commandID: UUID = UUID(),
        runID: UUID,
        action: RoutineWatchAction,
        createdAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(15 * 60)
    ) {
        self.commandID = commandID
        self.runID = runID
        self.action = action
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public func watchUserInfoPayload() throws -> [String: Any] {
        [
            Self.transportSchemaKey: Self.transportSchemaVersion,
            Self.transportPayloadKey: try JSONEncoder().encode(self)
        ]
    }

    public static func decodeWatchUserInfo(_ userInfo: [String: Any]) -> Self? {
        guard
            (userInfo[transportSchemaKey] as? Int) == transportSchemaVersion,
            let data = userInfo[transportPayloadKey] as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}
