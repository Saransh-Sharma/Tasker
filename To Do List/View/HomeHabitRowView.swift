//
//  HomeHabitRowView.swift
//  Tasker
//
//  Compact habit row for the mixed Home agenda.
//

import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @ObservedObject private var themeManager = TaskerThemeManager.shared

    private var spacing: TaskerSpacingTokens { themeManager.currentTheme.tokens.spacing }
    private var colorTokens: TaskerColorTokens {
        themeManager.currentTheme.tokens.color
    }

    private var textPrimaryColor: Color { Color(uiColor: colorTokens.textPrimary) }
    private var textSecondaryColor: Color { Color(uiColor: colorTokens.textSecondary) }
    private var surfaceSecondaryColor: Color { Color(uiColor: colorTokens.surfaceSecondary) }
    private var strokeHairlineColor: Color { Color(uiColor: colorTokens.strokeHairline) }
    private var accentPrimaryColor: Color { Color(uiColor: colorTokens.accentPrimary) }
    private var statusDangerColor: Color { Color(uiColor: colorTokens.statusDanger) }
    private var statusSuccessColor: Color { Color(uiColor: colorTokens.statusSuccess) }
    private var textTertiaryColor: Color { Color(uiColor: colorTokens.textTertiary) }

    var body: some View {
        let card = HStack(alignment: .top, spacing: spacing.s12) {
            iconBadge

            contentColumn
        }
        card
            .padding(spacing.s12)
            .background(surfaceSecondaryColor)
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
            .overlay(cardBorder)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier("home.habitRow.\(row.id)")
    }

    private var contentColumn: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text(row.title)
                    .font(.tasker(.body))
                    .foregroundColor(textPrimaryColor)
                    .lineLimit(2)

                Spacer(minLength: 0)

                statusChip
            }

            Text(subtitleText)
                .font(.tasker(.caption2))
                .foregroundColor(textSecondaryColor)
                .lineLimit(1)

            HabitHistoryStripView(marks: displayMarks)

            if isActionable {
                actionRow
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
            .stroke(strokeHairlineColor, lineWidth: 1)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(accentPrimaryColor.opacity(0.12))
                .frame(width: 36, height: 36)

            Image(systemName: row.iconSymbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(rowColor)
        }
    }

    private var statusChip: some View {
        Text(statusText)
            .font(.tasker(.caption2).weight(.semibold))
            .foregroundColor(rowColor)
            .padding(.horizontal, spacing.s8)
            .padding(.vertical, spacing.s4)
            .background(rowColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var subtitleText: String {
        var parts: [String] = [row.lifeAreaName]
        if let projectName = row.projectName, !projectName.isEmpty {
            parts.append(projectName)
        }
        parts.append("\(row.currentStreak) day streak")
        return parts.joined(separator: " · ")
    }

    private var statusText: String {
        switch row.state {
        case .due:
            return "Due"
        case .overdue:
            return "Overdue"
        case .completedToday:
            return "Done"
        case .lapsedToday:
            return "Lapsed"
        case .skippedToday:
            return "Skipped"
        case .tracking:
            return "Tracking"
        }
    }

    private var rowColor: Color {
        switch row.state {
        case .due:
            return accentPrimaryColor
        case .overdue, .lapsedToday:
            return statusDangerColor
        case .completedToday:
            return statusSuccessColor
        case .skippedToday:
            return textTertiaryColor
        case .tracking:
            return accentPrimaryColor
        }
    }

    private var displayMarks: [HomeHabitDayMark] {
        if row.last14Days.isEmpty {
            return Array(repeating: HomeHabitDayMark(date: row.dueAt ?? Date(), state: .none), count: 14)
        }
        return row.last14Days
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: spacing.s8) {
            if let secondaryActionLabel, let onSecondaryAction {
                actionButton(
                    title: secondaryActionLabel,
                    tint: Color.tasker.surfaceTertiary,
                    foreground: Color.tasker.textSecondary,
                    action: onSecondaryAction
                )
            }

            if let primaryActionLabel, let onPrimaryAction {
                actionButton(
                    title: primaryActionLabel,
                    tint: rowColor.opacity(0.12),
                    foreground: rowColor,
                    action: onPrimaryAction
                )
            }
        }
    }

    private func actionButton(
        title: String,
        tint: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tasker(.caption2).weight(.semibold))
                .foregroundColor(foreground)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s4)
                .frame(maxWidth: .infinity)
                .background(tint)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var isActionable: Bool {
        switch row.state {
        case .due, .overdue, .tracking:
            return true
        case .completedToday, .lapsedToday, .skippedToday:
            return false
        }
    }

    private var primaryActionLabel: String? {
        if row.trackingMode == .lapseOnly {
            return row.state == .tracking ? "Log Lapse" : nil
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Done"
        case (.negative, .dailyCheckIn):
            return "Stayed Clean"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var secondaryActionLabel: String? {
        if row.trackingMode == .lapseOnly {
            return nil
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Skip"
        case (.negative, .dailyCheckIn):
            return "Lapsed"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var accessibilityLabel: String {
        "\(row.title), \(statusText), \(subtitleText)"
    }

    private var accessibilityValue: String {
        "Current streak \(row.currentStreak), best streak \(row.bestStreak)"
    }
}

private struct HabitHistoryStripView: View {
    let marks: [HomeHabitDayMark]

    @ObservedObject private var themeManager = TaskerThemeManager.shared

    private var colorTokens: TaskerColorTokens {
        themeManager.currentTheme.tokens.color
    }

    private var statusSuccessColor: Color { Color(uiColor: colorTokens.statusSuccess) }
    private var statusDangerColor: Color { Color(uiColor: colorTokens.statusDanger) }
    private var textQuaternaryColor: Color { Color(uiColor: colorTokens.textQuaternary) }
    private var strokeHairlineColor: Color { Color(uiColor: colorTokens.strokeHairline) }
    private var accentMutedColor: Color { Color(uiColor: colorTokens.accentMuted) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(marks.prefix(14).enumerated()), id: \.offset) { _, mark in
                Circle()
                    .fill(color(for: mark.state))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for state: HabitDayState) -> Color {
        switch state {
        case .success:
            return statusSuccessColor
        case .failure:
            return statusDangerColor
        case .skipped:
            return textQuaternaryColor
        case .none:
            return strokeHairlineColor
        case .future:
            return accentMutedColor
        }
    }
}
