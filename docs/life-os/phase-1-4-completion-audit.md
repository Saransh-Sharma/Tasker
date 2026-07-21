# LifeBoard 5.0 Phase I–IV completion audit

This file is the implementation checklist for the Phase I–IV completion pass. A box is checked only after the behavior is implemented and verified in the current worktree.

## Verification ledger

- [x] 2026-07-15 baseline: generic iPhone 17 Pro simulator build succeeded on iOS 26.5.
- [x] 2026-07-15 route milestone: 59 focused tests passed (32 Life OS, 18 Planning/Track, 9 evidence/privacy).
- [x] 2026-07-15 current working set: generic iPhone 17 Pro simulator build succeeded and 79 focused tests passed (49 Life OS, 20 Planning/Track, 10 evidence/privacy); the UI-test target compiled while building the selected test plan.
- [x] 2026-07-16 simulator integration pass: compact Home/Plan/Week/Track/Eva/capture and resilience states were exercised through the accessibility tree; Plan Week persisted across termination/relaunch; 84 focused tests pass (50 Life OS, 20 Planning/Track, 14 evidence/privacy).
- [x] 2026-07-16 habit recovery milestone: generic simulator build succeeded and 86 focused tests pass (50 Life OS, 22 Planning/Track, 14 evidence/privacy); additive legacy-policy decoding, protected Core Data receipt round-trip, and canonical-completion-only grading are covered.
- [x] 2026-07-16 boundary-routing milestone: simulator build succeeded and 88 focused tests pass (52 Life OS, 22 Planning/Track, 14 evidence/privacy); widget URL vocabulary and private Journal Spotlight identifiers resolve through typed routes with deterministic malformed-input fallback.
- [x] 2026-07-16 notification-boundary milestone: simulator build succeeded and 89 focused tests pass (53 Life OS, 22 Planning/Track, 14 evidence/privacy); navigation notification actions enter the typed foundation router while mutation actions retain their canonical handlers.
- [x] 2026-07-16 dependency-hardening milestone: simulator build and the same 89-test gate pass after making every core Phase I–IV repository a shell initialization requirement and removing normal-navigation repository-placeholder views.
- [x] 2026-07-16 correction-receipt milestone: simulator build succeeded and 92 focused tests pass (53 Life OS, 25 Planning/Track, 14 evidence/privacy); typed before/after recovery, protected atomic persistence, deterministic identity, reversible/reversed projection, and exact-value restoration are covered.
- [x] 2026-07-16 compact-accessibility milestone: generic simulator build and all 92 focused tests pass; two condition-driven iPhone 17 Pro journeys at accessibility XXXL verify all five roots, the measured/scrollable capture palette, deterministic canonical habit seeding, resilience policy editing, and reachable 30-day history with no fixed test sleeps.
- [x] 2026-07-16 Backlog-deletion milestone: all 92 focused tests and a seeded end-to-end simulator journey pass after adding confirmed sync-safe tombstones, exact receipt undo, immediate projection removal, typed-source exclusion, idempotent apply/undo, and persistence across a fresh app process.
- [x] 2026-07-16 Home-hierarchy milestone: the generic simulator build and all 93 focused tests pass (54 Life OS, 25 Planning/Track, 14 evidence/privacy), and a condition-driven seeded iPhone 17 Pro journey reaches the complete curated Phase II hierarchy. The additive dashboard v3 migration preserves stable placement IDs and custom sizes while introducing distinct Tasks, Routines, and Journal surfaces.
- [x] 2026-07-16 Day-presentation milestone: a canonical full-timeline seed gates the foundation shell, Timeline renders, Agenda remains selectable, the native composer persists an exact titled time block, and receipt-backed one-step Undo is exposed and consumed in a condition-driven iPhone 17 Pro journey.
- [x] 2026-07-16 regular-width Week milestone: a dedicated iOS 26.5 iPad Air 13-inch simulator passes the canonical seeded Week journey; the adaptive branch mounts the horizontal seven-day board, hides the compact list, retains the Weekly Operating Layer, and exposes exactly seven stable day targets.
- [x] 2026-07-16 Home-action/navigation milestone: all 95 focused tests pass (56 Life OS, 25 Planning/Track, 14 evidence/privacy), and four condition-driven Home journeys pass together. Active-root reselection now pops to root, interactive cross-root navigation selects before appending its typed leaf, Task/Care/Day/Insights/Journal actions mount native destinations, task rows expose full-width 44-point hit regions, and Morning/Afternoon/Evening/Night overrides remain independently selectable.
- [x] 2026-07-16 Home-capture/reflection hardening milestone: all 96 focused tests pass (57 Life OS, 25 Planning/Track, 14 evidence/privacy). Condition-driven simulator journeys verify Task capture → authoritative close → Journal capture, the multi-root Home action sequence, and the native protected Weekly Reflection route. The shared preferences environment now reaches presentation content (removing a reproducible Journal-sheet fatal error), sequential capture dismissal is driven by `CaptureRouter`, and the Weekly Reflection row exposes a genuine full-width 44-point activation region.
- [x] 2026-07-16 Home appearance/routine/iPad milestone: dark appearance remains independently usable after manually selecting Night and opening protected Weekly Reflection; a habit-backed routine suggestion opens the typed native Habit Board; and the full curated Home hierarchy passes on the regular-width iPad Air 13-inch simulator. UI-test reset now clears both the application and App Group defaults so inactive typed stacks cannot leak between journeys.
- [x] 2026-07-16 Home Dynamic Type milestone: a relaunch-and-scroll iPhone 17 Pro matrix passes all twelve UIKit content-size categories from extra small through accessibility XXXL. The deepest curated Home section remains reachable and the measured capture control remains independently hittable; the run also removed an ambiguous duplicated widget-title accessibility identifier by combining each semantic title into one element.
- [x] 2026-07-16 warning/recovery hardening milestone: a clean `build-for-testing` succeeds with no repository-source warnings, all 96 Phase I–IV contract tests pass, and a broader 501-test targeted regression set passes. Swift 6 async UI-test lifecycle replaces synchronous actor crossings; Home passive replan visibility, post-streak widget snapshots, typed local widget-flag contracts, schema validation precedence, and CloudSync-only quarantine/rebuild for missing-mapping-model errors are covered. The remaining clean-build diagnostics are four MLX package C++17-extension warnings in DerivedData and Xcode's App Intents metadata skip for the UI-test bundle.
- [ ] Run the complete unit and UI schemes after every atomic row below is implemented.

