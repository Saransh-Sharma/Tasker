import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @State private var isExpanded = false

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var accentColor: Color {
        TaskerHexColor.color(row.accentHex, fallback: row.kind == .positive ? Color.tasker.statusSuccess : Color.tasker.accentSecondary)
    }

    private var boardFallbackColor: Color {
        row.kind == .positive ? Color.tasker.statusSuccess : Color.tasker.accentSecondary
    }

    private var isResolved: Bool {
        switch row.state {
        case .completedToday, .lapsedToday, .skippedToday:
            return true
        case .due, .overdue, .tracking:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            collapsedRow

            if isExpanded {
                expandedContent
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, isExpanded ? 14 : spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: isExpanded ? 156 : 88)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: row.state == .overdue || row.riskState != .stable ? 1.2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange, value: isExpanded)
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.feedbackFast, value: row.state)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habitRow.\(row.id)")
    }

    private var collapsedRow: some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            leadingIdentity
                .frame(maxWidth: 124, alignment: .leading)

            VStack(alignment: .trailing, spacing: spacing.s8) {
                HabitBoardStripView(
                    cells: boardCells,
                    accentHex: row.accentHex,
                    fallbackColor: boardFallbackColor,
                    mode: .compact
                )

                HStack(spacing: spacing.s8) {
                    streakSummary
                    Spacer(minLength: 0)
                    quickActionSlot
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            expandButton
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                iconTile(size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .lineLimit(2)

                    Text(row.cadenceLabel)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                stateChip
            }

            HabitBoardStripView(
                cells: row.boardCellsExpanded.isEmpty ? boardCells : row.boardCellsExpanded,
                accentHex: row.accentHex,
                fallbackColor: boardFallbackColor,
                mode: .expanded
            )

            HStack(spacing: spacing.s12) {
                statCard(title: "Current", value: "\(row.currentStreak)")
                statCard(title: "Best", value: "\(row.bestStreak)")
                Spacer(minLength: 0)
            }

            HStack(spacing: spacing.s8) {
                if let primaryActionTitle, let onPrimaryAction {
                    actionButton(
                        title: primaryActionTitle,
                        isPrimary: true,
                        action: onPrimaryAction
                    )
                }

                if let secondaryActionTitle, let onSecondaryAction {
                    actionButton(
                        title: secondaryActionTitle,
                        isPrimary: false,
                        action: onSecondaryAction
                    )
                }
            }

            Text(expandedHelperText)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
        }
    }

    private var leadingIdentity: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)

                iconTile(size: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(2)

                Text(metadataLine)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private func iconTile(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor.opacity(0.12))
                .frame(width: size, height: size)

            Image(systemName: row.iconSymbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .frame(width: size, height: size)
    }

    private var streakSummary: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("\(row.currentStreak)d")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(row.bestStreak > 0 ? "best \(row.bestStreak)" : stateText)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
        }
    }

    @ViewBuilder
    private var quickActionSlot: some View {
        if isResolved {
            Text(stateText)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(accentColor)
        } else if let primaryActionTitle, let onPrimaryAction {
            Button(primaryActionTitle) {
                TaskerFeedback.light()
                onPrimaryAction()
            }
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accentColor.opacity(0.10))
            .clipShape(Capsule())
            .buttonStyle(.plain)
            .scaleOnPress()
        }
    }

    private var expandButton: some View {
        Button {
            TaskerFeedback.selection()
            withAnimation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange) {
                isExpanded.toggle()
            }
        } label: {
            Label(
                isExpanded ? "Collapse habit details" : "Expand habit details",
                systemImage: isExpanded ? "chevron.up" : "chevron.down"
            )
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: 44, height: 44)
            .background(Color.tasker.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var stateChip: some View {
        Text(stateText)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(stateChipForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(stateChipBackground)
            .clipShape(Capsule())
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
            Text(value)
                .font(.tasker(.metric))
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfaceSecondary.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func actionButton(
        title: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(title) {
            TaskerFeedback.light()
            action()
        }
        .font(.tasker(.buttonSmall))
        .foregroundStyle(isPrimary ? Color.white : Color.tasker.textPrimary)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(isPrimary ? accentColor : Color.tasker.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private var primaryActionTitle: String? {
        guard !isResolved else { return nil }
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

    private var secondaryActionTitle: String? {
        guard !isResolved, row.trackingMode != .lapseOnly else { return nil }
        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "Skip"
        case (.negative, .dailyCheckIn):
            return "Lapsed"
        case (.negative, .lapseOnly):
            return nil
        }
    }

    private var backgroundColor: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color(uiColor: UIColor(taskerHex: "#FFF9F7"))
        case .tracking:
            return Color(uiColor: UIColor(taskerHex: "#FCFCF8"))
        case .completedToday:
            return Color(uiColor: UIColor(taskerHex: "#FBFCF7"))
        case .skippedToday:
            return Color(uiColor: UIColor(taskerHex: "#FBFBF8"))
        case .due:
            return Color(uiColor: UIColor(taskerHex: "#FFFDF9"))
        }
    }

    private var borderColor: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color(uiColor: UIColor(taskerHex: "#E2B3A8"))
        case .due:
            return accentColor.opacity(0.22)
        case .tracking, .completedToday, .skippedToday:
            return Color.tasker.strokeHairline.opacity(0.75)
        }
    }

    private var metadataLine: String {
        if row.state == .tracking {
            return row.helperText ?? row.cadenceLabel
        }

        if let projectName = row.projectName, projectName.isEmpty == false {
            return "\(row.lifeAreaName) · \(projectName)"
        }
        return row.lifeAreaName
    }

    private var expandedHelperText: String {
        switch row.state {
        case .due:
            return "Due today"
        case .overdue:
            return "Recovery needed"
        case .completedToday:
            return "Completed today"
        case .lapsedToday:
            return "Lapse logged today"
        case .skippedToday:
            return "Skipped without breaking the streak"
        case .tracking:
            return row.trackingMode == .lapseOnly ? "Tracking quietly" : row.cadenceLabel
        }
    }

    private var stateText: String {
        switch row.state {
        case .due:
            return "Due today"
        case .overdue:
            return "Recovery"
        case .completedToday:
            return "Done"
        case .lapsedToday:
            return "Lapsed"
        case .skippedToday:
            return "Skipped"
        case .tracking:
            return row.trackingMode == .lapseOnly ? "Quiet" : "On track"
        }
    }

    private var stateChipForeground: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color.tasker.statusDanger
        case .completedToday:
            return accentColor
        case .skippedToday:
            return Color.tasker.textSecondary
        case .due, .tracking:
            return accentColor
        }
    }

    private var stateChipBackground: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color.tasker.statusDanger.opacity(0.10)
        case .skippedToday:
            return Color.tasker.surfaceSecondary
        case .due, .tracking, .completedToday:
            return accentColor.opacity(0.10)
        }
    }

    private var boardCells: [HabitBoardCell] {
        if row.boardCellsCompact.isEmpty {
            return HabitBoardPresentationBuilder.buildCells(
                marks: row.last14Days,
                cadence: row.cadence,
                referenceDate: row.dueAt ?? Date(),
                dayCount: 14
            )
        }
        return row.boardCellsCompact
    }
}
