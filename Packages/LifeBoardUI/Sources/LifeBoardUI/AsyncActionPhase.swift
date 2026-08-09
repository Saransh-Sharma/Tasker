import Foundation

// The state an async, receipted action can be in. A primitive vocabulary —
// `CommitControl` and `AsyncActionControl` both speak it.
public struct AsyncActionFailure: Error, Equatable, Sendable {
    public enum Recovery: String, Equatable, Sendable { case retry, edit, discard, reopen }

    public let message: String
    public let recovery: Recovery

    public init(message: String, recovery: Recovery) {
        self.message = message
        self.recovery = recovery
    }
}

public enum AsyncActionPhase<Receipt: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case running(progress: Double?)
    case success(receipt: Receipt)
    case recoverableFailure(AsyncActionFailure)
    case cancelled
}
