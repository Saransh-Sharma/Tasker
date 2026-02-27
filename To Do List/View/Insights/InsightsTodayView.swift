import SwiftUI

/// Today tab content for the Insights screen.
struct InsightsTodayView: View {

    @ObservedObject var viewModel: InsightsViewModel

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsTodayState { viewModel.todayState }

    private var progress: CGFloat {
        guard state.dailyCap > 0 else { return 0 }
        return min(1.0, CGFloat(state.dailyXP) / CGFloat(state.dailyCap))
    }

    private var remainingToGoal: Int {
        max(0, state.dailyCap - state.dailyXP)
    }

    private var topXPSource: String {
        guard let top = state.xpBreakdown.max(by: { $0.xp < $1.xp }) else {
            return "No XP source yet"
        }
        return "\(top.displayName) (+\(top.xp) XP)"
    }

    var body: some View {
        VStack(spacing: spacing.s12) {
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Actionable Momentum")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)

                    statLine(
                        title: "Completed",
                        value: "\(state.tasksCompletedToday)/\(max(state.totalTasksToday, state.tasksCompletedToday)) tasks"
                    )
                    statLine(
                        title: "Remaining",
                        value: "\(remainingToGoal) XP to daily goal"
                    )
                    statLine(
                        title: "Top Source",
                        value: topXPSource
                    )
                    if state.tasksCompletedToday == 0 {
                        Text("Next: complete 1 task to start your streak momentum.")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Actionable momentum. Completed \(state.tasksCompletedToday) tasks. \(remainingToGoal) XP remaining to goal. Top source: \(topXPSource)."
                )
            }

            // XP Card
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Today's XP")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)

                    HStack(spacing: spacing.s16) {
                        // XP Ring
                        ZStack {
                            let size = GamificationTokens.XPRingSize.homeHero
                            Circle()
                                .stroke(Color.tasker.accentSecondaryMuted, lineWidth: size.ringWidth)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    AngularGradient(
                                        gradient: Gradient(colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary]),
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: size.ringWidth, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            Text("\(state.dailyXP)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color.tasker.accentPrimary)
                        }
                        .frame(width: GamificationTokens.XPRingSize.homeHero.diameter,
                               height: GamificationTokens.XPRingSize.homeHero.diameter)

                        VStack(alignment: .leading, spacing: spacing.s4) {
                            HStack(spacing: spacing.s4) {
                                Text("\(state.dailyXP)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.tasker.accentPrimary)
                                Text("/ \(state.dailyCap) XP")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }

                            // Progress bar
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.tasker.surfaceTertiary)
                                Capsule()
                                    .fill(
                                        state.dailyXP >= state.dailyCap
                                            ? Color.tasker.statusSuccess
                                            : Color.tasker.accentPrimary
                                    )
                                    .scaleEffect(x: progress, y: 1, anchor: .leading)
                            }
                            .frame(height: GamificationTokens.progressBarHeight)

                            Text("Level \(state.level)")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Today XP \(state.dailyXP) of \(state.dailyCap). Level \(state.level).")
            }

            // XP Breakdown
            if !state.xpBreakdown.isEmpty {
                insightsCard {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("XP Breakdown")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)

                        let maxXP = max(state.xpBreakdown.map(\.xp).max() ?? 1, 1)
                        ForEach(state.xpBreakdown) { item in
                            let ratio = min(1.0, CGFloat(item.xp) / CGFloat(maxXP))
                            HStack(spacing: spacing.s8) {
                                Text(item.displayName)
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                    .frame(width: 100, alignment: .leading)

                                Text("\(item.xp) XP")
                                    .font(.tasker(.caption1))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.tasker.textPrimary)
                                    .frame(width: 50, alignment: .trailing)

                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.tasker.surfaceTertiary)
                                    Capsule()
                                        .fill(Color.tasker.accentPrimary)
                                        .scaleEffect(x: ratio, y: 1, anchor: .leading)
                                }
                                .frame(height: 8)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.displayName)
                            .accessibilityValue("\(item.xp) XP")
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("XP breakdown with \(state.xpBreakdown.count) categories.")
                }
            } else {
                insightsCard {
                    Text("No XP events yet today. Start by completing one task.")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textSecondary)
                        .accessibilityLabel("No XP events yet today. Start by completing one task.")
                }
            }

            // Recovery Wins
            if state.recoveryCount > 0 {
                insightsCard {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Recovery Wins")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)

                        HStack(spacing: spacing.s8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.tasker.statusSuccess)
                            Text("\(state.recoveryCount) overdue tasks rescheduled")
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                        HStack(spacing: spacing.s8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color.tasker.accentPrimary)
                            Text("+\(state.recoveryXP) recovery XP")
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
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

    private func statLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
            Spacer()
            Text(value)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
