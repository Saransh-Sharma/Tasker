import SwiftUI

/// Systems tab content for the Insights screen.
struct InsightsSystemsView: View {

    @ObservedObject var viewModel: InsightsViewModel

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsSystemsState { viewModel.systemsState }

    private var levelProgress: CGFloat {
        let range = state.nextLevelXP - state.currentLevelThreshold
        guard range > 0 else { return 0 }
        let progress = state.totalXP - state.currentLevelThreshold
        return min(1.0, CGFloat(progress) / CGFloat(range))
    }

    var body: some View {
        VStack(spacing: spacing.s12) {
            // Level Progress
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Level Progress")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)

                    HStack(spacing: spacing.s8) {
                        Text("Level \(state.level)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color.tasker.accentPrimary)

                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.tasker.surfaceTertiary)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .scaleEffect(x: levelProgress, y: 1, anchor: .leading)
                        }
                        .frame(height: GamificationTokens.progressBarHeightLarge)
                    }

                    Text("\(state.totalXP) XP · Next: \(state.nextLevelXP) XP (L\(state.level + 1))")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }

            // Next Milestone
            if let milestone = state.nextMilestone {
                insightsCard {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Next Milestone")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)

                        HStack(spacing: spacing.s12) {
                            // Progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.tasker.surfaceTertiary, lineWidth: 6)
                                Circle()
                                    .trim(from: 0, to: state.milestoneProgress)
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary]),
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))

                                Text("\(Int(state.milestoneProgress * 100))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.tasker.accentPrimary)
                            }
                            .frame(width: 64, height: 64)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.name)
                                    .font(.tasker(.headline))
                                    .foregroundColor(Color.tasker.textPrimary)
                                Text("\(state.totalXP) / \(milestone.xpThreshold) XP")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                let remaining = milestone.xpThreshold - state.totalXP
                                Text("\(remaining) XP to go")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                            }
                        }
                    }
                }
            }

            // Achievements
            insightsCard {
                BadgeGalleryView(unlockedKeys: state.unlockedAchievements)
            }

            // Streaks
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Streaks")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)

                    HStack(spacing: spacing.s16) {
                        HStack(spacing: spacing.s4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: GamificationTokens.streakFlameSize))
                                .foregroundColor(state.streakDays > 0 ? Color.tasker.statusWarning : Color.tasker.textQuaternary)
                            VStack(alignment: .leading) {
                                Text("Current")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                                Text("\(state.streakDays) days")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.tasker.textPrimary)
                            }
                        }

                        HStack(spacing: spacing.s4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: GamificationTokens.streakFlameSize))
                                .foregroundColor(Color.tasker.accentPrimary)
                            VStack(alignment: .leading) {
                                Text("Best")
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)
                                Text("\(state.bestStreak) days")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.tasker.textPrimary)
                            }
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
}
