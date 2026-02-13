//
//  HomeDateHeaderView.swift
//  Tasker
//
//  Large date display for the navigation bar titleView.
//

import SwiftUI
import UIKit

struct HomeDateHeaderView: View {
    let date: Date
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
        formatter.dateFormat = "MMMM d, EEE"
        return formatter.string(from: date)
    }

    private var textColor: Color {
        Color(uiColor: accentOnPrimaryColor)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(topLabel)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(textColor.opacity(0.7))

            Text(dateText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isToday ? "Today, \(dateText)" : dateText)
        .accessibilityIdentifier("home.dateHeader")
    }
}
