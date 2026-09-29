import SwiftUI

struct InsightsRenderSnapshot: Equatable {
    struct SourceCount: Equatable {
        let domain: String
        let count: Int
    }

    var events: [NormalizedLifeEvent] = []
    var authorizedEvidence: [NormalizedLifeEvent] = []
    var interpretation = InsightsInterpretationService().interpret(events: [])
    var unifiedInsight = InsightsInterpretationService().unifiedInsight(events: [])
    var completenessDescription = String(localized: "No data yet")
    var confidence: Double?
    var missingDomains: [String] = []
    var sourceCounts: [SourceCount] = []
    /// Overview's claim reads two weeks; an empty today must not hide it.
    var hasPatternWindowEvidence = false

    static func build(
        authorizedEvents: [NormalizedLifeEvent],
        lens: InsightsLens,
        trendsDays: Int = InsightsRange.week.days,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightsRenderSnapshot {
        let startToday = calendar.startOfDay(for: now)
        // The pattern engine needs several days to say anything, so Overview's
        // interpretation reads a rolling two weeks even though its evidence list
        // stays on today. Reading today alone guaranteed the hero could never
        // state a pattern — it always fell back to "a few more days".
        let patternWindowStart = calendar.date(byAdding: .day, value: -13, to: startToday) ?? startToday
        let filtered: [NormalizedLifeEvent]
        switch lens {
        case .overview:
            filtered = authorizedEvents.filter { $0.occurredAt >= startToday }
        case .trends:
            // The window follows the chosen range, so a quiet week no longer
            // shows "nothing recorded" over a month or year that has records.
            let start = calendar.date(byAdding: .day, value: -(max(1, trendsDays) - 1), to: startToday) ?? startToday
            filtered = authorizedEvents.filter { $0.occurredAt >= start }
        case .review:
            filtered = authorizedEvents
        case .experience:
            filtered = []
        }
        let complete = filtered.lazy.filter {
            $0.completeness == .complete && $0.freshness == .complete
        }.count
        let confidence = filtered.isEmpty ? nil : Double(complete) / Double(filtered.count)
        let present = Set(filtered.map(\.domain))
        let sourceCounts = Dictionary(grouping: filtered, by: \.domain)
            .map { SourceCount(domain: $0.key, count: $0.value.count) }
            .sorted { $0.domain < $1.domain }
        return InsightsRenderSnapshot(
            events: filtered,
            authorizedEvidence: authorizedEvents,
            interpretation: InsightsInterpretationService().interpret(
                events: lens == .overview ? authorizedEvents.filter { $0.occurredAt >= patternWindowStart } : filtered,
                now: now,
                calendar: calendar
            ),
            unifiedInsight: InsightsInterpretationService().unifiedInsight(events: filtered, now: startToday, calendar: calendar),
            completenessDescription: filtered.isEmpty
                ? String(localized: "No data yet")
                : complete == filtered.count
                    ? String(localized: "All records complete")
                    : String(localized: "\(complete) of \(filtered.count) records complete"),
            confidence: confidence,
            missingDomains: ["hydration", "habit", "tracker", "routine", "goal", "plan"]
                .filter { present.contains($0) == false },
            sourceCounts: sourceCounts,
            hasPatternWindowEvidence: lens == .overview
                && authorizedEvents.contains { $0.occurredAt >= patternWindowStart }
        )
    }
}
