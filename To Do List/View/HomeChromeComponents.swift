import SwiftUI

struct HomeTopChromeView: View {
    @Binding var selectedQuickView: HomeQuickView
    let taskCounts: [HomeQuickView: Int]
    let title: String
    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void
    let onResetFilters: () -> Void
    let onOpenSearch: () -> Void
    let onOpenSettings: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textTertiary)

                Text(title)
                    .font(.tasker(.title3))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tasker.textPrimary)
            }

            HStack(spacing: spacing.s8) {
                QuickViewSelector(
                    selectedQuickView: $selectedQuickView,
                    taskCounts: taskCounts,
                    onShowDatePicker: onShowDatePicker,
                    onShowAdvancedFilters: onShowAdvancedFilters,
                    onResetFilters: onResetFilters
                )
                .frame(minHeight: 44)

                Spacer(minLength: spacing.s4)

                iconButton(
                    systemName: "magnifyingglass",
                    accessibilityIdentifier: "home.topNav.searchButton",
                    accessibilityLabel: "Search",
                    action: onOpenSearch
                )
                iconButton(
                    systemName: "gearshape",
                    accessibilityIdentifier: "home.settingsButton",
                    accessibilityLabel: "Settings",
                    action: onOpenSettings
                )
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s8)
    }

    private func iconButton(
        systemName: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 44, height: 44)
                .taskerChromeSurface(
                    cornerRadius: TaskerSearchChromeStyle.iconButtonCornerRadius,
                    accentColor: Color.tasker.accentSecondary,
                    level: .e1
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct HomeSearchChromeView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        TaskerSearchHeaderView(
            query: $query,
            isFocused: _isFocused,
            onQueryChanged: onQueryChanged,
            onSubmit: onSubmit,
            onClear: onClear
        )
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s4)
        .padding(.bottom, spacing.s8)
    }
}

struct HomeQuickFilterPillsView: View {
    let projectName: String?
    let hasAdvancedFilter: Bool
    let onClearProjectFilters: () -> Void
    let onClearAdvancedFilters: () -> Void
    let onResetAllFilters: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s4) {
                if let projectName {
                    TaskerFilterChip(
                        title: projectName,
                        systemImage: "folder",
                        action: onClearProjectFilters
                    )
                }

                if hasAdvancedFilter {
                    TaskerFilterChip(
                        title: "Filters",
                        systemImage: "slider.horizontal.3",
                        action: onClearAdvancedFilters
                    )
                }

                TaskerFilterChip(
                    title: "Clear all",
                    systemImage: "xmark.circle.fill",
                    isDestructive: true,
                    action: onResetAllFilters
                )
            }
            .padding(.vertical, spacing.s2)
        }
    }
}

struct HomeMomentumHUDView: View {
    let progress: HomeProgressState
    let completionRate: Double
    let reflectionEligible: Bool
    let momentumGuidanceText: String
    let animate: Bool
    let onToggleInsights: () -> Void
    let onOpenReflection: () -> Void

    var body: some View {
        HomeMomentumSummaryCard(
            progress: progress,
            completionRate: completionRate,
            reflectionEligible: reflectionEligible,
            momentumGuidanceText: momentumGuidanceText,
            animate: animate,
            onChartTap: onToggleInsights,
            onOpenReflection: onOpenReflection
        )
    }
}

struct HomeMomentumSummaryCard: View {
    let progress: HomeProgressState
    let completionRate: Double
    let reflectionEligible: Bool
    let momentumGuidanceText: String
    let animate: Bool
    var onChartTap: (() -> Void)? = nil
    var onOpenReflection: (() -> Void)? = nil

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var progressRatio: Double {
        let denominator = max(1, progress.todayTargetXP)
        return min(1, Double(progress.earnedXP) / Double(denominator))
    }

    private var completionPercent: Int {
        Int((completionRate * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s12) {
                NavPieChart(
                    score: progress.earnedXP,
                    maxScore: progress.todayTargetXP,
                    accessibilityContainerID: "home.navXpPieChart",
                    accessibilityButtonID: "home.navXpPieChart.button",
                    onTap: { onChartTap?() }
                )
                .padding(4)
                .taskerChromeSurface(
                    cornerRadius: 26,
                    accentColor: Color.tasker.accentSecondary,
                    level: .e1
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.earnedXP)/\(progress.todayTargetXP) XP")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .accessibilityIdentifier("home.dailyScoreLabel")
                        .lineLimit(1)

                    HStack(spacing: spacing.s8) {
                        Text("\(completionPercent)% complete")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .accessibilityIdentifier("home.completionRateLabel")
                            .lineLimit(1)

                        streakIndicator
                            .accessibilityIdentifier("home.streakLabel")
                    }
                }

                Spacer(minLength: spacing.s4)

                if reflectionEligible, let onOpenReflection {
                    Button("Reflection", action: onOpenReflection)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.tasker.accentPrimary)
                        .accessibilityIdentifier("home.reflectionChip")
                }
            }

            MomentumProgressBar(
                progress: progressRatio,
                colors: progressGradientColors,
                animate: animate
            )

            Text(momentumGuidanceText)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .taskerPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.tasker.surfaceSecondary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.8),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }

    private var progressGradientColors: [Color] {
        if progress.isStreakSafeToday {
            return [Color.tasker.accentPrimary, Color.tasker.accentSecondary]
        }
        return [Color.tasker.statusWarning, Color.tasker.statusWarning.opacity(0.7)]
    }

    private var streakIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(progress.isStreakSafeToday ? Color.tasker.accentSecondary : Color.tasker.statusWarning)
                .symbolEffect(
                    .pulse,
                    options: .repeating.speed(0.5),
                    isActive: !progress.isStreakSafeToday && animate
                )

            Text("\(progress.streakDays)d")
                .font(.tasker(.caption1))
                .fontWeight(.medium)
                .foregroundStyle(progress.isStreakSafeToday ? Color.tasker.textSecondary : Color.tasker.statusWarning)
        }
    }
}

private struct MomentumProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.tasker.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    )
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(
                        animate ? .spring(response: 0.34, dampingFraction: 0.82) : .linear(duration: 0.01),
                        value: clampedProgress
                    )
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}
