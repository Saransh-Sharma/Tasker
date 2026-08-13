import Foundation

final class DayCompassSnoozeStore: @unchecked Sendable {
    static let storageKey = "home.dayCompass.snoozedUntil.v1"

    private static let legacyNeedsReplanDismissedDayKey = "home.needsReplan.dismissedDayKey.v1"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load(
        now: Date = Date(),
        calendar: Calendar = .current,
        resumeDismissedForSession: Bool = false
    ) -> DayCompassSnoozeSnapshot {
        migrateLegacyNeedsReplanDismissalIfNeeded(now: now, calendar: calendar)

        // Expired entries are filtered in-memory only; pruning persists on the
        // next write so load stays side-effect-free on the hot resolve path.
        let payload = readPayload()
        let snoozedUntil = payload.snoozedUntil.compactMapValues { until in
            until > now ? until : nil
        }
        return DayCompassSnoozeSnapshot(
            snoozedUntil: snoozedUntil,
            resumeDismissedForSession: resumeDismissedForSession
        )
    }

    func snoozeUntilEndOfDay(
        flow: DayCompassFlow,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(24 * 60 * 60)
        snooze(flow: flow, until: startOfTomorrow)
        if flow == .replan {
            userDefaults.set(Self.dayKey(for: now, calendar: calendar), forKey: Self.legacyNeedsReplanDismissedDayKey)
        }
    }

    func snooze(flow: DayCompassFlow, until date: Date, now: Date = Date()) {
        var payload = readPayload()
        payload.snoozedUntil = payload.snoozedUntil.compactMapValues { until in
            until > now ? until : nil
        }
        payload.snoozedUntil[flow] = date
        writePayload(payload)
    }

    func clear(flow: DayCompassFlow) {
        var payload = readPayload()
        payload.snoozedUntil.removeValue(forKey: flow)
        writePayload(payload)
    }

    func clearAll() {
        userDefaults.removeObject(forKey: Self.storageKey)
    }

    private func migrateLegacyNeedsReplanDismissalIfNeeded(now: Date, calendar: Calendar) {
        let todayKey = Self.dayKey(for: now, calendar: calendar)
        guard userDefaults.string(forKey: Self.legacyNeedsReplanDismissedDayKey) == todayKey else {
            return
        }

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 60 * 60)
        var payload = readPayload()
        if (payload.snoozedUntil[.replan] ?? .distantPast) < endOfDay {
            payload.snoozedUntil[.replan] = endOfDay
            writePayload(payload)
        }
        userDefaults.removeObject(forKey: Self.legacyNeedsReplanDismissedDayKey)
    }

    private func readPayload() -> DayCompassSnoozePayload {
        guard let data = userDefaults.data(forKey: Self.storageKey),
              let payload = try? JSONDecoder().decode(DayCompassSnoozePayload.self, from: data) else {
            return DayCompassSnoozePayload()
        }
        return payload
    }

    private func writePayload(_ payload: DayCompassSnoozePayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private struct DayCompassSnoozePayload: Codable, Equatable {
    var snoozedUntil: [DayCompassFlow: Date] = [:]
}
