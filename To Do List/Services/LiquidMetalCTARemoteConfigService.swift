import Foundation

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Syncs the liquid-metal CTA rollout flag from Firebase Remote Config.
/// The product default is enabled, but this preserves a server-side rollback path.
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
            Keys.enabled: NSNumber(value: V2FeatureFlags.liquidMetalCTAEnabled)
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

            self.apply(remoteConfig: remoteConfig, reason: reason, status: status)
        }
        #else
        _ = reason
        #endif
    }
}

#if canImport(FirebaseRemoteConfig)
private extension LiquidMetalCTARemoteConfigService {
    enum Keys {
        static let enabled = "feature_ui_liquid_metal_cta_enabled"
    }

    func apply(remoteConfig: RemoteConfig, reason: String, status: RemoteConfigFetchAndActivateStatus) {
        let enabled = boolValue(for: Keys.enabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.liquidMetalCTAEnabled
        V2FeatureFlags.liquidMetalCTAEnabled = enabled

        logWarning(
            event: "liquid_metal_cta_remote_config_applied",
            message: "Applied liquid metal CTA remote config",
            fields: [
                "reason": reason,
                "status": "\(status.rawValue)",
                "enabled": enabled ? "true" : "false"
            ]
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
