//
//  BestDayCard.swift
//  Tasker
//
//  Card showing best day XP achievement.
//

import SwiftUI

public struct BestDayCard: View {
    public let xp: Int
    public let date: Date
    
    public init(xp: Int, date: Date) {
        self.xp = xp
        self.date = date
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Icon with subtle gold background
            Circle()
                .fill(TaskerTheme.Colors.xpGold.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.tasker(.title1))
                        .foregroundColor(TaskerTheme.Colors.xpGold)
                )

            Text("\(xp)")
                .font(.tasker(.display))
                .fontWeight(.bold)
                .foregroundColor(TaskerTheme.Colors.textPrimary)

            Text("Best Day XP")
                .font(TaskerTheme.Typography.caption)
                .foregroundColor(TaskerTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.card)
    }
}
