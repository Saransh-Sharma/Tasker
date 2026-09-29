import Foundation

/// One number per day for one thing a person can see about themselves. The
/// loaders that fill these live beside the Insights root; everything here is
/// pure and unit-tested. Direction is deliberately not encoded: "more steps"
/// is not "better" in the copy, and neither is "more sleep".
enum DailyMetric: String, CaseIterable, Identifiable, Sendable {
    case steps
    case sleepHours
    case activeEnergy
    case focusMinutes
    case journalEnergy
    case thingsDone
    case habitsCompleted

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steps: String(localized: "Steps")
        case .sleepHours: String(localized: "Sleep")
        case .activeEnergy: String(localized: "Active energy")
        case .focusMinutes: String(localized: "Focus")
        case .journalEnergy: String(localized: "Energy (journal)")
        case .thingsDone: String(localized: "Completions")
        case .habitsCompleted: String(localized: "Habits done")
        }
    }

    var unit: String {
        switch self {
        case .steps: "steps"
        case .sleepHours: "h"
        case .activeEnergy: "kcal"
        case .focusMinutes: "min"
        case .journalEnergy: "of 5"
        case .thingsDone: "done"
        case .habitsCompleted: "habits"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: "figure.walk"
        case .sleepHours: "bed.double"
        case .activeEnergy: "flame"
        case .focusMinutes: "timer"
        case .journalEnergy: "bolt"
        case .thingsDone: "checkmark.circle"
        case .habitsCompleted: "repeat"
        }
    }

    var fractionDigits: Int {
        switch self {
        case .sleepHours, .journalEnergy: 1
        default: 0
        }
    }
}

struct DailySeries: Equatable, Identifiable, Sendable {
    let metric: DailyMetric
    /// Ascending by day; one point per day that has a value.
    let points: [HomeSeriesPoint]

    var id: DailyMetric { metric }
    var values: [Double] { points.map(\.value) }
    var isEmpty: Bool { points.isEmpty }
}

/// The band a person "usually" lands in: median and interquartile range over
/// the window. "Usually 6–8 h" is the text equivalent; the chart draws it as
/// a quiet rectangle behind the line.
struct UsualRange: Equatable, Sendable {
    static let minimumDays = 3

    let median: Double
    let lower: Double
    let upper: Double

    var band: ClosedRange<Double> { lower...upper }

    static func make(_ values: [Double]) -> UsualRange? {
        let sorted = values.filter(\.isFinite).sorted()
        guard sorted.count >= minimumDays else { return nil }
        func quantile(_ q: Double) -> Double {
            let position = q * Double(sorted.count - 1)
            let low = Int(position.rounded(.down))
            let high = min(sorted.count - 1, low + 1)
            let fraction = position - Double(low)
            return sorted[low] + (sorted[high] - sorted[low]) * fraction
        }
        return UsualRange(median: quantile(0.5), lower: quantile(0.25), upper: quantile(0.75))
    }

    /// "usually 6.1–7.8 h"
    func text(unit: String, fractionDigits: Int) -> String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...fractionDigits))
        let unitSuffix = unit.isEmpty ? "" : " \(unit)"
        return "usually \(lower.formatted(format))–\(upper.formatted(format))\(unitSuffix)"
    }
}

/// How the loaders turn samples into one value per day.
enum DailySeriesAssembler {
    static func series(_ metric: DailyMetric, dailyValues: [Date: Double]) -> DailySeries {
        let points = dailyValues.keys.sorted().map { HomeSeriesPoint(date: $0, value: dailyValues[$0] ?? 0) }
        return DailySeries(metric: metric, points: points)
    }

    /// Count of items per calendar day.
    static func perDayCount(_ dates: [Date], calendar: Calendar = .current) -> [Date: Double] {
        dates.reduce(into: [:]) { result, date in
            result[calendar.startOfDay(for: date), default: 0] += 1
        }
    }

    /// Sum of values per calendar day.
    static func perDaySum(_ samples: [(date: Date, value: Double)], calendar: Calendar = .current) -> [Date: Double] {
        samples.reduce(into: [:]) { result, sample in
            result[calendar.startOfDay(for: sample.date), default: 0] += sample.value
        }
    }

    /// Mean of values per calendar day (journal energy: several check-ins a day).
    static func perDayAverage(_ samples: [(date: Date, value: Double)], calendar: Calendar = .current) -> [Date: Double] {
        var sums: [Date: (total: Double, count: Int)] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.date)
            var entry = sums[day] ?? (0, 0)
            entry.total += sample.value
            entry.count += 1
            sums[day] = entry
        }
        return sums.mapValues { $0.total / Double($0.count) }
    }

    /// Restrict a per-day dictionary to the last `days` days ending today.
    static func window(_ values: [Date: Double], days: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date: Double] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return values }
        return values.filter { $0.key >= start && $0.key <= today }
    }
}

/// Week / Month / Year on the Trends lens.
enum InsightsRange: String, CaseIterable, Identifiable, Sendable {
    case week, month, year
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: String(localized: "Week")
        case .month: String(localized: "Month")
        case .year: String(localized: "Year")
        }
    }
    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .year: 364
        }
    }
}
