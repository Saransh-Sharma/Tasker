import Foundation
import LifeBoardPersistence

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

    /// The Life OS shell is now the product on every build configuration.
    ///
    /// This was a hard-coded `false` in Release with no override path, which meant
    /// a shipped build could only ever show the legacy Sunrise home — and no
    /// amount of remote configuration could change that without a new binary. It
    /// now resolves through the same promoted-default policy as every other staged
    /// flag, so the shell ships on and remains rollback-able without a build.
    public static var lifeOSFoundationV1Enabled: Bool {
        get {
            stagedFeatureEnabled(
                key: "debug.life_os_foundation_v1",
                argument: "LIFE_OS_FOUNDATION"
            )
        }
        set { setStagedFeature(newValue, key: "debug.life_os_foundation_v1") }
    }

    /// Rollback gate for the Adaptive Home Canvas and shared conversational
    /// presentation. Domain stores remain canonical when this surface is off.
    public static var lifeOSUnifiedPresentationV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.unified_presentation_v2", argument: "LIFE_OS_UNIFIED_PRESENTATION_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.unified_presentation_v2") }
    }

    /// Presentation-only rollback gate for the LifeBoard 5 information
    /// architecture, root header, contextual capture, and motion choreography.
    /// Domain models, receipts, and stored records never depend on this flag.
    public static var lifeBoardPremiumIAV5Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.premium_ia_v5", argument: "PREMIUM_IA_V5") }
        set { setStagedFeature(newValue, key: "feature.life_os.premium_ia_v5") }
    }

    /// Additive domain gates. Turning one off only removes unfinished surfaces;
    /// canonical records and migrations are never rolled back or discarded.
    public static var wellnessCoreV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.wellness_core_v1", argument: "WELLNESS_CORE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.wellness_core_v1") }
    }

    public static var fastingV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.fasting_v2", argument: "FASTING_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.fasting_v2") }
    }

    public static var nutritionV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.nutrition_v1", argument: "NUTRITION_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.nutrition_v1") }
    }

    public static var lifeMomentsV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.life_moments_v1", argument: "LIFE_MOMENTS_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.life_moments_v1") }
    }

    public static var lifeOSSystemSurfacesV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.system_surfaces_v2", argument: "LIFE_OS_SYSTEM_SURFACES_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.system_surfaces_v2") }
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

    /// Two-way Apple Health sync. `healthIntegrationsV1Enabled` remains the master
    /// read gate; this additionally opens the local→HealthKit write-back path
    /// (hydration, nutrition, body metrics, workouts). Turning it off leaves
    /// read projections intact and never rolls back records already written.
    public static var healthWriteBackV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.health_writeback_v1", argument: "HEALTH_WRITEBACK_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.health_writeback_v1") }
    }

    public static var journalV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.journal_v1", argument: "JOURNAL_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.journal_v1") }
    }

    /// Phase 5: OffRecord journal parity (shared JournalKit packages — mood
    /// dial, capture modes, semantic memory, reflection, watch capture).
    public static var journalParityV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.journal_parity_v1", argument: "JOURNAL_PARITY_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.journal_parity_v1") }
    }

    public static var knowledgeNotesV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_v1", argument: "KNOWLEDGE_NOTES_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_v1") }
    }

    public static var knowledgeNotesTextKitEditorV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_textkit_v2", argument: "KNOWLEDGE_NOTES_TEXTKIT_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_textkit_v2") }
    }

    public static var knowledgeNotesSearchIndexV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_search_v2", argument: "KNOWLEDGE_NOTES_SEARCH_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_search_v2") }
    }

    // `knowledgeNotesMediaPipelineV2Enabled` and `knowledgeNotesFlagshipV1Enabled`
    // were removed rather than promoted. Neither had a single call site, so both
    // gated nothing: the media pipeline (protected attachment ingestion,
    // checksum deduplication, PhotosPicker capture) already shipped
    // unconditionally, and the flagship umbrella was never wired to a surface.
    // Recording a default for a flag that controls nothing only makes the
    // promotion table lie about what is staged.

    public static var knowledgeNotesSecurityV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_security_v1", argument: "KNOWLEDGE_NOTES_SECURITY_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_security_v1") }
    }

    public static var knowledgeNotesEVAV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.knowledge_notes_eva_v1", argument: "KNOWLEDGE_NOTES_EVA_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.knowledge_notes_eva_v1") }
    }

    public static var planningCoreV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.planning_core_v1", argument: "PLANNING_CORE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.planning_core_v1") }
    }

    public static var focusExecutionV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.focus_execution_v2", argument: "FOCUS_EXECUTION_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.focus_execution_v2") }
    }

    public static var trackFoundationsV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.track_foundations_v2", argument: "TRACK_FOUNDATIONS_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.track_foundations_v2") }
    }

    // `habitResilienceV2Enabled`, `planDestinationV1Enabled` and
    // `starterPacksV1Enabled` were removed rather than promoted, for the same
    // reason as the two Notes flags above: none had a single call site, so none
    // gated anything. Their surfaces shipped unconditionally and their
    // `-LIFEBOARD_ENABLE_*` launch arguments — still passed by the UI tests —
    // set a default nothing read. A flag that controls nothing only makes the
    // promotion table lie about what is staged.

    public static var goalsRoutinesV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.goals_routines_v1", argument: "GOALS_ROUTINES_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.goals_routines_v1") }
    }

    public static var careModulesV2Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.care_modules_v2", argument: "CARE_MODULES_V2") }
        set { setStagedFeature(newValue, key: "feature.life_os.care_modules_v2") }
    }

    /// Stage 1 of the Beyond Notes rollout: trust, recovery and release closure.
    /// Gates the Recovery Center. Data-preserving by construction — everything
    /// behind it is a read model over subsystems that already exist, plus
    /// rebuilds of derived indexes, so turning it off hides a screen and never
    /// changes a canonical record.
    public static var lifeBoardTrustClosureV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.trust_closure_v1", argument: "TRUST_CLOSURE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.trust_closure_v1") }
    }

    /// Stage 2 of the Beyond Notes rollout: the daily execution loop. Gates the
    /// task completion control and the magnetic schedule spine — both of which
    /// touch canonical mutations, so the flag has to hide the new presentation
    /// without hiding work created while it was on.
    public static var lifeBoardDailyLoopV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.daily_loop_v1", argument: "DAILY_LOOP_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.daily_loop_v1") }
    }

    /// Stage 3 of the Beyond Notes rollout: the task and project flagship. Gates
    /// the directional Plan Repair deck.
    public static var taskProjectFlagshipV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.task_project_flagship_v1", argument: "TASK_PROJECT_FLAGSHIP_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.task_project_flagship_v1") }
    }

    /// Home led by the day-loop spine, with the pinned dashboard beneath it.
    ///
    /// Presentation-only: the spine reorders and reframes surfaces that already
    /// exist and writes nothing of its own. Off restores the previous section
    /// order exactly, including "Close the loop" as its own rendered section.
    public static var homeLoopSpineV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.home_loop_spine_v1", argument: "HOME_LOOP_SPINE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.home_loop_spine_v1") }
    }

    /// The morning commitment: today proposed from what last night decided, and
    /// confirmed in one tap.
    ///
    /// Separate from `dayCloseV1Enabled` because it carries a different bet. The
    /// evening has a natural trigger; the morning does not, and this is the
    /// milestone most likely to be skipped into irrelevance. Rolling it back
    /// leaves the carry — which the evening's own write already provides —
    /// working untouched.
    public static var dayOpenCommitV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.day_open_commit_v1", argument: "DAY_OPEN_COMMIT_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.day_open_commit_v1") }
    }

    /// The end-of-day ritual: the day ribbon, the reconciliation deck, the one
    /// line, and tomorrow's first thing.
    ///
    /// Gates presentation only. Everything the ritual writes goes through the
    /// existing planning receipt path and the existing `ReflectionNote` store,
    /// so turning this off hides the surface while every carry-forward and note
    /// made while it was on stays readable — and undoable — from Plan.
    public static var dayCloseV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.day_close_v1", argument: "DAY_CLOSE_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.day_close_v1") }
    }

    /// Phase 2 umbrella gate for the behavior, goal, medication, and tracker
    /// flagship surfaces. The additive schema remains readable when this is
    /// disabled; only the new presentation and mutation entry points disappear.
    public static var trackBehaviorFlagshipV1Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.life_os.track_behavior_flagship_v1", argument: "TRACK_BEHAVIOR_FLAGSHIP_V1") }
        set { setStagedFeature(newValue, key: "feature.life_os.track_behavior_flagship_v1") }
    }

    /// The v6 "Life Weave" first run: six core decisions, review folded into
    /// capture, connectors demoted to an optional branch off the reveal, and no
    /// root tour. Presentation-only. The v5 Life Map journey stays composed and
    /// resumable while this is off, and both write the same canonical records
    /// through `LifeMapCommitCoordinator`, so rollback strands nothing.
    ///
    /// Held back from Release promotion until the rollout completes — see
    /// `heldBackFromReleasePromotion` in `FeatureFlagPromotionTests`.
    public static var onboardingLifeWeaveV6Enabled: Bool {
        get { stagedFeatureEnabled(key: "feature.onboarding.life_weave_v6", argument: "ONBOARDING_V6") }
        set { setStagedFeature(newValue, key: "feature.onboarding.life_weave_v6") }
    }

    /// Route-level Phase 1 gate. New Plan roots and their stores are composed
    /// only when both halves of the execution flagship are enabled. This is
    /// deliberately stronger than sprinkling flags over individual buttons:
    /// either rollback switch restores the previous Home task experience.
    public static var phase1ExecutionFlagshipEnabled: Bool {
        lifeBoardDailyLoopV1Enabled && taskProjectFlagshipV1Enabled
    }

    /// Flags whose staged rollout is complete and which now ship on by default.
    ///
    /// Release builds used to fall through to `false` for every staged flag, so a
    /// shipped LifeBoard showed the legacy Sunrise home and none of Plan, Track,
    /// Insights, Eva, journal, wellness, nutrition, fasting, or life moments was
    /// reachable. Promotion is expressed as data rather than as a build-config
    /// branch so a single flag can be held back by name without disturbing the
    /// rest, and so a stored override still wins in both directions.
    private static let promotedDefaults: [String: Bool] = [
        "debug.life_os_foundation_v1": true,
        "feature.life_os.unified_presentation_v2": true,
        "feature.life_os.premium_ia_v5": true,
        "feature.life_os.wellness_core_v1": true,
        "feature.life_os.fasting_v2": true,
        "feature.life_os.nutrition_v1": true,
        "feature.life_os.life_moments_v1": true,
        "feature.life_os.system_surfaces_v2": true,
        "feature.life_os.dashboard_customization_v2": true,
        "feature.life_os.trackers_v1": true,
        "feature.life_os.health_integrations_v1": true,
        "feature.life_os.health_writeback_v1": true,
        "feature.life_os.journal_v1": true,
        "feature.life_os.journal_parity_v1": true,
        "feature.life_os.knowledge_notes_v1": true,
        "feature.life_os.planning_core_v1": true,
        "feature.life_os.focus_execution_v2": true,
        "feature.life_os.track_foundations_v2": true,
        "feature.life_os.goals_routines_v1": true,
        "feature.life_os.care_modules_v2": true,
        // The Notes flagship. These had no entry at all, so they resolved to
        // `false` and Release shipped none of the TextKit editor, the ranked
        // search index, per-note encryption, or the Notes Eva actions — every
        // one of them reachable and working on an ordinary Debug launch. Each
        // has a live call site and a rollback path (the block editor, the
        // unindexed search, the unlocked note), so they ship on.
        "feature.life_os.knowledge_notes_textkit_v2": true,
        "feature.life_os.knowledge_notes_search_v2": true,
        "feature.life_os.knowledge_notes_security_v1": true,
        "feature.life_os.knowledge_notes_eva_v1": true,
        // The Recovery Center. Reports real persistent-store health and real
        // journal-index health, and omits any subsystem it cannot observe rather
        // than showing it as healthy. Backup/export, restore preview, conflict
        // resolution and deletion are still to come; the screen is honest about
        // what it does and does not cover, so it ships.
        "feature.life_os.trust_closure_v1": true,
        // The daily execution loop: the task completion control in task detail
        // and on Plan rows, and the four-direction Plan Repair deck. Both write
        // canonical mutations through the existing receipt path with Undo.
        "feature.life_os.daily_loop_v1": true,
        "feature.life_os.task_project_flagship_v1": true,
        // Close the Day. The terminus of the daily loop: reconcile what is left,
        // write one line, name tomorrow's first thing. Every write is one
        // existing-ledger batch with a single Undo receipt, so rollback hides
        // the ritual without stranding anything it produced.
        "feature.life_os.day_close_v1": true,
        // The morning commit. Ships on; rollback leaves the carry intact.
        "feature.life_os.day_open_commit_v1": true,
        // Home as the loop spine over a pinned dashboard. Presentation only.
        "feature.life_os.home_loop_spine_v1": true,
        // Universal input. Routing ships on so the home capture box stops
        // routing every typed line to Eva and instead opens the right
        // activity. Live dictation ships on (SpeechAnalyzer is the modern
        // path on iOS 26). Submitted EVA classification ships on so
        // paraphrases resolve without
        // an exact command match. Each has a staged-feature rollback path.
        "feature.universal_input.routing_v1": true,
        "feature.universal_input.dictation_v1": true,
        "feature.universal_input.semantic_v1": true,
        // Retained staged flags ship on. Each remains a disable-only rollback
        // path whose off state preserves canonical records and deterministic
        // behavior.
        "feature.life_os.track_behavior_flagship_v1": true,
        // Held back deliberately: the v6 first run is still being built, so it
        // is on for developers and off in Release until the rollout completes.
        // The entry exists so the flag cannot be *silently* missing.
        "feature.onboarding.life_weave_v6": false
    ]

    private static func stagedFeatureEnabled(key: String, argument: String) -> Bool {
        #if DEBUG
        if launchArguments.contains("-LIFEBOARD_ENABLE_\(argument)") { return true }
        if launchArguments.contains("-LIFEBOARD_DISABLE_\(argument)") { return false }
        #endif
        if let override = sharedDefaults?.object(forKey: key) as? Bool
            ?? defaults.object(forKey: key) as? Bool {
            return override
        }
        #if DEBUG
        // Every staged surface is intentionally visible on an ordinary developer
        // launch, so manual product/design testing follows the same path as CI.
        return true
        #else
        return promotedDefaults[key] ?? false
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

    /// All 22 bounded signature Metal effects. Enabled by default; callers still
    /// gate on Reduce Motion / Low Power / thermal / GPU support.
    public static var signatureShadersEnabled: Bool {
        if launchArguments.contains("-LIFEBOARD_ENABLE_SIGNATURE_SHADERS") { return true }
        if launchArguments.contains("-LIFEBOARD_DISABLE_SIGNATURE_SHADERS") { return false }
        return remoteDecorativeCTAEffectsAllowed
    }

    /// "Button flourishes". On by default: the bezel is the only shader that animates at rest.
    public static var userDecorativeCTAEffectsEnabled: Bool {
        get { defaults.object(forKey: decorativeCTAEffectsUserKey) as? Bool ?? true }
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

    /// Kill switch for universal intent routing. When off, all composer
    /// submissions go to EVA conversation (pre-existing behavior).
    public static var universalInputRoutingEnabled: Bool {
        get { stagedFeatureEnabled(key: "feature.universal_input.routing_v1", argument: "UNIVERSAL_INPUT_ROUTING") }
        set { setStagedFeature(newValue, key: "feature.universal_input.routing_v1") }
    }

    /// Kill switch for live composer dictation. When off, the microphone
    /// button opens the Journal audio-attachment flow (pre-existing behavior).
    public static var universalInputDictationEnabled: Bool {
        get { stagedFeatureEnabled(key: "feature.universal_input.dictation_v1", argument: "UNIVERSAL_INPUT_DICTATION") }
        set { setStagedFeature(newValue, key: "feature.universal_input.dictation_v1") }
    }

    /// Gate for EVA semantic classification after explicit submission.
    public static var universalInputSemanticClassifierEnabled: Bool {
        get { stagedFeatureEnabled(key: "feature.universal_input.semantic_v1", argument: "UNIVERSAL_INPUT_SEMANTIC") }
        set { setStagedFeature(newValue, key: "feature.universal_input.semantic_v1") }
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
