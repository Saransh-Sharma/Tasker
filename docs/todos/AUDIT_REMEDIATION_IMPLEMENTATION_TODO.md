# Audit Remediation Implementation TODO

This tracker records the concrete implementation state for the 7-phase audit remediation plan.

## Phase 1: Correctness Hotfixes

- [x] Reset cached presentation models when persistence runtime is reconfigured.
- [x] Replace unstable task-list section identity with deterministic IDs.
- [x] Submit Add Task project selection by `projectID` instead of project name.
- [x] Advance gamification persistent-history tokens only after reconciliation succeeds.
- [x] Log persistence recovery deletion failures.
- [x] Add focused regression coverage for duplicate-name project selection and task-list section IDs.

## Phase 2: Swift Concurrency And Isolation

- [x] Enable strict concurrency diagnostics while staying in Swift 5 mode.
- [x] Move app bootstrap application of persistent sync state onto the main actor.
- [x] Replace app-level `Task.detached` bootstrap with retained/structured task usage where practical.
- [x] Retain and cancel slash-command tasks in Chat.
- [x] Move cancellation checks around awaited continuation bridges in LLM context projection.
- [x] Remove `@unchecked Sendable` from `DeviceStat` and isolate it to the main actor.
- [ ] Burn down highest-signal strict-concurrency warnings exposed by diagnostics.
  - [x] Isolate LLMDataController degraded-state/shared container setup to the main actor.
  - [x] Mark UI-bound dependency-injection protocols and UIKit host controllers as main-actor isolated.
  - [x] Replace shared mutable formatter statics in logging and assistant date parsing with per-use factories.
  - [x] Replace Home render snapshot shared `empty` statics with computed factories.
  - [x] Mark LLM slash-command, chat attachment, assistant card, and core task value snapshots as `Sendable`.
  - [x] Isolate the assistant action pipeline provider to the main actor.
  - [x] Mark weekly/reflection value models surfaced by strict diagnostics as `Sendable`.
  - [x] Replace shared Core Data merge-policy singleton references with fresh `NSMergePolicy` instances.
  - [x] Replace the final unchecked LLM generation cancellation token with a checked `Synchronization.Mutex` token.
  - [x] Mark AppIntent static metadata as immutable `let` values for strict-concurrency diagnostics.
  - [x] Expand `Sendable` coverage for project, habit, occurrence, schedule, and read-query value snapshots.
  - [x] Isolate UIKit search delegate callbacks and EventKit coordinator conformance for UI-bound execution.
  - [x] Replace LLM template profile global mutable cache with `Synchronization.Mutex`.
  - [x] Replace write-gate access to `AppDelegate.persistentSyncMode` with a locked nonisolated snapshot.
  - [x] Remove typography static cache escape hatch and replace time-of-day header asset cache with `Synchronization.Mutex`.
  - [x] Replace targeted Home prewarm/onboarding `Task.sleep(nanoseconds:)` calls with duration-based `Task.sleep(for:)`.
- [x] Add chat cancellation tests for disappear/thread switching.
- [ ] Run Thread Sanitizer on chat, onboarding, and Home launch flows.
  - [x] 2026-05-18 focused TSan pass: chat cancellation, semantic concurrent indexing, Core Data write-boundary invariants, Home reload/calendar state, and LLM chat-entry prewarm selected tests passed.
  - [ ] Add a TSan UI/smoke pass for onboarding install flow and real Home launch.
  - [ ] Burn down Swift 6 warnings still emitted by unrelated test fixtures during selected simulator test builds.

## Phase 3: Persistence And Data Integrity

- [x] Remove production launch-time Core Data store deletion from the V3 bootstrap epoch path.
  - [x] Treat epoch mismatch as observe/log/recoverable state in production.
  - [x] Keep destructive state reset limited to explicit UI-test/debug reset entrypoints.
- [x] Replace silent duplicate pruning with explicit merge/repair logging and metrics.
  - [x] Keep canonical read lookups observe-only; delete duplicate rows only from explicit write-boundary upsert/repair flows.
  - [x] Split Core Data canonical lookup helpers into `canonicalReadObject` and `canonicalWriteRepairObject`.
  - [x] Throttle observe-only duplicate logs per process by entity, predicate, canonical object, and duplicate count; keep repair logs unthrottled.
  - [x] Route Reminder, Occurrence, ScheduleException, Tag, Weekly review mutation, ExternalSync map, Gamification, and TaskDefinition write-boundary canonicalization through explicit repair semantics.
  - [x] Keep WeeklyPlan/WeeklyReview fetch paths observe-only.
