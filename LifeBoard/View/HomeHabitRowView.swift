import SwiftUI

struct HomeHabitRowHitTargetMetrics: Equatable {
    static let normalMaximumCellSide: CGFloat = 48
    static let accessibilityMaximumCellSide: CGFloat = 56
    static let normalMinimumRowHeight: CGFloat = 44
    static let accessibilityMinimumRowHeight: CGFloat = 68

    let cellSide: CGFloat
    let rowHeight: CGFloat
    let visualLastCellWidth: CGFloat

    init(
        stripWidth: CGFloat,
        cellCount: Int,
        showsLastCellDecoration: Bool,
        usesExpandedTitle: Bool = false
    ) {
        let resolvedStripWidth = max(stripWidth, 1)
        let resolvedCellCount = max(cellCount, 1)
        let maximumCellSide = usesExpandedTitle ? Self.accessibilityMaximumCellSide : Self.normalMaximumCellSide
        let minimumRowHeight = usesExpandedTitle ? Self.accessibilityMinimumRowHeight : Self.normalMinimumRowHeight
        let resolvedCellSide = min(max(resolvedStripWidth / CGFloat(resolvedCellCount), 1), maximumCellSide)

        self.cellSide = resolvedCellSide
        self.rowHeight = max(minimumRowHeight, resolvedCellSide)
        self.visualLastCellWidth = showsLastCellDecoration
            ? resolvedCellSide
            : 0
    }
}

struct HomeHabitLastCellDecorationPolicy {
    static func showsDecoration(for state: HomeHabitRowState) -> Bool {
        switch state {
        case .due, .overdue, .tracking:
            return true
        case .completedToday, .lapsedToday, .skippedToday:
            return false
        }
    }
}

private struct HomeHabitRowInteractiveButton<Label: View>: View {
    enum Feedback {
        case selection

        @MainActor
        func play() {
            switch self {
            case .selection:
                LifeBoardFeedback.selection()
            }
        }
    }

    let action: () -> Void
    let feedback: Feedback?
    @ViewBuilder let label: () -> Label

    init(
        action: @escaping () -> Void,
        feedback: Feedback? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.feedback = feedback
        self.label = label
    }

