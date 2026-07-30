# LifeBoard 5.0 Remaining Completion Ledger

Updated: 2026-07-31

This is the active implementation ledger for the remaining LifeBoard 5.0 work. It supersedes overlapping Phase 5/6 and UI-overhaul checklists as a tracking surface; those documents remain product references. A checked item means implemented and verified, not merely scaffolded.

Product intent and UX acceptance live in the [LifeBoard 5.0 Product Handbook](../product/README.md). Design behavior lives in the [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md) and [DESIGN.md](../../DESIGN.md). This ledger alone decides current completion status.

## Protected baseline

- [x] Adaptive Home grid, semantic card sizes, transactional editing, Smart Slots, Now rail, Today Story, shared Home composer, Add to Home, rollback presentation, and fasting effect exist.
- [x] JournalKit shared baseline: 67 tests pass.
- [x] The configured shared-package consumer's generic iOS build passes against the shared JournalKit revision.
- [x] LifeBoard focused foundation baseline: 112 tests pass; the adjacent Eva transcript contract adds 9 passing tests (121/121 combined).
- [x] LifeBoard adaptive Home edit/composer and Add-to-Home UI journeys pass.
- [x] LifeBoard generic Simulator and Mac Catalyst builds pass.
- [x] Record widget-extension and Watch-extension standalone build results; iOS WidgetKit, watchOS app/widget, Simulator, and Catalyst compile against the shared system-surface contract.
- [x] Capture deterministic root-state screenshot fixtures for populated, empty, loading, denied, and error states (`LifeBoardVisualFixture.catalog` covers 45 root/state pairs; representative iPhone evidence is stored under `docs/evidence/lifeboard-5/root-state-fixtures/iphone-17-pro`).

## Milestone 0 — Truth, rollback, and observability

- [x] Keep `lifeOSUnifiedPresentationV2` as the presentation rollback gate.
- [x] Add data-preserving gates for Wellness, Fasting v2, Nutrition, Life Moments, and system surfaces.
- [x] Add content-free typed performance operations for card snapshots, context, composer resolution, journal rebuilds, migrations, shader warm-up, and system refresh.
- [x] Preserve unrelated dirty-worktree changes; milestone edits remain narrowly scoped.
- [x] Re-run the shared-contract baselines: JournalKit 67/67, configured consumer generic iOS (including its embedded Watch app), LifeBoard Simulator, and Catalyst pass.

## Milestone 1 — Adaptive Home architecture closure

- [x] Add the provider registry, enriched snapshot context, typed actions, and explicit snapshot availability states.
- [x] Register current Plan, Track, Journal, Insights, Eva, fasting, goals, routines, care, and Life Snapshot projections behind provider contracts.
- [x] Move all Home canonical reads behind domain providers (glance/compact card bodies resolve `HomeCardSnapshot`s through `HomeCardProviderRegistry`; the Home view no longer queries repositories directly — mood fallback moved into `HomeLifeOSProjectionStore`).
- [x] Verify collision-free 4/8/12-column packing plus the accessibility single-column fallback with executable contracts; typed layout restoration and atomic edit rollback remain covered by the focused foundation suite.
- [x] Capture size-specific density and atomic edit accessibility visual evidence on compact iPhone, regular iPad, and wide iPad destinations (including the wide atomic-edit proof at `docs/evidence/lifeboard-5/root-state-fixtures/ipad/home-atomic-edit-wide.png`; semantic 4-column spans now scale proportionally at 8/12 columns).
- [x] Complete Smart Slot schedules, freeze behavior, starter layouts, safe-area composer measurement, and fixture matrix (schedule eligibility, frozen widget identity, curated starter reset, measured composer/dock clearance, and 45-state visual catalog are executable).

## Milestone 2 — Conversational runtime

