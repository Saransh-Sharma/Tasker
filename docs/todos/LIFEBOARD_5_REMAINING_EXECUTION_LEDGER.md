# LifeBoard 5.0 Remaining Completion Ledger

Updated: 2026-07-22

This is the active implementation ledger for the remaining LifeBoard 5.0 work. It supersedes overlapping Phase 5/6 and UI-overhaul checklists as a tracking surface; those documents remain product references. A checked item means implemented and verified, not merely scaffolded.

## Protected baseline

- [x] Adaptive Home grid, semantic card sizes, transactional editing, Smart Slots, Now rail, Today Story, shared Home composer, Add to Home, rollback presentation, and fasting effect exist.
- [x] JournalKit shared baseline: 67 tests pass.
- [x] OffRecord generic iOS build passes against the shared JournalKit revision.
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
- [x] Re-run both application baselines after the shared-contract boundary: JournalKit 67/67, OffRecord generic iOS (including its embedded Watch app), LifeBoard Simulator, and Catalyst pass.

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
- [x] Mount the existing save-first audio/transcription controls directly in the shared composer recording state (the composer's Voice action now presents `LifeBoardJournalAudioCapture` in a sheet that appends to today's journal through the derived pipeline).
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
- [~] Accessibility/contrast gates: WCAG contrast contracts and the light/dark/high-contrast/reduced-transparency/reduced-motion/grayscale screenshot matrix are green. Device performance/memory/launch/thermal remain signed-device gates (not locally runnable). Latest complete inherited `LifeBoardTests` rerun executed 1,677 tests with 3 skips and reported 98 assertions across 48 distinct failing tests; the one drift caused by the new Eva status wording was subsequently corrected and its focused 9-test contract is green. The remaining failures are inherited Phase 5/6 contract drift and time-sensitive legacy tests, so release promotion remains blocked until that suite and the device gates close.
- [x] Retain the previous presentation for one release (legacy Sunrise palette + legacy Home remain behind `lifeOSUnifiedPresentationV2` / `adaptiveHomeV2` as the documented rollback).
