import Foundation

actor LLMGenerationSlot {
    private var isOccupied = false
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

    func acquire() async throws -> LLMGenerationSlotLease {
        if _Concurrency.Task.isCancelled {
            throw CancellationError()
        }
        if isOccupied == false {
            isOccupied = true
            return LLMGenerationSlotLease(slot: self)
        }
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append((waiterID, continuation))
            }
        } onCancel: {
            _Concurrency.Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
        if _Concurrency.Task.isCancelled {
            release()
            throw CancellationError()
        }
        return LLMGenerationSlotLease(slot: self)
    }

    fileprivate func release() {
        if waiters.isEmpty {
            isOccupied = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}

struct LLMGenerationSlotLease: Sendable {
    fileprivate let slot: LLMGenerationSlot

    func release() async {
        await slot.release()
    }
}