- [x] Implement deterministic Life Thread projection without a duplicate database.
- [x] Implement four-outcome intent resolution and one mutation/undo coordinator.
- [x] Implement the shared composer state machine, cross-root host, draft continuity, and truthful working states.
- [x] Complete shared preview/diff, Apply/Edit/Not now, receipt, and Undo presentation in the persistent composer.
- [x] Route all legacy direct mutations through the coordinator (foundation-shell time-block capture now prepares/applies a `LifeBoardMutationCommand` and surfaces the shared receipt with Undo; domain composers retain their audited correction-based CRUD).
- [x] Implement punctuation/length/140-ms phrase settling with bounded ink-reveal input.
- [x] Wire cumulative phrase settling into Eva generation; Stop preserves settled text and drops only the unfinished tail.
- [x] Replace the continuous whole-bubble ink shimmer with a 220-ms one-shot reveal bounded to the newly settled transcript region.
- [x] Stop automatic following after manual scroll and expose one accessible “New response” return control.
- [x] Add draft-preserving Continue/Retry recovery contracts and shared-composer presentation after Stop or failure.
- [x] Turn the persistent shell composer into Universal Input: exact commands and explicit task/note/journal language route to canonical native activities for Journal, Note, Task, Meetings, Day Plan, Weekly Planner, Day Rescue, and Overdue Rescue.
- [x] Add deterministic-only live previews plus explicit-submit semantic resolution through Apple Foundation Models and the installed on-device MLX runtime; both are bounded by an intent allow-list, confidence thresholds, clarification, and Eva fallback.
- [x] Wire live microphone input through the shared iOS 26 `SpeechAnalyzer`/`SpeechTranscriber` stack in both the shell composer and Eva. Stop commits the latest cumulative transcript, Cancel restores the typed prefix, and backgrounding or surface dismissal tears down preparation/recording.
- [x] Add focused Universal Input contracts: five selected tests pass for required command routing, empty editor seeds, task-question false positives, preview/semantic separation, and cumulative transcript preservation. The iPhone 17 Pro Simulator app build also passes.
- [ ] Complete signed-device Universal Input promotion evidence: locale/asset-install matrix, microphone interruptions and denial recovery, long-dictation thermal/memory profiling, real Foundation Models/MLX fallback, intent-corpus accuracy, and assistive-technology journeys.
- [ ] Extend `TranscriptionKit.LiveTranscriptionEvent` with finalized/volatile ranges. LifeBoard is currently correctness-safe by treating the cumulative string as provisional, but cannot style only the analyzer-confirmed substring.

## Milestone 3 — Context and cross-domain cards

- [x] Add a deterministic domain-candidate provider registry and merge boundary.
- [x] Move live candidates to domain providers and add meaningful-boundary refresh (Home refreshes candidates and provider snapshots on app foreground, daypart boundary, task mutation, and tracker commit boundaries).
- [x] Add persistent Hide Today/Suggest Less/Never/Keep feedback, repetition cooldown, and per-card sensitive consent contracts.
- [x] Complete all interaction freezes and migrate every live candidate source onto domain candidate providers (scroll, customization, direct context-card touch, and VoiceOver focus freeze the deterministic provider merge).
- [x] Finish Add-to-Home configuration from every major domain with singleton handling and Undo (Track now offers goals, wellness, nutrition, and Life Moments kinds behind their flags; Eva offers the saved-conversation card; singleton reuse and receipt Undo were already in `addCardToHome`).

## Milestone 4 — Shared journal infrastructure

- [x] Connect journal commit/delete/exclusion, semantic index, deterministic graph rebuild, and projection invalidation seams through one derived pipeline actor.
- [x] Connect ReflectionKit generation, live Eva evidence answering, and Home cache invalidators to the pipeline seams (`JournalProjectionInvalidationHub` broadcasts from the derived pipeline; Home projections, Eva authorized evidence, and loaded reflection reports refresh live).
- [x] Add launch reconciliation, tombstones, resumable rebuilds, and cache eviction (first-load `reconcileAll` re-runs interrupted rebuilds; deletion tombstones are persisted with complete file protection and block late re-ingest; derived index invalidation and orphaned-audio cleanup evict stale caches).
- [x] Adopt JournalSecurityKit and complete protected-route/system-surface redaction (`BiometricAppLock` backs the journal lock; protected routes defer through `DeferredProtectedRoute`; Spotlight and system-surface envelopes carry no journal content, including mood).
- [x] Centralize Watch connectivity and complete journal envelope import, durable retry, deduplication, acknowledgement, and quarantine, with user-visible phone recovery actions.

## Milestone 5 — Journal and Eva completion

