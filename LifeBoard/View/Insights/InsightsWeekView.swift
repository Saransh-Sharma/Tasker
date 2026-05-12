import SwiftUI

/// Week tab content for the Insights screen.
struct InsightsWeekView: View {

    @ObservedObject var viewModel: InsightsViewModel

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsWeekState { viewModel.weekState }
    private var weekRangeText: String {
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekStart = XPCalculationEngine.mondayStartOfWeek(for: Date(), calendar: calendar)
        return WeeklyCopy.weekRangeText(for: weekStart)
    }

    private var maxBarXP: Int {
        let personalMax = max(state.weeklyBars.map(\.xp).max() ?? 1, 1)
        switch viewModel.weekScaleMode {
        case .goal:
            return max(personalMax, GamificationTokens.dailyXPCap)
        case .personalMax:
            return personalMax
        }
    }

    var body: some View {
        LazyVStack(spacing: spacing.s12) {
            module(index: 0) {
                heroCard
            }
            module(index: 1) {
                weeklyPatternCard
            }
            module(index: 2) {
                weeklyMomentumCard
            }
            module(index: 3) {
                weeklyOperatingCard
            }
            module(index: 4) {
                leaderboardCard
            }
            module(index: 5) {
                mixCard(
                    eyebrow: "Priority mix",
                    title: "What actually got finished",
                    items: state.priorityMix
                )
            }
            module(index: 6) {
                mixCard(
                    eyebrow: "Task-type mix",
                    title: "When that work lands",
                    items: state.taskTypeMix
                )
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
    }

    @ViewBuilder
    private var weeklyOperatingCard: some View {
        if let weeklyOperating = state.weeklyOperating {
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: spacing.s4) {
                            Text("Review this week")
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard.textTertiary)
                            Text("\(weeklyOperating.momentumScore)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color.lifeboard.textPrimary)
                        }
                        Spacer()
                        Text(weeklyOperating.reviewStatusTitle)
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                    }

                    Text(weeklyOperating.momentumNarrative)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        insightsSummaryRow(title: "What still needs a decision", body: weeklyOperating.carryOverSummary)
                        insightsSummaryRow(title: "Weekly outcomes", body: weeklyOperating.contributionSummary)
                        insightsSummaryRow(title: "Reflection", body: weeklyOperating.reflectionSummary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text(weeklyOperating.recoveryHeadline)
                            .font(.lifeboard(.callout))
                            .foregroundColor(Color.lifeboard.textPrimary)
                        Text(weeklyOperating.recoverySummary)
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                        DisclosureGroup("Details") {
                            Text(weeklyOperating.recoveryNarrative)
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard.textSecondary)
                                .padding(.top, spacing.s4)
                        }
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textTertiary)
                    }

