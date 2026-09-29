import Foundation
import LifeBoardDomain

/// Turns authorized life events into one honest interpretation.
///
/// The previous Overview headline was "whichever domain has the most records",
/// which is not an insight and is actively misleading: a hydration log fires
/// eight times a day and a journal entry once, so the "clearest signal" was
/// always just the chattiest tracker. This ranks by *days present* instead —
/// how consistently something is recorded — and refuses to interpret at all
/// below a evidence floor, mirroring the weekly reflection's density gate so
/// the app has one honesty threshold rather than two.
public struct InsightsInterpretation: Equatable, Sendable {
    public enum Density: String, Equatable, Sendable {
        /// Not enough recorded history to say anything responsibly.
        case empty
        /// Enough to describe, not enough to claim a pattern.
        case light
        /// Enough for a pattern claim with evidence behind it.
        case full
    }

    public var density: Density
    /// The claim itself, in human language.
    public var claim: String
    /// What to consider doing about it. Never a prescription.
    public var recommendedAction: String
    /// 0...1 share of contributing records that are complete and current.
    public var completeness: Double?
    /// Records that support the claim, for the Evidence disclosure.
    public var evidenceReferences: [UUID]
    /// Daily activity for the Trends chart.
    public var dailyCounts: [HomeSeriesPoint]

    public var supportsClaim: Bool { density == .full }
}

public struct InsightsInterpretationService: Sendable {
    /// Below this many recorded days nothing is claimed. Three days is the
    /// same floor the weekly reflection uses before it will call anything a
    /// pattern.
    public static let minimumDaysForPattern = 3
    /// Below this, Overview says so plainly rather than filling space.
    public static let minimumRecordsForDescription = 3

    public init() {}

