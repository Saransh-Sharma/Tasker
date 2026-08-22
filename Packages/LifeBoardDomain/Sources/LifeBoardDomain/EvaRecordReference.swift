import Foundation

/// A stable domain identifier that can cross Eva cards and cloud contracts.
/// It deliberately has no knowledge of application navigation routes.
public enum RecordKind: String, Codable, CaseIterable, Hashable, Sendable {
    case task
    case project
    case habit
    case tracker
    case routine
    case goal
    case journal
    case note
    case knowledgeFolder
    case focusSession
    case lifeMoment
    case bodyMetric
    case hydration
    case mood
    case sleep
    case medication
    case insight
}

/// Closed surface choices a model may select. These are product concepts, not
/// URLs or `AppRoute` values; the app resolves them locally.
public enum EvaNavigationTarget: String, Codable, CaseIterable, Hashable, Sendable {
    case home
    case today
    case dayPlan
    case weekPlan
    case weeklyReview
    case backlog
    case focus
    case habits
    case trackers
    case journal
    case notes
    case goals
    case routines
    case lifeMoments
    case wellness
    case nutrition
    case fasting
    case insights
    case settings
    case eva
}

/// A compact, durable link to a LifeBoard record.
///
/// The display copy is captured with the identifier so historical result cards
/// remain understandable when the underlying record is later removed. The
/// destination can then render its ordinary missing-record state.
public struct EvaRecordReference: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { "\(kind.rawValue):\(recordID.uuidString.lowercased())" }

    public let kind: RecordKind
    public let recordID: UUID
    public let title: String
    public let subtitle: String?
    public let occurredAt: Date?

    public init(
        kind: RecordKind,
        recordID: UUID,
        title: String,
        subtitle: String? = nil,
        occurredAt: Date? = nil
    ) {
        self.kind = kind
        self.recordID = recordID
        self.title = title
        self.subtitle = subtitle
        self.occurredAt = occurredAt
    }
}