## Foundation and shell

- [x] All Phase I–IV destinations and detail routes resolve through typed `AppRoute` values.
  - [x] Five root destinations restore through `LifeBoardDestination`.
  - [x] Task, Habit Board/library/detail, tracker detail, care library, project, routine, goal, Journal day/search, weekly reflection, Note/folder, Plan Day/Week/Backlog, Focus, weekly planning/review, settings, and reference leaves have Codable `AppRoute` cases.
  - [x] URL routes translate into typed leaves and round-trip through Codable restoration tests.
  - [x] Focus routes fetch the exact requested session by stable ID, open only an active match, and distinguish ended, missing/stale, and repository-failure states without substituting another session.
  - [x] The complete shipped widget URL vocabulary maps to typed Home/Plan/Track leaves; malformed project, task, and habit inputs fall back deterministically instead of leaving a partial path.
  - [x] Private Journal Spotlight items carry a protected Journal URL; searchable identifiers translate to the same typed/deferred route and malformed LifeBoard-owned identifiers fall back without exposing an entry UUID.
  - [x] Default/open/today/weekly/done notification actions translate directly into typed foundation destinations; completion and snooze actions remain canonical mutations, and the route-bus adapter is retained only for the legacy shell behind the disabled foundation flag.
- [x] No Phase I–IV route renders a placeholder or depends on a notification bridge.
  - [x] Both internal Habit Board notification posts are replaced with direct router callbacks.
  - [x] Habit Board’s empty-state Manage action now opens a native pushed Habit Library route through `AppRoute`; the mature library adapts to the parent navigation stack rather than posting a notification or nesting another shell.
  - [x] The mature Habit Board renders as a pushed native route without a nested navigation shell.
  - [x] Core dashboard, Phase II, Plan, Track, habit-runtime, goal-sample, routine mutation, starter-pack mutation, and habit-recovery dependencies are required before `LifeOSFoundationShell` can initialize. Missing persistent/canonical services enter the existing bootstrap-recovery root; the shell’s feature/repository unavailable views and route branches were removed.
