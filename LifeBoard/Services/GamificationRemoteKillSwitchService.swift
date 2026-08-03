import Foundation

/// Compatibility facade retained while call sites migrate to typed local flags.
/// Phase 1 deliberately performs no network fetches or remote configuration.
@MainActor
final class GamificationRemoteKillSwitchService {
    static let shared = GamificationRemoteKillSwitchService()

    private init() {}

    func refreshIfAvailable(reason: String) {
        logDebug(
            event: "gamification_local_flags_active",
            message: "Using device-local typed feature flags",
            fields: ["reason": reason]
        )
    }
}
