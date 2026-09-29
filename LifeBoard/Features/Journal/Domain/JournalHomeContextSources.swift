import Foundation
import LifeBoardDomain

public struct JournalHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "journal"
    private let repository: any PhaseIIRepository

    public init(repository: any PhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: context.date)
        guard hour >= 17,
              (try? await repository.fetchJournalDay(containing: context.date)) == nil else { return [] }
        return [.init(
            id: "evening-reflection:\(calendar.startOfDay(for: context.date).timeIntervalSince1970)",
            widgetKind: .journal,
            title: String(localized: "Write about today"),
            reason: .init(message: String(localized: "No entry today"), signal: String(localized: "time of day")),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 180,
            relevantFrom: context.date
        )]
    }
}

/// Suggests the Weekly Reflection once the week is winding down and the week
/// actually contains journal material to reflect on.
public struct WeeklyReflectionHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "weekly-reflection"
    private let repository: any PhaseIIRepository

    public init(repository: any PhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        var calendar = Calendar.current
        calendar.firstWeekday = Calendar.current.firstWeekday
        let weekday = calendar.component(.weekday, from: context.date)
        let lastWeekday = ((calendar.firstWeekday + 5) % 7) + 1
        guard weekday == lastWeekday else { return [] }
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: context.date),
              let days = try? await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil),
              days.contains(where: { weekInterval.contains($0.day) }) else { return [] }
        return [.init(
            id: "weekly-reflection:\(Int(weekInterval.start.timeIntervalSince1970))",
            widgetKind: .journal,
            title: String(localized: "Review your week"),
            reason: .init(
                message: String(localized: "The week ends today."),
                signal: String(localized: "end of week")
            ),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 260,
            relevantFrom: context.date,
            relevantUntil: weekInterval.end
        )]
    }
}

/// Resurfaces a journal day from exactly one year ago — a gentle memory, only
/// when the user permits sensitive content on Home, and never with content in
/// the candidate itself.
public struct JournalMemoryHomeContextCandidateSource: HomeContextCandidateSource {
    public let providerID = "journal-memory"
    private let repository: any PhaseIIRepository

    public init(repository: any PhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let calendar = Calendar.current
        guard let lastYear = calendar.date(byAdding: .year, value: -1, to: context.date),
              let memory = try? await repository.fetchJournalDay(containing: lastYear) else { return [] }
        return [.init(
            id: "journal-memory:\(memory.id.uuidString)",
            widgetKind: .journal,
            title: String(localized: "A year ago today"),
            reason: .init(
                message: String(localized: "You wrote on this day last year."),
                signal: String(localized: "last year’s entry")
            ),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 150,
            relevantFrom: context.date,
            relevantUntil: calendar.startOfDay(for: context.date).addingTimeInterval(24 * 60 * 60)
        )]
    }
}