- [x] Replace fallback UUID/date creation in task snapshots with validation and explicit repair paths.
- [x] Add schema/versioning strategy for SwiftData LLM chat store.
- [x] Add schema/versioning strategy for SwiftData reflection stores.
- [x] Surface user-visible degraded state when LLM SwiftData falls back to temporary/in-memory storage.
- [x] Add app-level uniqueness checks for CloudKit-backed project names at the repository write boundary.
- [x] Add app-level uniqueness checks for any remaining CloudKit-backed entities without Core Data constraints.
  - [x] Add CloudKit identity matrix for current `TaskModelV3` syncable entities.
  - [x] Add write-boundary validation/canonicalization for LifeArea names, ProjectSection names, Occurrence keys, ScheduleException keys, and Reminder source/policy identity.
- [x] Add migration and malformed-row tests.
  - [x] Add non-destructive SwiftData migration/disposition tests for LLM chat schema mismatch.
  - [x] Add reflection SwiftData schema and in-memory fallback tests.
  - [x] Add repository duplicate-name write-boundary regression for CloudKit-backed project names.
  - [x] Add malformed/duplicate repository invariant tests for remaining Phase 3 identity boundaries.
  - [x] Add Core Data fresh-install and historical `TaskModelV3` migration coverage using temporary SQLite stores.
  - [x] Add guard coverage that active CloudKit-backed entities have no Core Data uniqueness constraints.
  - [x] Add historical whitespace/case-folded duplicate-row tests for LifeArea, ProjectSection, and Tag.

### CloudKit Identity Matrix

Core Data uniqueness constraints stay out of CloudKit-backed entities; identities below are enforced at repository write boundaries or repair/canonicalization flows.

| Entity | Classification | App-level identity |
| --- | --- | --- |
| LifeArea | business-unique | Active normalized `name` globally. |
| Project | business-unique | Active normalized `name` globally, plus fixed Inbox ID. |
| ProjectSection | business-unique | Normalized `name` within `projectID`. |
| Tag | business-unique | Normalized `name` globally, canonicalized on create. |
| TaskDefinition | id-only | Stable `id`/`taskID`; malformed optional fields repaired explicitly. |
| TaskDependency | derived/canonicalized | `(taskID, dependsOnTaskID, kind)`. |
| TaskTagLink | derived/canonicalized | `(taskID, tagID)`. |
| WeeklyPlan | id-only | Stable `id`; queried by `weekStartDate`. |
| WeeklyOutcome | id-only | Stable `id`; ordered within `weeklyPlanID`. |
| WeeklyReview | id-only | Stable `id`; associated to `weeklyPlanID`. |
| ReflectionNote | id-only | Stable `id`; linked IDs are optional references. |
| HabitDefinition | id-only | Stable `id`; title validation only. |
| ScheduleTemplate | id-only | Stable `id`; source references are validated. |
| ScheduleRule | id-only | Stable `id`; owned by `scheduleTemplateID`. |
| ScheduleException | derived/canonicalized | `(scheduleTemplateID, canonical occurrenceKey)`. |
| Occurrence | derived/canonicalized | Canonical `occurrenceKey`. |
| OccurrenceResolution | id-only | Stable `id`; validates `occurrenceID`. |
| Reminder | derived/canonicalized | `(sourceType, sourceID, occurrenceID, policy)`. |
| ReminderTrigger | id-only | Stable `id`; validates `reminderID`. |
| GamificationProfile | id-only | Stable `id`. |
| XPEvent | business-unique | `idempotencyKey`. |
| AchievementUnlock | id-only | Stable `id`. |
| DailyXPAggregate | business-unique | `dateKey`. |
| FocusSession | id-only | Stable `id`; queried by `startedAt`. |
| ExternalContainerMap | derived/canonicalized | `(provider, projectID)`. |
| ExternalItemMap | derived/canonicalized | `(provider, localEntityType, localEntityID)` and `(provider, externalItemID)`. |
| Tombstone | id-only | Stable `id`; payload identifies deleted entity. |
| AssistantActionRun | id-only | Stable `id`. |

## Phase 4: Home Architecture Decomposition

