import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil

    @State private var isExpanded = false

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var family: HabitColorFamily {
        HabitColorFamily.family(for: row.accentHex, fallback: row.kind == .positive ? .green : .coral)
    }

    private var accentColor: Color {
        HabitEverydayPalette.familyPreview(family)
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
        VStack(alignment: .leading, spacing: 10) {
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
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.stateChange, value: isExpanded)
        .animation(reduceMotion ? .linear(duration: 0.01) : TaskerAnimation.feedbackFast, value: row.state)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.habitRow.\(row.id)")
    }

    private var collapsedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                leadingIdentity
                Spacer(minLength: 0)
                expandButton
            }

            HabitBoardStripView(
                cells: boardCells,
                family: family,
                mode: .compact
            )

            HStack(alignment: .center, spacing: 8) {
                HabitStatBadgeView(
                    value: "\(row.currentStreak)",
                    family: family,
                    highlighted: row.currentStreak > 0 && row.currentStreak == row.bestStreak
                )
                HabitStatBadgeView(
                    value: "\(row.bestStreak)",
                    family: family,
                    highlighted: row.bestStreak > 0 && row.currentStreak == row.bestStreak
                )

                Text(row.bestStreak > 0 ? "best" : stateText.lowercased())
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)

                Spacer(minLength: 0)

                quickActionSlot
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(row.cadenceLabel.uppercased())
                    .font(.tasker(.caption2).weight(.semibold))
                    .foregroundStyle(Color.tasker.textSecondary)

                Spacer(minLength: 0)

                stateChip
            }

            HabitBoardStripView(
                cells: row.boardCellsExpanded.isEmpty ? boardCells : row.boardCellsExpanded,
                family: family,
                mode: .expanded
            )

            HStack(spacing: 10) {
                metricCluster(title: "Current", value: "\(row.currentStreak)", highlighted: row.currentStreak > 0 && row.currentStreak == row.bestStreak)
                metricCluster(title: "Longest", value: "\(row.bestStreak)", highlighted: row.bestStreak > 0 && row.currentStreak == row.bestStreak)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: row.iconSymbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accentColor)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)

                Text(metadataLine)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(1)
            }
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
            .foregroundStyle(Color.tasker.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
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
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.7))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.tasker.strokeHairline.opacity(0.55), lineWidth: 1))
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    private var stateChip: some View {
        Text(stateText)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(stateChipForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(stateChipBackground)
            )
    }

    private func metricCluster(title: String, value: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
            HabitStatBadgeView(value: value, family: family, highlighted: highlighted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.45), lineWidth: 1)
        )
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
        .frame(minHeight: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isPrimary ? accentColor : Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isPrimary ? accentColor.opacity(0.12) : Color.tasker.strokeHairline.opacity(0.52), lineWidth: 1)
        )
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
        Color(uiColor: UIColor(taskerHex: "#FCFAF4"))
    }

    private var borderColor: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color(uiColor: UIColor(taskerHex: "#D8BAAF"))
        default:
            return Color.tasker.strokeHairline.opacity(0.52)
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
            return "Skipped without breaking the chain"
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
        case .skippedToday:
            return Color.tasker.textSecondary
        case .completedToday, .due, .tracking:
            return accentColor
        }
    }

    private var stateChipBackground: Color {
        switch row.state {
        case .overdue, .lapsedToday:
            return Color.tasker.statusDanger.opacity(0.10)
        case .skippedToday:
            return Color.white.opacity(0.62)
        case .completedToday, .due, .tracking:
            return accentColor.opacity(0.10)
        }
    }

    private var boardCells: [HabitBoardCell] {
        if row.boardCellsCompact.isEmpty {
            return HabitBoardPresentationBuilder.buildCells(
                marks: row.last14Days,
                cadence: row.cadence,
                referenceDate: row.dueAt ?? Date(),
                dayCount: 10
            )
        }
        return row.boardCellsCompact
    }
}
