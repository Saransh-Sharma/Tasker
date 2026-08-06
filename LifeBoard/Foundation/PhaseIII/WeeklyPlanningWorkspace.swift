import Foundation

// MARK: - Entry

/// How the workspace was opened.
///
/// The two entries differ only in what the surface leads with. `week` opens on
/// the ribbon with the tray on Inbox; `overdue` opens on the backlog briefing,
/// because at any real overdue count the first useful decision is a bulk one and
/// placing a hundred items one at a time is a punishment rather than a ritual.
public enum WeeklyPlanningEntry: String, Codable, Hashable, Sendable {
    case week
    case overdue
}

/// The source tray's filters.
public enum WeeklyWorkspaceLane: String, CaseIterable, Identifiable, Codable, Sendable {
    case overdue
    case inbox
    case anytime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overdue: "Overdue"
        case .inbox: "Inbox"
        case .anytime: "Anytime"
        }
    }

    public var systemImage: String {
        switch self {
        case .overdue: "clock.badge.exclamationmark"
        case .inbox: "tray"
        case .anytime: "circle.dashed"
        }
    }
}

// MARK: - Load

/// How full a day is, and how that is said out loud.
///
/// Load is deliberately a *bar*, not a number, in the ribbon: the number is
/// available in the day lane for anyone who wants it, but you plan a week by
/// comparing days to each other, which is a shape comparison. Everything here
/// stays pure so the shape and its spoken description can never disagree.
public enum WeeklyWorkspaceLoad {
    /// What an unestimated task is assumed to cost.
    ///
    /// Most tasks carry no estimate. Treating them as free would let a day
    /// accept twenty items and still read empty, which is the exact failure the
    /// capacity bar exists to prevent.
    public static let assumedTaskMinutes = 30

    /// Ceiling on the drawn bar. Load past this is still reported in text; the
    /// bar stops growing because a 400%-full day and a 900%-full day call for
    /// the same response.
    public static let maximumDrawnFraction: Double = 1.35

    /// Fraction of the day's usable time already spoken for.
    ///
    /// Returns `nil` when the day has no working hours at all — a Sunday, or a
    /// profile that was never configured. That is not a full day and not an
    /// empty one; it is a day we cannot speak about, and callers must render it
    /// differently rather than showing a confident empty bar.
    public static func fraction(plannedMinutes: Int, usableMinutes: Int) -> Double? {
        guard usableMinutes > 0 else { return nil }
        return Double(max(0, plannedMinutes)) / Double(usableMinutes)
    }

    public static func drawnFraction(plannedMinutes: Int, usableMinutes: Int) -> Double {
        guard let value = fraction(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes) else {
            return 0
        }
        return min(maximumDrawnFraction, value)
    }

    public static func isOverCapacity(plannedMinutes: Int, usableMinutes: Int) -> Bool {
        guard let value = fraction(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes) else {
            // No working hours, but work placed anyway. Worth flagging — it is
            // how a weekend quietly fills up — without calling it "over
            // capacity", which would imply a budget that does not exist.
            return false
        }
        return value > 1
    }

    public static func remainingMinutes(plannedMinutes: Int, usableMinutes: Int) -> Int {
        max(0, usableMinutes - max(0, plannedMinutes))
    }

    /// The non-color overload indicator.
    ///
    /// Every state the bar can be in has words, because the bar is a colour and
    /// a length and neither survives greyscale, Increase Contrast, or a
    /// screen-reader.
    public static func summary(
        plannedMinutes: Int,
        usableMinutes: Int,
        placedCount: Int
    ) -> String {
        let items = placedCount == 1 ? "1 item" : "\(placedCount) items"
        guard usableMinutes > 0 else {
            return placedCount == 0
                ? "No working hours"
                : "\(items), outside working hours"
        }
        guard placedCount > 0 else {
            return "Open · \(durationPhrase(usableMinutes)) free"
        }
        let remaining = remainingMinutes(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes)
        if isOverCapacity(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes) {
            let over = max(0, plannedMinutes - usableMinutes)
            return "\(items) · \(durationPhrase(over)) more than the day holds"
        }
        return "\(items) · \(durationPhrase(remaining)) still free"
    }

