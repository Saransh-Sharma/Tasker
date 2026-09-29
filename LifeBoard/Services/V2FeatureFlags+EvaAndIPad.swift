import Foundation

extension V2FeatureFlags {
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
        get { defaults.object(forKey: "feature.eva.applied_run_history") as? Bool ?? true }
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
        get { defaults.object(forKey: "feature.ipad.perf.home_animation_trim_v3") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.home_animation_trim_v3") }
    }

    public static var iPadPerfTaskRenderMemoizationV3Enabled: Bool {
        get { defaults.object(forKey: "feature.ipad.perf.task_render_memoization_v3") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feature.ipad.perf.task_render_memoization_v3") }
    }

    public static var iPadPerfCoreDataMappingSnapshotV3Enabled: Bool {
        get { CoreDataTaskMappingConfiguration.isSnapshotMappingEnabled }
        set { CoreDataTaskMappingConfiguration.isSnapshotMappingEnabled = newValue }
    }
}
