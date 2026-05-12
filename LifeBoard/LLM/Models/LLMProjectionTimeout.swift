import Foundation

enum LLMProjectionTimeout {
    static func execute(
        timeoutMs: UInt64,
        operation: @escaping @Sendable () async -> String
    ) async -> (payload: String, timedOut: Bool) {
        enum ProjectionResult {
            case payload(String)
            case timeout
            case cancelled
        }

        let result = await withTaskGroup(of: ProjectionResult.self) { group in
            group.addTask {
                guard !Task.isCancelled else { return .cancelled }
                return .payload(await operation())
            }
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: timeoutMs * 1_000_000)
                    return .timeout
                } catch is CancellationError {
                    return .cancelled
                } catch {
                    return .timeout
                }
            }
            var first = await group.next() ?? .timeout
            if case .cancelled = first {
                first = await group.next() ?? .timeout
            }
            group.cancelAll()
            return first
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
