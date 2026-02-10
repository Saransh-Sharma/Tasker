//
//  StatsView.swift
//  Tasker
//
//  Stats page with scrollable sections showing XP, streaks, charts, and insights.
//  Driven by real user data from StatsViewModel.
//

import SwiftUI

/// Main stats page with snap-to-sections scrolling
public struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel

    public init(viewModel: StatsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? StatsViewModel())
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // XP Ring Section
                xpSection
                    .staggeredAppearance(index: 0)

                // Streak Cards Section
                streakCardsSection
                    .staggeredAppearance(index: 1)

                // Weekly Chart Section
                weeklyChartSection
                    .staggeredAppearance(index: 2)

                // Heatmap Section
                heatmapSection
                    .staggeredAppearance(index: 3)

                // Performance & Insights Section
                performanceInsightsSection
                    .staggeredAppearance(index: 4)
            }
            .padding()
            .padding(.bottom, TaskerTheme.Spacing.tabBarHeight)  // Extra padding for tab bar
        }
        .background(TaskerTheme.Colors.background)
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - XP Section

    private var xpSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Progress")
                    .font(TaskerTheme.Typography.title3)
                    .foregroundColor(TaskerTheme.Colors.textPrimary)
                Spacer()
                Text("Goal: \(viewModel.dailyXPGoal) XP")
                    .font(TaskerTheme.Typography.caption)
                    .foregroundColor(TaskerTheme.Colors.textSecondary)
            }

            HStack {
                Spacer()
                XPRingView(
                    currentXP: viewModel.todayXP,
                    goalXP: viewModel.dailyXPGoal,
                    thickness: 12,
                    size: 100
                )
                Spacer()
            }

            Text("\(completionPercentage)% complete")
                .font(TaskerTheme.Typography.caption)
                .foregroundColor(TaskerTheme.Colors.textSecondary)
        }
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
        .scaleOnPress()
    }

    private var completionPercentage: Int {
        guard viewModel.dailyXPGoal > 0 else { return 0 }
        return min(100, (viewModel.todayXP * 100) / viewModel.dailyXPGoal)
    }

    // MARK: - Streak Cards Section

    private var streakCardsSection: some View {
        HStack(spacing: 12) {
            CurrentStreakCard(streak: viewModel.currentStreak)
            BestDayCard(xp: viewModel.bestDayXP, date: viewModel.bestDayDate)
        }
    }

    // MARK: - Weekly Chart Section

    private var weeklyChartSection: some View {
        VStack(spacing: 12) {
            Text("This Week")
                .font(TaskerTheme.Typography.title3)
                .foregroundColor(TaskerTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            WeeklyBarChartView(data: viewModel.weeklyXPData)
                .frame(height: 200)  // Explicit height for DGCharts to render
        }
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
    }

    // MARK: - Heatmap Section

    private var heatmapSection: some View {
        VStack(spacing: 12) {
            Text("Activity")
                .font(TaskerTheme.Typography.title3)
                .foregroundColor(TaskerTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ActivityHeatmapView(data: viewModel.heatmapData)
        }
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
    }

    // MARK: - Performance & Insights Section

    private var performanceInsightsSection: some View {
        VStack(spacing: 12) {
            HabitPerformanceCard(completionRate: viewModel.habitCompletionRate)
            InsightsCard(
                mostProductiveDay: viewModel.mostProductiveDay,
                averageDailyXP: viewModel.averageDailyXP,
                weekOverWeekChange: viewModel.weekOverWeekChange
            )
        }
    }
}

#if DEBUG
struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView(viewModel: StatsViewModel.preview)
    }
}
#endif