- [x] Extract `HomeNavigationCoordinator`.
  - [x] Move notification route decisions into `HomeNavigationCoordinator` with delegate-backed presentation.
  - [x] Keep deep-link and notification parsing in `HomeNavigationEventAdapter` and remove stale persistent-sync navigation path.
  - [x] Add adapter coverage for route payloads, chat prompts, task/project IDs, habit detail, and invalid payload no-op behavior.
- [x] Extract `HomeReloadCoordinator`.
  - [x] Move Home task mutation chart-refresh debounce and search invalidation into `HomeReloadCoordinator`.
  - [x] Move Home reload notification parsing into `HomeReloadEventAdapter`.
  - [x] Add typed reload adapter coverage for task mutation, app-active, time-change, workspace preference, persistent-sync, calendar, habit, and gamification invalidations.
- [x] Extract Needs Replan view model/use-case boundary.
  - [x] Promote Needs Replan session state ownership into `HomeNeedsReplanCoordinator` and route `HomeReplanSessionState` derivation through it.
  - [x] Move Needs Replan applying/error, skipped-review, dismissal, passive tray, resolution, and undo state transitions into `HomeNeedsReplanCoordinator`.
- [x] Extract pure timeline snapshot projection builder.
  - [x] Add explicit `HomeTimelineSnapshotProjectionInput` with injected `now` and `Calendar`.
  - [x] Move the remaining timeline snapshot body out of `HomeViewModel` into a value-only `HomeTimelineSnapshotProjectionBuilder`.
- [x] Replace broad NotificationCenter mutation handling with typed domain event adapters.
- [x] Move test seeding out of `HomeViewController.viewDidAppear`.
  - [x] Introduce `UITestWorkspaceSeeder` as the named service boundary behind `HomeLaunchHarnessService`.
- [x] Add internal Home architecture protocol boundaries.
  - [x] Define seams for reload orchestration, timeline projection, habit actions, calendar state, search coordination, and widget snapshot writing.
  - [x] Wire existing `HomeViewModel`, `HomeSearchEngineAdapter`, and `TaskListWidgetSnapshotService` conformance without changing runtime behavior.
- [ ] Split `AppOnboarding.swift` into state/store, catalog/copy, eligibility/guidance, flow model, coordinator, demo/theme, and SwiftUI view files.

## Phase 5: Query And Performance Work

- [ ] Move Needs Replan candidate selection into repository-level predicates/projections.
  - [ ] Define `NeedsReplanCandidateProjection` value model with IDs, dates, completion state, review metadata, and lightweight display fields.
  - [ ] Add repository fetch methods that apply due/scheduled/completion/review predicates before materializing domain models.
  - [ ] Add projection tests for overdue, today, snoozed, completed, deleted, and malformed historical rows.
  - [ ] Wire `HomeNeedsReplanCoordinator` to projections while preserving current review/apply/undo behavior.
- [ ] Reduce Home timeline builder main-thread work.
  - [x] Move snapshot assembly from `HomeViewModel` into `HomeTimelineSnapshotProjectionBuilder.build(input:cached:)`.
  - [ ] Make repository projection fetches return sorted/grouped timeline inputs where safe.
  - [ ] Run timeline builder determinism tests with fixed `now`, calendar, preferences, hidden-event state, and replan state.
  - [ ] Profile selected-day timeline build before/after with `LifeBoardPerformanceTrace` intervals.
- [ ] Add or verify Core Data fetch indexes for Home projection predicates.
  - [ ] Audit indexes for due date, scheduled date, completion/deleted state, project ID, occurrence key, and updated-at query paths.
  - [ ] Add migration/codegen guard coverage that index changes do not introduce CloudKit uniqueness constraints.
  - [ ] Capture before/after fetch counts and wall-clock timing on representative Home reload fixtures.
- [ ] Reduce `UIHostingController` churn in Home.
  - [ ] Inventory hosts remounted during Home face changes, chat presentation, settings surfaces, and Add Task flows.
  - [ ] Retain hosts where the view identity is stable and update root state instead of remounting.
  - [ ] Add lifecycle tests that assert host reuse across reload/filter/navigation paths.
- [ ] Gate LLM/search/insights prewarm by device, memory pressure, thermal state, and recent usage.
  - [x] Add `LLMPrewarmEligibilityPolicy` for device class, memory budget, thermal state, low-power mode, active sessions, recent usage, readiness, unsupported models, and cancellation.
  - [x] Add policy tests for healthy, stale, thermal, low-power, and active-session pressure cases.
  - [ ] Extend the same policy shape or sibling policies to semantic search and insight prewarm.
