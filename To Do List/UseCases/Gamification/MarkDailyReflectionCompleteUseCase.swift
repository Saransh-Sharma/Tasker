import Foundation

public extension Notification.Name {
    static let dailyReflectionCompleted = Notification.Name("DailyReflectionCompleted")
}

/// Records a daily reflection completion and awards XP.
/// One reflection per day (idempotent via period key).
public final class MarkDailyReflectionCompleteUseCase {

    private let engine: GamificationEngine
    private static let reflectionCompletionDateKeysDefaultsKey = "gamification.reflection.completedDateKeys"

    public init(engine: GamificationEngine) {
        self.engine = engine
    }

    public func isCompletedToday() -> Bool {
        let dateKey = reflectionDateStamp(for: Date())
        let dateKeys = UserDefaults.standard.stringArray(forKey: Self.reflectionCompletionDateKeysDefaultsKey) ?? []
        return dateKeys.contains(dateKey)
    }

    /// Marks today's reflection as complete and awards XP.
    public func execute(completion: @escaping (Result<XPEventResult, Error>) -> Void) {
        let context = XPEventContext(
            category: .reflection,
            source: .manual
        )
        engine.recordEvent(context: context) { result in
            switch result {
            case .success(let xpResult):
                self.markReflectionCompletedToday()
                TaskerNotificationRuntime.orchestrator?.reconcile(reason: "daily_reflection_completed")
                NotificationCenter.default.post(
                    name: .dailyReflectionCompleted,
                    object: nil,
                    userInfo: ["dateKey": self.reflectionDateStamp(for: Date())]
                )
                completion(.success(xpResult))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func markReflectionCompletedToday() {
        let dateKey = reflectionDateStamp(for: Date())
        let defaults = UserDefaults.standard
        var dateKeys = defaults.stringArray(forKey: Self.reflectionCompletionDateKeysDefaultsKey) ?? []
        if dateKeys.contains(dateKey) == false {
            dateKeys.append(dateKey)
        }
        // Keep a rolling window for reconciliation checks.
        dateKeys = Array(Array(Set(dateKeys)).sorted().suffix(30))
        defaults.set(dateKeys, forKey: Self.reflectionCompletionDateKeysDefaultsKey)
    }

    private func reflectionDateStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        return formatter.string(from: date)
    }
}