    /// Deliberately warm and non-clinical. An over-full day is information, not
    /// a failure, and the copy has to sound like it or people stop planning.
    public static func overloadHint(plannedMinutes: Int, usableMinutes: Int) -> String? {
        guard isOverCapacity(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes) else {
            return nil
        }
        return "Fuller than it looks"
    }

    public static func durationPhrase(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value == 0 { return "no time" }
        if value < 60 { return "\(value)m" }
        let hours = value / 60
        let rest = value % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

// MARK: - Horizon

/// How much of the week is presented as concrete.
///
/// Sunsama refuses to let you fill every day in advance, on the stated grounds
/// that it leaves people feeling crushed once they fall behind early in the
/// week. We keep per-day placement — it is Todoist's model and it is what the
/// ribbon is for — but only the near days are lanes you land in by default.
/// Falling behind on Tuesday then costs two days of re-planning, not seven.
public enum WeeklyPlanningHorizon {
    /// Today plus the next two days.
    public static let concreteDayCount = 3

    /// Days that get a full lane of their own, given the days on screen.
    ///
    /// Anchored on `today` rather than on the week start: on a Friday the
    /// concrete window is Friday–Sunday, not Monday–Wednesday, which is over
    /// and cannot be planned into.
    public static func concreteDays(
        in days: [PlanningDay],
        today: PlanningDay
    ) -> [PlanningDay] {
        let forward = days.filter { $0 >= today }
        guard forward.isEmpty == false else { return [] }
        return Array(forward.prefix(concreteDayCount))
    }

    public static func isConcrete(_ day: PlanningDay, in days: [PlanningDay], today: PlanningDay) -> Bool {
        concreteDays(in: days, today: today).contains(day)
    }

    /// Days beyond the concrete window that are still in this week. These
    /// collapse into one soft "Later this week" lane until opened.
    public static func softDays(in days: [PlanningDay], today: PlanningDay) -> [PlanningDay] {
        let concrete = Set(concreteDays(in: days, today: today))
        return days.filter { $0 >= today && concrete.contains($0) == false }
    }

    /// Days in this week that have already gone.
    ///
    /// Shown, dimmed, and still selectable: work placed on Monday is a fact you
    /// need to see on Wednesday, and hiding it is how a week silently loses
    /// items. Placement onto a past day is refused (`canReceivePlacement`).
    public static func pastDays(in days: [PlanningDay], today: PlanningDay) -> [PlanningDay] {
        days.filter { $0 < today }
    }

    /// A day can take new work only if it has not already happened.
    public static func canReceivePlacement(_ day: PlanningDay, today: PlanningDay) -> Bool {
        day >= today
    }
}

// MARK: - Spread

public struct WeeklySpreadCandidate: Equatable, Hashable, Sendable {
    public let taskID: UUID
    /// `nil` when the task carries no estimate; costed at
    /// `WeeklyWorkspaceLoad.assumedTaskMinutes`.
    public let estimatedMinutes: Int?

    public init(taskID: UUID, estimatedMinutes: Int?) {
        self.taskID = taskID
        self.estimatedMinutes = estimatedMinutes
    }

    public var cost: Int {
        guard let estimatedMinutes, estimatedMinutes > 0 else {
            return WeeklyWorkspaceLoad.assumedTaskMinutes
        }
        return estimatedMinutes
    }
}

public struct WeeklySpreadDay: Equatable, Hashable, Sendable {
    public let day: PlanningDay
    /// `nil` when the day's capacity is unknown — no working-hours profile.
    /// Those days fall back to a count cap rather than accepting everything.
    public let remainingMinutes: Int?
    public let placedCount: Int

    public init(day: PlanningDay, remainingMinutes: Int?, placedCount: Int) {
        self.day = day
        self.remainingMinutes = remainingMinutes
        self.placedCount = placedCount
    }
}

public struct WeeklySpreadPlacement: Equatable, Hashable, Sendable {
    public let taskID: UUID
    public let day: PlanningDay

    public init(taskID: UUID, day: PlanningDay) {
        self.taskID = taskID
        self.day = day
    }
}

public struct WeeklySpreadPlan: Equatable, Sendable {
    public let placements: [WeeklySpreadPlacement]
    public let unplacedTaskIDs: [UUID]

    public var isEmpty: Bool { placements.isEmpty }

    public init(placements: [WeeklySpreadPlacement], unplacedTaskIDs: [UUID]) {
        self.placements = placements
        self.unplacedTaskIDs = unplacedTaskIDs
    }

    /// What the receipt says afterwards. The unplaced count is stated plainly
    /// rather than hidden — the whole point of stopping at capacity is that the
    /// user finds out the week was full.
    public var summary: String {
        let placed = placements.count
        let placedPhrase = placed == 1 ? "1 task placed" : "\(placed) tasks placed"
        guard unplacedTaskIDs.isEmpty == false else { return placedPhrase }
        let left = unplacedTaskIDs.count
        return "\(placedPhrase) · \(left) left — the week filled up"
    }
}

/// Spreads a backlog across the days that still have room.
///
/// Greedy and earliest-first, which is what "bring it forward" means: the
/// oldest work lands on the soonest day that can hold it. Crucially it *stops*
/// rather than overfilling. An algorithm that empties the backlog by cramming
/// forty items into Thursday produces a week the user immediately abandons, and
/// it lies about capacity in a surface whose entire subject is capacity.
public enum WeeklyBacklogSpread {
    /// Cap used when a day's minute capacity is unknown.
    ///
    /// Without this, an unconfigured working-hours profile makes every day look
    /// infinite and the spread dumps the whole backlog onto the first day.
    public static let fallbackTasksPerDay = 5

    public static func plan(
        candidates: [WeeklySpreadCandidate],
        days: [WeeklySpreadDay],
        fallbackTasksPerDay: Int = fallbackTasksPerDay
    ) -> WeeklySpreadPlan {
        guard days.isEmpty == false else {
            return WeeklySpreadPlan(placements: [], unplacedTaskIDs: candidates.map(\.taskID))
        }

        var remainingByDay: [PlanningDay: Int?] = [:]
        var countByDay: [PlanningDay: Int] = [:]
        for day in days {
            remainingByDay[day.day] = day.remainingMinutes
            countByDay[day.day] = day.placedCount
        }

        var placements: [WeeklySpreadPlacement] = []
        var unplaced: [UUID] = []

        for candidate in candidates {
            let cost = candidate.cost
            var landed = false
            for day in days {
                let key = day.day
                if let minutes = remainingByDay[key] ?? nil {
                    guard minutes >= cost else { continue }
                    remainingByDay[key] = minutes - cost
                } else {
                    // Unknown capacity: fall back to a count cap so the day
                    // still fills up instead of absorbing everything.
                    let placed = countByDay[key] ?? 0
                    guard placed < fallbackTasksPerDay else { continue }
                }
                countByDay[key] = (countByDay[key] ?? 0) + 1
                placements.append(WeeklySpreadPlacement(taskID: candidate.taskID, day: key))
                landed = true
                break
            }
            if landed == false { unplaced.append(candidate.taskID) }
        }

        return WeeklySpreadPlan(placements: placements, unplacedTaskIDs: unplaced)
    }
}

// MARK: - Overdue briefing

/// What the overdue entry leads with.
public struct WeeklyOverdueBriefing: Equatable, Sendable {
    public let count: Int
    public let oldestDate: Date?

    public init(count: Int, oldestDate: Date?) {
        self.count = count
        self.oldestDate = oldestDate
    }

    public var isEmpty: Bool { count == 0 }

    public var headline: String {
        switch count {
        case 0: "Nothing is waiting"
        case 1: "1 task has been waiting"
        default: "\(count) tasks have been waiting"
        }
    }

    /// No scolding, no streak language, no "you missed". People with a hundred
    /// overdue items already know. Copy that judges them is why they stopped
    /// opening the list.
    public func detail(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let oldestDate, count > 0 else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: oldestDate), to: calendar.startOfDay(for: now)).day ?? 0
        guard days > 0 else { return nil }
        if days == 1 { return "The oldest is from yesterday." }
        if days < 14 { return "The oldest is from \(days) days ago." }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "d MMMM"
        return "The oldest is from \(formatter.string(from: oldestDate))."
    }
}

