import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var spacing: TaskerSpacingTokens { themeManager.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { themeManager.tokens(for: layoutClass).corner }
    private var colorTokens: TaskerColorTokens { themeManager.tokens(for: layoutClass).color }

    private var isResolved: Bool {
        switch row.state {
        case .completedToday, .lapsedToday, .skippedToday:
            return true
        case .due, .overdue, .tracking:
            return false
        }
    }

    var body: some View {
        ZStack {
            if isResolved {
                resolvedCard
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
            } else {
                activeCard
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .padding(isResolved ? spacing.s8 : spacing.s12)
        .background(cardFill)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: corner.card, style: .continuous))
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(primaryTone.opacity(isResolved ? 0.55 : 0.92))
                .frame(width: isResolved ? 48 : 72, height: 4)
                .padding(.horizontal, spacing.s16)
                .padding(.top, 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier("home.habitRow.\(row.id)")
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange, value: row.state)
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.feedbackFast, value: row.riskState)
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                iconCluster
                VStack(alignment: .leading, spacing: spacing.s8) {
                    HStack(alignment: .top, spacing: spacing.s8) {
                        VStack(alignment: .leading, spacing: spacing.s4) {
                            Text(row.title)
                                .font(.tasker(.bodyStrong))
                                .foregroundColor(textPrimaryColor)
                                .lineLimit(2)

                            Text(ownershipLine)
                                .font(.tasker(.caption1))
                                .foregroundColor(textSecondaryColor)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: spacing.s4) {
                            HomeHabitBadge(text: stateText, tone: stateTone)
                            HomeHabitBadge(text: riskText, tone: riskTone, emphasis: row.riskState != .stable)
                        }
                    }

                    Text(activeSummary)
                        .font(.tasker(.caption1))
                        .foregroundColor(textSecondaryColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .center, spacing: spacing.s12) {
                HabitHistoryStripView(marks: displayMarks)
                Spacer(minLength: 0)
                streakPill
            }

            if isActionable {
                actionRow
            }
        }
    }

    private var resolvedCard: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .center, spacing: spacing.s8) {
                iconCluster
                    .scaleEffect(0.94)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    HStack(alignment: .center, spacing: spacing.s8) {
                        Text(row.title)
                            .font(.tasker(.callout).weight(.semibold))
                            .foregroundColor(textPrimaryColor.opacity(0.96))
                            .lineLimit(1)

                        HomeHabitBadge(text: stateText, tone: stateTone, compact: true)
                        if row.state == .lapsedToday {
                            HomeHabitBadge(text: riskText, tone: riskTone, compact: true, emphasis: true)
                        }
                    }

                    Text(resolvedSummary)
                        .font(.tasker(.caption2))
                        .foregroundColor(textSecondaryColor)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: spacing.s4) {
                    Text("\(row.currentStreak)d")
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundColor(primaryTone)
                    Text("streak")
                        .font(.tasker(.caption2))
                        .foregroundColor(textSecondaryColor)
                }
            }

            HabitHistoryStripView(marks: displayMarks)
        }
    }

    private var cardFill: Color {
        switch row.state {
        case .overdue:
            return statusDangerColor.opacity(colorSchemeIsDark ? 0.18 : 0.10)
        case .due:
            return accentPrimaryColor.opacity(colorSchemeIsDark ? 0.18 : 0.09)
        case .tracking:
            return accentSecondaryColor.opacity(colorSchemeIsDark ? 0.16 : 0.08)
        case .completedToday:
            return statusSuccessColor.opacity(colorSchemeIsDark ? 0.16 : 0.08)
        case .lapsedToday:
            return statusDangerColor.opacity(colorSchemeIsDark ? 0.16 : 0.10)
        case .skippedToday:
            return surfaceSecondaryColor
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: corner.card, style: .continuous)
            .stroke(borderColor, lineWidth: row.state == .overdue || row.state == .lapsedToday ? 1.2 : 1)
    }

    private var borderColor: Color {
        switch row.state {
        case .overdue:
            return statusDangerColor.opacity(0.36)
        case .due:
            return accentPrimaryColor.opacity(0.22)
        case .tracking:
            return accentSecondaryColor.opacity(0.22)
        case .completedToday:
            return statusSuccessColor.opacity(0.26)
        case .lapsedToday:
            return statusDangerColor.opacity(0.32)
        case .skippedToday:
            return strokeHairlineColor
        }
    }

    private var iconCluster: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(primaryTone.opacity(isResolved ? 0.12 : 0.18))
                .frame(width: isResolved ? 38 : 44, height: isResolved ? 38 : 44)

            Image(systemName: row.iconSymbolName)
                .font(.system(size: isResolved ? 16 : 18, weight: .semibold))
                .foregroundColor(primaryTone)
        }
    }

    private var streakPill: some View {
        VStack(alignment: .trailing, spacing: spacing.s2) {
            Text("\(row.currentStreak)d streak")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(primaryTone)
            if row.bestStreak > row.currentStreak {
                Text("Best \(row.bestStreak)d")
                    .font(.tasker(.caption2))
                    .foregroundColor(textSecondaryColor)
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, spacing.s8)
        .background(primaryTone.opacity(0.10))
        .overlay(
            Capsule(style: .continuous)
                .stroke(primaryTone.opacity(0.20), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: spacing.s8) {
            if let secondaryActionLabel, let onSecondaryAction {
                actionButton(
                    title: secondaryActionLabel,
                    fill: Color(uiColor: colorTokens.surfacePrimary),
                    stroke: strokeHairlineColor,
                    foreground: textSecondaryColor,
                    action: onSecondaryAction
                )
            }

            if let primaryActionLabel, let onPrimaryAction {
                actionButton(
                    title: primaryActionLabel,
                    fill: primaryTone.opacity(0.16),
                    stroke: primaryTone.opacity(0.24),
                    foreground: primaryTone,
                    action: onPrimaryAction
                )
            }
        }
    }

    private func actionButton(
        title: String,
        fill: Color,
        stroke: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private var ownershipLine: String {
        var parts: [String] = [row.lifeAreaName]
        if let projectName = row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        return parts.joined(separator: " · ")
    }

    private var activeSummary: String {
        switch row.state {
        case .overdue:
            return "Needs attention now. \(dueText)"
        case .due:
            return "\(dueText). Keep the loop moving while momentum is still available."
        case .tracking:
            if row.trackingMode == .lapseOnly {
                return "Tracking quietly in the background. Only log the slip if it happens."
            }
            return "Still tracking today. Check in when you know the outcome."
        case .completedToday, .lapsedToday, .skippedToday:
            return resolvedSummary
        }
    }

    private var resolvedSummary: String {
        switch row.state {
        case .completedToday:
            return "Done today. Progress stays visible without taking over the list."
        case .skippedToday:
            return "Skipped today. The habit stays readable, but without pressure."
        case .lapsedToday:
            return "Lapse logged. Recovery can start from the next clean day."
        case .due, .overdue, .tracking:
            return activeSummary
        }
    }

    private var dueText: String {
        guard let dueAt = row.dueAt else {
            return row.state == .tracking ? "Tracking quietly" : "Due today"
        }
        let time = dueAt.formatted(date: .omitted, time: .shortened)
        switch row.state {
        case .overdue:
            return "Overdue since \(time)"
        case .due:
            return "Due by \(time)"
        case .tracking:
            return "Tracking through \(time)"
        case .completedToday, .lapsedToday, .skippedToday:
            return time
        }
    }

    private var stateText: String {
        switch row.state {
        case .due:
            return "Due"
        case .overdue:
            return "Overdue"
        case .completedToday:
            return "Done today"
        case .lapsedToday:
            return "Lapse logged"
        case .skippedToday:
            return "Skipped"
        case .tracking:
            return row.trackingMode == .lapseOnly ? "Tracking" : "Open"
        }
    }

    private var riskText: String {
        switch row.riskState {
        case .stable:
            return row.state == .tracking ? "Stable" : "On track"
        case .atRisk:
            return "At risk"
        case .broken:
            return "Recovery focus"
        }
    }

    private var stateTone: HomeHabitBadgeTone {
        switch row.state {
        case .due:
            return .accent
        case .overdue:
            return .danger
        case .completedToday:
            return .success
        case .lapsedToday:
            return .danger
        case .skippedToday:
            return .neutral
        case .tracking:
            return .secondary
        }
    }

    private var riskTone: HomeHabitBadgeTone {
        switch row.riskState {
        case .stable:
            return .neutral
        case .atRisk:
            return .warning
        case .broken:
            return .danger
        }
    }

    private var primaryTone: Color {
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
            return row.riskState == .broken ? statusDangerColor : accentSecondaryColor
        }
    }

    private var displayMarks: [HomeHabitDayMark] {
        if row.last14Days.isEmpty {
            return Array(repeating: HomeHabitDayMark(date: row.dueAt ?? Date(), state: .none), count: 14)
        }
        return row.last14Days
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

    private var textPrimaryColor: Color { Color(uiColor: colorTokens.textPrimary) }
    private var textSecondaryColor: Color { Color(uiColor: colorTokens.textSecondary) }
    private var surfaceSecondaryColor: Color { Color(uiColor: colorTokens.surfaceSecondary) }
    private var strokeHairlineColor: Color { Color(uiColor: colorTokens.strokeHairline) }
    private var accentPrimaryColor: Color { Color(uiColor: colorTokens.accentPrimary) }
    private var accentSecondaryColor: Color { Color(uiColor: colorTokens.accentSecondary) }
    private var statusDangerColor: Color { Color(uiColor: colorTokens.statusDanger) }
    private var statusSuccessColor: Color { Color(uiColor: colorTokens.statusSuccess) }
    private var textTertiaryColor: Color { Color(uiColor: colorTokens.textTertiary) }
    private var colorSchemeIsDark: Bool { colorScheme == .dark }

    private var accessibilityLabel: String {
        "\(row.title), \(stateText), \(ownershipLine)"
    }

    private var accessibilityValue: String {
        "Current streak \(row.currentStreak) days, best streak \(row.bestStreak) days, risk \(riskText)"
    }

    private var accessibilityHint: String {
        if let primaryActionLabel {
            return "Primary action \(primaryActionLabel)." + (secondaryActionLabel.map { " Secondary action \($0)." } ?? "")
        }
        return resolvedSummary
    }
}

private struct HomeHabitBadge: View {
    let text: String
    let tone: HomeHabitBadgeTone
    var compact = false
    var emphasis = false

    var body: some View {
        Text(text)
            .font(compact ? .tasker(.caption2).weight(.semibold) : .tasker(.caption1).weight(.semibold))
            .foregroundColor(tone.textColor)
            .padding(.horizontal, compact ? 7 : 8)
            .padding(.vertical, compact ? 4 : 5)
            .background(tone.fillColor.opacity(emphasis ? 1 : 0.92))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tone.strokeColor.opacity(emphasis ? 1 : 0.84), lineWidth: emphasis ? 1.2 : 1)
            )
            .clipShape(Capsule())
    }
}

