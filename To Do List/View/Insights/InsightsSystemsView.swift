import SwiftUI

/// Systems tab content for the Insights screen.
struct InsightsSystemsView: View {

    @ObservedObject var viewModel: InsightsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: AchievementDefinition.AchievementCategory?
    @State private var selectedBadgeKey: String?
    @State private var didAppear = false

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
            module(index: 0) {
                progressionCard
            }
            module(index: 1) {
                metricGridCard(
                    eyebrow: "Streak resilience",
                    title: "The system should reward return, not perfection.",
                    subtitle: state.heroSummary,
                    metrics: state.streakMetrics
                )
            }
            module(index: 2) {
                metricGridCard(
                    eyebrow: "Achievement velocity",
                    title: "Progression should feel active, not decorative.",
                    subtitle: "Unlocks matter most when they reflect how often you return to the loop.",
                    metrics: state.achievementVelocityMetrics
                )
            }
            module(index: 3) {
                reminderResponseCard
            }
            module(index: 4) {
                metricGridCard(
                    eyebrow: "Focus ritual health",
                    title: "How reliable the focus system is right now",
                    subtitle: "A strong focus ritual makes the rest of the system easier to trust.",
                    metrics: state.focusHealthMetrics
                )
            }
            module(index: 5) {
                metricGridCard(
                    eyebrow: "Recovery loop health",
                    title: "How often the system catches you before backlog turns sticky",
                    subtitle: "Recovery, decomposition, and reflection are the anti-spiral tools.",
                    metrics: state.recoveryHealthMetrics
                )
            }
            module(index: 6) {
                achievementsCard
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
            didAppear = true
            applyHighlightedAchievementIfNeeded()
        }
        .onChange(of: viewModel.highlightedAchievementKey) { _ in
            applyHighlightedAchievementIfNeeded()
        }
    }

    private var progressionCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Systems")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text("Progression is stronger when reminders, focus, and return behavior agree.")
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker.textPrimary)

                HStack(alignment: .center, spacing: spacing.s16) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Level \(state.level)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.tasker.accentPrimary)
                        Text("\(state.totalXP) XP total")
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textSecondary)
                        Text(state.nextMilestone.map { "Next milestone: \($0.name)" } ?? "Top milestone reached")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.tasker.surfaceTertiary, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: levelProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.tasker.accentPrimary, Color.tasker.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((levelProgress * 100).rounded()))%")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textPrimary)
                    }
                    .frame(width: 96, height: 96)
                }

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
                .frame(height: 12)

                Text(state.heroSummary)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }

    private var reminderResponseCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Reminder response")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(state.reminderResponse.headline)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(state.reminderResponse.detail)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                if state.reminderResponse.statusItems.isEmpty {
                    Text("Enable and act on reminders to make this system visible.")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                } else {
                    ForEach(state.reminderResponse.statusItems) { item in
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
                                Capsule().fill(Color.tasker.surfaceTertiary)
                                    .frame(width: 116, height: 10)
                                Capsule().fill(toneColor(item.tone))
                                    .frame(width: max(10, 116 * CGFloat(item.share)), height: 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private var achievementsCard: some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Achievement board")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

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
    }

    private func metricGridCard(
        eyebrow: String,
        title: String,
        subtitle: String,
        metrics: [InsightsMetricTile]
    ) -> some View {
        insightsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(eyebrow)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)

                Text(title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text(subtitle)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: spacing.s8) {
                    ForEach(metrics) { metric in
                        metricCard(metric)
                    }
                }
            }
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
                .fixedSize(horizontal: false, vertical: true)
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

    private func module<Content: View>(index: Int, @ViewBuilder content: () -> Content) -> some View {
        let delay = Double(index) * 0.05
        return content()
            .opacity(reduceMotion || didAppear ? 1 : 0)
            .offset(y: reduceMotion || didAppear ? 0 : 14)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.32).delay(delay),
                value: didAppear
            )
    }

    @ViewBuilder
    private func insightsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.tasker.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.8), lineWidth: 1)
            )
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
