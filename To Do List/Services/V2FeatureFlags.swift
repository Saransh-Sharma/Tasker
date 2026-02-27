import Foundation

public enum V2FeatureFlags {
    private static let defaults = UserDefaults.standard

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

    public static var assistantCopilotEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.copilot") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.copilot") }
    }

    public static var assistantSemanticRetrievalEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.semantic_retrieval") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.semantic_retrieval") }
    }

    public static var assistantFastModeEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.fast_mode") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.fast_mode") }
    }

    public static var assistantBreakdownEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.breakdown") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.breakdown") }
    }

    public static var remindersBackgroundRefreshEnabled: Bool {
        get { defaults.object(forKey: "feature.reminders.background_refresh") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.reminders.background_refresh") }
    }

    public static var llmChatPrewarmEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.chat_prewarm") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.llm.chat_prewarm") }
    }

    public static var evaFocusEnabled: Bool {
        get { defaults.object(forKey: "feature.eva.focus") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.focus") }
    }

    public static var evaTriageEnabled: Bool {
        get { defaults.object(forKey: "feature.eva.triage") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.triage") }
    }

    public static var evaRescueEnabled: Bool {
        get { defaults.object(forKey: "feature.eva.rescue") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.rescue") }
    }

    // MARK: - Gamification v2

    public static var gamificationV2Enabled: Bool {
        get { defaults.object(forKey: "feature.gamification.v2") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.gamification.v2") }
    }

    public static var gamificationWidgetsEnabled: Bool {
        get { defaults.object(forKey: "feature.gamification.widgets") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.gamification.widgets") }
    }

    public static var gamificationFocusSessionsEnabled: Bool {
        get { defaults.object(forKey: "feature.gamification.focus_sessions") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.gamification.focus_sessions") }
    }
}