// MARK: - Meetings

/// The real RSVP, read from EventKit and never written back.
public enum CalendarParticipation: String, Codable, Hashable, Sendable {
    case accepted
    case tentative
    case declined
    case pending
    case unknown

    public var badge: String {
        switch self {
        case .accepted: "Accepted"
        case .tentative: "Tentative"
        case .declined: "Declined"
        case .pending: "No reply"
        case .unknown: ""
        }
    }
}

public enum CalendarEventState: String, Codable, Hashable, Sendable {
    case confirmed
    case tentative
    case cancelled
    case unspecified
}

/// LifeBoard's private, local choice about a meeting. Never sent anywhere.
public enum WeeklyMeetingIntent: String, Codable, Hashable, Sendable {
    /// Counted against the day's capacity.
    case attending
    /// Counted, but marked: the user has not actually decided, and reserving
    /// the time is the conservative error.
    case undecided
    /// Released from the day's capacity.
    case skipping

    public var title: String {
        switch self {
        case .attending: "In my week"
        case .undecided: "Undecided"
        case .skipping: "Skipping"
        }
    }
}

public enum WeeklyMeetingPolicy {
    /// The decision LifeBoard makes on the user's behalf, or `nil` when there
    /// is no decision to make at all.
    ///
    /// Returning `nil` matters as much as the intents do. A declined or
    /// cancelled meeting, or one marked free, is not a choice the user should
    /// be asked to confirm — surfacing it as a pending decision is how a week
    /// review turns into forty taps of "yes, still declined".
    public static func defaultIntent(
        participation: CalendarParticipation,
        state: CalendarEventState,
        isBusy: Bool
    ) -> WeeklyMeetingIntent? {
        if state == .cancelled { return nil }
        if participation == .declined { return nil }
        if isBusy == false { return nil }
        switch participation {
        case .accepted, .unknown:
            // `unknown` covers events with no attendee list at all — a personal
            // block, a holiday. Those are real time and default to attending.
            return .attending
        case .tentative, .pending:
            return .undecided
        case .declined:
            return nil
        }
    }