- [x] Implement VisionKit document capture, on-device text recognition, editable review, cancellation, and save-only-after-review behavior.
- [x] Preserve the existing save-first Journal audio/transcription controls as the flag-off fallback. With Universal Input dictation enabled, the composer microphone performs live SpeechAnalyzer dictation; saved Journal audio still uses the same SpeechAnalyzer-backed `TranscriptionService`.
- [x] Add the one-shot `LifeBoardMemoryDevelopReveal` with static/crossfade policy fallbacks and reflection-open integration.
- [x] Complete attachment inspection and availability recovery: photos open full-screen with pinch zoom, reset and system sharing; unavailable photo/audio blocks preserve their place and expose encrypted-restore guidance plus a discoverable removal action.
- [x] Attach exact Journal evidence to proactive reflection claims and add protected save/snooze/dismiss/follow-up state with explicit local reflection visuals.
- [x] Add app-side journal intent, Spotlight, and redacted widget snapshot contracts (`QuickJournalCaptureIntent`, `LifeBoardJournalSpotlightIndexer` with content-free attributes, and the redacted journal system-surface envelope).

## Milestone 6 — Wellness Core

- [x] Add additive Wellness Core model version and migration fixtures from every predecessor.
- [x] Add typed body metric, workout, sleep, and movement values with captured timezone, stable source identity, canonical unit normalization, correction, deterministic CRUD, export, deletion, and normalized private events.
- [x] Expand the flag-gated HealthKit projection to optional body mass, workouts, sleep, distance, steps, and active energy without overwriting manual records.
- [x] Add permission-gated, size-specific body metric, workout, sleep, and movement Home provider contracts and registry descriptors.
- [x] Add a persistent Core Data adapter for body metrics, workouts, sleep notes, and movement records.
- [x] Add outlier confirmation, search, Today-first capture, accessible charts/tables, and complete degraded states (Wellness leads with a Today capture card, Swift Charts trend with text equivalents, searchable history, Health-source labels, and flag-aware empty copy; `WellnessOutlierPolicy` review was already wired in capture).

## Milestone 7 — Fasting and Nutrition

- [x] Add the actor-serialized fasting lifecycle with one-active enforcement, target calculation, reminder sanitization, early/planned/cancelled meaning, correction, and deterministic duplicate-active recovery.
- [x] Route the Track timer through the shared lifecycle and add a review choice for Finish, Cancel, or Keep running.
- [x] Persist fasting completion meaning and correction timestamps in the additive Wellness Core model with legacy-model compatibility.
- [x] Finish history, all card densities, and canonical external actions (`LifeBoardFastingHistoryView` shows every session with its recorded meaning plus correction/undo; card densities render through the provider registry; Start/End intents run through the shared `FastingTimerStore`).
- [x] Add additive Nutrition model version, local-first library/search, immutable macro snapshots, and explicit opt-in remote lookup (`TaskModelV3_Nutrition` + `CoreDataNutritionRepository`; remote lookup remains off and the barcode flow says so plainly).
- [x] Add tested Nutrition domain contracts for canonical per-100g macros, serving conversion, immutable historical snapshots, stable local-first search, explicit remote lookup policy, recents, deletion/Undo semantics, and bounded barcode deduplication.
- [x] Build meal timeline, reviewable barcode/voice/manual flows, reports, system projections, and undo coverage (slot-grouped timeline, dedup-guarded barcode review, on-device voice-to-composer flow, honest 7-day energy report, redacted system envelope, and restore-in-place delete Undo).

## Milestone 8 — Life Moments and final Home

- [x] Add additive Life Moments model version and persistent adapter, export/search/system contracts (`TaskModelV3_LifeMoments` + `CoreDataLifeMomentRepository`; searchable list, explicit user-triggered JSON export, redacted system envelope gated on per-moment Home consent).
- [x] Add typed Life Moment values, captured-timezone recurrence expansion, stable-identity CRUD/archive contracts, Home opt-in, semantic card density, and final-week explainable candidate provider.
- [x] Add goal, routine, reflection, memory, and saved-insight providers, including evidence-linked proactive Journal insights shared through `ReflectionKit`.
- [x] Finish the continuous Home composition, canonical return navigation, resilient degraded states, and calm removable starter experiences (open reading order, typed root restoration, inline safe-layout recovery, curated reset, and fixture evidence are connected).

## Milestone 9 — System surfaces and continuity