- [x] Compact capture chrome derives its content clearance from its measured height; the shared host participates in layout instead of visually overlaying destination content, and compact Home no longer duplicates the universal capture surface as a competing dashboard card.
- [x] Home never renders fabricated progress for missing, stale, or unauthorized signals.
- [x] Daypart and appearance remain independent across restoration.
- [x] Atmosphere pauses or simplifies for scene state, Low Power, thermal pressure, Reduce Motion, and Reduce Transparency.
- [ ] Compact iPhone, arbitrary iPad window sizes, and Catalyst layouts remain usable at accessibility text sizes.
  - [x] Habit Board removed its `UIScreen.main` layout fallback and uses measured width.
  - [x] At accessibility XXXL, compact root chrome switches to icon-first navigation without losing VoiceOver labels; all five roots remain reachable and expose their native identifiers, while the measured capture orb stays anchored above a bounded, scrollable action palette.
  - [ ] Complete iPad split-view and Catalyst accessibility-size verification.

### Shared interaction system

- [x] `LifeBoardMotionPolicy` resolves Reduce Motion, Reduce Transparency, Low Power, thermal, scene activity, shader capability, and Catalyst fallback.
- [x] `AsyncActionPhase` represents real progress, receipts, cancellation, and recoverable failure without timers.
- [x] Eva ink reveal is attached to the real live-output state and Journal media reveal is attached to real photo presentation.
- [ ] Replace render-to-image shader warm-up with measured asynchronous compilation or an equivalent verified no-hitch strategy.
  - [x] Hidden SwiftUI rasterization is removed; a detached utility task now loads the build-compiled default metallib, materializes all three stitchable function symbols, records duration/result, and deduplicates repeated activation requests without touching the main actor.
  - [ ] Record signed-device first-use frame timing and confirm no hitch over the 100 ms interaction budget.
- [x] Complete capture drag-selection, localized confirmation ripple, async morphing action control, and active-work-only Journal page indicator with attribution.
  - [x] The measured compact capture orb supports forgiving drag-highlight-release selection, refuses releases outside visible targets, provides direct VoiceOver capture actions, and plays a 380 ms control-clipped ripple only after a real capture request commits.
  - [x] The reusable async morphing action control reflects real cancellable Journal export state, while the restrained two-page indicator runs only during real export or index rebuild work and pauses under Reduce Motion or scene inactivity.
  - [x] The complete Apache 2.0 license, original author/project attribution, and prominent LifeBoard modification notice ship in the app bundle and are readable from Settings.

## Phase II

- [ ] Home exposes header, adaptive strip, signals, care, tasks, routines, schedule/capacity, capture, timeline, progress, Journal, and reflection without false data.
  - [x] The fixed narrative layer exposes a contextual header/daypart control, adaptive hero, honest signal rail, and the measured universal capture host; unavailable hydration distinguishes loading, setup-required, and repository-unavailable states and never renders progress outside `available`.
  - [x] The curated dashboard now gives care, tasks, routines, schedule/capacity, timeline, Journal/weekly reflection, and progress distinct reachable surfaces instead of collapsing tasks into the hero or routines into care. Every section has a stable accessibility contract and remains reachable by condition-driven scrolling in the seeded simulator journey.
  - [x] Dashboard schema v3 upgrades default layouts additively while preserving existing placement identity, size, configuration, unknown widgets, and user-customized layouts.
  - [x] Empty/load/unavailable copy is source-aware for tasks, routines, care, capacity, calendar, and signals; no missing Health/device signal is substituted with numeric zero.
  - [x] A seeded compact-iPhone journey verifies the native typed Task, Care, Day, Insights, and Journal Search transitions end to end. Cross-root taps no longer leave a typed path hidden behind the previous root, and active-root reselection deterministically returns to root while preserving inactive stacks.
  - [x] A condition-driven simulator journey selects Morning, Afternoon, Evening, and Night through the real Home menu while retaining the signal hierarchy; daypart remains independent from functional appearance by contract tests.
  - [x] Task and Journal capture mount sequential native sheets through authoritative router state, and Weekly Reflection opens its typed protected route with a 44-point full-width hit region.
  - [x] The habit-backed routine fallback opens a typed native Habit Board leaf; light and dark appearance journeys retain independent manual daypart selection and protected Journal navigation.
  - [x] The complete Home hierarchy remains reachable on the regular-width iPad Air 13-inch simulator.
  - [x] The complete hierarchy remains reachable at every UIKit content-size category through accessibility XXXL on compact iPhone, with the capture control independently hittable.
  - [ ] Repeat the complete hierarchy/action journey in constrained iPad split view.
