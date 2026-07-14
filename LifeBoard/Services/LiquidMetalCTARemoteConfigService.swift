import Foundation

/// Compatibility facade for the former network-backed flag service.
/// The allow-list is device-local in Phase 1.
@MainActor
final class LiquidMetalCTARemoteConfigService {
    static let shared = LiquidMetalCTARemoteConfigService()

    private init() {}

    func refreshIfAvailable(reason: String) {
        logDebug(
            event: "decorative_cta_local_flags_active",
            message: "Using device-local typed feature flags",
            fields: ["reason": reason]
        )
    }
}