- [x] Add redacted, versioned, atomic app-group snapshot envelopes with backup recovery and schema/domain validation.
- [x] Move the display-only envelope, privacy classification, app-group locations, and backup-aware reader into `Shared` for independent app, WidgetKit, Watch, and Watch-widget compilation.
- [x] Register domain widgets, Live Activities, intents, Spotlight, notifications, deep links, and Watch projections through canonical mutations (`LifeBoardSystemSurfaceRefresher` debounces envelope republish from fasting, nutrition, wellness, Life Moments, goal, and routine mutations plus the journal pipeline hub; intents already run through the canonical stores; journal Spotlight donates on save/delete).
- [x] Verify locally reproducible termination, offline, ordering, deduplication, schema/domain mismatch, protection, and migration cases (corrupt-primary interruption recovers from the atomic backup; absent-file offline reads do not create state; envelopes deterministically deduplicate/order; legacy schema is accepted and future/wrong-domain data rejected; file protection and every compiled predecessor migration are contract-tested). Paired-Watch delivery interruption remains a signed-device gate below.

## Milestone 10 — UI/UX migration and release hardening

- [x] Complete Plan, Track, Insights, Eva, Journal, Notes, detail, settings, onboarding, iPad, and Catalyst visual migration (all five roots verified warm in the simulator; the canonical palette + global cocoa `.tint` + shared clay primitives bring every semantic-token leaf — details, sheets, settings, onboarding, widgets, Watch — to parity by construction; no system-blue remains).
- [x] Implement and prewarm exactly five signature effects with centralized motion/power/thermal/transparency fallbacks (`daypartBloom`, `evaInkReveal`, `journalMediaReveal`, `memoryDevelopReveal`, `fastingEmberRing`; enhanced completion-burst and ported liquid ring fill added within the existing motion budget, Reduce Motion / Low Power aware).
- [~] Finish timing and interaction polish across every migrated root and leaf (Foundation and Eva state changes now use centralized interactive/local/ambient motion roles; Home atomic customization, safe-area composer continuity, responsive 4/8/12 packing, bounded streaming reveal, truthful async states, and named haptic/elevation budgets are simulator-verified. Physical haptic feel, shader timing, drag velocity, and oldest-device frame pacing remain signed-device tuning gates).
- [~] Accessibility/contrast and regression gates: WCAG contrast contracts and the stored light/dark/high-contrast/reduced-transparency/reduced-motion/grayscale screenshot matrix are green. In the 2026-07-23 validation snapshot, the official `DESIGN.md` lint and both UI guardrails completed with 0 warnings/errors, and a serial generic Simulator build passed. The baseline-aware `LifeBoardTests` run executed 1,704 tests: 1,657 passed, 3 skipped, and 44 distinct methods failed with 78 failure assertions, 2 unexpected. The checked-in failure baseline is empty, so this is unresolved baseline drift and release promotion remains blocked. Active Overdue Rescue source changed after that run and requires a fresh candidate rerun. Device performance, memory, launch, thermal, haptics, App Group, and paired-Watch gates also remain open.
- [x] Retain the previous presentation for one release (legacy Sunrise palette + legacy Home remain behind `lifeOSUnifiedPresentationV2` / `adaptiveHomeV2` as the documented rollback).

## Milestone 12 — IA correction, card archetypes, and motion craft

Updated: 2026-07-27

### Shell
- [x] One bottom bar on iPhone. `.toolbar(.hidden, for: .tabBar)` was applied to the `TabView` itself, where it addresses an *enclosing* tab bar; the system Liquid Glass bar therefore rendered underneath the custom dock. Moved onto the tab content inside the `ForEach`.
- [x] iPad root navigation. Replaced the hand-rolled `NavigationSplitView` + `List` with `TabView` + `.tabViewStyle(.sidebarAdaptable)`, so roots stay switchable when the sidebar collapses and through Split View / Slide Over.
- [x] Mounted the floating conversational composer (`lifeThreadComposerHost`, ~145 lines, previously never called) above the dock inside one `GlassEffectContainer`. Suppressed on Eva, which owns its own composer; the header `+` now appears only where the composer does not.
- [x] Extended the composer tray with Habit, Tracker entry and Time block — all three had working capture hosts and no visible control.
- [x] Fixed the composer `+` hit target: it had no `contentShape`, so its tappable area was the glyph rather than its 44×44 frame.
- [x] Fixed the iPad atmosphere seam. The scenic band is capped at 520pt and centred; 28pt edge gradients could not bridge it, leaving a bright vertical stripe. Added a blurred full-bleed bed and masked the band's own alpha into it.

