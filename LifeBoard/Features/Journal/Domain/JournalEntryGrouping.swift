import Foundation

/// One visible entry inside a journal day: the blocks written in one sitting.
///
/// Storage stays one record per calendar day (no schema change). Entries are
/// derived at read time from `createdAt`: a gap of three hours or more starts
/// a new one, and a block whose `promptID` is `JournalEntryGrouping.breakMarker`
/// starts one regardless of time ("New entry" sets it on the first block).
struct JournalEntryGroup: Identifiable, Equatable {
    /// The first block's id, so the group is stable while the day is edited.
    let id: UUID
    let startedAt: Date
    let blocks: [JournalBlockValue]
}

enum JournalEntryGrouping {
    static let defaultGap: TimeInterval = 3 * 60 * 60
    /// `promptID` value that forces a boundary before the block carrying it.
    static let breakMarker = "entry.break"

    static func entries(for blocks: [JournalBlockValue], gap: TimeInterval = defaultGap) -> [JournalEntryGroup] {
        let ordered = blocks.sorted { lhs, rhs in
            if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
            return lhs.createdAt < rhs.createdAt
        }
        var groups: [JournalEntryGroup] = []
        var current: [JournalBlockValue] = []
        var previous: Date?
        for block in ordered {
            let forcedBreak = block.promptID == breakMarker
            let timeBreak = previous.map { block.createdAt.timeIntervalSince($0) >= gap } ?? false
            if current.isEmpty == false, forcedBreak || timeBreak {
                groups.append(JournalEntryGroup(id: current[0].id, startedAt: current[0].createdAt, blocks: current))
                current = []
            }
            current.append(block)
            previous = block.createdAt
        }
        if current.isEmpty == false {
            groups.append(JournalEntryGroup(id: current[0].id, startedAt: current[0].createdAt, blocks: current))
        }
        return groups
    }

    /// "9:14 AM" for the header of an entry; the day itself is already named
    /// above the card, so the header carries only the time.
    static func headerText(for group: JournalEntryGroup, calendar: Calendar = .current) -> String {
        group.startedAt.formatted(.dateTime.hour().minute())
    }
}