- [ ] Add performance baselines for launch, Home, filtering, timeline, Add Task, search, and chat.
  - [ ] Normalize existing `LifeBoardPerformanceTrace` and MetricKit events into a baseline report format.
  - [ ] Record launch critical path, first Home frame, Home reload, timeline build, filter query, Add Task save, semantic search activation, and chat prewarm/load.
  - [ ] Store baseline artifacts under `docs/audits/` with device/simulator, OS, build config, and sample count.

## Phase 6: SwiftUI Screen Cleanup

- [ ] Split oversized SwiftUI files into models, containers, sections, rows, and formatting helpers.
  - [ ] Split `AppOnboarding.swift` first: state/store, catalog/copy, eligibility/guidance, flow model, coordinator, demo/theme, and views.
  - [ ] Split Home shell/timeline surfaces by container, row, chrome, formatter, layout helper, and interaction ownership.
  - [ ] Split chat and settings surfaces only after their snapshot/accessibility coverage exists.
- [ ] Remove unnecessary `AnyView` in task-list headers/footers and chat hosts.
  - [ ] Replace onboarding, agenda row, chat host, task-list header/footer, and presentation-surface `AnyView` with `@ViewBuilder`, generics, or concrete wrappers.
  - [ ] Add compile-time smoke tests for the extracted concrete wrappers where practical.
- [ ] Replace formatter creation in view helpers with cached formatters or `FormatStyle`.
  - [x] Move Add Habit month/feedback labels from shared mutable `DateFormatter` statics to `FormatStyle`.
- [ ] Replace raw `.font(.system...)`, raw `UIColor` bridges, and ad-hoc `.shadow` until `scripts/token-law-guardrails.sh` passes.
  - [ ] Convert raw fonts to Dynamic Type-compatible design tokens.
  - [ ] Move remaining hex/UIColor bridges into design-system color tokens or explicit domain palette helpers.
  - [ ] Replace ad-hoc shadows with design-system elevation tokens.
- [ ] Make compact controls meet 44x44 minimum hit targets.
  - [ ] Convert decorative `onTapGesture` controls to `Button` where they trigger actions.
  - [ ] Add accessibility tests for VoiceOver labels, traits, Reduce Motion, and minimum hit area on compact controls.
- [ ] Move heavy view-model side effects out of initializers into explicit `start()`/`load()` methods.
  - [ ] Inventory initializers that perform fetches, subscribe to notifications, start timers, or launch tasks.
  - [ ] Move side effects behind idempotent lifecycle methods and update UIKit/SwiftUI owners to call them explicitly.
- [ ] Add snapshot and accessibility coverage for major screens.
  - [ ] Cover Home, onboarding, Add Task, chat, settings, timeline, habit, and weekly planning surfaces.

## Phase 7: Rollout, Monitoring, And Cleanup

- [ ] Add MetricKit or existing telemetry checkpoints for performance baselines.
  - [x] Existing MetricKit subscriber and `LifeBoardPerformanceTrace` cover launch, Home render/search, Add Task open, task detail open, calendar projection, Home filtering, and notification reconciliation checkpoints.
  - [ ] Add missing checkpoints for timeline builder duration, Add Task save duration, semantic-index activation, chat prewarm/load, persistence repair outcomes, and SwiftData degraded-mode events.
- [ ] Add diagnostics for persistence repair, duplicate merges, SwiftData degraded mode, Home reload timing, and chat cancellation.
  - [x] Log duplicate Core Data row repair.
  - [x] Log malformed task row repair.
  - [x] Log and surface SwiftData degraded chat storage.
  - [x] Emit Home task mutation chart refresh trace events.
  - [x] Log chat generation/slash-command cancellation.
- [ ] Remove dead hooks after coordinator extraction.
  - [x] Add `scripts/check-xcode-target-membership.sh` guardrail for Swift files missing from `LifeBoard.xcodeproj`.
  - [x] Add explicit allowlist for known orphan/dead-code investigation candidates, including presentation model, mesh, pulse, and test files.
- [x] Document new architecture boundaries and async bridge rules.
  - [x] Document Home reload/navigation adapters, timeline projection builder, Core Data identity validation, async bridge cancellation rules, and LLM prewarm policy in `docs/audits/audit-remediation-boundaries-2026-05-18.md`.