### Card system
- [x] Added `HomeCardPayload` (metric / progress / series / queue / streak / countdown / moment) to `HomeCardSnapshot`, decoded additively so persisted snapshots and app-group widget envelopes keep working. `redactingPayload()` strips it for system surfaces.
- [x] Added `HomeCardArchetype` and `HomeSectionRole` to `DashboardWidgetDescriptor`; assigned both to all 22 registered kinds.
- [x] New `LifeBoardCardPrimitives.swift`: numeric roll, sparkline, Swift Charts trend with prose equivalent, liquid progress ring, streak grid, bounded 3-card deck stack.
- [x] New `LifeBoardHomeCardBodies.swift`: ten archetype bodies, each rendering at all five presets. **This closes a real accessibility defect** — eleven kinds previously fell through to `EmptyView()` at wide and above, and accessibility text sizes force the wide preset, so those cards were blank for large-type users.
- [x] `HomeCardSnapshot.actions` now render. Providers had always populated them; nothing ever drew them.
- [x] Section membership moved onto the descriptor, replacing three hardcoded string sets in the Home view and a divergent fourth copy in `DashboardLayoutRepository`. The two copies disagreed on ownership, so a user-pinned anchored card persisted forever and never rendered.

### Home
- [x] New anchored order: Now → Signals → **Today** → Day ahead → Needs attention → Keep steady → Close the loop → Your space. `tasks` previously fell through to "Your space" and rendered below wellbeing and reflection on a default install.
- [x] Removed the standalone day-summary line, which restated the same projection the Now card and Day ahead already narrated.
- [x] Raised the context-candidate cap from 2 to 4. Nine domain providers were competing for a "Needs attention" section that could only ever render one row.
- [x] Header ink follows the scene, not the system appearance. A Night daypart in Light appearance resolved cocoa ink onto navy sky; the greeting and date were effectively invisible.

### Modes
- [x] Surfaced the Smart / Work / Personal / Low Energy control in the root header. It previously existed only inside `adaptiveHeader`, which is never called — modes were persisted and restored with no way to change them.
- [x] Added `DashboardModePolicy` so every mode changes content: permitted planning contexts, card permission, and a section budget. Work excludes sensitive cards; Low Energy reduces Home to Now, Signals and Keep steady. Verified live.
- [x] Deleted the dead `adaptiveHeader` and its duplicate `DashboardMode.systemImage`.

### Reconnections
- [x] Plan's `capacityCard` is called from the Day lens. It was unreferenced, which also made `PlanWorkingHoursComposer` unreachable — Plan was showing a capacity figure derived from inputs the user could not edit. Verified live.
- [x] Add to Home wired from the Plan/Track/Insights/Eva overflow menus. The sheet, receipt and Undo were fully built with nothing setting the request.

### Insights
- [x] New `InsightsInterpretationEngine`. The Overview headline was "whichever domain has the most records", which always named the chattiest tracker; it now ranks by days-present and refuses to claim a pattern below a three-day floor, mirroring the weekly reflection's density gate.
- [x] Trends renders a real Swift Charts series with its prose equivalent, replacing a list of per-domain row counts.
- [x] The Eva handoff carries the interpretation Insights actually made instead of a generic "help me understand this pattern".

### Motion
- [x] Five new Metal shaders in the governed allowlist and `warmUp()`: `chartRevealSweep`, `liquidGlassRefract`, `cardMorphWarp`, `paperGrain`, `dissolveAway`. `paperGrain` adapts the sample project's Halftone; `dissolveAway` adapts Burn. All inherit the existing Reduce Motion / Reduce Transparency / Low Power / thermal fallbacks.
- [x] Ported the sample project's AddView expansion as the composer tray's staggered entrance (28ms per chip, capped at 220ms) and its rotating plus-to-close control.
- [x] Apache 2.0 attribution for `SwiftUI-Animations-master` preserved; it remains reference material, not a runtime dependency.

