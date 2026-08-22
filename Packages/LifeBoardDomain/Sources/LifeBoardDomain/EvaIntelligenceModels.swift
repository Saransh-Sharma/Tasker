import Foundation

/// The single intelligence object rendered by Insights, Home, and Eva chat.
/// Dismissal is keyed by `id`, so every projection disappears together.
public struct Insight: Identifiable, Codable, Hashable, Sendable {
    public enum Confidence: String, Codable, CaseIterable, Hashable, Sendable {
        case low, medium, high

        public var minimumEvidenceCount: Int {
            switch self { case .low: 1; case .medium: 2; case .high: 3 }
        }
    }

    public enum Provenance: String, Codable, CaseIterable, Hashable, Sendable {
        case deterministic
        case assistantAdjudicated
        case userRequested
    }

    public enum RenderDensity: String, Codable, CaseIterable, Hashable, Sendable {
        case conversational
        case compact
        case full
    }

    public struct Evidence: Identifiable, Codable, Hashable, Sendable {
        public var id: String
        public var reference: EvaRecordReference
        public var reason: String
        public var signalKey: String

        public init(
            id: String? = nil,
            reference: EvaRecordReference,
            reason: String,
            signalKey: String? = nil
        ) {
            self.id = id ?? "\(reference.kind.rawValue):\(reference.recordID.uuidString)"
            self.reference = reference
            self.reason = reason
            self.signalKey = signalKey ?? self.id
        }
    }

    public var id: String
    public var claim: String
    public var evidence: [Evidence]
    public var confidence: Confidence
    public var suggestedAction: String?
    public var provenance: Provenance
    public var createdAt: Date
    public var expiresAt: Date?

    public init(
        id: String,
        claim: String,
        evidence: [Evidence],
        confidence: Confidence,
        suggestedAction: String? = nil,
        provenance: Provenance,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.claim = claim
        self.evidence = evidence
        self.confidence = confidence
        self.suggestedAction = suggestedAction
        self.provenance = provenance
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        expiresAt.map { $0 <= date } ?? false
    }
}

public struct EvaProactiveHistory: Codable, Hashable, Sendable {
    public struct Delivery: Codable, Hashable, Sendable {
        public var insightID: String?
        public var kind: String
        public var deliveredAt: Date
        public var wasUseful: Bool?

        public init(insightID: String? = nil, kind: String, deliveredAt: Date, wasUseful: Bool? = nil) {
            self.insightID = insightID
            self.kind = kind
            self.deliveredAt = deliveredAt
            self.wasUseful = wasUseful
        }
    }

    public struct Dismissal: Codable, Hashable, Sendable {
        public var kind: String
        public var dismissedAt: Date

        public init(kind: String, dismissedAt: Date) {
            self.kind = kind
            self.dismissedAt = dismissedAt
        }
    }

    public var deliveries: [Delivery]
    public var dismissals: [Dismissal]

    public init(deliveries: [Delivery] = [], dismissals: [Dismissal] = []) {
        self.deliveries = deliveries
        self.dismissals = dismissals
    }
}

public extension ReflectionInsight {
    func asUnifiedInsight() -> Insight {
        let unifiedConfidence: Insight.Confidence
        switch confidence {
        case .low: unifiedConfidence = .low
        case .medium: unifiedConfidence = .medium
        case .high: unifiedConfidence = .high
        }
        return Insight(
            id: id,
            claim: message,
            evidence: evidence.map { item in
                .init(
                    id: item.id,
                    reference: EvaRecordReference(
                        kind: .journal,
                        recordID: item.entryID,
                        title: "Journal — \(item.date.formatted(date: .abbreviated, time: .omitted))",
                        occurredAt: item.date
                    ),
                    reason: explanation,
                    signalKey: feedbackKey
                )
            },
            confidence: unifiedConfidence,
            suggestedAction: prompt,
            provenance: evidenceMode == .deterministicPattern ? .deterministic : .assistantAdjudicated,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }
}

public struct EvaProactiveCandidate: Codable, Hashable, Sendable {
    public var kind: String
    public var insight: Insight
    public var usefulProbability: Double

    public init(kind: String, insight: Insight, usefulProbability: Double) {
        self.kind = kind
        self.insight = insight
        self.usefulProbability = min(1, max(0, usefulProbability))
    }
}

public enum EvaProactiveDecision: Equatable, Sendable {
    case deliver
    case suppress(reason: String)
}

public struct EvaQuietHours: Codable, Hashable, Sendable {
    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(1_439, max(0, startMinute))
        self.endMinute = min(1_439, max(0, endMinute))
    }

    public func contains(_ minute: Int) -> Bool {
        startMinute <= endMinute
            ? (startMinute...endMinute).contains(minute)
            : minute >= startMinute || minute <= endMinute
    }
}

/// Local, deterministic interruption policy. The model cannot grant itself
/// notification authority or raise the daily budget.
public struct EvaProactiveGovernor: Sendable {
    public static let dailyBudget = 2
    public static let usefulProbabilityFloor = 0.65
    public static let dismissalDormancyDays = 21

    public init() {}

    public func evaluate(
        _ candidate: EvaProactiveCandidate,
        history: EvaProactiveHistory,
        quietHours: EvaQuietHours?,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> EvaProactiveDecision {
        guard candidate.usefulProbability >= Self.usefulProbabilityFloor else {
            return .suppress(reason: "Below the useful-to-noise floor")
        }
        let todayCount = history.deliveries.filter { calendar.isDate($0.deliveredAt, inSameDayAs: now) }.count
        guard todayCount < Self.dailyBudget else {
            return .suppress(reason: "Daily proactive budget exhausted")
        }
        if let quietHours {
            let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            if quietHours.contains(minute) { return .suppress(reason: "Quiet hours") }
        }
        let dormancyStart = calendar.date(byAdding: .day, value: -Self.dismissalDormancyDays, to: now) ?? now
        let recentDismissals = history.dismissals.filter {
            $0.kind == candidate.kind && $0.dismissedAt >= dormancyStart
        }.count
        guard recentDismissals < 2 else {
            return .suppress(reason: "This nudge type is silently dormant after repeated dismissals")
        }
        return .deliver
    }
}
