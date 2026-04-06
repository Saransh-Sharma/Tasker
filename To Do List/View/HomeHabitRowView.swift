import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @State private var isExpanded = false

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
        VStack(alignment: .leading, spacing: spacing.s8) {
            collapsedRail

            if isExpanded {
                expandedBand
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .padding(.horizontal, spacing.s8)
        .padding(.vertical, isExpanded ? spacing.s8 : spacing.s4)
        .frame(minHeight: isExpanded ? 94 : 56)
        .background(cardFill)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(primaryTone.opacity(isResolved ? 0.52 : 0.84))
                .frame(width: isExpanded ? 28 : 20, height: 2)
                .padding(.horizontal, spacing.s8)
                .padding(.top, 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier("home.habitRow.\(row.id)")
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange, value: row.state)
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.feedbackFast, value: row.riskState)
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.panelIn, value: isExpanded)
    }

    private var collapsedRail: some View {
        HStack(spacing: spacing.s8) {
            compactIconTile

            Text(row.title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(textPrimaryColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            streakToken
                .fixedSize(horizontal: true, vertical: false)

            quickActionSlot
                .fixedSize(horizontal: true, vertical: false)

            expandButton
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minHeight: 44)
    }

    private var expandedBand: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            HStack(alignment: .center, spacing: spacing.s8) {
                Text(expandedMetaText)
                    .font(.tasker(.caption1))
                    .foregroundColor(textSecondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: spacing.s8)

                if let compactSecondaryActionTitle, let onSecondaryAction, isResolved == false {
                    compactSecondaryButton(
                        title: compactSecondaryActionTitle,
                        accessibilityLabel: secondaryActionAccessibilityLabel ?? compactSecondaryActionTitle,
                        action: onSecondaryAction
                    )
                }
            }

            HabitHistoryStripView(marks: displayMarks)
        }
        .padding(.top, 1)
    }

    private var streakToken: some View {
        Text("\(row.currentStreak)d")
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundColor(primaryTone)
            .padding(.horizontal, spacing.s8)
            .frame(height: 28)
            .background(primaryTone.opacity(colorSchemeIsDark ? 0.16 : 0.09))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(primaryTone.opacity(colorSchemeIsDark ? 0.30 : 0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
            .accessibilityLabel("Current streak \(row.currentStreak) days")
    }

    @ViewBuilder
    private var quickActionSlot: some View {
        if isResolved {
            resolvedStateToken
        } else if let compactPrimaryActionTitle, let onPrimaryAction {
            compactPrimaryButton(
                title: compactPrimaryActionTitle,
                accessibilityLabel: primaryActionAccessibilityLabel ?? compactPrimaryActionTitle,
                action: onPrimaryAction
            )
        }
    }

    private func compactPrimaryButton(
        title: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            TaskerFeedback.light()
            action()
        } label: {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(primaryTone)
                .frame(minWidth: 58, minHeight: 44)
                .background(primaryTone.opacity(colorSchemeIsDark ? 0.18 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                        .stroke(primaryTone.opacity(colorSchemeIsDark ? 0.34 : 0.22), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r1, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(accessibilityLabel)
    }

    private func compactSecondaryButton(
        title: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            TaskerFeedback.light()
            action()
        } label: {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(textSecondaryColor)
                .frame(minWidth: 58, minHeight: 44)
                .background(surfaceSecondaryColor.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                        .stroke(strokeHairlineColor.opacity(0.9), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: corner.r1, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(accessibilityLabel)
    }

    private var resolvedStateToken: some View {
        Text(resolvedCompactStateText)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundColor(primaryTone)
            .frame(minWidth: 58, minHeight: 44)
            .background(primaryTone.opacity(colorSchemeIsDark ? 0.14 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: corner.r1, style: .continuous)
                    .stroke(primaryTone.opacity(colorSchemeIsDark ? 0.26 : 0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner.r1, style: .continuous))
            .accessibilityLabel("Status \(resolvedCompactStateText)")
    }

    private var expandButton: some View {
        Button {
            TaskerFeedback.selection()
            withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textSecondaryColor)
                .frame(width: 44, height: 44)
                .background(surfaceSecondaryColor.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeHairlineColor.opacity(0.8), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(isExpanded ? "Collapse habit details" : "Expand habit details")
        .accessibilityHint("Shows history and secondary action")
    }

    private var compactIconTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(primaryTone.opacity(isResolved ? 0.10 : 0.14))
                .frame(width: 30, height: 30)

            Image(systemName: row.iconSymbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(primaryTone)
        }
        .frame(width: 30, height: 30)
    }

    private var compactPrimaryActionTitle: String? {
        guard isResolved == false else { return nil }

        if row.trackingMode == .lapseOnly {
            return row.state == .tracking ? "Lapse" : nil
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Done"
        case (.negative, .dailyCheckIn):
            return "Clean"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var compactSecondaryActionTitle: String? {
        guard isResolved == false else { return nil }

        if row.trackingMode == .lapseOnly {
            return nil
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Skip"
        case (.negative, .dailyCheckIn):
            return "Lapse"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var primaryActionAccessibilityLabel: String? {
        if row.trackingMode == .lapseOnly {
            return "Log lapse"
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Done"
        case (.negative, .dailyCheckIn):
            return "Stayed clean"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var secondaryActionAccessibilityLabel: String? {
        if row.trackingMode == .lapseOnly {
            return nil
        }

        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Skip"
        case (.negative, .dailyCheckIn):
            return "Log lapse"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var resolvedCompactStateText: String {
        switch row.state {
        case .completedToday:
            return "Done"
        case .skippedToday:
            return "Skip"
        case .lapsedToday:
            return "Lapse"
        case .due, .overdue, .tracking:
            return stateText
        }
    }

    private var ownershipLine: String {
        var parts: [String] = [row.lifeAreaName]
        if let projectName = row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        return parts.joined(separator: " · ")
    }

    private var dueText: String {
        guard let dueAt = row.dueAt else {
            switch row.state {
            case .tracking:
                return "Open today"
            case .overdue:
                return "Overdue"
            case .due:
                return "Due today"
            case .completedToday, .lapsedToday, .skippedToday:
                return "Today"
            }
        }

        let time = dueAt.formatted(date: .omitted, time: .shortened)
        switch row.state {
        case .overdue:
            return "Overdue since \(time)"
        case .due:
            return "Due \(time)"
        case .tracking:
            return "Open until \(time)"
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
            return "Done"
        case .lapsedToday:
            return "Lapsed"
        case .skippedToday:
            return "Skipped"
        case .tracking:
            return row.trackingMode == .lapseOnly ? "Quiet" : "Open"
        }
    }

    private var riskText: String {
        switch row.riskState {
        case .stable:
            return row.state == .tracking ? "Open" : "On track"
        case .atRisk:
            return "At risk"
        case .broken:
            return "Recovery"
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

    private var expandedMetaText: String {
        switch row.state {
        case .completedToday:
            return "Completed today"
        case .skippedToday:
            return "Skipped today"
        case .lapsedToday:
            return "Lapsed today"
        case .due, .overdue, .tracking:
            var parts = [dueText]
            if row.riskState != .stable {
                parts.append(riskText)
            }
            return parts.joined(separator: " · ")
        }
    }

    private var displayMarks: [HomeHabitDayMark] {
        if row.last14Days.isEmpty {
            return Array(repeating: HomeHabitDayMark(date: row.dueAt ?? Date(), state: .none), count: 14)
        }
        return row.last14Days
    }

    private var cardFill: Color {
        switch row.state {
        case .overdue:
            return statusDangerColor.opacity(colorSchemeIsDark ? 0.12 : 0.05)
        case .due:
            return accentPrimaryColor.opacity(colorSchemeIsDark ? 0.10 : 0.04)
        case .tracking:
            return accentSecondaryColor.opacity(colorSchemeIsDark ? 0.09 : 0.035)
        case .completedToday:
            return statusSuccessColor.opacity(colorSchemeIsDark ? 0.10 : 0.04)
        case .lapsedToday:
            return statusDangerColor.opacity(colorSchemeIsDark ? 0.11 : 0.05)
        case .skippedToday:
            return surfaceSecondaryColor.opacity(0.88)
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
    }

    private var borderColor: Color {
        switch row.state {
        case .overdue:
            return statusDangerColor.opacity(0.20)
        case .due:
            return accentPrimaryColor.opacity(0.16)
        case .tracking:
            return accentSecondaryColor.opacity(0.14)
        case .completedToday:
            return statusSuccessColor.opacity(0.16)
        case .lapsedToday:
            return statusDangerColor.opacity(0.18)
        case .skippedToday:
            return strokeHairlineColor.opacity(0.82)
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
        "Current streak \(row.currentStreak) days, \(expandedMetaText)"
    }

    private var accessibilityHint: String {
        if let primaryActionAccessibilityLabel, isResolved == false {
            var hint = "Primary action \(primaryActionAccessibilityLabel)."
            if let secondaryActionAccessibilityLabel {
                hint += " Expand for secondary action \(secondaryActionAccessibilityLabel) and history."
            } else {
                hint += " Expand for history."
            }
            return hint
        }
        return "Expand for history and status details."
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