### Evidence
- [x] `LifeOSFoundationContractTests`: 129 tests, 5 failing — all five are the pre-existing CoreData `writeClosed` failures inherited from the Phase 5/6 worktree (Wellness, Nutrition, Life Moments, Fasting, PhaseII round-trips). Each fails identically when run in isolation, and this pass touched no CoreData store. The two contract tests this work deliberately changed (candidate cap, effect allowlist) were updated rather than worked around.
- [x] Four new contract tests: every registered kind declares a renderable archetype and section; payload decodes absent as `.none` and redacts on demand; each mode has distinct behaviour; the interpretation engine ranks consistency and refuses below its floor.
- [x] Live simulator verification on iPhone 17 Pro and iPad (iOS 26.5): single bottom bar, composer tray, mode switching changing content, Plan capacity → working hours, iPad sidebar and seam-free backdrop.

### Completion pass (2026-07-27)

- [x] Fasting migrated out of the legacy Track tree. It is a first-class module on `FastingTimerStore`: a live ring in Today while a fast runs, a Body-area entry when none does, plus the reused composer and history with correction and Undo. Verified live — start, ring, Finish/Cancel, and the Today/Areas move all work without the legacy sheet.
- [x] Journal de-duplicated in Areas; the Mind copy is gone and Library is the single module index.
- [x] Track History extended past hydration/sleep/mood to fasting, routines and goals, with a shared history row and a range cutoff.
- [x] `.trackHistory` is reachable: Insights evidence rows for hydration, sleep and mood push it instead of dropping the user on Track's Today lens.
- [x] `.insightEvidence(UUID)` honours its identifier — the disclosure opens, the named record is highlighted and scrolled to, and the lens widens to Review.
- [x] `.planningReview` deleted. It rendered the identical weekly-review route as `.weeklyReview` and was never pushed; `.weeklyReview` now pops the destination it was actually opened from, fixing Close doing nothing when opened from Insights.
- [x] Typed payloads for the remaining providers: body metric and sleep as series, workout / movement / nutrition energy as metrics with history, recent meal as a moment, life moment as a countdown.
- [x] `WorkoutRecord` and sleep render in Wellness with charts and history so the module matches its own subtitle; the health/care row no longer advertises fasting.
- [x] The daypart override picker was stranded in the same dead `adaptiveHeader` as the mode picker. Both, plus layout Undo, are now reachable, and `adaptiveHeader` with its orphaned helpers is deleted (150+ lines).
- [x] Every new shader has a real call site: `paperGrain` on the Home canvas, `dissolveAway` when a card is hidden, `liquidGlassRefract` on the dock selection well, `cardMorphWarp` on the card-to-detail background plane, `chartRevealSweep` in the trend chart.
- [x] Deck depth added to Plan Repair so queue length is visible. The generic dismiss-deck was deliberately not adopted there — Plan Repair maps swipe direction to distinct actions, which a generic deck would discard.
- [x] `LifeOSFoundationContractTests`: 131 tests, still only the 5 pre-existing CoreData `writeClosed` failures. The new in-memory fasting lifecycle test passes while the Core Data fasting round-trip fails, localising that failure to persistence rather than domain logic.

### Open

- [ ] Migrate medications and trackers out of the legacy `LifeBoardTrackRootView`. Fasting is done; those two are the only remaining reason the health/care sheet exists, and they need their own schedule/definition UI rather than a re-parented sheet.
- [ ] Capture the full appearance/daypart/Dynamic Type/Increased Contrast/Reduce Transparency screenshot matrix for the new card archetypes.
- [ ] Signed-device gates: Core Animation/SwiftUI Instruments for 60/120 fps, sub-100 ms main-thread stalls, warm-up cost of the five new shader functions, and post-transition idle work.
- [ ] `-SKIP_ONBOARDING` is bypassed when a journey snapshot exists, because `evaluateLaunchIfNeeded` resumes before consulting the eligibility service. Harness-only, but it makes seeded runs unreliable after a partial onboarding.
- [ ] The composer's voice action can present an empty sheet when the journal store has not loaded; it needs a loading state.

## Notes flagship completion pass (2026-07-27)

### Implemented

