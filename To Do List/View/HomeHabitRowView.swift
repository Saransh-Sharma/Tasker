import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil
    var onOpenDetail: (() -> Void)? = nil

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    private var stripWidth: CGFloat {
        CGFloat(boardCells.count) * HabitBoardStripMode.homeList.columnWidth
    }

    var body: some View {
        rowBase
            .contentShape(Rectangle())
            .onTapGesture {
                guard let onOpenDetail else { return }
                TaskerFeedback.selection()
                onOpenDetail()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: primaryActionTitle != nil) {
                if let primaryActionTitle, let onPrimaryAction {
                    Button {
                        TaskerFeedback.light()
                        onPrimaryAction()
                    } label: {
                        Label(primaryActionTitle, systemImage: primaryActionSymbolName)
                    }
                    .tint(primaryActionTint)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let secondaryActionTitle, let onSecondaryAction {
                    Button {
                        TaskerFeedback.light()
                        onSecondaryAction()
                    } label: {
                        Label(secondaryActionTitle, systemImage: secondaryActionSymbolName)
                    }
                    .tint(secondaryActionTint)
                }
            }
            .contextMenu {
                if let onOpenDetail {
                    Button {
                        onOpenDetail()
                    } label: {
                        Label("Open details", systemImage: "arrow.up.right.square")
                    }
                }

                if let primaryActionTitle, let onPrimaryAction {
                    Button {
                        onPrimaryAction()
                    } label: {
                        Label(primaryActionTitle, systemImage: primaryActionSymbolName)
                    }
                }

                if let secondaryActionTitle, let onSecondaryAction {
                    Button {
                        onSecondaryAction()
                    } label: {
                        Label(secondaryActionTitle, systemImage: secondaryActionSymbolName)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("home.habitRow.\(row.id)")
            .accessibilityLabel(row.title)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .hoverEffect(.highlight)
    }

    private var rowBase: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 52, alignment: .center)
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            titleView(lineLimit: 1)

            Spacer(minLength: spacing.s8)

            streakStrip
                .frame(width: stripWidth, alignment: .trailing)
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            titleView(lineLimit: dynamicTypeSize >= .accessibility1 ? 2 : 1)
            streakStrip
        }
    }

    private func titleView(lineLimit: Int) -> some View {
        Text(row.title)
            .font(.tasker(dynamicTypeSize >= .accessibility1 ? .bodyStrong : .body))
            .foregroundStyle(Color.tasker.textPrimary)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.habitRow.title.\(row.id)")
    }

    private var streakStrip: some View {
        HabitBoardStripView(
            cells: boardCells,
            family: family,
            mode: .homeList
        )
        .frame(minHeight: HabitBoardStripMode.homeList.cellSize)
        .accessibilityIdentifier("home.habitRow.strip.\(row.id)")
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

    private var primaryActionSymbolName: String {
        if row.trackingMode == .lapseOnly {
            return "exclamationmark.circle"
        }
        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "checkmark.circle"
        case (.negative, .dailyCheckIn):
            return "checkmark.shield"
        case (.negative, .lapseOnly):
            return "checkmark.circle"
        }
    }

    private var secondaryActionSymbolName: String {
        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return "forward.circle"
        case (.negative, .dailyCheckIn):
            return "xmark.circle"
        case (.negative, .lapseOnly):
            return "xmark.circle"
        }
    }

    private var primaryActionTint: Color {
        row.trackingMode == .lapseOnly ? Color.tasker.statusDanger : accentColor
    }

    private var secondaryActionTint: Color {
        switch (row.kind, row.trackingMode) {
        case (.positive, _):
            return Color.tasker.textSecondary
        case (.negative, .dailyCheckIn):
            return Color.tasker.statusDanger
        case (.negative, .lapseOnly):
            return Color.tasker.textSecondary
        }
    }

    private var accessibilityValue: String {
        "\(stateText). Current streak \(row.currentStreak) days. Best streak \(row.bestStreak) days."
    }

    private var accessibilityHint: String {
        if primaryActionTitle != nil || secondaryActionTitle != nil {
            return "Opens habit details. Swipe for quick actions."
        }
        return "Opens habit details."
    }

    private var stateText: String {
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
            return "Skipped today"
        case .tracking:
            return row.trackingMode == .lapseOnly ? "Tracking quietly" : "On track"
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
