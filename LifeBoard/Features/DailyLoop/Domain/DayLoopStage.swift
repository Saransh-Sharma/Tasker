import Foundation

/// Where the day is in the loop.
///
/// The loop's five beats, named once so Home, the ritual and the notification
/// router can agree. Before this existed, "is it time to close?" was answered
/// independently in three places by three different rules — a time-of-day
/// window on Home, a fixed 21:00 schedule in the notification orchestrator, and
/// a `UserDefaults` reflection flag the ritual never wrote. They disagreed.
public enum DayLoopStage: String, CaseIterable, Hashable, Sendable {
    /// The day has not been committed to yet.
    case commit
    /// The day is underway.
    case act
    /// The plan has drifted far enough to be worth repairing.
    case repair
    /// The day is ready to be put down.
    case close
    /// The day is closed. Nothing further is being asked.
    case rest
}

/// Resolves the stage from loop state and the clock, in that order of priority.
///
/// Pure and input-driven: the window predicates come in as booleans rather than
/// being computed here, so this reuses `DayCompassService`'s already-tested hour
/// rules without depending on it, and stays trivially testable.
public enum DayLoopStageResolver {
    /// - Parameters:
    ///   - closedToday: an *applied* day-close receipt exists for today. Undo
    ///     flips this back, which is why the ritual reopens after an undo.
    ///   - openedToday: an applied day-open receipt exists for today.
    ///   - isMorningWindow / isEveningWindow: from `DayCompassService`.
    ///   - driftCount: unstarted commitments whose planned time has passed.
    ///   - suppressesRepair: Low Energy never surfaces drift.
    public static func resolve(
        closedToday: Bool,
        openedToday: Bool,
        isMorningWindow: Bool,
        isEveningWindow: Bool,
        driftCount: Int = 0,
        suppressesRepair: Bool = false
    ) -> DayLoopStage {
        // Loop state dominates the clock. A day closed at 15:00 is closed; the
        // old rule kept offering the ritual until midnight because it only ever
        // asked what time it was.
        if closedToday { return .rest }

        // Evening beats repair: once the day is ending, repairing its plan is
        // moot — the close will carry whatever is left anyway.
        if isEveningWindow { return .close }

        // Only in the morning, and only before the day has been committed to.
        if isMorningWindow, openedToday == false { return .commit }

        if driftCount > 0, suppressesRepair == false { return .repair }

        return .act
    }
}

/// A local, per-device note of which days have been closed.
///
/// **Not the source of truth.** The applied `planning.scenario.dayClose.*`
/// receipt is; this exists only so the notification orchestrator — which is
/// synchronous and callback-based — can suppress the evening nudge without
/// threading an async Core Data read through its reconcile pass.
///
/// Per-device is correct here rather than a limitation: local notifications are
/// scheduled per device, so a day closed on the iPad should not silence the
/// phone's nudge for a day this phone still shows as open.
///
/// Retired reflection completion preferences never participate in ritual state.
/// The single configured nudge consults this local closure log before scheduling.
/// `@unchecked Sendable` for the same reason as `DayCompassSnoozeStore`:
/// `UserDefaults` is not `Sendable` under Swift 6's complete checking, but it is
/// internally thread-safe and every access here is a single atomic read or write.
public final class DayLoopClosureLog: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "lifeOS.dayLoop.closedStamps.v1"
    /// Bounded so the list cannot grow without limit; the orchestrator only
    /// ever asks about today and the next two days.
    private let retainedDays = 14

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func stamp(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public func closedStamps() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    public func markClosed(_ date: Date, calendar: Calendar = .current) {
        var stamps = closedStamps()
        stamps.insert(Self.stamp(for: date, calendar: calendar))
        write(stamps, calendar: calendar)
    }

    /// Undo reopens the day, so the nudge must come back with it.
    public func clearClosed(_ date: Date, calendar: Calendar = .current) {
        var stamps = closedStamps()
        stamps.remove(Self.stamp(for: date, calendar: calendar))
        write(stamps, calendar: calendar)
    }

    private func write(_ stamps: Set<String>, calendar: Calendar) {
        let cutoff = calendar.date(byAdding: .day, value: -retainedDays, to: Date())
        let floor = cutoff.map { Self.stamp(for: $0, calendar: calendar) } ?? ""
        // Stamps are zero-padded `yyyyMMdd`, so lexicographic order is date
        // order and pruning needs no parsing.
        defaults.set(stamps.filter { $0 >= floor }.sorted(), forKey: key)
    }
}

public extension DayLoopStage {
    /// Whether the day can still be put down from here.
    ///
    /// True for every stage except `.rest`, which is the whole point: the close
    /// used to be reachable only between 18:00 and midnight, so a day finished
    /// early — or a day whose owner works nights — had no door at all.
    var offersClose: Bool { self != .rest }

    /// Whether this stage is asking the person for something.
    ///
    /// `.rest` deliberately asks for nothing. Closing a day must not open a new
    /// obligation.
    var isDemanding: Bool {
        switch self {
        case .commit, .repair, .close: true
        case .act, .rest: false
        }
    }
}
