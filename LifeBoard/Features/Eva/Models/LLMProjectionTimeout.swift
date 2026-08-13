import Foundation

enum LLMProjectionTimeout {
    private enum ProjectionResult {
        case payload(String)
        case timeout
        case cancelled
    }

    private final class RaceGate: @unchecked Sendable {
        private let lock = NSLock()
        private var didResume = false

        func resume(
            _ result: ProjectionResult,
            continuation: CheckedContinuation<ProjectionResult, Never>
        ) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard didResume == false else { return false }
            didResume = true
            continuation.resume(returning: result)
            return true
        }
    }

    static func execute(
        timeoutMs: UInt64,
        onTimeout: @escaping @Sendable () async -> Void = {},
        operation: @escaping @Sendable () async -> String
    ) async -> (payload: String, timedOut: Bool) {
        let operationTask = Task {
            guard !Task.isCancelled else { return ProjectionResult.cancelled }
            return ProjectionResult.payload(await operation())
        }

        let gate = RaceGate()
        let result = await withCheckedContinuation { continuation in
            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                    if gate.resume(.timeout, continuation: continuation) {
                        operationTask.cancel()
                        await onTimeout()
                    }
                } catch is CancellationError {
                    _ = gate.resume(.cancelled, continuation: continuation)
                } catch {
                    if gate.resume(.timeout, continuation: continuation) {
                        operationTask.cancel()
                        await onTimeout()
                    }
                }
            }

            Task {
                let operationResult = await operationTask.value
                if gate.resume(operationResult, continuation: continuation) {
                    timeoutTask.cancel()
                }
            }
        }

        switch result {
        case .payload(let payload):
            return (payload, false)
        case .timeout:
            return ("{}", true)
        case .cancelled:
            return ("{}", false)
        }
    }
}
