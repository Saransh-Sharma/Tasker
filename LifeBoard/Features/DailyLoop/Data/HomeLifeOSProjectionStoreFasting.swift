import Foundation

extension HomeLifeOSProjectionStore {
    @discardableResult
    func startFast(
        targetDuration: TimeInterval?,
        reminderOffsets: [TimeInterval] = [],
        at date: Date = HomeReferenceClock.now
    ) async -> Bool {
        guard let fastingTimerStore else {
            fastingMutationError = String(localized: "Couldn’t update fast.")
            return false
        }
        do {
            _ = try await fastingTimerStore.start(
                targetDuration: targetDuration,
                reminderOffsets: reminderOffsets,
                at: date
            )
            fastingMutationError = nil
            mutationRevision &+= 1
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func endActiveFast(at date: Date = HomeReferenceClock.now) async -> Bool {
        guard let fastingTimerStore else {
            fastingMutationError = String(localized: "Couldn’t update fast.")
            return false
        }
        do {
            let undoSession = activeFast
            _ = try await fastingTimerStore.finish(at: date)
            fastEndUndoSession = undoSession
            fastingMutationError = nil
            mutationRevision &+= 1
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func undoLastFastEnd() async -> Bool {
        guard let fastingTimerStore, let session = fastEndUndoSession else { return false }
        do {
            _ = try await fastingTimerStore.correct(
                sessionID: session.id,
                startedAt: session.startedAt,
                endedAt: nil,
                targetDuration: session.targetDuration,
                note: session.note
            )
            fastEndUndoSession = nil
            fastingMutationError = nil
            mutationRevision &+= 1
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }
}
