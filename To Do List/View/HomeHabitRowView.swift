import SwiftUI

struct HomeHabitRowHitTargetMetrics: Equatable {
    let detailRegionWidth: CGFloat
    let visualLastCellWidth: CGFloat
    let interactiveLastCellWidth: CGFloat

    init(stripWidth: CGFloat, cellCount: Int, hasLastCellInteraction: Bool) {
        let resolvedStripWidth = max(stripWidth, 1)
        let resolvedCellCount = max(cellCount, 1)
        let trailingCellWidth = hasLastCellInteraction
            ? max(resolvedStripWidth / CGFloat(resolvedCellCount), 1)
            : 0
        let interactiveTrailingCellWidth = hasLastCellInteraction
            ? min(max(trailingCellWidth * 2, 64), 80)
            : 0

        self.visualLastCellWidth = trailingCellWidth
        self.interactiveLastCellWidth = min(max(interactiveTrailingCellWidth, trailingCellWidth), resolvedStripWidth)
        self.detailRegionWidth = max(resolvedStripWidth - interactiveLastCellWidth, 0)
    }
}

private struct HomeHabitRowInteractiveButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

private struct HomeHabitRowInteractiveSurface: View {
    let row: HomeHabitRow
    let boardCellCount: Int
    let colorScheme: ColorScheme
    let lastCellInteraction: HomeHabitLastCellInteraction?
    let accessibilityValue: String
    let accessibilityHint: String
    let onOpenDetail: (() -> Void)?
    let onLastCellAction: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let metrics = HomeHabitRowHitTargetMetrics(
                stripWidth: proxy.size.width,
                cellCount: boardCellCount,
                hasLastCellInteraction: lastCellInteraction != nil && onLastCellAction != nil
            )

            HStack(spacing: 0) {
                if let onOpenDetail {
                    HomeHabitRowInteractiveButton(
                        action: onOpenDetail
                    ) {
                        Color.clear
                    }
                    .frame(width: metrics.detailRegionWidth)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(row.title)
                    .accessibilityValue(accessibilityValue)
                    .accessibilityHint(accessibilityHint)
                } else if metrics.detailRegionWidth > 0 {
                    Color.clear
                        .frame(width: metrics.detailRegionWidth)
                }

                if let interaction = lastCellInteraction,
                   let onLastCellAction,
                   metrics.interactiveLastCellWidth > 0 {
                    HomeHabitRowInteractiveButton(
                        action: onLastCellAction
                    ) {
                        ZStack(alignment: .trailing) {
                            Color.clear

                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.2)
                                .frame(width: metrics.visualLastCellWidth)
                        }
                    }
                    .frame(width: metrics.interactiveLastCellWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("home.habitRow.lastCell.\(row.id)")
                    .accessibilityLabel("\(row.title) status")
                    .accessibilityValue("\(interaction.currentStateText). Next: \(interaction.nextActionText).")
                    .accessibilityHint("Cycles the last habit cell for the selected date.")
                    .zIndex(1)
                } else if metrics.interactiveLastCellWidth > 0 {
                    Color.clear
                        .frame(width: metrics.interactiveLastCellWidth)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
        }
    }
}

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

    private var boardCellCount: Int {
        max(boardCells.count, 1)
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

    @ViewBuilder
    private var iconTile: some View {
        if let onOpenDetail {
            HomeHabitRowInteractiveButton(
                action: onOpenDetail
            ) {
                iconTileVisual
            }
            .accessibilityHidden(true)
        } else {
            iconTileVisual
        }
    }

    private var iconTileVisual: some View {
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
            streakSurfaceVisual
                .allowsHitTesting(false)

            HomeHabitRowInteractiveSurface(
                row: row,
                boardCellCount: boardCellCount,
                colorScheme: colorScheme,
                lastCellInteraction: lastCellInteraction,
                accessibilityValue: accessibilityValue,
                accessibilityHint: accessibilityHint,
                onOpenDetail: onOpenDetail,
                onLastCellAction: onLastCellAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("home.habitRow.strip.\(row.id)")
    }

    private var streakSurfaceVisual: some View {
        ZStack(alignment: .topLeading) {
            stretchedStrip
            titleReadabilityScrim
            titleView(lineLimit: usesExpandedTitle ? 2 : 1)
                .padding(.horizontal, usesExpandedTitle ? spacing.s12 : spacing.s8)
                .padding(.vertical, usesExpandedTitle ? spacing.s12 : spacing.s8)
        }
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
            .allowsHitTesting(false)
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
        .allowsHitTesting(false)
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
        max(totalWidth / CGFloat(boardCellCount), 1)
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
