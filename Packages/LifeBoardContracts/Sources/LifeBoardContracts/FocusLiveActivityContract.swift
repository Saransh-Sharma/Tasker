import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

public struct FocusActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: String
        public var remainingDuration: TimeInterval
        public var expectedEndAt: Date?
        public var updatedAt: Date
        public var primaryCommandToken: UUID
        public var endCommandToken: UUID
        /// The session's full length, so the island can draw how much is done
        /// rather than only a countdown. Nil for open-ended sessions.
        public var targetDuration: TimeInterval?
        /// Time actually focused, for the ended state ("Done · 25 min").
        public var focusedDuration: TimeInterval?

        public init(
            phase: String,
            remainingDuration: TimeInterval,
            expectedEndAt: Date?,
            updatedAt: Date,
            primaryCommandToken: UUID = UUID(),
            endCommandToken: UUID = UUID(),
            targetDuration: TimeInterval? = nil,
            focusedDuration: TimeInterval? = nil
        ) {
            self.phase = phase
            self.remainingDuration = max(0, remainingDuration)
            self.expectedEndAt = expectedEndAt
            self.updatedAt = updatedAt
            self.primaryCommandToken = primaryCommandToken
            self.endCommandToken = endCommandToken
            self.targetDuration = targetDuration
            self.focusedDuration = focusedDuration
        }

        /// Where the progress ring starts: the moment the session would have
        /// begun had it never paused, so `start...expectedEndAt` spans exactly
        /// the target and the ring shows real progress.
        public var progressStart: Date? {
            guard let expectedEndAt, let targetDuration, targetDuration > 0 else { return nil }
            return expectedEndAt.addingTimeInterval(-targetDuration)
        }
    }

    public var sessionID: UUID
    public var title: String

    public init(sessionID: UUID, title: String) {
        self.sessionID = sessionID
        self.title = String(title.prefix(80))
    }
}

public enum FocusActivityLink {
    public static func url(sessionID: UUID, command: String, token: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "lifeboard"
        components.host = "focus"
        components.path = "/\(sessionID.uuidString)"
        components.queryItems = [
            URLQueryItem(name: "command", value: command),
            URLQueryItem(name: "token", value: token.uuidString)
        ]
        return components.url!
    }
}

public struct FastingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: String
        public var startedAt: Date
        public var targetEndAt: Date?
        public var elapsedDuration: TimeInterval
        public var updatedAt: Date
        public var finishCommandToken: UUID
        public var cancelCommandToken: UUID

        public init(
            phase: String,
            startedAt: Date,
            targetEndAt: Date?,
            elapsedDuration: TimeInterval,
            updatedAt: Date,
            finishCommandToken: UUID = UUID(),
            cancelCommandToken: UUID = UUID()
        ) {
            self.phase = phase
            self.startedAt = startedAt
            self.targetEndAt = targetEndAt
            self.elapsedDuration = max(0, elapsedDuration)
            self.updatedAt = updatedAt
            self.finishCommandToken = finishCommandToken
            self.cancelCommandToken = cancelCommandToken
        }
    }

    public var sessionID: UUID
    public var title: String

    public init(sessionID: UUID, title: String = "Fasting") {
        self.sessionID = sessionID
        self.title = String(title.prefix(80))
    }
}

public enum FastingActivityLink {
    public static func url(sessionID: UUID, command: String, token: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "lifeboard"
        components.host = "fasting"
        components.path = "/\(sessionID.uuidString)"
        components.queryItems = [
            URLQueryItem(name: "command", value: command),
            URLQueryItem(name: "token", value: token.uuidString)
        ]
        return components.url!
    }
}

public struct RoutineActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var status: String
        public var stepTitle: String
        public var completedStepCount: Int
        public var totalStepCount: Int
        public var updatedAt: Date
        public var primaryCommandToken: UUID
        public var stopCommandToken: UUID

        public init(
            status: String,
            stepTitle: String,
            completedStepCount: Int,
            totalStepCount: Int,
            updatedAt: Date,
            primaryCommandToken: UUID = UUID(),
            stopCommandToken: UUID = UUID()
        ) {
            self.status = status
            self.stepTitle = String(stepTitle.prefix(100))
            self.completedStepCount = max(0, completedStepCount)
            self.totalStepCount = max(0, totalStepCount)
            self.updatedAt = updatedAt
            self.primaryCommandToken = primaryCommandToken
            self.stopCommandToken = stopCommandToken
        }
    }

    public var runID: UUID
    public var routineID: UUID
    public var title: String

    public init(runID: UUID, routineID: UUID, title: String) {
        self.runID = runID
        self.routineID = routineID
        self.title = String(title.prefix(80))
    }
}

public enum RoutineActivityLink {
    public static func url(runID: UUID, command: String, token: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "lifeboard"
        components.host = "routine"
        components.path = "/\(runID.uuidString)"
        components.queryItems = [
            URLQueryItem(name: "command", value: command),
            URLQueryItem(name: "token", value: token.uuidString)
        ]
        return components.url!
    }
}
#endif