- [x] Trackers and care support create, edit, archive/delete, correction, history, source, permission, empty, and failure states.
  - [x] Generic trackers support create/edit/archive/delete, weekday schedules, authorized recurring reminder delivery/reconciliation, quick capture, 30-entry history, and in-place value/note correction; destructive deletion removes dependent entries and archived definitions no longer leak into active UI.
  - [x] Medication supports stable-definition editing, archive/delete, scheduled reminders, 30-day event history, explicit taken/skipped/snoozed/unresolved states, and correction of status/time/note; destructive deletion removes schedules and events.
- [x] Goal and routine links use typed searchable source selection rather than raw UUID input.
  - [x] Task, canonical project, habit, routine, and tracker sources resolve to stable IDs and human-readable labels; UUID-derived project labels are removed and covered by repository tests.
- [x] Notes support typed tables, bookmarks, note links, attachments, nested folders, and persisted graph edits.
  - [x] Versioned `KnowledgeBlockPayload` metadata round-trips editable tables, bookmarks, and typed note links while decoding legacy text payloads non-destructively.
  - [x] Notes expose recursive child-folder navigation, breadcrumbs/parent navigation, parent-aware creation, folder/note moves, and deterministic cycle prevention.
  - [x] The knowledge graph supports text, folder, and tag filtering plus an explicit and VoiceOver-automatic accessible list fallback.
  - [x] Attachments persist stable protected local copies, open through Quick Look, rebuild a missing copy from the existing payload, expose retry, and remove local and persisted material together.
  - [x] Image/file blocks retain stable attachment IDs, render recoverable content, and clean up both block and attachment state together.
  - [x] Bookmark previews fetch bounded HTML metadata, cache title/summary in the typed payload, decode readable entities, and expose retry without blocking note editing.
- [x] Journal preserves existing LifeBoard entries and keeps its FTS5/vector index protected, local-only, cancellable, incrementally updated, invalidatable, and recoverable from corruption.
- [ ] Journal completes the remaining OffRecord-equivalent capture/draft, weekly reflection, export/import, and privacy-control parity.
  - [x] Journal text drafts autosave into the existing protected `JournalDraft` local entity and restore after interrupted presentation.
  - [x] Draft payload retains stable day identity, prompt, mood/energy, up to five photo payloads, audio paths, and edit position without a CloudKit schema change.
  - [x] Journal renders actual photo attachments and caps capture at five photos.
  - [x] Audio capture is save-first: protected audio and stable media/block identity commit before optional transcription; Speech failure exposes retry, manual text, keep-audio, and discard recovery without losing a successful recording.
  - [x] Journal privacy policy persists with app-switcher shielding on, sensitive ordinary-export exclusion on, and Eva evidence off by default; the Journal gate uses device-owner authentication, remains locked after cancellation, and exposes a non-destructive settings recovery path when authentication is unavailable.
  - [x] Weekly Reflection persists protected local Monday–Sunday versions with selected evidence, takeaway, dismissal/deletion, deterministic regeneration, and cancellable JSON/Markdown/CSV/PDF export; ordinary exports remove mood, energy, transcripts, media paths, source identifiers, and semantic-index data unless sensitive export is explicitly enabled.
  - [x] Journal photos support stable-ID center crop (original, square, and 4:5), quarter-turn rotation, block reorder/delete, and transactional media removal; load-time reconciliation persists repairs before deleting unreferenced protected audio and preserves every saved-day or recoverable-draft reference.
  - [x] Encrypted backup/import uses authenticated encryption, cancellable password derivation, protected files, manifest/version and path validation, tamper/wrong-passphrase rejection, stable duplicate policies, protected audio rematerialization, and transactional primary/reflection rollback.
  - [x] Exact Journal-day and weekly-reflection deep links defer behind a generic locked route, resume only after a successful session unlock, and are sanitized from visible/restorable paths on background relock.
  - [ ] Complete signed-device lock/file-protection verification.

## Phase III

