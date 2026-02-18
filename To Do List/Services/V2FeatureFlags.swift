import Foundation

public enum V2FeatureFlags {
    private static let defaults = UserDefaults.standard

    public static var v2Enabled: Bool {
        get { defaults.object(forKey: "feature.v2.enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.v2.enabled") }
    }

    public static var remindersSyncEnabled: Bool {
        get { defaults.object(forKey: "feature.reminders.sync") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.reminders.sync") }
    }

    public static var assistantApplyEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.apply") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.apply") }
    }

    public static var assistantUndoEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.undo") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.undo") }
    }

    public static var remindersBackgroundRefreshEnabled: Bool {
        get { defaults.object(forKey: "feature.reminders.background_refresh") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.reminders.background_refresh") }
    }
}
