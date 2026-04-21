import SwiftUI

struct HomeHabitRowHitTargetMetrics: Equatable {
    let visualLastCellWidth: CGFloat

    init(stripWidth: CGFloat, cellCount: Int, showsLastCellDecoration: Bool) {
        let resolvedStripWidth = max(stripWidth, 1)
        let resolvedCellCount = max(cellCount, 1)
        let trailingCellWidth = showsLastCellDecoration
            ? max(resolvedStripWidth / CGFloat(resolvedCellCount), 1)
            : 0

        self.visualLastCellWidth = trailingCellWidth
    }
}

private struct HomeHabitRowInteractiveButton<Label: View>: View {
    enum Feedback {
        case selection

        @MainActor
        func play() {
            switch self {
            case .selection:
                TaskerFeedback.selection()
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
                showsLastCellDecoration: stripAction != nil
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
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .stroke(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.2)
                                .frame(width: metrics.visualLastCellWidth)
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
        .frame(minHeight: rowMinHeight, alignment: .center)
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
                accessibilityHint: accessibilityHint,
                onRowAction: onRowAction,
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