                    if weeklyOperating.momentumDrivers.isEmpty == false {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: spacing.s8) {
                            ForEach(weeklyOperating.momentumDrivers) { metric in
                                metricCard(metric)
                            }
                        }
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .center, spacing: spacing.s8) {
                    Text("This Week")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textTertiary)

                    LifeBoardStatusPill(
                        text: weekRangeText,
                        systemImage: "calendar",
                        tone: .quiet
                    )
                }

                Text(state.heroCard.title)
                    .font(.lifeboard(.title2))
                    .foregroundColor(Color.lifeboard.textPrimary)

                Text(state.heroCard.metric)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)

                Text(state.heroCard.hint)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textSecondary)

                if let detail = state.heroCard.detail, detail.isEmpty == false {
                    DisclosureGroup("Details") {
                        Text(detail)
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                            .padding(.top, spacing.s4)
                    }
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: spacing.s8) {
                    ForEach(state.weeklySummaryMetrics) { metric in
                        metricCard(metric)
                    }
                }
            }
        }
    }

    private var weeklyMomentumCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Weekly momentum")
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textTertiary)
                        Text("\(state.weeklyTotalXP) XP")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.lifeboard.textPrimary)
                    }
                    Spacer()
                    Picker("Scale", selection: Binding(
                        get: { viewModel.weekScaleMode },
                        set: { viewModel.setWeekScaleMode($0) }
                    )) {
                        ForEach(InsightsWeekScaleMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .accessibilityLabel("Weekly XP scale mode")
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(state.weeklyBars) { bar in
                        VStack(spacing: spacing.s4) {
                            xpBar(for: bar)
                            Text(bar.label)
                                .font(.lifeboard(.caption2))
                                .foregroundColor(bar.isToday ? Color.lifeboard.textPrimary : Color.lifeboard.textTertiary)
                            Text("\(bar.completionCount)")
                                .font(.lifeboard(.caption2))
                                .foregroundColor(Color.lifeboard.textQuaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(bar.label). \(bar.xp) XP. \(bar.completionCount) completions\(bar.isToday ? ". Today." : "")\(bar.isFuture ? ". Future day." : "")"
                        )
                    }
                }

                Text("Bars = XP, labels = completions.")
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textQuaternary)
            }
        }
    }

    private var weeklyPatternCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Weekday pattern")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)

                Text(state.patternSummary)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)

                HStack(spacing: spacing.s8) {
                    ForEach(state.weeklyBars) { bar in
                        VStack(spacing: spacing.s4) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(patternColor(for: bar))
                                .frame(height: 60)
                                .overlay(
                                    Text("\(Int((bar.intensity * 100).rounded()))")
                                        .font(.lifeboard(.caption2))
                                        .foregroundColor(bar.intensity > 0.5 ? Color.lifeboard.textInverse : Color.lifeboard.textSecondary)
                                )
                            Text(bar.label)
                                .font(.lifeboard(.caption2))
                                .foregroundColor(Color.lifeboard.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(state.deltaSummary)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }
        }
    }

    private var leaderboardCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Project leaderboard")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)

                if state.projectLeaderboard.isEmpty {
                    Text("Project signal appears after a few completions.")
                        .font(.lifeboard(.callout))
                        .foregroundColor(Color.lifeboard.textSecondary)
                } else {
                    ForEach(Array(state.projectLeaderboard.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .top, spacing: spacing.s12) {
                            Text("\(index + 1)")
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard.textQuaternary)
                                .frame(width: 18, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.lifeboard(.headline))
                                    .foregroundColor(Color.lifeboard.textPrimary)
                                Text(row.subtitle)
                                    .font(.lifeboard(.caption1))
                                    .foregroundColor(Color.lifeboard.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(row.value)
                                    .font(.lifeboard(.headline))
                                    .foregroundColor(toneColor(row.tone))
                                Text(row.detail)
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(Color.lifeboard.textTertiary)
                            }
                        }
                        if index < state.projectLeaderboard.count - 1 {
                            Divider()
                                .overlay(Color.lifeboard.strokeHairline)
                        }
                    }
                }
            }
        }
    }

    private func mixCard(
        eyebrow: String,
        title: String,
        items: [InsightsDistributionItem]
    ) -> some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(eyebrow)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)

                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)

                if items.isEmpty {
                    Text("This fills in as completions land.")
                        .font(.lifeboard(.callout))
                        .foregroundColor(Color.lifeboard.textSecondary)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: spacing.s8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label)
                                    .font(.lifeboard(.callout))
                                    .foregroundColor(Color.lifeboard.textPrimary)
                                Text(item.valueText)
                                    .font(.lifeboard(.caption2))
                                    .foregroundColor(Color.lifeboard.textTertiary)
                            }
                            Spacer()
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.lifeboard.surfaceTertiary)
                                    .frame(width: 110, height: 10)
                                Capsule()
                                    .fill(toneColor(item.tone))
                                    .frame(width: max(10, 110 * CGFloat(item.share)), height: 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private func xpBar(for bar: WeeklyBarData) -> some View {
        let ratio = CGFloat(max(0, bar.xp)) / CGFloat(maxBarXP)
        let outerHeight = max(36, 168 * max(0.12, ratio))
        let innerHeight = max(8, outerHeight * (bar.xp == 0 ? 0.2 : 0.78))

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(patternColor(for: bar).opacity(bar.isFuture ? 0.25 : 0.3))
                    .frame(height: outerHeight)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(patternColor(for: bar))
                    .frame(height: innerHeight)
            }
            .frame(height: 172, alignment: .bottom)
        }
    }

    private func metricCard(_ metric: InsightsMetricTile) -> some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(metric.title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textTertiary)
            Text(metric.value)
                .font(.lifeboard(.headline))
                .foregroundColor(toneColor(metric.tone))
            Text(metric.detail)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(toneColor(metric.tone).opacity(0.14), lineWidth: 1)
        )
    }

    private func insightsSummaryRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textTertiary)
            Text(body)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func module<Content: View>(index _: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
    }

    @ViewBuilder
    private func insightsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeboardAnalyticsSurface(
                cornerRadius: 24,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.82),
                accentColor: Color.lifeboard.accentSecondary,
                level: .e1
            )
    }

    private func patternColor(for bar: WeeklyBarData) -> Color {
        if bar.isFuture {
            return Color.lifeboard.surfaceTertiary
        }
        if bar.isToday {
            return Color.lifeboard.accentPrimary
        }
        if bar.intensity >= 0.75 {
            return Color.lifeboard.statusSuccess
        }
        if bar.intensity >= 0.45 {
            return Color.lifeboard.accentSecondary
        }
        if bar.intensity > 0 {
            return Color.lifeboard.statusWarning
        }
        return Color.lifeboard.surfaceTertiary
    }

    private func toneColor(_ tone: InsightsMetricTone) -> Color {
        switch tone {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        case .neutral:
            return Color.lifeboard.textPrimary
        }
    }
}
