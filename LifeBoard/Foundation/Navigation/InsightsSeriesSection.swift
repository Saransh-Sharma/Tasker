import Accessibility
import Charts
import SwiftUI

/// The Trends lens' charts: one per domain with at least three days of data,
/// each with its usual range drawn behind the line and spelled out beneath
/// it. Week / Month / Year switch the window. Nothing here says "better".
struct InsightsSeriesSection: View {
    let series: [DailySeries]
    let isLoading: Bool
    @Binding var range: InsightsRange
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    static let minimumDays = 3

    /// At pad widths one chart per row left each plot a wide, shallow strip
    /// with most of the card empty; two columns keep the plots readable and
    /// let a person compare areas side by side. `.adaptive` falls back to a
    /// single column when the pad column is too narrow for two.
    private var padColumns: [GridItem] { [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)] }

    private var charted: [DailySeries] {
        series.filter { $0.points.count >= Self.minimumDays }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader("Your usual")
                Spacer(minLength: 8)
            }
            LensPicker(
                "Range",
                selection: $range,
                values: InsightsRange.allCases,
                identifierPrefix: "insights.range",
                title: \.title,
                identifier: \.rawValue
            )

            if charted.isEmpty {
                Text(isLoading ? "Loading…" : "Not enough data yet")
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            } else if layoutClass.isPad {
                LazyVGrid(columns: padColumns, alignment: .leading, spacing: 16) {
                    chartRows
                }
            } else {
                chartRows
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.series")
    }

    private var chartRows: some View {
        ForEach(charted) { item in
            InsightsSeriesChart(series: item, range: range)
                .lifeBoardScrollEntrance(intensity: 0.5)
        }
    }
}

private struct InsightsSeriesChart: View {
    let series: DailySeries
    let range: InsightsRange
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var usual: UsualRange? { UsualRange.make(series.values) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: series.metric.systemImage)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Text(series.metric.label)
                    .lifeboardFont(.bodyStrong)
                Spacer()
                Text("Last \(range.days) days")
                    .lifeboardFont(.meta)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            let chart = InsightsScrubbableChart(
                points: series.points,
                tint: Color(SemanticColorTokens.foundationApricotInk),
                unit: series.metric.unit,
                accessibilityTitle: "\(series.metric.label), last \(range.days) days",
                band: usual?.band,
                revealID: range
            )
            chart
                // Taller at pad widths: the grid gives each chart a wider
                // column, and a 120pt plot there flattens every change.
                .frame(height: layoutClass.isPad ? 180 : 120)
                // One reading for VoiceOver, including the usual range: the
                // visible copy below says the same and is hidden from it.
                .accessibilityValue(text(for: chart))
            Text(text(for: chart))
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            if usual != nil {
                UsualRangeLegend()
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.series.\(series.metric.rawValue)")
    }

    private func text(for chart: InsightsScrubbableChart) -> String {
        guard let usual else { return chart.textEquivalent }
        return chart.textEquivalent + " · " + usual.text(unit: series.metric.unit, fractionDigits: series.metric.fractionDigits)
    }
}

/// Names the quiet band behind the line, so the shape is not the only
/// explanation of what it is.
private struct UsualRangeLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(SemanticColorTokens.foundationSurfaceRecessed))
                .frame(width: 14, height: 8)
            Text("Usual range")
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .accessibilityHidden(true)
    }
}

/// `TrendChart`'s drawing plus scrubbing: a pointer hover, click or touch-drag
/// picks the nearest day, and a rule names that day's reading. On Mac and iPad
/// the chart was otherwise a picture — the only way to learn a single value
/// was to read it off the axis.
///
/// It lives here rather than as an option on `TrendChart` because the rule and
/// its label have to be marks inside the `Chart`; nothing applied from outside
/// a finished chart can add one. The marks, axes, reveal sweep and VoiceOver
/// reading match `TrendChart`, so swapping one for the other changes only the
/// scrubbing. The selection is visual only: VoiceOver already hears every
/// value through the text equivalent.
struct InsightsScrubbableChart: View {
    let points: [HomeSeriesPoint]
    let tint: Color
    let unit: String?
    let accessibilityTitle: String
    var band: ClosedRange<Double>? = nil
    /// Redraws the sweep when the range changes, as `TrendChart` does.
    var revealID: AnyHashable? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress: Double = 0
    @State private var hasRevealed = false
    @State private var selectedDate: Date?

