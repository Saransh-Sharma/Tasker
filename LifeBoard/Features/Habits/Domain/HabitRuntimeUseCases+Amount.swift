import Foundation

/// A change to how much of a habit's amount has been done today.
public enum HabitAmountChange: Equatable, Sendable {
    /// Add (or, with a negative value, take away) this much.
    case add(Double)
    /// Replace the logged amount with exactly this much.
    case set(Double)
}

public struct HabitAmountReceipt: Equatable, Sendable {
    public let habitID: UUID
    public let occurrenceID: UUID
    public let before: Double
    public let after: Double
    public let target: Double
    /// This change took the occurrence to its target, so it was completed.
    public let resolvedNow: Bool
    /// This change took a completed occurrence back below its target.
    public let unresolvedNow: Bool
}

/// The pure rules behind logging an amount. No persistence, so every edge —
/// crossing the target in either direction, clamping, step size — is tested.
public enum HabitAmountRule {
    /// The amount that completes the day, in the unit progress is recorded in:
    /// the quantity, the seconds, or the count. Nil for habits without an
    /// amount (check-ins and avoidance), which never take this path, and for
    /// weekly or monthly quotas, which a single day's occurrence cannot hold.
    public static func target(for target: HabitTarget) -> Double? {
        switch target {
        case .binary, .avoidance:
            return nil
        case let .quantitative(value, _):
            return value > 0 ? value : nil
        case let .quota(count, period):
            return period == .day && count > 0 ? Double(count) : nil
        case let .timed(seconds):
            return seconds > 0 ? seconds : nil
        }
    }

    /// One tap's worth. Chosen so a target is reached in a handful of taps
    /// without overshooting small ones.
    public static func step(for target: HabitTarget) -> Double {
        switch target {
        case .binary, .avoidance:
            return 1
        case .quota:
            return 1
        case .timed(let seconds):
            return seconds <= 10 * 60 ? 60 : 5 * 60
        case let .quantitative(value, unit):
            let normalizedUnit = unit.lowercased()
            if normalizedUnit == "ml" { return value >= 1_000 ? 250 : 100 }
            if value <= 20 { return 1 }
            // About ten taps to the target, rounded to a friendly number.
            let raw = value / 10
            let magnitude = pow(10, floor(log10(raw)))
            let friendly = [1.0, 2.0, 2.5, 5.0, 10.0].first { raw <= $0 * magnitude } ?? 10
            return friendly * magnitude
        }
    }

    /// The new amount: never below zero, never beyond ten times the target
    /// (a guard against a runaway scrub, not a judgement about effort).
    public static func apply(_ change: HabitAmountChange, to current: Double, target: Double) -> Double {
        let next: Double
        switch change {
        case .add(let delta): next = current + delta
        case .set(let value): next = value
        }
        guard next.isFinite else { return current }
        return min(max(0, next), target * 10)
    }

    public static func transition(before: Double, after: Double, target: Double, isCompleted: Bool) -> (resolve: Bool, unresolve: Bool) {
        let reaches = after >= target
        return (resolve: reaches && isCompleted == false, unresolve: reaches == false && isCompleted)
    }
}

/// Logs progress toward a habit's amount target ("3 of 8 glasses").
///
/// It stores the amount on today's occurrence, and when that amount crosses
/// the target it goes through the same resolve and reset paths a check-in
/// does — so streaks, XP (awarded once, on the crossing), reminders, and the
/// habit mutation notification all stay on one road.
public final class LogHabitAmountUseCase: @unchecked Sendable {
    private let habitRepository: HabitRepositoryProtocol
    fileprivate let occurrenceRepository: OccurrenceRepositoryProtocol
    private let resolveUseCase: ResolveHabitOccurrenceUseCase
    private let resetUseCase: ResetHabitOccurrenceUseCase

    public init(
        habitRepository: HabitRepositoryProtocol,
        occurrenceRepository: OccurrenceRepositoryProtocol,
        resolveUseCase: ResolveHabitOccurrenceUseCase,
        resetUseCase: ResetHabitOccurrenceUseCase
    ) {
        self.habitRepository = habitRepository
        self.occurrenceRepository = occurrenceRepository
        self.resolveUseCase = resolveUseCase
        self.resetUseCase = resetUseCase
    }

    public func execute(
        habitID: UUID,
        occurrenceID: UUID? = nil,
        change: HabitAmountChange,
        on date: Date = Date(),
        mutationContext: HabitMutationContext? = nil
    ) async throws -> HabitAmountReceipt {
        let habit = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HabitDefinitionRecord?, Error>) in
            habitRepository.fetchByID(id: habitID) { continuation.resume(with: $0) }
        }
        guard let habit else { throw HabitRuntimeError.habitNotFound }
        let habitTarget = habit.targetConfig?.effectiveTarget ?? .binary
        guard let target = HabitAmountRule.target(for: habitTarget) else {
            throw HabitAmountError.habitHasNoAmountTarget
        }
        let resolvedID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UUID, Error>) in
            resolveUseCase.resolveOccurrenceID(habit: habit, occurrenceID: occurrenceID, date: date) { continuation.resume(with: $0) }
        }
        let occurrence = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OccurrenceDefinition?, Error>) in
            occurrenceRepository.fetchByID(id: resolvedID) { continuation.resume(with: $0) }
        }
        guard let occurrence else { throw HabitRuntimeError.occurrenceNotFound }

        let before = occurrence.recordedValue ?? 0
        let after = HabitAmountRule.apply(change, to: before, target: target)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            occurrenceRepository.setRecordedValue(occurrenceID: resolvedID, value: after, updatedAt: date) { continuation.resume(with: $0) }
        }

        let step = HabitAmountRule.transition(
            before: before,
            after: after,
            target: target,
            isCompleted: occurrence.state == .completed
        )
        if step.resolve {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                resolveUseCase.execute(habitID: habitID, occurrenceID: resolvedID, action: .complete, on: date, mutationContext: mutationContext) {
                    continuation.resume(with: $0)
                }
            }
        } else if step.unresolve {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                resetUseCase.execute(habitID: habitID, occurrenceID: resolvedID, on: date, mutationContext: mutationContext) {
                    continuation.resume(with: $0)
                }
            }
        } else {
            // Progress without a crossing still changes what Home and the board
            // show, so it announces itself the same way.
            TaskNotificationDispatcher.postOnMain(
                name: .homeHabitMutation,
                object: HomeHabitMutationNotification(habitID: habitID, context: mutationContext)
            )
        }
        return HabitAmountReceipt(
            habitID: habitID,
            occurrenceID: resolvedID,
            before: before,
            after: after,
            target: target,
            resolvedNow: step.resolve,
            unresolvedNow: step.unresolve
        )
    }
}

extension LogHabitAmountUseCase {
    /// Today's logged amount for a habit, without creating an occurrence just to
    /// read it. Zero when nothing is logged yet.
    public func currentAmount(habitID: UUID, on date: Date = Date()) async -> Double {
        let occurrence = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OccurrenceDefinition?, Error>) in
            occurrenceRepository.fetchLatestForHabit(habitID: habitID, on: date) { continuation.resume(with: $0) }
        }
        return occurrence?.recordedValue ?? 0
    }
}

public enum HabitAmountError: Error, Equatable {
    case habitHasNoAmountTarget
}
