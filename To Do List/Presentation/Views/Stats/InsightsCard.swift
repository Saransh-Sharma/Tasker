//
//  InsightsCard.swift
//  Tasker
//
//  Card showing productivity insights and stats.
//  Displays real user data: most productive day, average XP, week-over-week change.
//

import SwiftUI

public struct InsightsCard: View {
    public let mostProductiveDay: String
    public let averageDailyXP: Int
    public let weekOverWeekChange: Int

    public init(
        mostProductiveDay: String = "—",
        averageDailyXP: Int = 0,
        weekOverWeekChange: Int = 0
    ) {
        self.mostProductiveDay = mostProductiveDay
        self.averageDailyXP = averageDailyXP
        self.weekOverWeekChange = weekOverWeekChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(TaskerTheme.Typography.title3)
                .foregroundColor(TaskerTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "calendar.badge.checkmark",
                    color: TaskerTheme.Colors.badgeComplete,
                    text: "Most productive: \(mostProductiveDay)"
                )
                InsightRow(
                    icon: "star.fill",
                    color: TaskerTheme.Colors.xpGold,
                    text: "Avg daily XP: \(averageDailyXP)"
                )
                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: changeColor,
                    text: changeText
                )
            }
        }
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
    }

    /// Color for the week-over-week change indicator
    private var changeColor: Color {
        if weekOverWeekChange > 0 {
            return TaskerTheme.Colors.badgeComplete
        } else if weekOverWeekChange < 0 {
            return TaskerTheme.Colors.coral
        } else {
            return TaskerTheme.Colors.textSecondary
        }
    }

    /// Text for the week-over-week change
    private var changeText: String {
        if weekOverWeekChange > 0 {
            return "+\(weekOverWeekChange)% vs last week"
        } else if weekOverWeekChange < 0 {
            return "\(weekOverWeekChange)% vs last week"
        } else {
            return "Same as last week"
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(TaskerTheme.Typography.caption)
                .foregroundColor(TaskerTheme.Colors.textSecondary)
        }
    }
}

#if DEBUG
struct InsightsCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            InsightsCard(
                mostProductiveDay: "Wednesday",
                averageDailyXP: 42,
                weekOverWeekChange: 15
            )

            InsightsCard(
                mostProductiveDay: "Monday",
                averageDailyXP: 28,
                weekOverWeekChange: -10
            )

            InsightsCard(
                mostProductiveDay: "—",
                averageDailyXP: 0,
                weekOverWeekChange: 0
            )
        }
        .padding()
        .background(TaskerTheme.Colors.background)
    }
}
#endif
