import Foundation

enum QuietTrackingOutcome: String, CaseIterable, Identifiable {
    case progress
    case lapse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress: return "Log progress"
        case .lapse: return "Log lapse"
        }
    }
}

struct QuietTrackingComposerEntry: Equatable, Identifiable {
    let sourceRow: HomeHabitRow
    let colorFamily: HabitColorFamily
    let historyCells: [HabitBoardCell]

    var id: String { sourceRow.id }
    var title: String { sourceRow.title }
    var lifeAreaName: String { sourceRow.lifeAreaName }
    var iconSymbolName: String { sourceRow.iconSymbolName }
    var currentStreak: Int { sourceRow.currentStreak }
    var kind: HabitKind { sourceRow.kind }

    init(row: HomeHabitRow) {
        sourceRow = row
        colorFamily = HabitColorFamily.family(
            for: row.accentHex,
            fallback: row.kind == .positive ? .green : .coral
        )
        historyCells = Self.resolveHistoryCells(for: row)
    }

    private static func resolveHistoryCells(for row: HomeHabitRow) -> [HabitBoardCell] {
        if row.boardCellsExpanded.count >= 14 {
            return Array(row.boardCellsExpanded.suffix(14))
        }

        let referenceDate = row.boardCellsExpanded.last?.date
            ?? row.boardCellsCompact.last?.date
            ?? row.last14Days.last?.date
            ?? row.dueAt
            ?? Date()

        return HabitBoardPresentationBuilder.buildCells(
            marks: row.last14Days,
            cadence: row.cadence,
            referenceDate: referenceDate,
            dayCount: max(row.last14Days.count, 14)
        )
    }
}

struct QuietTrackingComposerSnapshot: Equatable, Identifiable {
    let id = UUID()
    let entries: [QuietTrackingComposerEntry]
    let entriesByID: [String: QuietTrackingComposerEntry]
    let initialSelectedHabitID: String?
    let initialDate: Date
    let initialOutcome: QuietTrackingOutcome

    init(
        rows: [HomeHabitRow],
        initialSelectedHabitID: String?,
        initialDate: Date,
        initialOutcome: QuietTrackingOutcome
    ) {
        let resolvedEntries = rows.map(QuietTrackingComposerEntry.init)
        let resolvedEntriesByID = Dictionary(uniqueKeysWithValues: resolvedEntries.map { ($0.id, $0) })
        self.entries = resolvedEntries
        self.entriesByID = resolvedEntriesByID

        if let initialSelectedHabitID, resolvedEntriesByID[initialSelectedHabitID] != nil {
            self.initialSelectedHabitID = initialSelectedHabitID
        } else {
            self.initialSelectedHabitID = resolvedEntries.first?.id
        }

        self.initialDate = initialDate
        self.initialOutcome = initialOutcome
    }

    static func == (lhs: QuietTrackingComposerSnapshot, rhs: QuietTrackingComposerSnapshot) -> Bool {
        lhs.entries == rhs.entries
            && lhs.initialSelectedHabitID == rhs.initialSelectedHabitID
            && lhs.initialDate == rhs.initialDate
            && lhs.initialOutcome == rhs.initialOutcome
    }

    func entry(for selectedHabitID: String?) -> QuietTrackingComposerEntry? {
        guard let resolvedSelectedHabitID = resolvedSelectedHabitID(selectedHabitID) else { return nil }
        return entriesByID[resolvedSelectedHabitID]
    }

    func resolvedSelectedHabitID(_ selectedHabitID: String?) -> String? {
        if let selectedHabitID, entriesByID[selectedHabitID] != nil {
            return selectedHabitID
        }

        return initialSelectedHabitID ?? entries.first?.id
    }

    func heroSubtitle(for entry: QuietTrackingComposerEntry?) -> String {
        guard let entry else {
            return "Choose a quiet habit and repair the day without pushing it back into your main task list."
        }

        if entry.kind == .negative {
            return "Keep the streak honest. Confirm a clean day or record the lapse on the exact date it happened."
        }

        return "Log the day quietly while keeping the main list focused on active work."
    }

    func progressTitle(for entry: QuietTrackingComposerEntry?) -> String {
        entry?.kind == .negative ? "Stayed clean" : "Done"
    }

    func progressDetail(for entry: QuietTrackingComposerEntry?) -> String {
        entry?.kind == .negative
            ? "Use this when the day stayed clean."
            : "Use this when the habit happened without needing a full task."
    }

    func footerTitle(for entry: QuietTrackingComposerEntry?, outcome: QuietTrackingOutcome) -> String {
        outcome == .lapse ? "Record lapse" : progressTitle(for: entry)
    }
}

struct QuietTrackingComposerSaveRequest: Equatable {
    let habitID: String
    let date: Date
    let outcome: QuietTrackingOutcome
}
