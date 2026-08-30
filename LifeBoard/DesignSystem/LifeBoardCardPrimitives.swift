import Charts
import SwiftUI

/// Shared building blocks for Home and Insights cards.
///
/// Cards used to be title + sentence + "Open", because `HomeCardSnapshot`
/// carried only strings. With a typed payload the dashboard can finally show a
/// number as a number, a series as a chart, and a target as a ring. Everything
/// here is Dynamic Type-backed, tokenised, and degrades under Reduce Motion.

// MARK: - Hero numeral

// MARK: - Focus dial

enum FocusDialMetrics {
    static func elapsedFraction(
        totalDuration: TimeInterval?,
        remainingDuration: TimeInterval?
    ) -> Double? {
        guard let totalDuration, let remainingDuration, totalDuration > 0 else { return nil }
        return min(1, max(0, 1 - (remainingDuration / totalDuration)))
    }
}

/// A presentation-only focus dial. Timer ownership stays with the Focus domain;
/// this view only turns a supplied progress value into one calm, interruptible arc.
/// The dial's ambient breath.
///
/// `DESIGN.md`: "While a session is running the dial carries ambient motion
/// within the budget above, so an active session reads as alive rather than
/// frozen; it settles to a static progress presentation when paused, when
/// completed, and whenever the ambient budget withdraws." The dial had no
/// ambient motion at all, so a running session and a paused one were the same
/// picture.
///
/// It breathes the arc's *glow*, not its geometry. The budget caps amplitude at
/// 2% of the element's dimension "and never enough to shift a reading position"
/// — on a 200-point dial that is four points, which on a progress arc would be
/// legible as the value moving. A luminance breath reads as alive and cannot
/// misreport the number.
private struct FocusDialBreath: ViewModifier {
    let isActive: Bool

    private let restingOpacity: Double = 0.2
    /// Half-band, so the breath spans 0.14–0.26 around the resting glow.
    private let band: Double = 0.06

    /// One `TimelineView`, one shadow, and `paused:` doing the gating.
    ///
    /// The two-branch version needed a second `.shadow(` for the settled case,
    /// which the shadow law counts as new ad-hoc shadow geometry — correctly, as
    /// far as a grep can tell. Pausing the timeline is also the mechanism the
    /// ambient budget already names for withdrawing motion, so this is the
    /// shape the rule was pointing at.
    func body(content: Content) -> some View {
        TimelineView(
            .animation(
                minimumInterval: 1 / AmbientMotionBudget.maximumFrameRate,
                paused: isActive == false
            )
        ) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            let breath = isActive ? restingOpacity + band * sin(phase * 1.1) : 0
            content.shadow(
                color: Color(SemanticColorTokens.foundationApricotAccent).opacity(breath),
                radius: 8
            )
        }
    }
}

/// Claims the screen's one ambient timeline, but only while the dial is
/// actually running — a settled dial must not hold the budget.
private struct ConditionalAmbientClaim: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.lifeBoardClaimsAmbientTimeline()
        } else {
            content
        }
    }
}

public struct FocusDial<Content: View>: View {
    private let progress: Double?
    private let isPaused: Bool
    private let accessibilityValue: String
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init(
        progress: Double?,
        isPaused: Bool,
        accessibilityValue: String,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress.map { min(1, max(0, $0)) }
        self.isPaused = isPaused
        self.accessibilityValue = accessibilityValue
        self.content = content()
    }

    /// Running, and the budget has not withdrawn.
    ///
    /// A paused or completed dial settles to a static presentation, and so does
    /// one under Reduce Motion or on an inactive scene — ambient motion is a
    /// privilege with a budget, not a property of the component.
    private var carriesAmbientMotion: Bool {
        progress != nil
            && isPaused == false
            && MotionOverride.resolve(reduceMotion) == false
            && scenePhase == .active
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color(SemanticColorTokens.foundationSurfaceRecessed),
                    style: StrokeStyle(lineWidth: 11)
                )

            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.018, progress))
                    .stroke(
                        isPaused
                            ? Color(SemanticColorTokens.foundationSageAccent)
                            : Color(SemanticColorTokens.foundationApricotAccent),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .modifier(FocusDialBreath(isActive: carriesAmbientMotion))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.9),
                        value: progress
                    )
            } else {
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        Color(SemanticColorTokens.foundationSageAccent),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            content
                .padding(26)
        }
        .modifier(ConditionalAmbientClaim(isActive: carriesAmbientMotion))
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus timer")
        .accessibilityValue(accessibilityValue)
    }
}

/// Change against the comparison window. Never colour alone — the arrow and the
/// spoken label both carry the direction.
public struct TrendBadge: View {
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
        Color(SemanticColorTokens.inkSecondary)
    }
}

// MARK: - Sparkline

/// A compact shape-only series for glance and standard sizes. Deliberately not
/// a chart: no axes, no gridlines, nothing to read precisely.
public struct Sparkline: View {
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
public struct TrendChart: View {
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
public struct ProgressRing: View {
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
public struct StreakGrid: View {
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

/// A plain-advance deck is now the degenerate case of
/// `DirectionalDeck` (a single candidate action fills the `right`
/// slot), so `LifeBoardDeckStack` was removed rather than left as a second deck
/// idiom with its own hardcoded springs and horizontal-only gesture. It had no
/// call sites. See `LifeBoard/DesignSystem/DirectionalDeck.swift`.