- [ ] Day supports timeline and accessible agenda projections, conflicts, free windows, moves, and undo.
  - [x] Day now offers a chronological hour-grid canvas over commitments, free windows, and LifeBoard blocks, with visible conflict explanations, tap-to-reserve openings, task drop scheduling, 15-minute snapped vertical block movement, resize/split/delete/focus actions, and the existing persisted one-step undo receipts.
  - [x] VoiceOver, accessibility Dynamic Type, and Reduce Motion automatically select the fully operable linear agenda; users otherwise retain an explicit Timeline/Agenda choice.
  - [x] Day/Week/Backlog lens selection persists deterministically across termination/relaunch, rejects malformed stored values, and remains overrideable by explicit typed routes.
  - [x] A seeded compact-iPhone journey reaches the real Timeline, switches to Agenda, creates a persisted named block through the native composer, observes the receipt-backed Undo control, and consumes the receipt without fixed sleeps.
  - [ ] Execute seeded canvas drag/drop, conflict, DST/travel, relaunch, and accessibility journeys across compact iPhone and iPad split view.
- [ ] Week supports outcomes, minimum viable week, review, triage, redistribution, and the adaptive seven-day board.
  - [x] The Week overview retains capacity/deadline summaries and redistribution controls while its distinct typed planner/review routes now mount the existing persisted Weekly Operating Layer for outcomes, minimum viable week, triage, carry-forward decisions, and review instead of duplicate lightweight screens.
  - [x] Regular-width Week presents a horizontally navigable seven-day capacity board with pointer feedback and stable task drop targets; task rows drag directly across days while compact width, VoiceOver, and accessibility text retain the adaptive list board.
  - [x] Focused Week task rows accept left/right hardware-keyboard commands for cross-day movement while retaining menu and pointer alternatives.
  - [x] Compact Week, its stable day targets, planning/review entry points, and capture coexistence were exercised in the iPhone 17 Pro simulator accessibility tree without truncating the available controls.
  - [x] A dedicated regular-width iPad simulator verifies the seven-day board branch, all seven stable day targets, and the Weekly Operating Layer while confirming the compact list is not mounted.
  - [ ] Complete Catalyst and iPad split-view cross-day drag/drop verification. Current Catalyst UI automation is environment-blocked because the macOS 26.4.1 host does not satisfy the UI-test target’s macOS 26.5 deployment target; the iPad 26.5 regular-width run passes.
- [ ] Backlog supports filters, grouping, bulk mutations, archive/delete, undo, relaunch, and reconciliation.
  - [x] Search plus context/readiness/energy/duration/project filters, grouping, selection, bulk day/context/waiting/paused/someday actions, and stable receipt-backed undo remain integrated.
  - [x] Single and bulk archive now use an additive `archived` planning disposition in the existing synced task metadata; archived items form an explicit recoverable group, restore to Inbox, persist across fresh repository instances, and participate in normal Plan receipt undo.
  - [x] Single and bulk deletion require explicit confirmation and write an additive `deleted` tombstone into the existing synced task metadata. Deleted tasks leave Day/Week/Backlog and typed source pickers immediately without destroying canonical identity; the visible undo surface replays the persisted inverse receipt exactly.
  - [x] Repository tests cover repeated apply/undo, exact prior-day/disposition restoration, typed-source exclusion, and a fresh repository instance; a seeded simulator journey covers confirmation, immediate removal, undo, stable identity, a second deletion, termination, and relaunch persistence.
  - [ ] Execute offline multi-device CloudKit conflict/reconciliation journeys on signed builds.
- [x] Focus handles stale activity repair, foreground/background restoration, and notification fallback.
  - [x] Startup ends expired running sessions through the authoritative command repository and removes orphaned Live Activities.
  - [x] Foreground activation reloads persisted state; Live Activities remain projections rather than authoritative storage.
  - [x] Authorized local fallback notifications schedule only when Live Activities are unavailable and cancel on pause, end, or repair.
- [ ] Eva cites normalized evidence, exposes missing/stale sources, and applies only confirmed reversible proposals.
  - [x] The temporary canned responder is removed and the destination mounts the existing Eva activation/conversation/planner runtime.
  - [x] The mounted runtime now receives only normalized destination-authorized Track/Plan/Focus action evidence; sensitive health, medication, mood, and Journal domains remain withheld by default. Its bounded prompt contract carries stable `[LB-…]` references, explicit freshness/completeness/withheld states, sensitive-summary redaction, a no-inference rule, and confirmation-only mutation instructions without breaking planner JSON receipts.
  - [x] Settled assistant citations resolve only against the injected authorized snapshot and render as accessible evidence chips that deep-link to typed sources; private-sensitive chips use domain-only labels rather than source text.
  - [x] Eva exposes persistent, default-off opt-ins for body, mood, and medication/care evidence; the existing Journal Privacy opt-in is now connected to projection. Every explicit sensitive projection is tagged `sensitiveSummary`, and malformed consent storage recovers to all-off.
  - [ ] Verify factual citation coverage plus confirmed proposal receipts/undo end to end on a signed device with a supported local-model GPU; the simulator correctly reports the runtime as unsupported.