    var textEquivalent: String {
        TrendChart.textEquivalent(for: points.map(\.value), unit: unit)
    }

    /// The recorded day nearest the pointer. The raw selection is a
    /// continuous date between days; snapping keeps the rule on a real
    /// reading instead of an interpolated one the person never logged.
    private var selectedPoint: HomeSeriesPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            if let band, band.upperBound > band.lowerBound {
                RectangleMark(
                    yStart: .value("Usual low", band.lowerBound),
                    yEnd: .value("Usual high", band.upperBound)
                )
                .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceRecessed).opacity(0.7))
            }
            ForEach(points) { point in
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
            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    // Fitted to the chart on both axes so the label never
                    // spills over the card edge or the header above it.
                    .annotation(
                        position: .top,
                        spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        selectionLabel(for: selectedPoint)
                    }
                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected value", selectedPoint.value)
                )
                .foregroundStyle(tint)
                .symbolSize(48)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel().font(.caption2)
            }
        }
        .lifeboardChartRevealSweep(progress: revealProgress)
        // Same reveal contract as `TrendChart`: once when data first appears,
        // again when the range changes, never on an empty chart.
        .onAppear {
            guard points.isEmpty == false, hasRevealed == false else {
                if points.isEmpty { revealProgress = 0 }
                return
            }
            reveal()
        }
        .onChange(of: points.count) { previous, updated in
            guard updated > 0 else {
                revealProgress = 0
                return
            }
            guard previous == 0 else { return }
            reveal()
        }
        .onChange(of: revealID) { _, _ in
            // A selection made in the old window points at a day that may
            // not be in the new one.
            selectedDate = nil
            guard points.isEmpty == false else { return }
            reveal()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(textEquivalent)
        // Audio Graphs: VoiceOver can play the series and step day by day.
        .accessibilityChartDescriptor(
            InsightsChartDescriptor(title: accessibilityTitle, summary: textEquivalent, points: points, unit: unit)
        )
    }

    private func selectionLabel(for point: HomeSeriesPoint) -> some View {
        let value = point.value.formatted(.number.precision(.fractionLength(0...1)))
        let unitSuffix = unit.map { " \($0)" } ?? ""
        return VStack(alignment: .leading, spacing: 4) {
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Text(value + unitSuffix)
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Color.lifeboard(.surfacePrimary),
            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
        )
    }

    private func reveal() {
        hasRevealed = true
        guard reduceMotion == false else {
            revealProgress = 1
            return
        }
        revealProgress = 0
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { revealProgress = 1 }
    }
}

/// The chart as data for VoiceOver's Audio Graphs.
struct InsightsChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let points: [HomeSeriesPoint]
    let unit: String?

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = unit
        let dates = points.map(\.date)
        let values = points.map(\.value)
        let start = dates.min() ?? Date()
        let end = dates.max() ?? start
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Date",
            range: start.timeIntervalSince1970...max(end.timeIntervalSince1970, start.timeIntervalSince1970 + 1),
            gridlinePositions: []
        ) { value in
            Date(timeIntervalSince1970: value).formatted(.dateTime.month(.abbreviated).day())
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: unit ?? "Value",
            range: min(0, low)...max(high, low + 1),
            gridlinePositions: []
        ) { value in
            value.formatted(.number.precision(.fractionLength(0...1))) + (unit.map { " \($0)" } ?? "")
        }
        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.value) }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