    public func unifiedInsight(
        events: [NormalizedLifeEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Insight {
        let interpretation = interpret(events: events, now: now, calendar: calendar)
        let supporting = events.filter { interpretation.evidenceReferences.contains($0.sourceID) }
        let evidence = supporting.compactMap { event -> Insight.Evidence? in
            let source = event.evidence.first
            guard let kind = recordKind(for: source?.kind ?? event.kind) else { return nil }
            return .init(
                reference: EvaRecordReference(
                    kind: kind,
                    recordID: source?.routeID ?? event.sourceID,
                    title: source?.display ?? event.provenance,
                    occurredAt: event.occurredAt
                ),
                reason: "Contributed to the \(event.domain) pattern",
                signalKey: "\(event.domain):\(event.sourceID.uuidString)"
            )
        }
        let confidence: Insight.Confidence = switch interpretation.completeness ?? 0 {
        case 0.8...: .high
        case 0.5...: .medium
        default: .low
        }
        return Insight(
            id: "insights.overview.\(interpretation.evidenceReferences.map(\.uuidString).sorted().joined(separator: "."))",
            claim: interpretation.claim,
            evidence: evidence,
            confidence: confidence,
            suggestedAction: interpretation.recommendedAction,
            provenance: .deterministic,
            createdAt: now,
            expiresAt: calendar.date(byAdding: .day, value: 1, to: now)
        )
    }

    private func recordKind(for raw: String) -> RecordKind? {
        switch raw.lowercased() {
        case "task", "plan": .task
        case "project": .project
        case "habit": .habit
        case "tracker", "care": .tracker
        case "routine": .routine
        case "goal": .goal
        case "journal": .journal
        case "note", "knowledge": .note
        case "focus": .focusSession
        case "hydration": .hydration
        case "mood": .mood
        case "sleep": .sleep
        case "medication": .medication
        case "lifemoment", "life_moment", "moment": .lifeMoment
        default: nil
        }
    }

    public func interpret(
        events: [NormalizedLifeEvent],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightsInterpretation {
        let dailyCounts = Self.dailyCounts(events: events, calendar: calendar)

        guard events.count >= Self.minimumRecordsForDescription else {
            return InsightsInterpretation(
                density: .empty,
                claim: String(localized: "Not enough data yet"),
                recommendedAction: String(localized: "Log a few days to see patterns."),
                completeness: nil,
                evidenceReferences: [],
                dailyCounts: dailyCounts
            )
        }

        // Consistency, not volume: how many distinct days each domain appears on.
        let daysByDomain = Dictionary(grouping: events, by: \.domain).mapValues { domainEvents in
            Set(domainEvents.map { calendar.startOfDay(for: $0.occurredAt) })
        }
        let mostConsistent = daysByDomain
            .max { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
                // Stable ordering so the same evidence always yields the same claim.
                return lhs.key > rhs.key
            }

        let completeness = Self.completeness(of: events)
        let recordedDays = Set(events.map { calendar.startOfDay(for: $0.occurredAt) }).count

        guard let mostConsistent, recordedDays >= Self.minimumDaysForPattern else {
            let domainCount = daysByDomain.keys.count
            return InsightsInterpretation(
                density: .light,
                claim: domainCount == 1
                    ? String(localized: "\(events.count) records in 1 area")
                    : String(localized: "\(events.count) records in \(domainCount) areas"),
                recommendedAction: Self.minimumDaysForPattern - recordedDays == 1
                    ? String(localized: "Needs 1 more day")
                    : String(localized: "Needs \(max(1, Self.minimumDaysForPattern - recordedDays)) more days"),
                completeness: completeness,
                evidenceReferences: events.map(\.sourceID),
                dailyCounts: dailyCounts
            )
        }

        if let change = Self.weekOverWeekChange(events: events, now: now, calendar: calendar) {
            let direction = change.lastWeekDays > change.priorWeekDays ? "up from" : "down from"
            return InsightsInterpretation(
                density: .full,
                claim: String(localized: "\(InsightsDomainCopy.title(for: change.domain)) showed up on \(change.lastWeekDays) of the last 7 days, \(direction) \(change.priorWeekDays) the week before."),
                // Named without a verdict: fewer entries can mean a hard week,
                // a finished goal, or simply less to record.
                recommendedAction: String(localized: "Open details to see what changed."),
                completeness: completeness,
                evidenceReferences: events.filter { $0.domain == change.domain }.map(\.sourceID),
                dailyCounts: dailyCounts
            )
        }

        let domain = mostConsistent.key
        let dayCount = mostConsistent.value.count
        let supporting = events.filter { $0.domain == domain }

        return InsightsInterpretation(
            density: .full,
            claim: String(localized: "\(InsightsDomainCopy.title(for: domain)) is your most consistent record, on \(dayCount) of \(recordedDays) days."),
            recommendedAction: String(localized: "Open details to see the days."),
            completeness: completeness,
            evidenceReferences: supporting.map(\.sourceID),
            dailyCounts: dailyCounts
        )
    }

    struct WeekOverWeekChange: Equatable {
        let domain: String
        let lastWeekDays: Int
        let priorWeekDays: Int
    }

    /// The area whose presence changed most between the last 7 days and the 7
    /// before, counted in distinct days (consistency, not volume). Needs records
    /// in the earlier week — a first week has nothing to change from — and a
    /// move of at least two days, so one busy afternoon is not a trend.
    static func weekOverWeekChange(
        events: [NormalizedLifeEvent],
        now: Date,
        calendar: Calendar
    ) -> WeekOverWeekChange? {
        let today = calendar.startOfDay(for: now)
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let priorWeekStart = calendar.date(byAdding: .day, value: -13, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        let priorWeek = events.filter { $0.occurredAt >= priorWeekStart && $0.occurredAt < lastWeekStart }
        guard priorWeek.isEmpty == false else { return nil }
        let lastWeek = events.filter { $0.occurredAt >= lastWeekStart && $0.occurredAt < tomorrow }

        func days(_ events: [NormalizedLifeEvent]) -> [String: Int] {
            Dictionary(grouping: events, by: \.domain).mapValues { Set($0.map { calendar.startOfDay(for: $0.occurredAt) }).count }
        }
        let recent = days(lastWeek), earlier = days(priorWeek)
        let candidates = Set(recent.keys).union(earlier.keys).map { domain in
            WeekOverWeekChange(domain: domain, lastWeekDays: recent[domain] ?? 0, priorWeekDays: earlier[domain] ?? 0)
        }
        return candidates
            .filter { abs($0.lastWeekDays - $0.priorWeekDays) >= 2 }
            .max { lhs, rhs in
                let l = abs(lhs.lastWeekDays - lhs.priorWeekDays), r = abs(rhs.lastWeekDays - rhs.priorWeekDays)
                return l != r ? l < r : lhs.domain > rhs.domain
            }
    }

    /// One point per day in the covered range, including days with no records
    /// so gaps read as gaps rather than being silently collapsed.
    static func dailyCounts(
        events: [NormalizedLifeEvent],
        calendar: Calendar
    ) -> [HomeSeriesPoint] {
        guard events.isEmpty == false else { return [] }
        let byDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.occurredAt) }
        guard let earliest = byDay.keys.min(), let latest = byDay.keys.max() else { return [] }

        var points: [HomeSeriesPoint] = []
        var cursor = earliest
        // Bounded so a single stale record cannot generate an unbounded series.
        while cursor <= latest, points.count < 90 {
            points.append(
                HomeSeriesPoint(
                    date: cursor,
                    value: Double(byDay[cursor]?.count ?? 0)
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    static func completeness(of events: [NormalizedLifeEvent]) -> Double? {
        guard events.isEmpty == false else { return nil }
        let complete = events.filter { $0.completeness == .complete }.count
        return Double(complete) / Double(events.count)
    }
}
