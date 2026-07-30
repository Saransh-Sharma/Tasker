import Charts
import SwiftUI

/// Shared building blocks for Home and Insights cards.
///
/// Cards used to be title + sentence + "Open", because `HomeCardSnapshot`
/// carried only strings. With a typed payload the dashboard can finally show a
/// number as a number, a series as a chart, and a target as a ring. Everything
/// here is Dynamic Type-backed, tokenised, and degrades under Reduce Motion.

// MARK: - Hero numeral

/// An odometer-style numeral. Rolls only when the *value* changes, never on an
/// incidental redraw, so a scrolling dashboard stays still.
public struct LifeBoardNumericRoll: View {
    private let value: Double
    private let fractionDigits: Int
    private let unit: String?
    private let emphasis: Emphasis

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum Emphasis {
        /// Inline with supporting copy.
        case standard
        /// The card's single largest element.
        case hero

        var textStyle: LifeBoardTextStyle {
            switch self {
            case .standard: .metric
            case .hero: .heroDisplay
            }
        }
    }

    public init(
        value: Double,
        fractionDigits: Int = 0,
        unit: String? = nil,
        emphasis: Emphasis = .standard
    ) {
        self.value = value
        self.fractionDigits = fractionDigits
        self.unit = unit
        self.emphasis = emphasis
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(formatted)
                .lifeboardFont(emphasis.textStyle)
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                    value: value
                )
            if let unit, unit.isEmpty == false {
                Text(unit)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleValue)
    }

    private var formatted: String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .grouping(.automatic)
        )
    }

    private var accessibleValue: String {
        guard let unit, unit.isEmpty == false else { return formatted }
        return "\(formatted) \(unit)"
    }
}

/// Change against the comparison window. Never colour alone — the arrow and the
/// spoken label both carry the direction.
public struct LifeBoardTrendBadge: View {
    private let trend: HomeMetricValue.Trend
    private let description: String?

    public init(trend: HomeMetricValue.Trend, description: String?) {
        self.trend = trend
        self.description = description
    }

    public var body: some View {
        if let description, description.isEmpty == false {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                Text(description)
                    .lifeboardFont(.caption1)
            }
            .foregroundStyle(tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(spokenDirection), \(description)")
        }
    }

