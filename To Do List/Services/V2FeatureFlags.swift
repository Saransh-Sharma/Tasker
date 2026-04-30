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
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)
    private static let decorativeCTAEffectsUserKey = "feature.ui.decorative_cta_effects.user_enabled"
    private static let decorativeCTAEffectsRemoteAllowKey = "feature.ui.decorative_cta_effects.remote_allowed"
    public static let homeBackdropNoiseAmountUserKey = "feature.ui.home_backdrop_noise_amount"
    public static let defaultHomeBackdropNoiseAmount = 20

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
            if launchArguments.contains("-TASKER_ENABLE_LIQUID_METAL_CTA") {
                return true
            }
            if launchArguments.contains("-TASKER_DISABLE_LIQUID_METAL_CTA") {
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

    public static func clampedHomeBackdropNoiseAmount(_ amount: Int) -> Int {
        min(max(amount, 0), 100)
    }

    public static var homeBackdropNoiseAmount: Int {
        get {
            guard let storedAmount = defaults.object(forKey: homeBackdropNoiseAmountUserKey) as? NSNumber else {
                return defaultHomeBackdropNoiseAmount
            }
            let clamped = clampedHomeBackdropNoiseAmount(storedAmount.intValue)
            if clamped != storedAmount.intValue {
                defaults.set(clamped, forKey: homeBackdropNoiseAmountUserKey)
            }
            return clamped
        }
        set {
            defaults.set(clampedHomeBackdropNoiseAmount(newValue), forKey: homeBackdropNoiseAmountUserKey)
        }
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
            if launchArguments.contains("-TASKER_LLM_TEMPLATE_DIAGNOSTICS") {
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
            if launchArguments.contains("-TASKER_LLM_RUN_SMOKE") {
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
