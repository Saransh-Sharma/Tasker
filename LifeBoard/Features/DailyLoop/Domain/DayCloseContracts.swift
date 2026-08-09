import Foundation

// MARK: - Reconciliation

/// What a person decided to do with one unfinished commitment when the day ended.
///
/// Declaration order **is** the deck's direction order. `DeckPhysics`
/// fills `[.right, .left, .up, .down]` by index, so reordering these cases
/// silently rebinds the gestures — `.release` would stop being the hardest
/// direction to reach by accident. `DayCloseScenarioBuilderTests` pins the
/// mapping for that reason.
///
/// There is deliberately no `leave` case. "Decide later" is the *absence* of a
/// decision — no map entry, no mutation — surfaced as an ordinary button rather
/// than a direction. Making it a fifth outcome would force every card to be
/// resolved before the day could close, which is the exact pressure the
/// anti-guilt rule exists to remove.
public enum DayCloseDirection: String, Codable, CaseIterable, Hashable, Sendable {
    /// Carry it into tomorrow. The non-destructive default, in the easiest slot.
    case tomorrow
    /// Off the calendar, still wanted.
    case someday
    /// It happened; the checkbox just never got ticked.
    case doneAnyway
    /// Kept for the record, never chased again.
    case release

    public var title: String {
        switch self {
        case .tomorrow: "Tomorrow"
        case .someday: "Someday"
        case .doneAnyway: "Already done"
        case .release: "Let it go"
        }
    }

    /// Written in the past tense of the *decision*, not of the task, so the
    /// summary can read "3 moved to tomorrow" rather than scoring the day.
    public var summaryVerb: String {
        switch self {
        case .tomorrow: "moved to tomorrow"
        case .someday: "moved to someday"
        case .doneAnyway: "marked done"
        case .release: "let go"
        }
    }

    public var symbolName: String {
        switch self {
        case .tomorrow: "arrow.turn.up.right"
        case .someday: "tray.and.arrow.down"
        case .doneAnyway: "checkmark"
        case .release: "wind"
        }
    }

    /// Spoken form for the deck's per-direction VoiceOver action. The gesture is
    /// an accelerator; this is the equal path.
    public func accessibilityLabel(for taskTitle: String) -> String {
        switch self {
        case .tomorrow: "Move \(taskTitle) to tomorrow"
        case .someday: "Move \(taskTitle) to someday"
        case .doneAnyway: "Mark \(taskTitle) already done"
        case .release: "Let \(taskTitle) go"
        }
    }
}

/// One line of the evening's outcome, keeping its direction so each outcome can
/// carry its own feedback after the batch lands. The summary was a plain
/// `[String]`, which left the view unable to tell "let go" from "moved to
/// tomorrow" and so applied the erosion effect to both.
public struct DayCloseSummaryLine: Identifiable, Hashable, Sendable {
    public let direction: DayCloseDirection
    public let text: String

    public var id: DayCloseDirection { direction }

    public init(direction: DayCloseDirection, text: String) {
        self.direction = direction
        self.text = text
    }
}

/// One resolved card. Ordered by when the decision was made so the ritual can
/// take exactly one step back without a second undo stack.
public struct DayCloseDecision: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { taskID }
    public let taskID: UUID
    public var direction: DayCloseDirection
    public var decidedAt: Date

    public init(taskID: UUID, direction: DayCloseDirection, decidedAt: Date = Date()) {
        self.taskID = taskID
        self.direction = direction
        self.decidedAt = decidedAt
    }
}

// MARK: - The day, replayed

/// One drawn span on the ribbon.
///
/// `lane` is resolved by the caller rather than stored as a role, because two
/// external commitments that overlap must sit on different lanes while still
/// reading as the same kind of thing.
public struct DayCloseRibbonSegment: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// A LifeBoard time block the person authored.
        case planned
        /// An external calendar event. Read-only, and visually distinct — the
        /// ribbon must never imply the app scheduled someone else's meeting.
        case commitment
        /// A focus session that actually ran.
        case focused
    }

    public let id: String
    public var title: String
    public var kind: Kind
    public var startAt: Date
    public var endAt: Date
    public var lane: Int

    public init(id: String, title: String, kind: Kind, startAt: Date, endAt: Date, lane: Int = 0) {
        self.id = id
        self.title = title
        self.kind = kind
        self.startAt = startAt
        self.endAt = max(endAt, startAt)
        self.lane = lane
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

/// A completion, placed at the moment it happened.
public struct DayCloseCompletionMark: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var completedAt: Date

    public init(id: UUID, title: String, completedAt: Date) {
        self.id = id
        self.title = title
        self.completedAt = completedAt
    }
}

