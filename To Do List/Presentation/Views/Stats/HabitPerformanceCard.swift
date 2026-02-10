//
//  HabitPerformanceCard.swift
//  Tasker
//
//  Card showing habit completion rate with progress ring.
//

import SwiftUI

public struct HabitPerformanceCard: View {
    public let completionRate: Double
    
    public init(completionRate: Double) {
        self.completionRate = completionRate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habit Performance")
                .font(TaskerTheme.Typography.title3)
                .foregroundColor(TaskerTheme.Colors.textPrimary)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(TaskerTheme.Colors.textTertiary.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: completionRate)
                        .stroke(TaskerTheme.Colors.coral, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(completionRate * 100))%")
                        .font(.tasker(.caption2))
                        .fontWeight(.bold)
                        .foregroundColor(TaskerTheme.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TaskerTheme.Colors.badgeComplete)
                        Text("Completed today")
                            .font(TaskerTheme.Typography.caption)
                            .foregroundColor(TaskerTheme.Colors.textSecondary)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(TaskerTheme.Colors.xpGold)
                        Text("On track this week")
                            .font(TaskerTheme.Typography.caption)
                            .foregroundColor(TaskerTheme.Colors.textSecondary)
                    }

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(TaskerTheme.Colors.coral)
                        Text("Best streak: 7 days")
                            .font(TaskerTheme.Typography.caption)
                            .foregroundColor(TaskerTheme.Colors.textSecondary)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
    }
}
