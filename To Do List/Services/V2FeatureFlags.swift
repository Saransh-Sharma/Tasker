import Foundation

public enum LLMChatPrewarmMode: String, CaseIterable {
    case disabled
    case adaptiveOnDemand
    case eager
}

public enum LLMChatContextStrategy: String, CaseIterable {
    case bounded
    case full
}

public enum V2FeatureFlags {
    private static let defaults = UserDefaults.standard
    private static let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName)

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

    public static var llmChatPrewarmMode: LLMChatPrewarmMode {
        get {
            let modeKey = "feature.llm.chat_prewarm_mode"
            if let raw = defaults.string(forKey: modeKey),
               let parsed = LLMChatPrewarmMode(rawValue: raw) {
                return parsed
            }

            // Backward-compatibility: map legacy boolean to nearest mode.
            if let legacy = defaults.object(forKey: "feature.llm.chat_prewarm") as? Bool {
                return legacy ? .adaptiveOnDemand : .disabled
            }
            return .adaptiveOnDemand
        }
        set { defaults.set(newValue.rawValue, forKey: "feature.llm.chat_prewarm_mode") }
    }

    public static var llmChatPrewarmEnabled: Bool {
        get { llmChatPrewarmMode != .disabled }
        set { llmChatPrewarmMode = newValue ? .adaptiveOnDemand : .disabled }
    }

    public static var llmChatContextStrategy: LLMChatContextStrategy {
        get {
            guard let raw = defaults.string(forKey: "feature.llm.chat_context_strategy"),
                  let parsed = LLMChatContextStrategy(rawValue: raw) else {
                return .bounded
            }
            return parsed
        }
        set { defaults.set(newValue.rawValue, forKey: "feature.llm.chat_context_strategy") }
    }

    public static var llmChatThinkingPhaseHapticsEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.chat_thinking_phase_haptics") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.llm.chat_thinking_phase_haptics") }
    }

    public static var llmChatAnswerPhaseHapticsEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.chat_answer_phase_haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.llm.chat_answer_phase_haptics") }
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

    public static var gamificationOverhaulV1Enabled: Bool {
        get { defaults.object(forKey: "feature.gamification.overhaul.v1") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.gamification.overhaul.v1") }
    }

    // MARK: - Task list widgets

    public static var taskListWidgetsEnabled: Bool {
        get {
            boolValue(
                forKey: "feature.task_list.widgets",
                defaultValue: true
            )
        }
        set {
            setBoolValue(
                newValue,
                forKey: "feature.task_list.widgets"
            )
        }
    }

    public static var interactiveTaskWidgetsEnabled: Bool {
        get {
            boolValue(
                forKey: "feature.task_list.widgets.interactive",
                defaultValue: true
            )
        }
        set {
            setBoolValue(
                newValue,
                forKey: "feature.task_list.widgets.interactive"
            )
        }
    }

    private static func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        if let value = defaults.object(forKey: key) as? Bool {
            return value
        }
        if let value = sharedDefaults?.object(forKey: key) as? Bool {
            return value
        }
        return defaultValue
    }

    private static func setBoolValue(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        sharedDefaults?.set(value, forKey: key)
    }
}
