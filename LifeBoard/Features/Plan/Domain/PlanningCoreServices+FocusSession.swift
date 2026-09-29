import Foundation

extension FocusSessionCommands {
    func receipt(for session: FocusSessionV2, id: UUID) throws -> FocusExecutionReceipt {
        guard let endedAt = session.endedAt, let outcome = session.outcome else {
            throw FocusSessionCommandError.sessionAlreadyEnded(session.id)
        }
        return .init(
            id: id,
            sessionID: session.id,
            taskID: session.taskID,
            timeBlockID: session.timeBlockID,
            targetDuration: session.targetDuration,
            actualFocusedDuration: session.focusedDuration(at: endedAt),
            interruptionCount: session.interruptionCount,
            outcome: outcome,
            energyAfter: session.energyAfter,
            reflection: session.reflection,
            startedAt: session.startedAt,
            endedAt: endedAt
        )
    }

    /// The stated intention wins, then the task's title, then the generic
    /// label; the same precedence `FocusSurfaceCommitmentSection` uses on screen.
    static func presentationTitle(
        for session: FocusSessionV2,
        companion: FocusSessionCompanion?,
        resolver: TitleResolver?
    ) async -> String {
        if let intention = companion?.intention.trimmingCharacters(in: .whitespacesAndNewlines), intention.isEmpty == false {
            return intention
        }
        if let resolved = await resolver?(session)?.trimmingCharacters(in: .whitespacesAndNewlines), resolved.isEmpty == false {
            return resolved
        }
        return "Focus session"
    }
}

/// XP is a downstream projection of a durable canonical completion receipt.
/// Gamification's existing session-key idempotency makes replay safe.
public final class FocusCompletionXPSubscriber: @unchecked Sendable {
    private var observationTask: Task<Void, Never>?

    public init(
        events: FocusCompletionReceiptEventStream,
        engine: GamificationService
    ) {
        observationTask = Task {
            let stream = await events.stream()
            for await receipt in stream {
                let context = XPEventContext(
                    category: .focus,
                    source: .manual,
                    taskID: receipt.taskID,
                    sessionID: receipt.sessionID,
                    completedAt: receipt.endedAt,
                    focusDurationSeconds: Int(receipt.actualFocusedDuration.rounded())
                )
                _ = await withCheckedContinuation { continuation in
                    engine.recordEvent(context: context) { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }

    deinit {
        observationTask?.cancel()
    }
}