- [x] Added the immutable `TaskModelV3_NotesCompletion` model after `TaskModelV3_NotesPro`, with conflict-aware draft/revision metadata, block-addressable links, secure attachment payloads, protected attachment metadata, and LocalOnly durable processing jobs. Cloud/private and LocalOnly boundaries are contract-tested.
- [x] Added backward-compatible Notes contracts: composable/paginated `KnowledgeNoteQuery`, version-2 rich-text payloads with forward-version fallback, reversible `NoteMutation`, `NoteEditorSession`, search, attachment, secure-note, EVA-proposal, and import/export codec interfaces.
- [x] Replaced the feature-flagged per-block editor with one TextKit 2 `UITextView(usingTextLayoutManager: true)` document, stable block-range attributes, deterministic split/merge identity, rich formatting, Markdown shortcuts, slash commands, `[[` note mentions, indent/outdent, focused/reading chrome, hardware text behavior, 450 ms autosave, draft recovery, and revision checkpoints. The old block editor remains the rollback path.
- [x] Added the protected Notes-only SQLite/FTS5 index with exact-title/prefix/tag/body/attachment ranking, transactional rebuilds, incremental updates, corruption-generation recovery, safe snippets, and immediate locked/trash tombstones.
- [x] Completed adaptive Notes Home organization with the built-in collections, list/grid sorting, folder/tag navigation, saved composable smart collections, multi-selection batch actions with Undo, and bounded 3° pinned-card drag/reorder.
- [x] Added save-first protected attachment ingestion with checksum deduplication and durable originals, privacy-preserving `PhotosPicker` capture with asynchronous loading, loss-conscious Markdown import/export, import revisions, attachment cleanup after permanent deletion, and cancellable bookmark metadata behavior already present in the block editor.
- [x] Added per-note AES-GCM envelopes, separately encrypted attachments, authenticated Keychain-backed keys, in-memory-only unlocked editing, encrypted autosaves, scene/screen-capture shielding, search/link/tag/preview redaction, block/link preservation inside ciphertext, and recoverable key-unavailable behavior.
- [x] Added explicit on-device EVA actions with selection/note-only input, a no-Journal system instruction, editable Apply/Edit/Discard review, content-version stale protection, one revision before Apply, and no automatic mutation.
- [x] Added content-safe Create/Open/Search Notes App Intents and preserved typed Notes library, note, folder, Universal Capture, search, backlinks, and graph routes.
- [x] Added staged TextKit/search/media/security/EVA/flagship rollout switches; Release remains rollback-safe while ordinary Debug launches exercise the new path.

### Verification evidence

- [x] Generic iOS Simulator build succeeds after the NotesCompletion model, TextKit editor, search, locking, EVA, smart collections, batch actions, Markdown codec, and intents.
- [x] Mac Catalyst build succeeds; the app also installs and launches on the available iPhone and iPad simulators. The iPhone Notes library/empty state and iPad split library plus focused unified editor were visually inspected through the typed Notes deep link.
- [x] Migration from every compiled predecessor, including `TaskModelV3_NotesPro`, passes with stable-ID preservation.
- [x] Focused contract suites pass for rich-text v2/forward fallback, block split/merge/inverse identity, ranked search and locked exclusion, composable queries, Markdown fidelity, typed deep-link restoration, folder cycles, templates, protected attachment recovery, and model store boundaries.
- [x] `git diff --check`, Core Data XML validation, and current-version plist validation pass.

### Remaining release gates

- [ ] Finish the durable enrichment worker UI for camera/scanner originals, Pencil drawings, audio recording/transcription, OCR thumbnails, TextBundle attachment staging, PDF export, retry/cancellation after relaunch, and background scheduling. PhotosPicker, protected file ingestion, and job entities are in place; these capture-specific producers are not complete.
- [ ] Finish permanent unlock/lock-policy removal, cross-device secure-payload conflict recovery, authenticated locked attachment preview/export, synchronizable-Keychain validation, Spotlight/widget/notification publishing, and privacy telemetry on signed devices.
- [ ] Persist user-dragged graph positions and folder/tag clustering; the accessible connections list, filtering, deterministic layout, pan/zoom, and editor transitions are present.
- [ ] Add the complete UI automation and screenshot matrix, 10k/500-block performance fixtures, corruption/termination fault injection, and physical-device camera/microphone/Pencil/haptics/authentication/CloudKit/thermal/Metal gates.
- [ ] The pre-existing isolated `testPhaseIIRepositoryRoundTripsTrackerJournalAndKnowledgeValues` failure remains `writeClosed`; it predates this pass and was reproduced before NotesCompletion changes. Do not promote the flagship Release flag until that baseline persistence defect is resolved.
