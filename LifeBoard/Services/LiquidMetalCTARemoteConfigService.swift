import Foundation

#if canImport(FirebaseRemoteConfig)
@preconcurrency import FirebaseRemoteConfig
#endif

/// Syncs the liquid-metal CTA rollback allow-list from Firebase Remote Config.
/// User preference is stored separately and defaults off.
@MainActor
final class LiquidMetalCTARemoteConfigService {
    static let shared = LiquidMetalCTARemoteConfigService()

    private init() {}

    func refreshIfAvailable(reason: String) {
        #if canImport(FirebaseRemoteConfig)
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 60 * 60
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            Keys.enabled: NSNumber(value: V2FeatureFlags.remoteDecorativeCTAEffectsAllowed)
        ])

        remoteConfig.fetchAndActivate { status, error in
            if let error {
                logError(
                    event: "liquid_metal_cta_remote_config_failed",
                    message: "Failed to refresh liquid metal CTA remote config",
                    fields: [
                        "reason": reason,
                        "error": error.localizedDescription
                    ]
                )
                return
            }

            Task { @MainActor in
                self.apply(remoteConfig: remoteConfig, reason: reason, status: status)
            }
        }
        #else
        _ = reason
        #endif
    }
}

#if canImport(FirebaseRemoteConfig)
@MainActor
private extension LiquidMetalCTARemoteConfigService {
    enum Keys {
        static let enabled = "feature_ui_liquid_metal_cta_enabled"
    }

    func apply(remoteConfig: RemoteConfig, reason: String, status: RemoteConfigFetchAndActivateStatus) {
        let allowed = boolValue(for: Keys.enabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.remoteDecorativeCTAEffectsAllowed
        V2FeatureFlags.remoteDecorativeCTAEffectsAllowed = allowed

        logInfo(
            "Applied liquid metal CTA remote config (reason: \(reason), status: \(status.rawValue), allowed: \(allowed ? "true" : "false"))"
        )
    }

    func boolValue(for key: String, remoteConfig: RemoteConfig) -> Bool? {
        let value = remoteConfig.configValue(forKey: key)
        switch value.source {
        case .remote, .default:
            return value.boolValue
        case .static:
            return nil
        @unknown default:
            return nil
        }
    }
}
#endif