    /// The user's explicit choice wins over the derived default, but only where
    /// a default existed. An override on a cancelled event is stale and ignored.
    public static func resolvedIntent(
        participation: CalendarParticipation,
        state: CalendarEventState,
        isBusy: Bool,
        override: WeeklyMeetingIntent?
    ) -> WeeklyMeetingIntent? {
        guard let base = defaultIntent(participation: participation, state: state, isBusy: isBusy) else {
            return nil
        }
        return override ?? base
    }

    /// Attending and undecided both hold the time. Only an explicit skip gives
    /// it back — and giving it back *visibly*, in the same frame, is the entire
    /// reason the control exists. A skip that changes no number is bookkeeping.
    public static func consumesCapacity(_ intent: WeeklyMeetingIntent) -> Bool {
        intent != .skipping
    }

    /// Minutes a day's meetings actually claim, once decisions are applied.
    public static func claimedMinutes(
        _ meetings: [(minutes: Int, intent: WeeklyMeetingIntent?)]
    ) -> Int {
        meetings.reduce(0) { total, meeting in
            guard let intent = meeting.intent, consumesCapacity(intent) else { return total }
            return total + max(0, meeting.minutes)
        }
    }

    /// EventKit exposes attendee status as read-only, so LifeBoard must never
    /// present a control that looks like it answers an invitation. Where a real
    /// reply is still outstanding we hand off to Calendar instead.
    public static func offersCalendarHandoff(participation: CalendarParticipation) -> Bool {
        participation == .pending || participation == .tentative
    }
}