## Phase IV

- [x] Habits support resilience editing, pause/skip/recovery, recurrence exceptions, corrections, and 30-day history.
  - [x] The native Habit Board/detail supplies pause/resume, today complete/skip/reset correction, archive, and a measured history viewport; Track now adds stable habit-group CRUD plus per-habit group, intentional local-day exception, recovery, and grade/streak framing editors without rewriting occurrence history.
  - [x] Habit groups and resilience policies round-trip in the existing Track store; confirmed group deletion deterministically detaches policies while preserving each habit and policy.
  - [x] The resilience editor exposes explicit 30-day recovered-day mutation and undo controls. Recovery completes the canonical occurrence before persisting a stable receipt; metadata failure compensates the completion, undo restores the prior pending/skipped/missed/failed state, existing completions can be labelled without replaying gamification, and grading refuses to treat receipt-only due work as complete.
  - [x] Recovery receipts share the existing policy payload through a backwards-compatible envelope; the prior bare off-day set still decodes without a model-version or CloudKit schema change.
  - [x] A deterministic seeded simulator journey opens Track → Habit resilience → the canonical policy at accessibility XXXL, verifies recovery and Save controls, and reaches the full 30-day section without truncation or off-window geometry.
- [x] Routines and goals support typed links, progress history, stable identity, archive, and delete.
  - [x] Goal create/edit preserves stable identity and explicit links; archive and confirmed delete remove only the goal plus its links while leaving every linked source untouched.
  - [x] Routine create/edit increments immutable definition versions, preserves stable identity and schedules, blocks deletion during an active run, and supports archive/confirmed delete while retaining prior run snapshots and evidence history.
  - [x] Typed routine routes retain and display the latest 30 version-snapshotted runs even after definition removal; typed goal routes display current evidence confidence plus a 30-day derived history and resolve source labels without UUID fallbacks.
  - [x] Missing goal sources are explicit and repairable in place through the typed source picker while preserving the existing stable link identity.
- [x] Mood, hydration, sleep, and care support correction, filtering, provenance, and explicit unavailable states.
  - [x] Mood check-ins retain stable IDs through correction, support confirmed deletion, load 30 days of history, and render honest empty/light/ready trend states without interpreting missing data as neutral.
  - [x] Hydration keeps today’s total separate from 30-day history, sleep context loads 30 days, both expose 7/30-day filtering and stable-ID correction/deletion, and their normalized evidence remains private with explicit provenance.
  - [x] Health/device permission, unavailable, stale/missing, and local repository failures remain distinct; no care source substitutes numeric zero for missing data.
- [x] Track, Plan, Focus, Journal, and care changes emit normalized events with evidence, sensitivity, receipts, and reversal metadata.
  - [x] The shared projector covers habit grades, generic trackers, medication/care observations, hydration, mood, sleep, routine definitions/runs, goals, Journal days, Plan receipts, and Focus commands.
  - [x] Plan mutation events carry reversible receipt metadata and undo changes the event to `reversed` instead of erasing its history.
  - [x] Persisted Plan mutation receipts re-project into a fresh Insights process, including durable applied/reversed state, provenance, evidence, and undo metadata.
  - [x] Persisted Focus sessions re-project their durable start, pause, and completion lifecycle into a fresh Insights process with stable evidence identity and measured duration.
  - [x] Focus commands persist stable, idempotent applied/ignored receipts in the existing session payload; a fresh Insights process reconstructs pause/resume/end command evidence without making Live Activities authoritative.
  - [x] Tracker-entry, hydration, sleep-context, mood/energy, medication-event, and fasting corrections persist deterministic typed before/after receipts in protected local Application Support without changing the sync schema. A failed receipt write compensates the primary mutation, only the newest correction can be undone, a failed reversal write restores the corrected value, and normalized hydration/sleep/mood/medication/tracker evidence exposes durable reversible or reversed metadata. Synced corrections without a local receipt remain honestly non-reversible.
