import Foundation
import LifeBoardDomain

/// The month, read back: what was written at the loop's boundaries, how the
/// usual ranges moved against the month before, and which experiments are
/// waiting for a verdict. Pure; the Review lens renders it.
struct MonthlyReviewSummary: Equatable {
    struct Shift: Equatable, Identifiable {
        let metric: DailyMetric
        let previousMedian: Double
        let currentMedian: Double
        var id: DailyMetric { metric }
        var delta: Double { currentMedian - previousMedian }
        /// Relative change, guarded against a zero baseline.
        var relative: Double { previousMedian == 0 ? (currentMedian == 0 ? 0 : 1) : delta / abs(previousMedian) }
    }

    let monthStart: Date
    let weeklyReviews: Int
    let daysClosed: Int
    let averageCloseEnergy: Double?
    let closeNotes: [ReflectionNote]
    let shifts: [Shift]
    let dueExperiments: [InsightExperiment]

    /// A shift is worth a line when the median moved by at least a fifth.
    static let minimumRelativeShift = 0.2

    static func make(
        notes: [ReflectionNote],
        current: [DailySeries],
        previous: [DailySeries],
        experiments: [InsightExperiment],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MonthlyReviewSummary {
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let inMonth = notes.filter { $0.createdAt >= monthStart && $0.createdAt <= now }
        let closes = inMonth.filter { $0.kind == .dayClose }.sorted { $0.createdAt > $1.createdAt }
        let energies = closes.compactMap(\.energy).map(Double.init)
        let previousByMetric = Dictionary(previous.map { ($0.metric, $0) }, uniquingKeysWith: { first, _ in first })
        let shifts: [Shift] = current.compactMap { series in
            guard let before = previousByMetric[series.metric],
                  let nowRange = UsualRange.make(series.values),
                  let thenRange = UsualRange.make(before.values) else { return nil }
            let shift = Shift(metric: series.metric, previousMedian: thenRange.median, currentMedian: nowRange.median)
            return abs(shift.relative) >= minimumRelativeShift ? shift : nil
        }
        .sorted { abs($0.relative) > abs($1.relative) }
        return MonthlyReviewSummary(
            monthStart: monthStart,
            weeklyReviews: inMonth.filter { $0.kind == .weeklyReview }.count,
            daysClosed: closes.count,
            averageCloseEnergy: energies.isEmpty ? nil : energies.reduce(0, +) / Double(energies.count),
            closeNotes: Array(closes.filter { $0.noteText.isEmpty == false }.prefix(4)),
            shifts: Array(shifts.prefix(3)),
            dueExperiments: experiments.filter { $0.verdict == nil && now >= $0.endsAt }
        )
    }

    /// "Sleep: usually 6.8 h, up from 6.1 h last month". Descriptive only.
    static func sentence(for shift: Shift) -> String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...shift.metric.fractionDigits))
        let direction = shift.delta > 0 ? "up from" : "down from"
        let unit = shift.metric.unit.isEmpty ? "" : " \(shift.metric.unit)"
        return "\(shift.metric.label): usually \(shift.currentMedian.formatted(format))\(unit), \(direction) \(shift.previousMedian.formatted(format))\(unit) the month before."
    }
}