/// The figures behind the day ring.
///
/// Every quantity is optional on purpose. A day with no blocks has `nil` planned
/// minutes, not zero — "you planned nothing" and "you planned nothing *and hit
/// none of it*" are different statements, and only one of them is true. The ring
/// renders a bare track for `nil` and never prints a percentage.
public struct DayCloseRingSummary: Codable, Hashable, Sendable {
    public var plannedMinutes: Int?
    public var focusedMinutes: Int?
    public var completedCount: Int
    public var unfinishedCount: Int

    public init(
        plannedMinutes: Int? = nil,
        focusedMinutes: Int? = nil,
        completedCount: Int = 0,
        unfinishedCount: Int = 0
    ) {
        self.plannedMinutes = plannedMinutes.map { max(0, $0) }
        self.focusedMinutes = focusedMinutes.map { max(0, $0) }
        self.completedCount = max(0, completedCount)
        self.unfinishedCount = max(0, unfinishedCount)
    }

    /// Focused against planned, or `nil` when nothing was planned.
    ///
    /// Not clamped to 1: focusing past what you planned is a real thing that
    /// happened, and flattening it to "100%" would hide it. The ring caps its
    /// *arc* for legibility; the number stays honest.
    public var focusRatio: Double? {
        guard let plannedMinutes, plannedMinutes > 0, let focusedMinutes else { return nil }
        return Double(focusedMinutes) / Double(plannedMinutes)
    }

    /// True when the day genuinely had no shape to report, as opposed to a shape
    /// we failed to load. The view uses this to pick the empty *success* copy.
    public var hasNothingToReport: Bool {
        plannedMinutes == nil && focusedMinutes == nil && completedCount == 0 && unfinishedCount == 0
    }
}

/// The whole retrospective, ready to draw. Pure geometry and text — no colors,
/// no view types, so it stays testable without a renderer.
public struct DayCloseRibbon: Codable, Hashable, Sendable {
    public var segments: [DayCloseRibbonSegment]
    public var completionMarks: [DayCloseCompletionMark]
    public var summary: DayCloseRingSummary
    public var windowStart: Date
    public var windowEnd: Date
    /// Set when the calendar could not be read, so the ribbon can say the
    /// external lane is missing instead of implying an empty calendar.
    public var externalCalendarUnavailable: Bool

    public init(
        segments: [DayCloseRibbonSegment],
        completionMarks: [DayCloseCompletionMark],
        summary: DayCloseRingSummary,
        windowStart: Date,
        windowEnd: Date,
        externalCalendarUnavailable: Bool = false
    ) {
        self.segments = segments
        self.completionMarks = completionMarks
        self.summary = summary
        self.windowStart = windowStart
        self.windowEnd = max(windowEnd, windowStart)
        self.externalCalendarUnavailable = externalCalendarUnavailable
    }

    public var duration: TimeInterval { max(0, windowEnd.timeIntervalSince(windowStart)) }

    /// Where a moment sits along the ribbon, 0...1. `nil` outside the window, so
    /// a stray timestamp is dropped rather than drawn off the end.
    public func position(of date: Date) -> Double? {
        guard duration > 0 else { return nil }
        let offset = date.timeIntervalSince(windowStart)
        guard offset >= 0, offset <= duration else { return nil }
        return offset / duration
    }

    public var laneCount: Int {
        (segments.map(\.lane).max() ?? -1) + 1
    }
}

// MARK: - Ritual structure

/// The five beats, in order.
///
/// Modelled explicitly rather than as an index so the store can report where it
/// is without the view owning the sequence, and so a skipped act (no anchor
/// candidates left) is a state rather than an off-by-one.
public enum DayCloseAct: String, Codable, CaseIterable, Hashable, Sendable {
    case ribbon
    case reconcile
    case reflect
    case anchor
    case close

    public var title: String {
        switch self {
        case .ribbon: "Your day"
        case .reconcile: "What carries"
        case .reflect: "One line"
        case .anchor: "Tomorrow's first thing"
        case .close: "Close"
        }
    }
}

/// What the ritual can be doing.
///
/// `.empty` is a **success** state, not a void, and is deliberately distinct
/// from `.failed`: the app must never congratulate someone for a fetch that did
/// not complete.
public enum DayCloseLoadState: Equatable, Sendable {
    case loading
    case ready
    case empty
    case failed(String)
}
