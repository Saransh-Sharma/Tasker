import Foundation

actor ChatContextInjectionTracker {
    struct CachedContext {
        let payload: String
        let querySignature: String
        let generatedAt: Date
        let usedTimeoutFallback: Bool
    }

    private var cacheByThreadID: [UUID: CachedContext] = [:]

    func cachedContext(
        for threadID: UUID,
        querySignature: String,
        now: Date,
        throttleMs: UInt64
    ) -> CachedContext? {
        guard throttleMs > 0, let cached = cacheByThreadID[threadID] else {
            return nil
        }
        guard cached.querySignature == querySignature else {
            return nil
        }
        let ageMs = now.timeIntervalSince(cached.generatedAt) * 1_000
        return ageMs < Double(throttleMs) ? cached : nil
    }

    func store(
        threadID: UUID,
        querySignature: String,
        payload: String,
        usedTimeoutFallback: Bool,
        generatedAt: Date
    ) {
        cacheByThreadID[threadID] = CachedContext(
            payload: payload,
            querySignature: querySignature,
            generatedAt: generatedAt,
            usedTimeoutFallback: usedTimeoutFallback
        )
    }

    func clear(threadID: UUID) {
        cacheByThreadID.removeValue(forKey: threadID)
    }
}

enum ChatContextInjectionPolicy {
    case perTurn(throttleMs: UInt64)

    var throttleMs: UInt64 {
        switch self {
        case .perTurn(let throttleMs):
            return throttleMs
        }
    }

    var rawValue: String {
        switch self {
        case .perTurn:
            return "per_turn"
        }
    }
}