    var body: some View {
        Button {
            feedback?.play()
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
    let usesExpandedTitle: Bool
    let showsLastCellDecoration: Bool
    let lastCellInteraction: HomeHabitLastCellInteraction
    let accessibilityHint: String
    let onRowAction: (() -> Void)?
    let onLastCellAction: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let stripAction = onRowAction ?? onLastCellAction
            let metrics = HomeHabitRowHitTargetMetrics(
                stripWidth: proxy.size.width,
                cellCount: boardCellCount,
                showsLastCellDecoration: stripAction != nil && showsLastCellDecoration,
                usesExpandedTitle: usesExpandedTitle
            )

            if let stripAction {
                HomeHabitRowInteractiveButton(
                    action: stripAction
                ) {
                    ZStack(alignment: .trailing) {
                        // Non-zero opacity keeps the full strip in hit-testing across
                        // scroll/gesture contention where fully clear content can drop taps.
                        Color.black.opacity(0.001)

                        if metrics.visualLastCellWidth > 0 {
                            Image(systemName: "circle.dotted.circle")
                                .font(.system(size: min(metrics.visualLastCellWidth * 0.58, usesExpandedTitle ? 28 : 22), weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .yellow)
                                .symbolEffect(.breathe.pulse.byLayer, options: .repeat(.periodic(delay: 2.5)))
                                .frame(width: metrics.visualLastCellWidth, height: metrics.visualLastCellWidth)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityIdentifier("home.habitRow.lastCell.\(row.id)")
                .accessibilityLabel("\(row.title) status")
                .accessibilityValue("\(lastCellInteraction.currentStateText). Next: \(lastCellInteraction.nextActionText).")
                .accessibilityHint(accessibilityHint)
            } else {
                Color.clear
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            }
        }
    }
}

struct HomeHabitRowView: View {
    let row: HomeHabitRow
    var onPrimaryAction: (() -> Void)? = nil
    var onSecondaryAction: (() -> Void)? = nil
    var onRowAction: (() -> Void)? = nil
    var onOpenDetail: (() -> Void)? = nil
    var onLastCellAction: (() -> Void)? = nil

    init(
        row: HomeHabitRow,
        onPrimaryAction: (() -> Void)? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        onRowAction: (() -> Void)? = nil,
        onOpenDetail: (() -> Void)? = nil,
        onLastCellAction: (() -> Void)? = nil
    ) {
        self.row = row
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
        self.onRowAction = onRowAction
        self.onOpenDetail = onOpenDetail
        self.onLastCellAction = onLastCellAction
    }

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var measuredStreakWidth: CGFloat = 0

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

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
        usesExpandedTitle
            ? HomeHabitRowHitTargetMetrics.accessibilityMinimumRowHeight
            : HomeHabitRowHitTargetMetrics.normalMinimumRowHeight
    }

    private var resolvedRowHeight: CGFloat {
        guard measuredStreakWidth > 0 else { return rowMinHeight }
        return HomeHabitRowHitTargetMetrics(
            stripWidth: measuredStreakWidth,
            cellCount: boardCellCount,
            showsLastCellDecoration: false,
            usesExpandedTitle: usesExpandedTitle
        ).rowHeight
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

    private var showsLastCellDecoration: Bool {
        HomeHabitLastCellDecorationPolicy.showsDecoration(for: row.state)
    }

    private var lastCellInteraction: HomeHabitLastCellInteraction {
        HomeHabitLastCellInteraction.resolve(for: row)
    }

    var body: some View {
        rowBase
            .accessibilityIdentifier("home.habitRow.\(row.id)")
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
        .frame(minHeight: resolvedRowHeight, alignment: .center)
    }

    @ViewBuilder
    private var iconTile: some View {
        if let onOpenDetail {
            HomeHabitRowInteractiveButton(
                action: onOpenDetail,
                feedback: .selection
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
                .fill(Color.lifeboard.strokeHairline.opacity(0.55))
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
                usesExpandedTitle: usesExpandedTitle,
                showsLastCellDecoration: showsLastCellDecoration,
                lastCellInteraction: lastCellInteraction,
                accessibilityHint: accessibilityHint,
                onRowAction: onRowAction,
                onLastCellAction: onLastCellAction
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            measuredStreakWidth = newWidth
        }
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
            .font(.lifeboard(usesExpandedTitle ? .bodyStrong : .body))
            .foregroundStyle(Color.lifeboard.textPrimary)
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
            let metrics = HomeHabitRowHitTargetMetrics(
                stripWidth: proxy.size.width,
                cellCount: boardCellCount,
                showsLastCellDecoration: false,
                usesExpandedTitle: usesExpandedTitle
            )

            HabitBoardStripView(
                cells: boardCells,
                family: family,
                mode: .homeList,
                cellWidthOverride: metrics.cellSide,
                cellHeightOverride: metrics.cellSide
            )
            .frame(width: proxy.size.width, height: metrics.rowHeight, alignment: .trailing)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private var titleReadabilityScrim: some View {
        LinearGradient(
            colors: [
                Color.lifeboard.surfacePrimary.opacity(0.82),
                Color.lifeboard.surfacePrimary.opacity(0.56),
                Color.lifeboard.surfacePrimary.opacity(0.12),
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

    private var accessibilityHint: String {
        if onRowAction != nil {
            if onOpenDetail != nil {
                return "Double-tap to cycle today. Tap the icon to open details. Long-press for quick actions."
            }
            return "Double-tap to cycle today. Long-press for quick actions."
        }

        if primaryActionTitle != nil || secondaryActionTitle != nil {
            return "Opens habit details. Long-press for quick actions."
        }
        return "Opens habit details."
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
