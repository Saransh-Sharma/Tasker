//
//  CurrentStreakCard.swift
//  Tasker
//
//  Card showing current streak with fire icon animation.
//

import SwiftUI

public struct CurrentStreakCard: View {
    public let streak: Int
    @State private var isAnimating = false
    
    public init(streak: Int) {
        self.streak = streak
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Icon with subtle background
            Circle()
                .fill(TaskerTheme.Colors.coral.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    ZStack {
                        if streak >= 3 {
                            Circle()
                                .fill(TaskerTheme.Colors.coral.opacity(0.2))
                                .scaleEffect(isAnimating ? 1.5 : 1)
                                .opacity(isAnimating ? 0 : 1)
                        }

                        Image(systemName: streak >= 3 ? "flame.fill" : "calendar")
                            .font(.tasker(.title1))
                            .foregroundColor(streak >= 3 ? TaskerTheme.Colors.coral : TaskerTheme.Colors.textTertiary)
                    }
                )

            Text("\(streak)")
                .font(.tasker(.display))
                .fontWeight(.bold)
                .foregroundColor(streak >= 3 ? TaskerTheme.Colors.coral : TaskerTheme.Colors.textSecondary)

            Text(streak == 1 ? "Day Streak" : "Day Streak")
                .font(TaskerTheme.Typography.caption)
                .foregroundColor(TaskerTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(TaskerTheme.Colors.cardBackground)
        .cornerRadius(TaskerTheme.CornerRadius.card)
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.card)
        .onAppear {
            if streak >= 3 {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
        }
    }
}
