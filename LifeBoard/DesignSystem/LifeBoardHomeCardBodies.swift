import SwiftUI

/// One body per card archetype, each rendering at *every* size preset.
///
/// This replaces the old per-kind `switch` in the Home view, which had cases
/// only for six kinds at wide and above and fell through to `EmptyView()` for
/// the rest. Because accessibility text sizes force the wide preset, eleven
/// registered card kinds drew literally nothing for anyone using large type.
/// Dispatching on archetype makes that class of failure unrepresentable: a
/// registered kind has an archetype, and an archetype always draws something.
public struct LifeBoardHomeCardBody: View {
    private let snapshot: HomeCardSnapshot?
    private let archetype: HomeCardArchetype
    private let preset: WidgetSizePreset
    private let palette: LifeBoardDaypartPalette
    private let title: String
    private let symbol: String
    private let queueLimit: Int
    private let onAction: (HomeCardActionDescriptor) -> Void
    private let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        snapshot: HomeCardSnapshot?,
        archetype: HomeCardArchetype,
        preset: WidgetSizePreset,
        palette: LifeBoardDaypartPalette,
        title: String,
        symbol: String,
        queueLimit: Int = 4,
        onAction: @escaping (HomeCardActionDescriptor) -> Void = { _ in },
        onOpen: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.archetype = archetype
        self.preset = preset
        self.palette = palette
        self.title = title
        self.symbol = symbol
        self.queueLimit = queueLimit
        self.onAction = onAction
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: preset == .compact ? 6 : 10) {
            header
            content
            Spacer(minLength: 0)
            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(preset == .compact ? 12 : 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: preset == .compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(snapshot?.title ?? title)
                .lifeboardFont(.caption1)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let snapshot {
            switch snapshot.availability {
            case .unavailable, .redacted:
                statusBody(snapshot)
            case .empty:
                emptyBody(snapshot)
            case .ready, .degraded:
                payloadBody(snapshot)
            }
        } else {
            // A card shows its title alone until its provider resolves, which
            // is a frame at most. Never placeholder copy that might disagree
            // with what follows.
            Color.clear.frame(height: 1)
        }
    }

    @ViewBuilder
    private func payloadBody(_ snapshot: HomeCardSnapshot) -> some View {
        switch archetype {
        case .metric: metricBody(snapshot)
        case .ring: ringBody(snapshot)
        case .trend: trendBody(snapshot)
        case .queue: queueBody(snapshot)
        case .streak: streakBody(snapshot)
        case .decision: decisionBody(snapshot)
        case .spine: spineBody(snapshot)
        case .moment: momentBody(snapshot)
        case .countdown: countdownBody(snapshot)
        case .action: actionBody(snapshot)
        }
    }

    // MARK: Archetypes

    @ViewBuilder
    private func metricBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .metric(let metric) = snapshot.payload {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    LifeBoardNumericRoll(
                        value: metric.amount,
                        fractionDigits: metric.fractionDigits,
                        unit: metric.unit,
                        emphasis: usesLargeNumeral ? .hero : .standard
                    )
                    .foregroundStyle(palette.color(for: .foreground))
                    LifeBoardTrendBadge(trend: metric.trend, description: metric.deltaDescription)
                }

                if let detail = snapshot.detail, preset != .compact {
                    Text(detail)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }

                // History earns its space only once the card is big enough to
                // read it, and never at accessibility sizes where the numeral
                // and label already fill the card.
                if metric.history.count > 1, showsInlineGraphics {
                    if preset == .standard {
                        LifeBoardSparkline(points: metric.history, tint: accentTint)
                            .frame(height: 26)
                    } else {
                        LifeBoardTrendChart(
                            points: metric.history,
                            tint: accentTint,
                            unit: metric.unit,
                            showsAxis: preset == .tall || preset == .expanded
                        )
                        .frame(height: preset == .wide ? 58 : 96)
                    }
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func ringBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .progress(let fraction, let label) = snapshot.payload {
            HStack(spacing: 12) {
                LifeBoardProgressRing(
                    fraction: fraction,
                    tint: accentTint,
                    trackTint: palette.color(for: .canvasSecondary),
                    lineWidth: preset == .compact ? 5 : 7,
                    label: preset == .compact ? nil : label
                )
                .frame(width: ringDiameter, height: ringDiameter)

                if preset != .compact {
                    VStack(alignment: .leading, spacing: 3) {
                        if let value = snapshot.value {
                            Text(value)
                                .lifeboardFont(.bodyStrong)
                                .foregroundStyle(palette.color(for: .foreground))
                                .lineLimit(2)
                        }
                        if let detail = snapshot.detail {
                            Text(detail)
                                .lifeboardFont(.caption1)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .lineLimit(2)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func trendBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .series(let points) = snapshot.payload, points.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                if let value = snapshot.value {
                    Text(value)
                        .lifeboardFont(.metric)
                        .monospacedDigit()
                        .foregroundStyle(palette.color(for: .foreground))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if showsInlineGraphics {
                    let chart = LifeBoardTrendChart(
                        points: points,
                        tint: accentTint,
                        showsAxis: preset == .tall || preset == .expanded
                    )
                    if preset == .compact {
                        LifeBoardSparkline(points: points, tint: accentTint)
                            .frame(height: 22)
                    } else {
                        chart.frame(height: chartHeight)
                        if preset == .tall || preset == .expanded {
                            // The prose equivalent is visible, not just spoken,
                            // so the chart is never the sole carrier.
                            Text(chart.textEquivalent)
                                .lifeboardFont(.caption1)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    // Accessibility sizes: prose instead of a shrunken chart.
                    Text(LifeBoardTrendChart(points: points, tint: accentTint).textEquivalent)
                        .lifeboardFont(.body)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func queueBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .queue(let items) = snapshot.payload, items.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                if preset == .compact {
                    LifeBoardNumericRoll(value: Double(items.count), unit: itemNoun(items.count))
                        .foregroundStyle(palette.color(for: .foreground))
                } else {
                    ForEach(items.prefix(rowCount)) { item in
                        queueRow(item)
                    }
                    if items.count > rowCount {
                        Text("\(items.count - rowCount) more")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    private func queueRow(_ item: HomeQueueItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage ?? stateSymbol(item.state))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(item.state == .overdue ? overdueTint : palette.color(for: .foregroundSecondary))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lifeboardFont(.body)
                    .foregroundStyle(palette.color(for: .foreground))
                    .strikethrough(item.state == .done)
                    .lineLimit(1)
                if let supporting = item.supporting, preset != .standard {
                    Text(supporting)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(stateDescription(item.state))
    }

    @ViewBuilder
    private func streakBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .streak(let days) = snapshot.payload, days.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                if let value = snapshot.value {
                    Text(value)
                        .lifeboardFont(.bodyStrong)
                        .foregroundStyle(palette.color(for: .foreground))
                        .lineLimit(1)
                }
                if showsInlineGraphics {
                    LifeBoardStreakGrid(
                        days: Array(days.suffix(streakDayCount)),
                        tint: accentTint,
                        columns: 7
                    )
                    .frame(height: streakHeight)
                }
                if let detail = snapshot.detail {
                    Text(detail)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func decisionBody(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let value = snapshot.value {
                Text(value)
                    .lifeboardFont(preset == .compact ? .bodyStrong : .title3)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(preset == .compact ? 2 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = snapshot.detail {
                // The rationale is the point of a decision card; never truncate
                // it to a single line.
                Text(detail)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(preset == .compact ? 2 : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func spineBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .queue(let items) = snapshot.payload, items.isEmpty == false {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.prefix(rowCount).enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(index == 0 ? accentTint : palette.color(for: .canvasSecondary))
                                .frame(width: 7, height: 7)
                            if index < min(rowCount, items.count) - 1 {
                                Rectangle()
                                    .fill(palette.color(for: .canvasSecondary))
                                    .frame(width: 1.5)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 7)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .lifeboardFont(index == 0 ? .bodyStrong : .body)
                                .foregroundStyle(palette.color(for: .foreground))
                                .lineLimit(1)
                            if let supporting = item.supporting {
                                Text(supporting)
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.bottom, 10)
                        Spacer(minLength: 0)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func momentBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .moment(let moment) = snapshot.payload {
            VStack(alignment: .leading, spacing: 8) {
                if let mood = moment.moodLabel {
                    Text(mood)
                        .lifeboardFont(.caption1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(palette.color(for: .canvasSecondary), in: Capsule())
                        .foregroundStyle(palette.color(for: .foreground))
                }
                if let excerpt = moment.excerpt, excerpt.isEmpty == false {
                    Text(excerpt)
                        .lifeboardFont(.body)
                        .foregroundStyle(palette.color(for: .foreground))
                        .lineLimit(excerptLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let capturedAt = moment.capturedAt {
                    Text(capturedAt, format: .relative(presentation: .named))
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func countdownBody(_ snapshot: HomeCardSnapshot) -> some View {
        if case .countdown(let target, let label) = snapshot.payload {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: target)
            ).day ?? 0
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    LifeBoardNumericRoll(
                        value: Double(abs(days)),
                        unit: abs(days) == 1 ? "day" : "days",
                        emphasis: usesLargeNumeral ? .hero : .standard
                    )
                    .foregroundStyle(palette.color(for: .foreground))
                    Text(days < 0 ? "ago" : "away")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Text(label)
                    .lifeboardFont(.body)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
                if preset != .compact {
                    Text(target, format: .dateTime.weekday(.wide).day().month(.wide))
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
            }
        } else {
            fallbackSummary(snapshot)
        }
    }

    @ViewBuilder
    private func actionBody(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let value = snapshot.value {
                Text(value)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
            }
            if let detail = snapshot.detail, preset != .compact {
                Text(detail)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(2)
            }
        }
    }

    // MARK: States

    @ViewBuilder
    private func emptyBody(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.value ?? "Nothing yet")
                .lifeboardFont(.body)
                .foregroundStyle(palette.color(for: .foreground))
                .lineLimit(2)
            if let detail = snapshot.detail {
                Text(detail)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func statusBody(_ snapshot: HomeCardSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: snapshot.availability == .redacted ? "lock.fill" : "exclamationmark.triangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.value ?? (snapshot.availability == .redacted ? "Hidden here" : "Not available"))
                    .lifeboardFont(.body)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
                if let detail = snapshot.detail {
                    Text(detail)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Payload absent or the wrong shape for this archetype. Falls back to the
    /// provider's own strings rather than drawing nothing.
    @ViewBuilder
    private func fallbackSummary(_ snapshot: HomeCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let value = snapshot.value {
                Text(value)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let detail = snapshot.detail, preset != .compact {
                Text(detail)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions

    /// Providers have always populated `actions`; nothing ever rendered them.
    @ViewBuilder
    private var actionRow: some View {
        if let actions = snapshot?.actions, actions.isEmpty == false, preset != .compact {
            HStack(spacing: 8) {
                ForEach(actions.prefix(preset == .standard ? 1 : 2)) { action in
                    Button {
                        onAction(action)
                    } label: {
                        Label(action.title, systemImage: action.systemImage)
                            .lifeboardFont(.caption1)
                            .lineLimit(1)
                            .padding(.horizontal, 11)
                            .frame(minHeight: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        action.role == .destructive
                            ? overdueTint
                            : palette.color(for: .foreground)
                    )
                    .background(
                        action.role == .primary
                            ? palette.color(for: .canvasSecondary)
                            : Color.clear,
                        in: Capsule()
                    )
                    .overlay {
                        if action.role != .primary {
                            Capsule().stroke(palette.color(for: .canvasSecondary), lineWidth: 1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Size resolution

    /// Accessibility sizes get words, not shrunken graphics. `DESIGN.md` is
    /// explicit that dashboards must not shrink type to preserve a grid.
    private var showsInlineGraphics: Bool {
        dynamicTypeSize.isAccessibilitySize == false
    }

    private var usesLargeNumeral: Bool {
        switch preset {
        case .compact, .standard: false
        case .wide, .tall, .expanded: true
        }
    }

    private var rowCount: Int {
        switch preset {
        case .compact: 1
        case .standard: min(queueLimit, 2)
        case .wide: min(queueLimit, 4)
        case .tall, .expanded: min(max(queueLimit, 4), 6)
        }
    }

    private var chartHeight: CGFloat {
        switch preset {
        case .compact: 24
        case .standard: 42
        case .wide: 70
        case .tall: 104
        case .expanded: 132
        }
    }

    private var ringDiameter: CGFloat {
        switch preset {
        case .compact: 38
        case .standard: 52
        case .wide: 64
        case .tall, .expanded: 76
        }
    }

    private var streakDayCount: Int {
        switch preset {
        case .compact, .standard: 7
        case .wide: 14
        case .tall, .expanded: 28
        }
    }

    private var streakHeight: CGFloat {
        let rows = ceil(Double(streakDayCount) / 7)
        return CGFloat(rows) * 16
    }

    private var excerptLineLimit: Int {
        switch preset {
        case .compact: 2
        case .standard: 3
        case .wide: 4
        case .tall, .expanded: 8
        }
    }

    private var accentTint: Color {
        palette.color(for: .celestialPrimary)
    }

    private var overdueTint: Color {
        Color(LifeBoardColorTokens.foundationDanger)
    }

    private func itemNoun(_ count: Int) -> String {
        count == 1 ? "item" : "items"
    }

    private func stateSymbol(_ state: HomeQueueItem.State) -> String {
        switch state {
        case .pending: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done: "checkmark.circle.fill"
        case .overdue: "exclamationmark.circle"
        case .skipped: "minus.circle"
        }
    }

    private func stateDescription(_ state: HomeQueueItem.State) -> String {
        switch state {
        case .pending: "Not started"
        case .inProgress: "In progress"
        case .done: "Done"
        case .overdue: "Overdue"
        case .skipped: "Skipped"
        }
    }
}