@MainActor
private enum HomeHabitBadgeTone {
    case accent
    case secondary
    case success
    case warning
    case danger
    case neutral

    var textColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary
        case .secondary:
            return Color.tasker.accentSecondary
        case .success:
            return Color.tasker.statusSuccess
        case .warning:
            return Color.tasker.statusWarning
        case .danger:
            return Color.tasker.statusDanger
        case .neutral:
            return Color.tasker.textSecondary
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentWash
        case .secondary:
            return Color.tasker.accentSecondaryWash
        case .success:
            return Color.tasker.statusSuccess.opacity(0.14)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.16)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.14)
        case .neutral:
            return Color.tasker.surfacePrimary
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary.opacity(0.26)
        case .secondary:
            return Color.tasker.accentSecondary.opacity(0.24)
        case .success:
            return Color.tasker.statusSuccess.opacity(0.24)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.26)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.28)
        case .neutral:
            return Color.tasker.strokeHairline.opacity(0.8)
        }
    }
}

struct HabitHistoryStripView: View {
    let marks: [HomeHabitDayMark]

    @ObservedObject private var themeManager = TaskerThemeManager.shared

    private var colorTokens: TaskerColorTokens { themeManager.currentTheme.tokens.color }
    private var statusSuccessColor: Color { Color(uiColor: colorTokens.statusSuccess) }
    private var statusDangerColor: Color { Color(uiColor: colorTokens.statusDanger) }
    private var textQuaternaryColor: Color { Color(uiColor: colorTokens.textQuaternary) }
    private var strokeHairlineColor: Color { Color(uiColor: colorTokens.strokeHairline) }
    private var accentMutedColor: Color { Color(uiColor: colorTokens.accentMuted) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(marks.prefix(14).enumerated()), id: \.offset) { _, mark in
                Capsule(style: .continuous)
                    .fill(color(for: mark.state))
                    .frame(width: 10, height: 6)
            }
        }
        .accessibilityHidden(true)
        .animation(TaskerAnimation.feedbackFast, value: marks)
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