- [ ] Move all targets to Swift 6 mode after strict-concurrency diagnostics are clean.
  - [x] Move production app, widget, and watch targets to Swift 6 mode while keeping complete strict concurrency.
  - [x] Move unit/UI test targets to Swift 6.
    - [x] Add `LockedTestState<Value>` under `LifeBoardTests/TestSupport`.
    - [x] Migrate first-pass mutable test doubles in `V3TestHarness.swift`, `DeleteTaskDefinitionUseCaseTests.swift`, `CalendarTestSupport.swift`, and high-fanout `LifeBoardTests.swift` doubles.
    - [x] Clear Swift 6 compile blockers in remaining unit-test callback accumulators, Core Data fixture helpers, and UI test key-path usages.
    - [ ] Burn down remaining UI-test XCTest lifecycle isolation warnings; latest `build-for-testing` passes with 73 first-party warnings, concentrated in `setUpWithError` overrides that touch `XCUIApplication`/page objects.
  - [ ] Reduce or justify the remaining app `@unchecked Sendable` inventory. Current app count on 2026-05-18: 167.
  - [ ] Keep test targets in Swift 6 language mode and finish warning burn-down before treating `build-for-testing` as a zero-warning gate.

## Verification Log

- [x] 2026-05-18 `git diff --check` clean.
- [x] 2026-05-18 `scripts/check-no-print-logs.sh` passed.
- [x] 2026-05-18 XcodeBuildMCP simulator build passed with no warnings.
- [x] 2026-05-18 focused simulator tests passed: 115 tests across chat cancellation, LLM runtime coordinator, semantic retrieval, Home calendar/timeline, Home lifecycle, and V2 repository invariants.
- [x] 2026-05-18 focused TSan simulator tests passed: 33 tests across chat cancellation, semantic concurrent indexing, Core Data write-boundary invariants, Home reload/calendar state, and LLM chat-entry prewarm.
- [ ] 2026-05-18 `scripts/token-law-guardrails.sh` still fails; remaining failures are raw `UIColor` bridges, raw `.font(.system...)`, and ad-hoc shadows across UI modules.
- [x] 2026-05-18 production Swift 6 simulator build passed after replacing deprecated `@UIApplicationMain` with `@main`.
- [x] 2026-05-18 production Swift 6 Debug simulator build passed with no warnings after fixing the Core Data remote-change main-actor observer crash and `LLMContextProjectionService` generic `Sendable` warning.
- [x] 2026-05-18 production Swift 6 Release simulator build passed; remaining warnings were third-party MLX C++ `constexpr if` and AppIntents metadata processor warnings.
- [x] 2026-05-18 `LifeBoardWidgets` Debug/Release simulator builds passed; previous containing-app/extension version mismatch warning is gone after aligning `CURRENT_PROJECT_VERSION = 2` and `MARKETING_VERSION = 1.9.5`.
- [x] 2026-05-18 `LifeBoardWatch` Debug/Release watchOS simulator builds passed on Apple Watch Series 11 (46mm), watchOS 26.2.
- [x] 2026-05-18 `LifeBoardWatchWidgets` Debug/Release watchOS simulator builds passed on Apple Watch Series 11 (46mm), watchOS 26.2.
- [x] 2026-05-18 focused simulator tests passed for canonical read-only duplicate observation and write-boundary duplicate repair.
- [x] 2026-05-18 full `V2RepositoryInvariantTests` simulator suite passed: 22 tests, including duplicate observe/repair coverage for Core Data repository boundaries.
- [x] 2026-05-18 affected test-migration simulator tests passed: `HomeViewModelFocusSessionThreadingTests` and `AssistantPipelineTransactionalTests`.
- [x] 2026-05-18 Swift 6 test-target compile blockers cleared; `build-for-testing` succeeds for `LifeBoardTests` and `LifeBoardUITests`.
- [ ] 2026-05-18 Swift 6 test-target warning burn-down remains open: latest `build-for-testing` emits 73 first-party UI-test lifecycle isolation warnings plus the expected AppIntents metadata processor warning.
- [x] 2026-05-18 Debug simulator app build passed with zero warnings.
- [x] 2026-05-18 target-membership guard passed with the current known-orphan allowlist.
- [x] 2026-05-18 Debug simulator app build passed after the Home boundary, target-membership, and Swift 6 cache/sleep hardening tranche.
