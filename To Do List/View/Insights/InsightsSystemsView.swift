import SwiftUI

/// Systems tab content for the Insights screen.
struct InsightsSystemsView: View {

    @ObservedObject var viewModel: InsightsViewModel
    @State private var selectedCategory: AchievementDefinition.AchievementCategory?
    @State private var selectedBadgeKey: String?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var state: InsightsSystemsState { viewModel.systemsState }
    private var progressByKey: [String: AchievementProgressState] {
        Dictionary(uniqueKeysWithValues: state.achievementProgress.map { ($0.key, $0) })
    }
    private var filteredAchievements: [AchievementDefinition] {
        AchievementCatalog.all.filter { achievement in
            guard let selectedCategory else { return true }
            return achievement.category == selectedCategory
        }
    }

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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Level \(state.level). \(state.totalXP) XP total. Next level at \(state.nextLevelXP) XP.")
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "Next milestone \(milestone.name). \(Int(state.milestoneProgress * 100)) percent complete. \(milestone.xpThreshold - state.totalXP) XP remaining."
                    )
                }
            }

            // Achievements
            insightsCard {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.s4) {
                            categoryChip(title: "All", isSelected: selectedCategory == nil) {
                                selectedCategory = nil
                            }

                            ForEach(AchievementDefinition.AchievementCategory.allCases, id: \.rawValue) { category in
                                categoryChip(
                                    title: category.rawValue.capitalized,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }

                    BadgeGalleryView(
                        achievements: filteredAchievements,
                        unlockedKeys: state.unlockedAchievements,
                        progressByKey: progressByKey,
                        onBadgeTap: { key in
                            selectedBadgeKey = key
                        }
                    )
                }
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
                                Text("\(state.streakDays) \(state.streakDays == 1 ? "day" : "days")")
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
                                Text("\(state.bestStreak) \(state.bestStreak == 1 ? "day" : "days")")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.tasker.textPrimary)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Streaks. Current \(state.streakDays) \(state.streakDays == 1 ? "day" : "days"). Best \(state.bestStreak) \(state.bestStreak == 1 ? "day" : "days")."
                )
            }
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.bottom, spacing.s16)
        .sheet(
            isPresented: Binding(
                get: { selectedBadgeKey != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedBadgeKey = nil
                    }
                }
            )
        ) {
            if let selectedBadgeKey,
               let achievement = AchievementCatalog.definition(for: selectedBadgeKey) {
                BadgeDetailSheet(
                    achievement: achievement,
                    unlockDate: progressByKey[selectedBadgeKey]?.unlockDate,
                    progressState: progressByKey[selectedBadgeKey]
                )
            }
        }
        .onAppear {
            applyHighlightedAchievementIfNeeded()
        }
        .onChange(of: viewModel.highlightedAchievementKey) { _ in
            applyHighlightedAchievementIfNeeded()
        }
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

    private func categoryChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(isSelected ? Color.tasker.textInverse : Color.tasker.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyHighlightedAchievementIfNeeded() {
        guard let highlightedKey = viewModel.consumeHighlightedAchievementKey() else { return }
        guard let definition = AchievementCatalog.definition(for: highlightedKey) else { return }
        selectedCategory = definition.category
        selectedBadgeKey = highlightedKey
    }
}