/// Stable identity for one occurrence of a calendar event.
///
/// `EKEvent.eventIdentifier` is shared by every occurrence of a recurring
/// series, so keying a decision on it alone makes "skip this Monday's standup"
/// silently skip all of them. The occurrence's start timestamp disambiguates
/// two instances on the same day as well as instances across different days.
public enum CalendarOccurrenceIdentity {
    public static func key(
        seriesID: String,
        occurrenceStart: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let day = PlanningDay(date: occurrenceStart, timeZone: timeZone, calendar: calendar)
        let occurrenceSecond = Int64(occurrenceStart.timeIntervalSince1970.rounded(.down))
        return "\(seriesID)#\(day.year)-\(day.month)-\(day.day)@\(occurrenceSecond)"
    }
}

/// One source of truth for the question "how much room does this day have?".
///
/// Capacity labels and time-box suggestions used to take separate paths. That
/// let a locally skipped meeting visibly release the load bar while continuing
/// to block every free-window suggestion. Carrying both values together makes
/// that disagreement impossible at the call site.
public struct WeeklyWorkspaceAvailability: Equatable, Sendable {
    public let day: PlanningDay
    public let skippedCommitmentIDs: Set<String>
    public let usableMinutes: Int
    public let plannedMinutes: Int
    public let freeWindows: [FreeWindow]

    public init(
        day: PlanningDay,
        skippedCommitmentIDs: Set<String>,
        usableMinutes: Int,
        plannedMinutes: Int,
        freeWindows: [FreeWindow]
    ) {
        self.day = day
        self.skippedCommitmentIDs = skippedCommitmentIDs
        self.usableMinutes = max(0, usableMinutes)
        self.plannedMinutes = max(0, plannedMinutes)
        self.freeWindows = freeWindows
    }

    public var remainingMinutes: Int {
        WeeklyWorkspaceLoad.remainingMinutes(
            plannedMinutes: plannedMinutes,
            usableMinutes: usableMinutes
        )
    }
}

/// A reversible local meeting decision. Plan mutations already have durable
/// receipts; this is their deliberately small UserDefaults counterpart.
public struct WeeklyMeetingDecisionReceipt: Equatable, Sendable {
    public let weekStart: Date
    public let occurrenceKey: String
    public let previousIntent: WeeklyMeetingIntent?
    public let newIntent: WeeklyMeetingIntent?
    public let titleSnapshot: String?

    public init(
        weekStart: Date,
        occurrenceKey: String,
        previousIntent: WeeklyMeetingIntent?,
        newIntent: WeeklyMeetingIntent?,
        titleSnapshot: String?
    ) {
        self.weekStart = weekStart
        self.occurrenceKey = occurrenceKey
        self.previousIntent = previousIntent
        self.newIntent = newIntent
        self.titleSnapshot = titleSnapshot
    }
}

public enum WeeklyWorkspaceUndoToken: Equatable, Sendable {
    case planMutation
    case meeting(WeeklyMeetingDecisionReceipt)
}

/// Semantic events keep choreography attached to meaning instead of a growing
/// pile of unrelated view booleans.
public enum WeeklyWorkspaceMotionEvent: Equatable, Sendable {
    case workspaceEntered
    case daySelected(PlanningDay)
    case taskPickedUp(UUID)
    case taskPlaced(UUID, PlanningDay)
    case taskPlacementFailed(UUID)
    case meetingDecided(String)
    case shelfChanged(WeeklyWorkspaceShelfDetent)
    case weekCommitted
}

public enum WeeklyWorkspaceShelfDetent: Int, CaseIterable, Equatable, Sendable {
    case compact
    case medium
    case expanded

    public var height: Double {
        switch self {
        case .compact: 176
        case .medium: 286
        case .expanded: 430
        }
    }
}

public struct WeeklyWorkspaceSessionSummary: Equatable, Sendable {
    public var tasksPlaced = 0
    public var tasksReleased = 0
    public var meetingDecisions = 0

    public init() {}

    public mutating func recordPlaced(_ count: Int) {
        tasksPlaced += max(0, count)
    }

    public mutating func recordReleased(_ count: Int) {
        tasksReleased += max(0, count)
    }

    public mutating func recordMeetingDecision() {
        meetingDecisions += 1
    }
}

public struct CalendarEventHandoff: Identifiable, Equatable, Sendable {
    public let eventID: String
    public let title: String

