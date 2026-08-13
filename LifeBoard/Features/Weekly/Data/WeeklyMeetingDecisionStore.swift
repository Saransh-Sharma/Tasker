import Foundation

/// The user's private Attend/Skip choices, keyed by week and occurrence.
///
/// Deliberately local and deliberately not Core Data. These are opinions about
/// one week's calendar, not records: they are worthless once the week is gone,
/// they must never leave the device, and they must never be mistaken for an
/// answer to the invitation itself. A CloudKit entity would give them a
/// lifetime and a reach they should not have, and a Core Data model version is
/// a one-way door opened for data whose whole nature is temporary.
///
/// If cross-device sync is ever wanted, the shape here — `(weekStart,
/// occurrenceKey) -> intent` — promotes to a record cleanly.
public final class WeeklyMeetingDecisionStore: @unchecked Sendable {
    private struct Entry: Codable, Hashable {
        var weekStart: String
        var occurrenceKey: String
        var intent: WeeklyMeetingIntent
        var titleSnapshot: String?
        var updatedAt: Date
    }

    public static let defaultsKey = "lifeOS.plan.weeklyMeetingDecisions.v1"
    /// Weeks kept before pruning. Two months of history is far more than any
    /// surface reads, and bounding it stops a decade of standups accumulating
    /// in UserDefaults.
    public static let retainedWeekCount = 8

    private let defaults: UserDefaults
    private let calendar: Calendar
    private var entries: [String: Entry]
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        } else {
            entries = [:]
        }
    }

    // MARK: Reading

    public func intent(weekStart: Date, occurrenceKey: String) -> WeeklyMeetingIntent? {
        lock.lock()
        defer { lock.unlock() }
        return entries[Self.storageKey(weekStart: weekStart, occurrenceKey: occurrenceKey, calendar: calendar)]?.intent
    }

    /// All overrides for one week, keyed by occurrence.
    public func intents(weekStart: Date) -> [String: WeeklyMeetingIntent] {
        lock.lock()
        defer { lock.unlock() }
        let prefix = Self.weekKey(weekStart, calendar: calendar)
        var result: [String: WeeklyMeetingIntent] = [:]
        for entry in entries.values where entry.weekStart == prefix {
            result[entry.occurrenceKey] = entry.intent
        }
        return result
    }

    // MARK: Writing

    /// Records an explicit choice. Writing the *derived default* back is
    /// pointless and actively harmful — it would freeze a decision that should
    /// keep tracking the real RSVP if the user later accepts in Calendar — so
    /// callers pass `nil` to clear instead.
    @discardableResult
    public func setIntent(
        _ intent: WeeklyMeetingIntent?,
        weekStart: Date,
        occurrenceKey: String,
        titleSnapshot: String? = nil,
        now: Date = Date()
    ) -> WeeklyMeetingDecisionReceipt {
        lock.lock()
        let key = Self.storageKey(weekStart: weekStart, occurrenceKey: occurrenceKey, calendar: calendar)
        let previous = entries[key]?.intent
        if let intent {
            entries[key] = Entry(
                weekStart: Self.weekKey(weekStart, calendar: calendar),
                occurrenceKey: occurrenceKey,
                intent: intent,
                titleSnapshot: titleSnapshot,
                updatedAt: now
            )
        } else {
            entries.removeValue(forKey: key)
        }
        let snapshot = entries
        lock.unlock()
        persist(snapshot)
        return WeeklyMeetingDecisionReceipt(
            weekStart: weekStart,
            occurrenceKey: occurrenceKey,
            previousIntent: previous,
            newIntent: intent,
            titleSnapshot: titleSnapshot
        )
    }

    public func restore(_ receipt: WeeklyMeetingDecisionReceipt, now: Date = Date()) {
        setIntent(
            receipt.previousIntent,
            weekStart: receipt.weekStart,
            occurrenceKey: receipt.occurrenceKey,
            titleSnapshot: receipt.titleSnapshot,
            now: now
        )
    }

    public func clearWeek(_ weekStart: Date) {
        lock.lock()
        let prefix = Self.weekKey(weekStart, calendar: calendar)
        entries = entries.filter { $0.value.weekStart != prefix }
        let snapshot = entries
        lock.unlock()
        persist(snapshot)
    }

    /// Drops decisions for weeks older than the retention window.
    ///
    /// Called on load rather than on a timer: the only moment this data matters
    /// is when a week is opened, so that is the only moment it needs trimming.
    public func prune(now: Date = Date()) {
        guard let cutoff = calendar.date(
            byAdding: .weekOfYear,
            value: -Self.retainedWeekCount,
            to: now
        ) else { return }
        let cutoffKey = Self.weekKey(cutoff, calendar: calendar)
        lock.lock()
        entries = entries.filter { $0.value.weekStart >= cutoffKey }
        let snapshot = entries
        lock.unlock()
        persist(snapshot)
    }

    // MARK: Keys

    /// ISO-ordered so string comparison is chronological, which is what makes
    /// `prune` a filter rather than a date parse per entry.
    static func weekKey(_ date: Date, calendar: Calendar) -> String {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func storageKey(weekStart: Date, occurrenceKey: String, calendar: Calendar) -> String {
        "\(weekKey(weekStart, calendar: calendar))|\(occurrenceKey)"
    }

    private func persist(_ snapshot: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
