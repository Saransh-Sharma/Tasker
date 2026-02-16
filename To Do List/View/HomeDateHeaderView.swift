//
//  HomeDateHeaderView.swift
//  Tasker
//
//  Compact date + XP display for the navigation bar titleView.
//

import SwiftUI
import UIKit

struct HomeDateHeaderView: View {
    let date: Date
    var progressState: HomeProgressState = .empty
    var accentOnPrimaryColor: UIColor = TaskerThemeManager.shared.currentTheme.tokens.color.accentOnPrimary

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var topLabel: String {
        if isToday { return "TODAY" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date).uppercased()
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var textColor: Color {
        Color(uiColor: accentOnPrimaryColor)
    }

    private var xpText: String {
        "\(progressState.earnedXP)/\(progressState.todayTargetXP) XP"
    }

    private var streakText: String {
        if progressState.isStreakSafeToday {
            return "\(progressState.streakDays)d streak"
        }
        return "streak at risk"
    }

    private var progressFraction: Double {
        let denom = max(1, progressState.todayTargetXP)
        return min(1.0, Double(progressState.earnedXP) / Double(denom))
    }

    private var streakColor: Color {
        progressState.isStreakSafeToday ? textColor.opacity(0.85) : Color.tasker.statusWarning
    }

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            // Line 1: Day label + Date (nav title size)
            HStack(spacing: 5) {
                Text(topLabel)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(textColor.opacity(0.7))

                Text("·")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor.opacity(0.4))

                Text(dateText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            // Line 2: XP + streak (subtitle size)
            HStack(spacing: 4) {
                Text(xpText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(textColor.opacity(0.8))

                Text("·")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor.opacity(0.4))

                Text(streakText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(streakColor)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isToday ? "Today" : topLabel), \(dateText), \(xpText), \(streakText)")
        .accessibilityIdentifier("home.dateHeader")
    }
}