    private var symbol: String {
        switch trend {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    private var spokenDirection: String {
        switch trend {
        case .up: "Up"
        case .down: "Down"
        case .flat: "Unchanged"
        }
    }

    private var tint: Color {
        // Direction is not judgement: a downward weight trend is not "bad".
        // Callers that need valence colour it themselves.
        Color(LifeBoardColorTokens.inkSecondary)
    }
}

// MARK: - Sparkline

/// A compact shape-only series for glance and standard sizes. Deliberately not
/// a chart: no axes, no gridlines, nothing to read precisely.
public struct LifeBoardSparkline: View {
    private let points: [HomeSeriesPoint]
    private let tint: Color

    public init(points: [HomeSeriesPoint], tint: Color) {
        self.points = points
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            let path = linePath(in: proxy.size)
            ZStack {
                path
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(closedPath(in: proxy.size))
                path
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard points.count > 1, size.width > 0, size.height > 0 else { return [] }
        let values = points.map(\.value)
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 1
        // A flat series should sit on the midline rather than divide by zero.
        let span = highest - lowest
        let stepX = size.width / CGFloat(points.count - 1)
        return points.enumerated().map { index, point in
            let ratio = span > 0 ? (point.value - lowest) / span : 0.5
            return CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - (CGFloat(ratio) * size.height)
            )
        }
    }

    private func linePath(in size: CGSize) -> Path {
        let resolved = normalized(in: size)
        guard resolved.isEmpty == false else { return Path() }
        var path = Path()
        path.move(to: resolved[0])
        for point in resolved.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func closedPath(in size: CGSize) -> Path {
        let resolved = normalized(in: size)
        guard let first = resolved.first, let last = resolved.last else { return Path() }
        var path = linePath(in: size)
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.addLine(to: CGPoint(x: first.x, y: size.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Trend chart

/// A real chart with an always-present text equivalent. The chart draws itself
/// in once behind a travelling mask; the equivalent is what VoiceOver reads and
/// what replaces the chart entirely at accessibility text sizes.
public struct LifeBoardTrendChart: View {
    private let points: [HomeSeriesPoint]
    private let tint: Color
    private let unit: String?
    private let showsAxis: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress: Double = 0

    public init(
        points: [HomeSeriesPoint],
        tint: Color,
        unit: String? = nil,
        showsAxis: Bool = true
    ) {
        self.points = points
        self.tint = tint
        self.unit = unit
        self.showsAxis = showsAxis
    }

    public var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.26), tint.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            .interpolationMethod(.monotone)
        }
        .chartXAxis {
            if showsAxis {
                AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                }
            }
        }
        .chartYAxis {
            if showsAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel().font(.caption2)
                }
            }
        }
        .lifeboardChartRevealSweep(progress: revealProgress)
        .onAppear {
            guard reduceMotion == false else {
                revealProgress = 1
                return
            }
            withAnimation(.easeOut(duration: 0.42)) { revealProgress = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trend chart")
        .accessibilityValue(textEquivalent)
    }

    /// Prose the chart can be read as. Charts must never be the only carrier.
    public var textEquivalent: String {
        guard let first = points.first, let last = points.last else {
            return "No readings yet."
        }
        let unitSuffix = unit.map { " \($0)" } ?? ""
        let start = first.value.formatted(.number.precision(.fractionLength(0...1)))
        let end = last.value.formatted(.number.precision(.fractionLength(0...1)))
        let direction: String = if last.value > first.value {
            "up from"
        } else if last.value < first.value {
            "down from"
        } else {
            "unchanged from"
        }
        return "\(points.count) readings, \(end)\(unitSuffix) \(direction) \(start)\(unitSuffix)."
    }
}

// MARK: - Progress ring

/// A ring whose fill settles rather than snapping, with a meniscus that
/// overshoots once and comes to rest.
public struct LifeBoardProgressRing: View {
    private let fraction: Double
    private let tint: Color
    private let trackTint: Color
    private let lineWidth: CGFloat
    private let label: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedFraction: Double = 0

    public init(
        fraction: Double,
        tint: Color,
        trackTint: Color,
        lineWidth: CGFloat = 6,
        label: String? = nil
    ) {
        self.fraction = fraction
        self.tint = tint
        self.trackTint = trackTint
        self.lineWidth = lineWidth
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(trackTint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, animatedFraction)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label, label.isEmpty == false {
                Text(label)
                    .lifeboardFont(.caption1)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
            }
        }
        .onAppear { settle(to: fraction) }
        .onChange(of: fraction) { _, updated in settle(to: updated) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue("\(Int((max(0, min(1, fraction)) * 100).rounded())) percent")
    }

    private func settle(to target: Double) {
        guard reduceMotion == false else {
            animatedFraction = target
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            animatedFraction = target
        }
    }
}

// MARK: - Streak grid

/// Recent performance as a row or grid of days. Shape and opacity both carry
/// the outcome, so it survives Differentiate Without Color.
public struct LifeBoardStreakGrid: View {
    private let days: [HomeDayState]
    private let tint: Color
    private let columns: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(days: [HomeDayState], tint: Color, columns: Int = 7) {
        self.days = days
        self.tint = tint
        self.columns = max(1, columns)
    }

    public var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
            spacing: 4
        ) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                cell(for: day)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.3, dampingFraction: 0.75)
                                .delay(min(Double(index) * 0.012, 0.32)),
                        value: appeared
                    )
            }
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent days")
        .accessibilityValue(summary)
    }

    @ViewBuilder
    private func cell(for day: HomeDayState) -> some View {
        switch day.outcome {
        case .complete:
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(tint)
        case .partial:
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(tint.opacity(0.45))
        case .missed:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        case .offDay:
            // Visually distinct from a miss: an off day is not a failure.
            Circle().fill(tint.opacity(0.18))
        case .future:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint.opacity(0.06))
        }
    }

    private var summary: String {
        let complete = days.filter { $0.outcome == .complete }.count
        let counted = days.filter { $0.outcome != .future && $0.outcome != .offDay }.count
        guard counted > 0 else { return "No days recorded yet." }
        return "\(complete) of \(counted) days complete."
    }
}

// MARK: - Deck stack

/// Shows that a triage card is the front of a queue.
///
/// Plan Repair and Overdue Rescue render one proposal at a time with no hint
/// that more are waiting, so resolving one felt like it produced another out of
/// nowhere. This is the sample project's shuffle idea reduced to the part that
/// carries information: depth. It deliberately does not take over the host's
/// gesture — Plan Repair maps swipe *direction* to distinct actions, which a
/// generic dismiss-deck would throw away.
public struct LifeBoardDeckDepth: ViewModifier {
    private let remaining: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Two backing cards is enough to read as "more than one"; more just adds
    /// visual noise at the bottom of the card.
    private static let maximumBackingCards = 2

    public init(remaining: Int) {
        self.remaining = remaining
    }

    private var backingCount: Int {
        max(0, min(Self.maximumBackingCards, remaining - 1))
    }

    public func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                if backingCount > 0 {
                    ZStack {
                        ForEach(Array((1...backingCount).reversed()), id: \.self) { depth in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                                }
                                .scaleEffect(1 - (CGFloat(depth) * 0.035))
                                .offset(y: CGFloat(depth) * 7)
                                .opacity(1 - (Double(depth) * 0.25))
                        }
                    }
                    .allowsHitTesting(false)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84),
                        value: backingCount
                    )
                }
            }
            .accessibilityValue(
                remaining > 1 ? "1 of \(remaining)" : ""
            )
    }
}

public extension View {
    /// Renders the card as the front of a queue of `remaining` items.
    func lifeBoardDeckDepth(remaining: Int) -> some View {
        modifier(LifeBoardDeckDepth(remaining: remaining))
    }
}

/// A plain-advance deck is now the degenerate case of
/// `LifeBoardDirectionalDeck` (a single candidate action fills the `right`
/// slot), so `LifeBoardDeckStack` was removed rather than left as a second deck
/// idiom with its own hardcoded springs and horizontal-only gesture. It had no
/// call sites. See `LifeBoard/DesignSystem/LifeBoardDirectionalDeck.swift`.
