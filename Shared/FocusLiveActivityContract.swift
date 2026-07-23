import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

public struct LifeBoardFocusActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: String
        public var remainingDuration: TimeInterval
        public var expectedEndAt: Date?
        public var updatedAt: Date
        public var primaryCommandToken: UUID
        public var endCommandToken: UUID

        public init(
            phase: String,
            remainingDuration: TimeInterval,
            expectedEndAt: Date?,
            updatedAt: Date,
            primaryCommandToken: UUID = UUID(),
            endCommandToken: UUID = UUID()
        ) {
            self.phase = phase
            self.remainingDuration = max(0, remainingDuration)
            self.expectedEndAt = expectedEndAt
            self.updatedAt = updatedAt
            self.primaryCommandToken = primaryCommandToken
            self.endCommandToken = endCommandToken
        }
    }

    public var sessionID: UUID
    public var title: String

    public init(sessionID: UUID, title: String) {
        self.sessionID = sessionID
        self.title = String(title.prefix(80))
    }
}

public enum LifeBoardFocusActivityLink {
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
#endif
