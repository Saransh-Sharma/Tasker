import SwiftUI

/// Week tab content for the Insights screen.
struct InsightsWeekView: View {

    @ObservedObject var viewModel: InsightsViewModel

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
            // Weekly Chart Card
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    HStack {
                        Text("Weekly XP")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                        Spacer()
                        Text("\(state.weeklyTotalXP) XP")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.tasker.textPrimary)
                    }

                    Picker("Scale", selection: Binding(
                        get: { viewModel.weekScaleMode },
                        set: { viewModel.setWeekScaleMode($0) }
                    )) {
                        ForEach(InsightsWeekScaleMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Weekly XP scale mode")

                    // Bar Chart
                    HStack(alignment: .bottom, spacing: GamificationTokens.weeklyBarSpacing) {
                        ForEach(state.weeklyBars) { bar in
                            VStack(spacing: 4) {
                                barView(for: bar)
                                    .frame(height: GamificationTokens.weeklyBarMaxHeight)

                                Text(bar.label)
                                    .font(.tasker(.caption2))
                                    .fontWeight(bar.isToday ? .bold : .regular)
                                    .foregroundColor(bar.isToday ? Color.tasker.textPrimary : Color.tasker.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                "\(bar.label). \(bar.xp) XP\(bar.isToday ? ". Today" : "")\(bar.isFuture ? ". Future day" : "")"
                            )
                        }
                    }

                    // Goal line label
                    HStack {
                        Spacer()
                        Text(viewModel.weekScaleMode == .goal
                                ? "Goal: \(GamificationTokens.dailyXPCap) XP"
                                : "Scale: Personal max")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textQuaternary)
                    }
                }
            }

            // Stats Card
            insightsCard {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Stats")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)

                    statRow(label: "Goal-hit days", value: "\(state.goalHitDays) / 7")
                    statRow(label: "Best day", value: state.bestDayLabel)
                    statRow(label: "Avg/day", value: "\(state.averageDailyXP) XP")
                }
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
    }

    @ViewBuilder
    private func barView(for bar: WeeklyBarData) -> some View {
        let ratio = CGFloat(max(0, bar.xp)) / CGFloat(maxBarXP)
        let barHeight = bar.xp > 0
            ? max(4, GamificationTokens.weeklyBarMaxHeight * ratio)
            : 4

        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: GamificationTokens.weeklyBarCornerRadius, style: .continuous)
                .fill(barColor(for: bar))
                .frame(width: GamificationTokens.weeklyBarWidth, height: barHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private func barColor(for bar: WeeklyBarData) -> Color {
        if bar.isFuture { return Color.tasker.surfaceTertiary }
        if bar.isToday { return Color.tasker.accentPrimary }
        return Color.tasker.accentMuted
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textSecondary)
            Spacer()
            Text(value)
                .font(.tasker(.callout))
                .fontWeight(.semibold)
                .foregroundColor(Color.tasker.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    @ViewBuilder
    private func insightsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.tasker.surfacePrimary)
            )
    }
}
