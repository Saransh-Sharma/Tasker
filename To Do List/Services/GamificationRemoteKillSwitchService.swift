import Foundation

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// Syncs launch-time gamification feature flags from Firebase Remote Config.
/// This preserves an emergency kill-switch path without requiring a redeploy.
final class GamificationRemoteKillSwitchService {
    static let shared = GamificationRemoteKillSwitchService()

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
            Keys.killSwitch: NSNumber(value: false),
            Keys.gamificationV2Enabled: NSNumber(value: V2FeatureFlags.gamificationV2Enabled),
            Keys.gamificationWidgetsEnabled: NSNumber(value: V2FeatureFlags.gamificationWidgetsEnabled),
            Keys.gamificationFocusSessionsEnabled: NSNumber(value: V2FeatureFlags.gamificationFocusSessionsEnabled),
            Keys.taskListWidgetsEnabled: NSNumber(value: V2FeatureFlags.taskListWidgetsEnabled),
            Keys.interactiveTaskWidgetsEnabled: NSNumber(value: V2FeatureFlags.interactiveTaskWidgetsEnabled)
        ])

        remoteConfig.fetchAndActivate { status, error in
            if let error {
                logError(
                    event: "gamification_remote_config_failed",
                    message: "Failed to refresh gamification remote config",
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
private extension GamificationRemoteKillSwitchService {
    enum Keys {
        static let killSwitch = "feature_gamification_kill_switch"
        static let gamificationV2Enabled = "feature_gamification_v2_enabled"
        static let gamificationWidgetsEnabled = "feature_gamification_widgets_enabled"
        static let gamificationFocusSessionsEnabled = "feature_gamification_focus_sessions_enabled"
        static let taskListWidgetsEnabled = "feature_task_list_widgets_enabled"
        static let interactiveTaskWidgetsEnabled = "feature_task_list_widgets_interactive_enabled"
    }

    func apply(remoteConfig: RemoteConfig, reason: String, status: RemoteConfigFetchAndActivateStatus) {
        let killSwitchOn = boolValue(for: Keys.killSwitch, remoteConfig: remoteConfig) ?? false
        let v2Enabled = boolValue(for: Keys.gamificationV2Enabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.gamificationV2Enabled
        let widgetsEnabled = boolValue(for: Keys.gamificationWidgetsEnabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.gamificationWidgetsEnabled
        let focusEnabled = boolValue(for: Keys.gamificationFocusSessionsEnabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.gamificationFocusSessionsEnabled
        let taskListWidgetsEnabled = boolValue(for: Keys.taskListWidgetsEnabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.taskListWidgetsEnabled
        let interactiveTaskWidgetsEnabled = boolValue(for: Keys.interactiveTaskWidgetsEnabled, remoteConfig: remoteConfig) ?? V2FeatureFlags.interactiveTaskWidgetsEnabled

        if killSwitchOn {
            V2FeatureFlags.gamificationV2Enabled = false
            V2FeatureFlags.gamificationWidgetsEnabled = false
            V2FeatureFlags.gamificationFocusSessionsEnabled = false
        } else {
            V2FeatureFlags.gamificationV2Enabled = v2Enabled
            V2FeatureFlags.gamificationWidgetsEnabled = widgetsEnabled
            V2FeatureFlags.gamificationFocusSessionsEnabled = focusEnabled
        }
        V2FeatureFlags.taskListWidgetsEnabled = taskListWidgetsEnabled
        V2FeatureFlags.interactiveTaskWidgetsEnabled = interactiveTaskWidgetsEnabled

        logWarning(
            event: "gamification_remote_config_applied",
            message: "Applied gamification remote config",
            fields: [
                "reason": reason,
                "status": "\(status.rawValue)",
                "kill_switch": killSwitchOn ? "true" : "false",
                "v2_enabled": V2FeatureFlags.gamificationV2Enabled ? "true" : "false",
                "widgets_enabled": V2FeatureFlags.gamificationWidgetsEnabled ? "true" : "false",
                "focus_sessions_enabled": V2FeatureFlags.gamificationFocusSessionsEnabled ? "true" : "false",
                "task_list_widgets_enabled": V2FeatureFlags.taskListWidgetsEnabled ? "true" : "false",
                "interactive_task_widgets_enabled": V2FeatureFlags.interactiveTaskWidgetsEnabled ? "true" : "false"
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
