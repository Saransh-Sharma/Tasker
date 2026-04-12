import SwiftUI

/// Week tab content for the Insights screen.
struct InsightsWeekView: View {

    @ObservedObject var viewModel: InsightsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsWeekState { viewModel.weekState }

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
        VStack(spacing: spacing.s12) {
            module(index: 0) {
                heroCard
            }
            module(index: 1) {
                weeklyOperatingCard
            }
            module(index: 2) {
                weeklyMomentumCard
            }
            module(index: 3) {
                weeklyPatternCard
            }
            module(index: 4) {
                leaderboardCard
            }
            module(index: 5) {
                mixCard(
                    eyebrow: "Priority mix",
                    title: "What kind of work actually got finished",
                    items: state.priorityMix
                )
            }
            module(index: 6) {
                mixCard(
                    eyebrow: "Task-type mix",
                    title: "When that work tends to land",
                    items: state.taskTypeMix
                )
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .onAppear {
            didAppear = true
        }
    }

    @ViewBuilder
    private var weeklyOperatingCard: some View {
        if let weeklyOperating = state.weeklyOperating {
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: spacing.s4) {
                            Text("Weekly operating layer")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textTertiary)
                            Text("\(weeklyOperating.momentumScore)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color.tasker.textPrimary)
                        }
                        Spacer()
                        Text(weeklyOperating.reviewStatusTitle)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }

                    Text(weeklyOperating.momentumNarrative)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text(weeklyOperating.carryOverSummary)
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textSecondary)
                        Text(weeklyOperating.contributionSummary)
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textSecondary)
                        Text(weeklyOperating.reflectionSummary)
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text(weeklyOperating.recoveryHeadline)
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text(weeklyOperating.recoverySummary)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                        Text(weeklyOperating.recoveryNarrative)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
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
                Text("Week")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(state.heroTitle)
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(state.heroSummary)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

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
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                        Text("\(state.weeklyTotalXP) XP")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.tasker.textPrimary)
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
                                .font(.tasker(.caption2))
                                .foregroundColor(bar.isToday ? Color.tasker.textPrimary : Color.tasker.textTertiary)
                            Text("\(bar.completionCount)")
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textQuaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(bar.label). \(bar.xp) XP. \(bar.completionCount) completions\(bar.isToday ? ". Today." : "")\(bar.isFuture ? ". Future day." : "")"
                        )
                    }
                }

                Text("Bottom labels show completions. Bars show XP intensity.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textQuaternary)
            }
        }
    }

    private var weeklyPatternCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Weekday pattern")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(state.patternSummary)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                HStack(spacing: spacing.s8) {
                    ForEach(state.weeklyBars) { bar in
                        VStack(spacing: spacing.s4) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(patternColor(for: bar))
                                .frame(height: 60)
                                .overlay(
                                    Text("\(Int((bar.intensity * 100).rounded()))")
                                        .font(.tasker(.caption2))
                                        .foregroundColor(bar.intensity > 0.5 ? Color.tasker.textInverse : Color.tasker.textSecondary)
                                )
                            Text(bar.label)
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(state.deltaSummary)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }

    private var leaderboardCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Project leaderboard")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                if state.projectLeaderboard.isEmpty {
                    Text("Weekly project signal appears once completions cluster around named projects.")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(Array(state.projectLeaderboard.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .top, spacing: spacing.s12) {
                            Text("\(index + 1)")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textQuaternary)
                                .frame(width: 18, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                    .font(.tasker(.headline))
                                    .foregroundColor(Color.tasker.textPrimary)
                                Text(row.subtitle)
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(row.value)
                                    .font(.tasker(.headline))
                                    .foregroundColor(toneColor(row.tone))
                                Text(row.detail)
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }
                        }
                        if index < state.projectLeaderboard.count - 1 {
                            Divider()
                                .overlay(Color.tasker.strokeHairline)
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
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                if items.isEmpty {
                    Text("This module unlocks after the week accumulates completed work.")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                } else {
                    ForEach(items) { item in
                        HStack(spacing: spacing.s8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label)
                                    .font(.tasker(.callout))
                                    .foregroundColor(Color.tasker.textPrimary)
                                Text(item.valueText)
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }
                            Spacer()
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.tasker.surfaceTertiary)
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
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)
            Text(metric.value)
                .font(.tasker(.headline))
                .foregroundColor(toneColor(metric.tone))
            Text(metric.detail)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(toneColor(metric.tone).opacity(0.14), lineWidth: 1)
        )
    }

    private func module<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        let delay = Double(index) * 0.05
        return content()
            .opacity(reduceMotion || didAppear ? 1 : 0)
            .scaleEffect(reduceMotion || didAppear ? 1 : 0.985)
            .offset(y: reduceMotion || didAppear ? 0 : 14)
            .animation(
                reduceMotion ? nil : TaskerAnimation.gentle.delay(delay),
                value: didAppear
            )
    }

    @ViewBuilder
    private func insightsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .taskerPremiumSurface(
                cornerRadius: 24,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.82),
                accentColor: Color.tasker.accentSecondary,
                level: .e2
            )
    }

    private func patternColor(for bar: WeeklyBarData) -> Color {
        if bar.isFuture {
            return Color.tasker.surfaceTertiary
        }
        if bar.isToday {
            return Color.tasker.accentPrimary
        }
        if bar.intensity >= 0.75 {
            return Color.tasker.statusSuccess
        }
        if bar.intensity >= 0.45 {
            return Color.tasker.accentSecondary
        }
        if bar.intensity > 0 {
            return Color.tasker.statusWarning
        }
        return Color.tasker.surfaceTertiary
    }

    private func toneColor(_ tone: InsightsMetricTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker.accentPrimary
        case .success:
            return Color.tasker.statusSuccess
        case .warning:
            return Color.tasker.statusWarning
        case .neutral:
            return Color.tasker.textPrimary
        }
    }
}
