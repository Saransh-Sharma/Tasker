import Foundation
import LifeBoardDomain

public enum SmartPromotionKind: String, Codable, Sendable {
    case safetySensitiveCare
    case activeContext
    case overdueOrSoon
    case timedRoutine
    case contextualSuggestion

    public var priority: Int {
        switch self {
        case .safetySensitiveCare: return 500
        case .activeContext: return 400
        case .overdueOrSoon: return 300
        case .timedRoutine: return 200
        case .contextualSuggestion: return 100
        }
    }
}

public struct SmartPromotionCandidate: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SmartPromotionKind
    public let title: String
    public let reason: String
    public let isUserStartedActiveFocus: Bool
    public let expiresAt: Date?

    public init(
        id: UUID,
        kind: SmartPromotionKind,
        title: String,
        reason: String,
        isUserStartedActiveFocus: Bool = false,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reason = reason
        self.isUserStartedActiveFocus = isUserStartedActiveFocus
        self.expiresAt = expiresAt
    }
}

public protocol SmartHomePolicy: Sendable {
    func decide(candidates: [SmartPromotionCandidate], now: Date) -> SmartPromotionCandidate?
}

public struct DeterministicSmartHomePolicy: SmartHomePolicy {
    public init() {}

    public func decide(candidates: [SmartPromotionCandidate], now: Date) -> SmartPromotionCandidate? {
        let available = candidates.filter { $0.expiresAt.map { $0 > now } ?? true }
        if let activeFocus = available.first(where: \.isUserStartedActiveFocus) {
            return activeFocus
        }
        return available.sorted {
            if $0.kind.priority != $1.kind.priority { return $0.kind.priority > $1.kind.priority }
            return $0.id.uuidString < $1.id.uuidString
        }.first
    }
}
