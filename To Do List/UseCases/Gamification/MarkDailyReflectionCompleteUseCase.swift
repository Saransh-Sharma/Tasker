import Foundation

public extension Notification.Name {
    static let dailyReflectionCompleted = Notification.Name("DailyReflectionCompleted")
}

/// Records a daily reflection completion and awards XP.
/// One reflection per day (idempotent via period key).
public final class MarkDailyReflectionCompleteUseCase {

    private let engine: GamificationEngine
    private let reflectionStore: DailyReflectionStoreProtocol
    private let calendar: Calendar

    public init(
        engine: GamificationEngine,
        reflectionStore: DailyReflectionStoreProtocol,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.engine = engine
        self.reflectionStore = reflectionStore
        self.calendar = calendar
    }

    public func isCompletedToday() -> Bool {
        isCompleted(on: Date())
    }

    public func isCompleted(on date: Date) -> Bool {
        reflectionStore.isCompleted(on: date)
    }

    public func execute(
        on reflectionDate: Date = Date(),
        payload: ReflectionPayload? = nil,
        completion: @escaping (Result<XPEventResult, Error>) -> Void
    ) {
        let normalizedDate = calendar.startOfDay(for: reflectionDate)
        if reflectionStore.isCompleted(on: normalizedDate) {
            do {
                _ = try reflectionStore.markCompleted(on: normalizedDate, completedAt: Date(), payload: payload)
                TaskerNotificationRuntime.orchestrator?.reconcile(reason: "daily_reflection_completed")
                NotificationCenter.default.post(
                    name: .dailyReflectionCompleted,
                    object: nil,
                    userInfo: ["dateKey": self.reflectionDateStamp(for: normalizedDate)]
                )
                completeWithoutXP(completion: completion)
            } catch {
                completion(.failure(error))
            }
            return
        }

        let context = XPEventContext(
            category: .reflection,
            source: .manual
        )
        engine.recordEvent(context: context) { result in
            switch result {
            case .success(let xpResult):
                do {
                    _ = try self.reflectionStore.markCompleted(
                        on: normalizedDate,
                        completedAt: Date(),
                        payload: payload
                    )
                } catch {
                    completion(.failure(error))
                    return
                }
                TaskerNotificationRuntime.orchestrator?.reconcile(reason: "daily_reflection_completed")
                NotificationCenter.default.post(
                    name: .dailyReflectionCompleted,
                    object: nil,
                    userInfo: ["dateKey": self.reflectionDateStamp(for: normalizedDate)]
                )
                completion(.success(xpResult))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func completeWithoutXP(completion: @escaping (Result<XPEventResult, Error>) -> Void) {
        engine.fetchCurrentProfile { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let profile):
                completion(
                    .success(
                        XPEventResult(
                            awardedXP: 0,
                            totalXP: profile.xpTotal,
                            level: profile.level,
                            previousLevel: profile.level,
                            currentStreak: profile.currentStreak,
                            didLevelUp: false,
                            dailyXPSoFar: 0,
                            dailyCap: XPCalculationEngine.dailyCap,
                            unlockedAchievements: [],
                            crossedMilestone: nil,
                            celebration: nil
                        )
                    )
                )
            }
        }
    }

    private func reflectionDateStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}