- [x] Insights consumes normalized authorized events and deterministic derived summaries only.
  - [x] Today/Week/System scopes expose source counts, evidence confidence, missing-domain explanations, freshness, and typed evidence navigation without reading raw domain repositories in the view.

## Hardening and promotion

- [x] Additive migration fixtures pass from every shipped schema covered by the foundation suite without stable-identity loss.
- [ ] Journal local indexes, protected media, lock recovery, redaction, backup tamper handling, and deferred deep links pass privacy tests.
  - [x] Privacy-policy defaults, persistence, and malformed-preference recovery pass a focused contract test; app-switcher shielding installs synchronously before resign-active snapshots.
  - [x] Ordinary-export redaction and encrypted-backup wrong-passphrase/tamper rejection pass focused contract tests, including idempotent keep-existing import and protected audio restoration.
  - [x] Deferred protected-route tests prove exact Journal identifiers remain out of locked restoration state, unlock resumes once, and relock returns to a generic safe route.
  - [ ] Add biometric cancellation/recovery UI automation and protected-file locked-state tests.
- [ ] Affected UI tests use condition-based waits and stable accessibility identifiers instead of fixed sleeps.
  - [x] All fixed `Thread.sleep` calls are removed from `LifeBoardUITests` and replaced with element, app-state, keyboard, sheet, or stable-frame conditions.
  - [x] Seeded foundation automation gates shell installation on the existing canonical repository seeder, so Track/Plan journeys no longer race Home presentation lifecycle.
  - [x] The compact-root/capture and Habit-resilience accessibility journeys compile and pass together on the seeded iPhone 17 Pro simulator.
  - [x] The seeded Backlog deletion/undo/relaunch journey compiles and passes without fixed sleeps.
  - [x] The seeded Home hierarchy journey reaches every curated Phase II section with stable identifiers and frame-based conditions rather than fixed sleeps.
  - [x] The seeded Day Timeline/Agenda block-create/undo journey compiles and passes using only accessibility identifiers and condition-based expectations.
  - [x] The seeded regular-width iPad Week journey compiles and passes with exact seven-day target and adaptive-branch assertions.
  - [x] Seeded Home action, sequential capture, manual-daypart, and Weekly Reflection journeys compile and pass without fixed waits; capture dismissal is asserted against authoritative sheet state and kind-specific accessibility value.
  - [x] UI reset clears application and App Group defaults, and dedicated dark-appearance, routine-fallback, and regular-width iPad Home journeys pass from isolated state.
  - [x] A condition-driven compact-iPhone matrix relaunches and verifies Home at every UIKit content-size category through accessibility XXXL, including deepest-section reachability and persistent capture access.
  - [x] The UI-test target compiles under Swift 6 with async main-actor setup/teardown and no repository-source warnings; a real seeded harness proves launch and teardown execute rather than merely type-check.
  - [ ] Compile and execute every affected UI-test journey against the seeded simulator. The current foundation journeys pass, but legacy `BaseUITest` Focus/Replan assertions still launch the pre-foundation shell and require migration to the typed Phase I–IV harness before this row can close.
- [x] Touched Phase I–IV code builds without deprecation warnings.
  - [x] App-source iOS 26 deprecations in the audited layout/replan/settings surfaces are removed; window geometry, container-relative height, view bounds, and contextual traits replace global-screen and obsolete coordinate-space access.
  - [x] Test fixtures use Swift 6-safe state capture, Core Data `performAndWait` return values, async main-actor UI-test lifecycle, contextual trait mutation, and scene geometry without project-owned deprecation or concurrency warnings.
  - [x] A clean all-target `build-for-testing` separates the four third-party MLX C++17-extension diagnostics and Xcode UI-test App Intents metadata skip from repository-source warnings; neither is hidden by project warning settings.
- [x] App, widgets, Watch app, and Watch widgets resolve marketing version through the shared `LIFEBOARD_MARKETING_VERSION` setting.
- [x] The stale tracked Xcode project backup is removed.
- [ ] Signed-device App Group, APNs, background work, biometrics, file protection, widgets, and Live Activities gates pass.
- [ ] Release flags are promoted in dependency order with rollback-compatible defaults.

## Scope guard

- [x] OffRecord is a selective Journal behavior and asset source, not a cross-app data migration.
- [x] Watch Journal, Journal widgets, full App Intents, full Eva autopilot, collaboration, runtime image generation, package extraction, and all Phase V+ work remain excluded.
