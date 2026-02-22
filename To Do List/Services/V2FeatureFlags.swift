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

    public static var remindersBackgroundRefreshEnabled: Bool {
        get { defaults.object(forKey: "feature.reminders.background_refresh") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.reminders.background_refresh") }
    }

    public static var assistantPlanModeEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.plan_mode") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.plan_mode") }
    }

    public static var assistantCopilotEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.copilot") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.copilot") }
    }

    public static var assistantSemanticRetrievalEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.semantic_retrieval") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.semantic_retrieval") }
    }

    public static var assistantSemanticMutationIndexingEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.semantic_mutation_indexing") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.assistant.semantic_mutation_indexing") }
    }

    public static var assistantBriefEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.brief") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.brief") }
    }

    public static var assistantBreakdownEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.breakdown") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.breakdown") }
    }

    public static var assistantFastModeEnabled: Bool {
        get { defaults.object(forKey: "feature.assistant.fast_mode") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.assistant.fast_mode") }
    }
}
