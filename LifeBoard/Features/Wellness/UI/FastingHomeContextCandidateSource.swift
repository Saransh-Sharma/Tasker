import Foundation

public struct FastingHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "fasting"
    private let repository: any FastingSessionRepository

    public init(repository: any FastingSessionRepository) {
        self.repository = repository
    }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        guard let fast = try? await repository.fetchFastingSessions(limit: 20)
            .first(where: { $0.endedAt == nil }) else { return [] }
        let elapsed = fast.elapsed(at: context.date)
        let reason: String
        if let target = fast.targetDuration {
            let remaining = max(0, target - elapsed)
            reason = remaining > 0
                ? String(localized: "\(Self.duration(remaining)) left")
                : String(localized: "Goal reached · \(Self.duration(target))")
        } else {
            reason = String(localized: "Timer running")
        }
        return [.init(
            id: "active-fast:\(fast.id.uuidString)",
            widgetKind: .fasting,
            title: String(localized: "Fasting · \(Self.duration(elapsed))"),
            reason: .init(message: reason, signal: "active fast"),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 650,
            relevantFrom: fast.startedAt,
            relevantUntil: fast.targetDuration.map { fast.startedAt.addingTimeInterval($0 + 21_600) },
            isUserStartedActiveState: true
        )]
    }

    private static func duration(_ interval: TimeInterval) -> String {
        LifeBoardDuration.text(minutes: max(0, Int(interval / 60)))
    }
}
