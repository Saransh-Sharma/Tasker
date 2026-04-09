import SwiftUI

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil
    var onOpenDetail: (() -> Void)? = nil
    var onLastCellAction: (() -> Void)? = nil

    init(
        row: HomeHabitRow,
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onOpenDetail: (() -> Void)? = nil,
        onLastCellAction: (() -> Void)? = nil
    ) {
        self.row = row
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onOpenDetail = onOpenDetail
        self.onLastCellAction = onLastCellAction
    }

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var family: HabitColorFamily {
        HabitColorFamily.family(for: row.accentHex, fallback: row.kind == .positive ? .green : .coral)
    }

    private var accentColor: Color {
        HabitEverydayPalette.familyPreview(family)
    }

    private var usesExpandedTitle: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var rowMinHeight: CGFloat {
        usesExpandedTitle ? 88 : 64
    }

    private var iconTileWidth: CGFloat {
        usesExpandedTitle ? 72 : 64
    }

    private var isResolved: Bool {
        switch row.state {
        case .completedToday, .lapsedToday, .skippedToday:
            return true
        case .due, .overdue, .tracking:
            return false
        }
    }

    private var lastCellInteraction: HomeHabitLastCellInteraction? {
        HomeHabitLastCellInteraction.resolve(for: row)
    }

    var body: some View {
        rowBase
            .overlay {
                rowInteractionOverlay
            }
            .accessibilityIdentifier("home.habitRow.\(row.id)")
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
            .hoverEffect(.highlight)
    }

    private var rowBase: some View {
        HStack(spacing: 0) {
            iconTile
            streakSurface
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: rowMinHeight, alignment: .center)
    }

    private var iconTile: some View {
        ZStack {
            accentColor.opacity(0.14)

            Image(systemName: row.iconSymbolName)
                .font(.system(size: usesExpandedTitle ? 20 : 18, weight: .semibold))
                .foregroundStyle(accentColor)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: iconTileWidth)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.55))
                .frame(width: 1)
        }
        .accessibilityHidden(true)
        .accessibilityIdentifier("home.habitRow.icon.\(row.id)")
    }

    private var streakSurface: some View {
        ZStack(alignment: .topLeading) {
            stretchedStrip
            titleReadabilityScrim
            titleView(lineLimit: usesExpandedTitle ? 2 : 1)
                .padding(.horizontal, usesExpandedTitle ? spacing.s12 : spacing.s8)
                .padding(.vertical, usesExpandedTitle ? spacing.s12 : spacing.s8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("home.habitRow.strip.\(row.id)")
    }

    private func titleView(lineLimit: Int) -> some View {
        Text(row.title)
            .font(.tasker(usesExpandedTitle ? .bodyStrong : .body))
            .foregroundStyle(Color.tasker.textPrimary)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.habitRow.title.\(row.id)")
            .accessibilityHidden(true)
    }

    private var stretchedStrip: some View {
        GeometryReader { proxy in
            HabitBoardStripView(
                cells: boardCells,
                family: family,
                mode: .homeList,
                cellWidthOverride: stretchedCellWidth(for: proxy.size.width),
                cellHeightOverride: max(proxy.size.height, 1)
            )
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
        .clipped()
    }

    private var titleReadabilityScrim: some View {
        LinearGradient(
            colors: [
                Color.tasker.surfacePrimary.opacity(0.82),
                Color.tasker.surfacePrimary.opacity(0.56),
                Color.tasker.surfacePrimary.opacity(0.12),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(
            LinearGradient(
                colors: [.white, .white, .black.opacity(0.65), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .allowsHitTesting(false)
    }

    private func stretchedCellWidth(for totalWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(boardCells.count, 1))
        return max(totalWidth / count, 1)
    }

    private func lastCellWidth(for totalWidth: CGFloat) -> CGFloat {
        let stripWidth = max(totalWidth - iconTileWidth, 1)
        return stretchedCellWidth(for: stripWidth)
    }

    private var rowInteractionOverlay: some View {
        GeometryReader { proxy in
            let lastCellWidth = lastCellInteraction == nil ? 0 : lastCellWidth(for: proxy.size.width)

            HStack(spacing: 0) {
                if let onOpenDetail {
                    Button {
                        TaskerFeedback.selection()
                        onOpenDetail()
                    } label: {
                        Color.clear
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(proxy.size.width - lastCellWidth, 0))
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel(row.title)
                    .accessibilityValue(accessibilityValue)
                    .accessibilityHint(accessibilityHint)
                } else {
                    Color.clear
                        .frame(width: max(proxy.size.width - lastCellWidth, 0))
                }

                if let interaction = lastCellInteraction,
                   let onLastCellAction {
                    Button {
                        TaskerFeedback.selection()
                        onLastCellAction()
                    } label: {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.2)
                            .background(Color.clear)
                    }
                    .buttonStyle(.plain)
                    .frame(width: lastCellWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("home.habitRow.lastCell.\(row.id)")
                    .accessibilityLabel("\(row.title) status")
                    .accessibilityValue("\(interaction.currentStateText). Next: \(interaction.nextActionText).")
                    .accessibilityHint("Cycles the last habit cell for the selected date.")
                } else {
                    Color.clear
                        .frame(width: lastCellWidth)
                }
            }
        }
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
        if primaryActionTitle != nil || secondaryActionTitle != nil || lastCellInteraction != nil {
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
                dayCount: 7
            )
        }
        return row.boardCellsCompact
    }
}
