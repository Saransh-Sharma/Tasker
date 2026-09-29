import SwiftUI

// MARK: - Graph lens

/// Grouped per-habit long-run heatmaps (GitHub-style weekday × week grid).
struct HabitBoardGraphLens: View {
    let sections: [HabitBoardGroupedSection]
    let isLoading: Bool
    let onSelect: (UUID) -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        if isLoading {
            VStack(spacing: spacing.s12) {
                ProgressView()
                Text("Loading…")
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s24)
        } else {
            VStack(alignment: .leading, spacing: spacing.s16) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        HabitBoardSectionHeader(section: section)
                        HabitBoardLensRows(isGrid: layoutClass.isPad, rowSpacing: spacing.s8) {
                            ForEach(section.rows) { row in
                                HabitGraphCard(row: row, onSelect: { onSelect(row.habitID) })
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HabitGraphCard: View {
    let row: HabitBoardRowPresentation
    let onSelect: () -> Void
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }
    private var accent: Color { HabitEverydayPalette.familyPreview(row.colorFamily) }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(spacing: 8) {
                    Image(systemName: row.iconSymbolName)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(accent)
                    Text(row.title)
                        .font(.lifeboard(.body).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: spacing.s8)
                    HStack(spacing: 12) {
                        // A habit with no history has no record — not a zero.
                        // `DESIGN.md`: never render an absent value as zero.
                        HabitGraphStat(
                            caption: String(localized: "30 days"),
                            value: row.cells.isEmpty ? "—" : "\(row.metrics.monthCount)",
                            family: row.colorFamily
                        )
                        HabitGraphStat(
                            caption: String(localized: "Best"),
                            value: row.cells.isEmpty ? "—" : "\(row.bestStreak)",
                            family: row.colorFamily
                        )
                    }
                }

                HabitGraphGrid(cells: row.cells, family: row.colorFamily)
            }
            .padding(spacing.s12)
            .background(HabitBoardFlatSurfaceBackground(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            row.cells.isEmpty
                ? String(localized: "\(row.title). Nothing logged yet.")
                : String(localized: "\(row.title). \(row.metrics.monthCount) done in the last 30 days. Best streak \(row.bestStreak) days.")
        )
        .accessibilityHint("Opens habit")
    }
}

private struct HabitGraphStat: View {
    let caption: String
    let value: String
    let family: HabitColorFamily

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.lifeboard(.caption1).weight(.bold))
                .foregroundStyle(HabitEverydayPalette.familyPreview(family))
            Text(caption)
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard.textTertiary)
        }
    }
}

/// GitHub-style contribution grid: 7 weekday rows × N week columns, with aligned
/// month labels along the top. Scrolls horizontally, anchored to the most recent.
private struct HabitGraphGrid: View {
    let cells: [HabitBoardCell]
    let family: HabitColorFamily

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 2.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealProgress = 0.0

    private var columns: [[HabitBoardCell?]] { Self.buildColumns(from: cells) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 3) {
                monthLabels
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { rowIndex in
                                if let cell = column[safe: rowIndex] ?? nil {
                                    HabitBoardCellView(
                                        cell: cell,
                                        family: family,
                                        mode: .compact,
                                        cellSizeOverride: cellSize
                                    )
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
            }
        }
        .defaultScrollAnchor(.trailing)
        .lifeboardChartRevealSweep(progress: revealProgress)
        // The sweep used to replay on every appear, so scrolling the board
        // through a lazy stack re-revealed graphs that had been on screen
        // moments earlier — and it swept an empty grid too. `DESIGN.md`: a
        // chart draws its reveal once, when valid data first appears or its
        // range changes, and empty states never sweep.
        .onAppear { revealProgress = cells.isEmpty ? 0 : 1 }
        .onChange(of: cells.count) { previous, updated in
            guard updated > 0 else {
                revealProgress = 0
                return
            }
            guard previous == 0 else { return }
            reveal()
        }
        .accessibilityHidden(true)
    }

    private func reveal() {
        guard reduceMotion == false else {
            revealProgress = 1
            return
        }
        revealProgress = 0
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
            revealProgress = 1
        }
    }

    private var monthLabels: some View {
        let columnWidth = cellSize + cellSpacing
        let labels = Self.monthLabels(for: columns)
        return HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard.textTertiary)
                    .frame(width: columnWidth, alignment: .leading)
                    .fixedSize()
            }
        }
    }

    /// One label per column: the month abbreviation on the first column of each
    /// month, empty otherwise. Precomputed so ForEach stays pure.
    static func monthLabels(for columns: [[HabitBoardCell?]]) -> [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortMonthSymbols
        var lastMonth: Int? = nil
        return columns.map { column in
            guard let date = column.compactMap({ $0 }).first?.date else { return "" }
            let month = calendar.component(.month, from: date)
            guard month != lastMonth else { return "" }
            lastMonth = month
            return (1...symbols.count).contains(month) ? symbols[month - 1] : ""
        }
    }

    /// Chunks chronological cells into weekday-aligned week columns.
    static func buildColumns(from cells: [HabitBoardCell]) -> [[HabitBoardCell?]] {
        guard cells.isEmpty == false else { return [] }
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        func weekdayIndex(_ date: Date) -> Int {
            (calendar.component(.weekday, from: date) - firstWeekday + 7) % 7
        }

        var columns: [[HabitBoardCell?]] = []
        var current: [HabitBoardCell?] = []
        for cell in cells {
            let index = weekdayIndex(cell.date)
            if current.isEmpty {
                current = Array(repeating: nil, count: index)
            } else if index == 0 {
                while current.count < 7 { current.append(nil) }
                columns.append(current)
                current = []
            }
            current.append(cell)
        }
        if current.isEmpty == false {
            while current.count < 7 { current.append(nil) }
            columns.append(current)
        }
        return columns
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