    public var id: String { eventID }

    public init(eventID: String, title: String) {
        self.eventID = eventID
        self.title = title
    }
}

public struct WeeklyTaskCreationOutcome: Equatable, Sendable {
    public let taskID: UUID
    public let wasPlaced: Bool

    public init(taskID: UUID, wasPlaced: Bool) {
        self.taskID = taskID
        self.wasPlaced = wasPlaced
    }
}

/// A tiny FIFO lock for planning writes. Optimistic UI remains immediate while
/// durable receipts are prepared and applied in the same order the user acted.
public actor WeeklyWorkspaceMutationCoordinator {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    public func release() {
        guard waiters.isEmpty == false else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

// MARK: - Intra-day order

/// The order of work inside one day.
///
/// Stored in `PlanningTaskMetadata.pinOrder`, which already exists for exactly
/// this. Ranks are kept dense and 0-based rather than sparse: gap-based ranking
/// buys cheap inserts, but this list is a handful of rows reordered by hand, and
/// a dense rank means the value is directly readable as "third thing today"
/// instead of an opaque 4096.
public enum WeeklyDayOrdering {
    /// `ids` with `moving` lifted out and dropped directly before `target`.
    ///
    /// A `nil` target means the end of the day. Dropping something onto itself,
    /// or onto a row it already sits before, is a no-op rather than an error —
    /// a fumbled drag should do nothing, not shuffle the list.
    public static func reordered(
        _ ids: [UUID],
        moving: UUID,
        before target: UUID?
    ) -> [UUID] {
        guard ids.contains(moving), moving != target else { return ids }
        var result = ids.filter { $0 != moving }
        guard let target else {
            result.append(moving)
            return result
        }
        guard let index = result.firstIndex(of: target) else { return ids }
        result.insert(moving, at: index)
        return result
    }

    /// Dense 0-based ranks in list order.
    public static func ranks(for ids: [UUID]) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for (index, id) in ids.enumerated() { result[id] = index }
        return result
    }

    /// Sorts by rank, then by a stable tiebreak.
    ///
    /// Tasks placed before ordering existed carry no `pinOrder` at all. They
    /// sort after ranked work rather than all collapsing to position zero,
    /// where they would silently jump above everything the user arranged.
    public static func sorted<T>(
        _ items: [T],
        rank: (T) -> Int?,
        tiebreak: (T) -> String
    ) -> [T] {
        items.enumerated().sorted { lhs, rhs in
            let left = rank(lhs.element)
            let right = rank(rhs.element)
            switch (left, right) {
            case let (l?, r?) where l != r:
                return l < r
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                let leftKey = tiebreak(lhs.element)
                let rightKey = tiebreak(rhs.element)
                return leftKey == rightKey ? lhs.offset < rhs.offset : leftKey < rightKey
            }
        }
        .map(\.element)
    }
}

// MARK: - Time boxing

/// Placing a task into a real gap in the day.
///
/// Optional by design. A day plan that is only a list is a complete plan; a
/// time-box is for the one or two things that need protecting. Auto-boxing
/// everything is what makes calendar-shaped planners collapse the first time a
/// morning runs long.
public enum WeeklyTimeBox {
    /// Shortest window that still fits, rather than the earliest.
    ///
    /// First-fit-by-time packs the morning and leaves an unusable scatter of
    /// gaps behind it. Best-fit keeps the long uninterrupted stretches intact,
    /// which are the only windows deep work can go in.
    public static func bestFitStart(
        windows: [FreeWindow],
        minutes: Int,
        after earliest: Date? = nil
    ) -> Date? {
        let required = TimeInterval(max(1, minutes) * 60)
        let usable = windows.compactMap { window -> (start: Date, duration: TimeInterval)? in
            let start = max(window.startAt, earliest ?? window.startAt)
            let available = window.endAt.timeIntervalSince(start)
            guard available >= required else { return nil }
            return (start, available)
        }
        return usable
            .sorted { lhs, rhs in
                lhs.duration == rhs.duration ? lhs.start < rhs.start : lhs.duration < rhs.duration
            }
            .first?
            .start
    }
}

// MARK: - Composer

/// One line typed into the day composer, after parsing.
public struct WeeklyComposerLine: Equatable, Sendable {
    public let title: String
    /// Where it should land. `nil` means the day the composer is pointed at.
    public let day: PlanningDay?
    public let estimatedMinutes: Int?

    public init(title: String, day: PlanningDay?, estimatedMinutes: Int?) {
        self.title = title
        self.day = day
        self.estimatedMinutes = estimatedMinutes
    }
}

public enum WeeklyComposerPlacement {
    /// Resolves a parsed capture into a placement.
    ///
    /// A recognised date phrase sets the **placement day**, not `dueDate`. That
    /// is the opposite of what the same parser means in a capture sheet, and it
    /// is deliberate: the field says "Add to Thursday", so a user who types
    /// "Friday" is saying where to put it, not declaring a deadline. Writing a
    /// due date from a word typed into a planning surface would invent
    /// commitments the user never made.
    ///
    /// A date already past is ignored rather than honoured — placement into the
    /// past is refused everywhere else in this surface, and a typo should not be
    /// the one path around that.
    public static func resolve(
        _ parsed: ParsedCapture,
        rawText: String,
        today: PlanningDay,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> WeeklyComposerLine? {
        let fallback = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = parsed.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        // A line that is *only* a date — "Friday" — parses to an empty title.
        // Creating a task called "Friday" is wrong, and creating an untitled one
        // is worse, so the raw text stands.
        let title = cleaned.isEmpty ? fallback : cleaned
        guard title.isEmpty == false else { return nil }

        var day: PlanningDay?
        if let dueDate = parsed.dueDate {
            let candidate = PlanningDay(date: dueDate, timeZone: timeZone, calendar: calendar)
            if candidate >= today { day = candidate }
        }

        let minutes = parsed.duration.map { Int($0 / 60) }.flatMap { $0 > 0 ? $0 : nil }
        return WeeklyComposerLine(title: title, day: day, estimatedMinutes: minutes)
    }
}

// MARK: - Copy

public enum WeeklyWorkspaceCopy {
    public static let title = "This week"

    public static func placementHint(dayName: String) -> String {
        "Add to \(dayName)"
    }

    public static func placedAnnouncement(title: String, dayName: String) -> String {
        "\(title) moved to \(dayName)"
    }

    public static func moveAction(dayName: String) -> String {
        "Move to \(dayName)"
    }

    public static let spreadAction = "Spread across this week"
    public static let bankruptcyAction = "Let them go to Someday"
    public static let manualAction = "I'll place them myself"

    /// Offered plainly, with no warning tone. At a hundred overdue items this
    /// is the correct answer, and every app that buries it gets abandonment
    /// instead of a cleared list.
    public static func bankruptcyConfirmation(count: Int) -> String {
        count == 1
            ? "Move 1 task to Someday. You can undo this."
            : "Move \(count) tasks to Someday. You can undo this."
    }

    public static func ritualSummary(placed: Int, released: Int, freeMinutes: Int) -> String {
        var parts: [String] = []
        parts.append(placed == 1 ? "1 placed" : "\(placed) placed")
        if released > 0 { parts.append("\(released) let go") }
        parts.append("\(WeeklyWorkspaceLoad.durationPhrase(freeMinutes)) of room left")
        return "Your week: " + parts.joined(separator: ", ") + "."
    }

    public static func closingSummary(
        placed: Int,
        tasksReleased: Int,
        meetingsReleased: Int,
        freeMinutes: Int
    ) -> String {
        var parts = [placed == 1 ? "1 task placed" : "\(placed) tasks placed"]
        if meetingsReleased > 0 {
            parts.append(
                meetingsReleased == 1
                    ? "1 meeting released"
                    : "\(meetingsReleased) meetings released"
            )
        }
        if tasksReleased > 0 {
            parts.append(tasksReleased == 1 ? "1 task moved to Someday" : "\(tasksReleased) tasks moved to Someday")
        }
        parts.append("about \(WeeklyWorkspaceLoad.durationPhrase(freeMinutes)) still open")
        return parts.joined(separator: " · ")
    }
}
