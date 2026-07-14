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
    private static var defaults: UserDefaults { .standard }
    private static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: AppGroupConstants.suiteName) }
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private static let decorativeCTAEffectsUserKey = "feature.ui.decorative_cta_effects.user_enabled"
    private static let decorativeCTAEffectsRemoteAllowKey = "feature.ui.decorative_cta_effects.remote_allowed"

    /// The Life OS shell is the default developer experience so a normal Xcode
    /// run exercises the new product. Release builds retain the promoted value
    /// policy and never inherit this Debug-only default.
    public static var lifeOSFoundationV1Enabled: Bool {
        get {
            #if DEBUG
            if launchArguments.contains("-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION") { return true }
            if launchArguments.contains("-LIFEBOARD_DISABLE_LIFE_OS_FOUNDATION") { return false }
            if let override = defaults.object(forKey: "debug.life_os_foundation_v1") as? Bool {
                return override
            }
            return true
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            defaults.set(newValue, forKey: "debug.life_os_foundation_v1")
            #endif
        }
    }

    public static var adaptiveHomeV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.adaptive_home_v2", argument: "ADAPTIVE_HOME_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.adaptive_home_v2") }
    }

    public static var dashboardCustomizationV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.dashboard_customization_v2", argument: "DASHBOARD_CUSTOMIZATION_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.dashboard_customization_v2") }
    }

    public static var trackersV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.trackers_v1", argument: "TRACKERS_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.trackers_v1") }
    }

    public static var healthIntegrationsV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.health_integrations_v1", argument: "HEALTH_INTEGRATIONS_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.health_integrations_v1") }
    }

    public static var journalV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.journal_v1", argument: "JOURNAL_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.journal_v1") }
    }

    public static var knowledgeNotesV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_v1", argument: "KNOWLEDGE_NOTES_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_v1") }
    }

    public static var planningCoreV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.planning_core_v1", argument: "PLANNING_CORE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.planning_core_v1") }
    }

    public static var planDestinationV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.plan_destination_v1", argument: "PLAN_DESTINATION_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.plan_destination_v1") }
    }

    public static var focusExecutionV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.focus_execution_v2", argument: "FOCUS_EXECUTION_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.focus_execution_v2") }
    }

    public static var evaPlanRepairV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.eva_plan_repair_v1", argument: "EVA_PLAN_REPAIR_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.eva_plan_repair_v1") }
    }

    public static var trackFoundationsV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.track_foundations_v2", argument: "TRACK_FOUNDATIONS_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.track_foundations_v2") }
    }

    public static var habitResilienceV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.habit_resilience_v2", argument: "HABIT_RESILIENCE_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.habit_resilience_v2") }
    }

    public static var goalsRoutinesV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.goals_routines_v1", argument: "GOALS_ROUTINES_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.goals_routines_v1") }
    }

    public static var careModulesV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.care_modules_v2", argument: "CARE_MODULES_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.care_modules_v2") }
    }

    public static var starterPacksV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.starter_packs_v1", argument: "STARTER_PACKS_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.starter_packs_v1") }
    }

    private static func stagedFeatureEnabled(key: String, argument: String) -> Bool {
        #if DEBUG
        if launchArguments.contains("-LIFEBOARD_ENABLE_\(argument)") { return true }
        if launchArguments.contains("-LIFEBOARD_DISABLE_\(argument)") { return false }
        if let override = sharedDefaults?.object(forKey: key) as? Bool
            ?? defaults.object(forKey: key) as? Bool {
            return override
        }
        // Phase II is intentionally visible on an ordinary developer launch.
        // This keeps manual product/design testing on the same path as CI while
        // preserving explicit per-feature disable arguments for rollback work.
        return true
        #else
        return sharedDefaults?.object(forKey: key) as? Bool
            ?? defaults.object(forKey: key) as? Bool
            ?? false
        #endif
    }

    private static func setStagedFeature(_ enabled: Bool, key: String) {
        (sharedDefaults ?? defaults).set(enabled, forKey: key)
    }

    public static var remindersSyncEnabled: Bool {
        get { defaults.object(forKey: "feature.reminders.sync") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.reminders.sync") }
    }

    public static var autoTaskIconsEnabled: Bool {
        get { defaults.object(forKey: "feature.tasks.auto_icons") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.tasks.auto_icons") }
    }

    public static var liquidMetalCTAEnabled: Bool {
        get {
            if launchArguments.contains("-LIFEBOARD_ENABLE_LIQUID_METAL_CTA") {
                return true
            }
            if launchArguments.contains("-LIFEBOARD_DISABLE_LIQUID_METAL_CTA") {
                return false
            }
            return userDecorativeCTAEffectsEnabled && remoteDecorativeCTAEffectsAllowed
        }
        set {
            userDecorativeCTAEffectsEnabled = newValue
        }
    }

    public static var userDecorativeCTAEffectsEnabled: Bool {
        get { defaults.object(forKey: decorativeCTAEffectsUserKey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: decorativeCTAEffectsUserKey) }
    }

    public static var remoteDecorativeCTAEffectsAllowed: Bool {
        get { defaults.object(forKey: decorativeCTAEffectsRemoteAllowKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: decorativeCTAEffectsRemoteAllowKey) }
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

    public static var llmExecutiveContextEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.executive_context") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.llm.executive_context") }
    }

    public static var llmSlashPinsEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.slash_pins") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.llm.slash_pins") }
    }

    public static var llmChatThinkingPhaseHapticsEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.chat_thinking_phase_haptics") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.llm.chat_thinking_phase_haptics") }
    }

    public static var llmChatAnswerPhaseHapticsEnabled: Bool {
        get { defaults.object(forKey: "feature.llm.chat_answer_phase_haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.llm.chat_answer_phase_haptics") }
    }

    public static var llmChatTemplateDiagnosticsEnabled: Bool {
        get {
            #if DEBUG
            if launchArguments.contains("-LIFEBOARD_LLM_TEMPLATE_DIAGNOSTICS") {
                return true
            }
            return defaults.object(forKey: "debug.llm.chat_template_diagnostics") as? Bool ?? false
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            defaults.set(newValue, forKey: "debug.llm.chat_template_diagnostics")
            #endif
        }
    }

    public static var llmRuntimeSmokeEnabled: Bool {
        get {
            #if DEBUG
            if launchArguments.contains("-LIFEBOARD_LLM_RUN_SMOKE") {
                return true
            }
            return defaults.object(forKey: "debug.llm.runtime_smoke") as? Bool ?? false
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            defaults.set(newValue, forKey: "debug.llm.runtime_smoke")
            #endif
        }
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

    public static var evaPlanWithText: Bool {
        get { defaults.object(forKey: "feature.eva.plan_with_text") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.plan_with_text") }
    }

    public static var evaStructuredComposer: Bool {
        get { defaults.object(forKey: "feature.eva.structured_composer") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.structured_composer") }
    }

    public static var evaProposalReviewCards: Bool {
        get { defaults.object(forKey: "feature.eva.proposal_review_cards") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.eva.proposal_review_cards") }
    }

    public static var evaTimelineInlineDiff: Bool {
        get { defaults.object(forKey: "feature.eva.timeline_inline_diff") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.eva.timeline_inline_diff") }
    }

    public static var evaAppliedRunHistory: Bool {
        get { defaults.object(forKey: "feature.eva.applied_run_history") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.eva.applied_run_history") }
    }

    public static var evaVoiceDeferred: Bool {
        get { defaults.object(forKey: "feature.eva.voice_deferred") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.eva.voice_deferred") }
    }

    public static var evaScanDeferred: Bool {
        get { defaults.object(forKey: "feature.eva.scan_deferred") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.eva.scan_deferred") }
    }

    public static var iPadNativeShellEnabled: Bool {
        get { defaults.object(forKey: "feature.ipad.native_shell") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.native_shell") }
    }

    public static var iPadPerfBottomBarSchedulerV2Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.bottomBar_scheduler_v2") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.bottomBar_scheduler_v2") }
    }

    public static var iPadPerfSearchCoalescingV2Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.search_coalescing_v2") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.search_coalescing_v2") }
    }

    public static var iPadPerfThemeTokenCacheV2Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.theme_token_cache_v2") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.theme_token_cache_v2") }
    }

    public static var iPadPerfDeferLLMPrewarmV2Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.defer_llm_prewarm_v2") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.defer_llm_prewarm_v2") }
    }

    public static var iPadPerfPrimarySurfacePersistenceV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.primary_surface_persistence_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.primary_surface_persistence_v3") }
    }

    public static var iPadPerfSearchFocusStabilizationV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.search_focus_stabilization_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.search_focus_stabilization_v3") }
    }

    public static var iPadPerfHomeAnimationTrimV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.home_animation_trim_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.home_animation_trim_v3") }
    }

    public static var iPadPerfTaskRenderMemoizationV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.task_render_memoization_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.task_render_memoization_v3") }
    }

    public static var iPadPerfCoreDataMappingSnapshotV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.coredata_mapping_snapshot_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.coredata_mapping_snapshot_v3") }
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
