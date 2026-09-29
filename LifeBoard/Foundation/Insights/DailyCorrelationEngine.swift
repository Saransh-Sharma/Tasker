import Foundation

/// On-device, rank-based (Spearman) relationships between two daily series.
/// It reports strength and how many days it rests on; it never reports a
/// p-value and its copy never claims a cause. Lag-1 pairs yesterday's value
/// of one thing with today's value of the other.
enum DailyCorrelationEngine {
    static let minimumPairs = 10

    enum Strength: String, Equatable, Sendable {
        case none, small, moderate, strong

        static func bucket(_ rho: Double) -> Strength {
            let magnitude = abs(rho)
            if magnitude < 0.3 { return .none }
            if magnitude < 0.5 { return .small }
            if magnitude < 0.7 { return .moderate }
            return .strong
        }

        var label: String { rawValue }
    }

    enum Lag: String, Equatable, Sendable {
        case sameDay
        /// `first` yesterday against `second` today.
        case previousDay
    }

    struct Result: Equatable, Identifiable, Sendable {
        let first: DailyMetric
        let second: DailyMetric
        let lag: Lag
        let rho: Double
        let pairs: Int
        let evidenceDays: [Date]

        var id: String { "\(first.rawValue)|\(second.rawValue)|\(lag.rawValue)" }
        var strength: Strength { Strength.bucket(rho) }
        /// A plain confidence word from the sample size and the strength;
        /// never a p-value.
        var confidence: String {
            switch (pairs, strength) {
            case (30..., .strong), (30..., .moderate): "fairly steady"
            case (20..., _): "emerging"
            default: "early"
            }
        }
    }

    /// Spearman's rho with tie-averaged ranks; `nil` under `minimumPairs` or
    /// when either side is constant.
    static func spearman(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= minimumPairs else { return nil }
        let rx = ranks(x), ry = ranks(y)
        let n = Double(x.count)
        let meanX = rx.reduce(0, +) / n, meanY = ry.reduce(0, +) / n
        var covariance = 0.0, varianceX = 0.0, varianceY = 0.0
        for i in 0..<x.count {
            let dx = rx[i] - meanX, dy = ry[i] - meanY
            covariance += dx * dy
            varianceX += dx * dx
            varianceY += dy * dy
        }
        guard varianceX > 0, varianceY > 0 else { return nil }
        return covariance / (varianceX * varianceY).squareRoot()
    }

    static func ranks(_ values: [Double]) -> [Double] {
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var ranks = Array(repeating: 0.0, count: values.count)
        var i = 0
        while i < indexed.count {
            var j = i
            while j + 1 < indexed.count, indexed[j + 1].element == indexed[i].element { j += 1 }
            let average = Double(i + j + 2) / 2 // ranks are 1-based
            for k in i...j { ranks[indexed[k].offset] = average }
            i = j + 1
        }
        return ranks
    }

    /// Pairs the two series by day (optionally shifting `first` one day
    /// earlier) and correlates them.
    static func correlate(_ first: DailySeries, _ second: DailySeries, lag: Lag, calendar: Calendar = .current) -> Result? {
        var firstByDay: [Date: Double] = [:]
        for point in first.points {
            let day = calendar.startOfDay(for: point.date)
            let key = lag == .previousDay ? (calendar.date(byAdding: .day, value: 1, to: day) ?? day) : day
            firstByDay[key] = point.value
        }
        var xs: [Double] = [], ys: [Double] = [], days: [Date] = []
        for point in second.points.sorted(by: { $0.date < $1.date }) {
            let day = calendar.startOfDay(for: point.date)
            guard let x = firstByDay[day] else { continue }
            xs.append(x); ys.append(point.value); days.append(day)
        }
        guard let rho = spearman(xs, ys) else { return nil }
        return Result(first: first.metric, second: second.metric, lag: lag, rho: rho, pairs: xs.count, evidenceDays: days)
    }

    /// Every distinct pair, same-day and lag-1, ranked by strength; only
    /// results with at least a small effect are worth a row.
    static func rank(_ series: [DailySeries], calendar: Calendar = .current, limit: Int = 3) -> [Result] {
        var results: [Result] = []
        for i in 0..<series.count {
            for j in (i + 1)..<series.count {
                for lag in [Lag.sameDay, .previousDay] {
                    if let result = correlate(series[i], series[j], lag: lag, calendar: calendar), result.strength != .none {
                        results.append(result)
                    }
                }
            }
        }
        return Array(results.sorted { abs($0.rho) > abs($1.rho) }.prefix(limit))
    }

    /// "On days with more focus, your energy (journal) tended to be higher."
    /// Descriptive, never causal. The evidence behind it is `evidence(for:)`,
    /// a separate line: the parenthetical "(12 days, moderate, early)" read
    /// as statistics jargon, and it was saved verbatim as an experiment's
    /// hypothesis and quoted back a week later.
    static func sentence(for result: Result) -> String {
        let direction = result.rho >= 0 ? "higher" : "lower"
        let when = result.lag == .previousDay
            ? "The day after more \(result.first.label.lowercased())"
            : "On days with more \(result.first.label.lowercased())"
        return "\(when), your \(result.second.label.lowercased()) tended to be \(direction)."
    }

    /// "Based on 12 days · early pattern", in words a person would use.
    static func evidence(for result: Result) -> String {
        let pattern: String = switch result.confidence {
        case "fairly steady": String(localized: "steady pattern")
        case "emerging": String(localized: "emerging pattern")
        default: String(localized: "early pattern")
        }
        return String(localized: "Based on \(result.pairs) days · \(pattern)")
    }

    /// Before there is enough to say anything: how far along the record is.
    /// Never a percentage (`DESIGN.md`), just days.
    static func progressLine(recordedDays: Int) -> String? {
        guard recordedDays < minimumPairs else { return nil }
        let remaining = minimumPairs - recordedDays
        return remaining == 1
            ? String(localized: "Needs 1 more day")
            : String(localized: "Needs \(remaining) more days")
    }

    /// Words the copy must never use; a test keeps it honest.
    static let forbiddenWords = ["because", "causes", "caused", "leads to", "led to", "makes", "results in", "due to"]
}
