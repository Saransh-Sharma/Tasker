import Foundation

public actor AssistantCommandExecutor {
    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    func enqueue<T>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }

    private func acquire() async {
        if isRunning == false {
            isRunning = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        if waiters.isEmpty {
            isRunning = false
            return
        }
        let continuation = waiters.removeFirst()
        continuation.resume()
    }
}
