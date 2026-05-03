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
- [ ] Add chat cancellation tests for disappear/thread switching.
- [ ] Run Thread Sanitizer on chat, onboarding, and Home launch flows.

## Phase 3: Persistence And Data Integrity

- [x] Replace silent duplicate pruning with explicit merge/repair logging and metrics.
- [x] Replace fallback UUID/date creation in task snapshots with validation and explicit repair paths.
- [x] Add schema/versioning strategy for SwiftData LLM chat store.
- [x] Add schema/versioning strategy for SwiftData reflection stores.
- [x] Surface user-visible degraded state when LLM SwiftData falls back to temporary/in-memory storage.
- [x] Add app-level uniqueness checks for CloudKit-backed project names at the repository write boundary.
- [ ] Add app-level uniqueness checks for any remaining CloudKit-backed entities without Core Data constraints.
- [ ] Add migration and malformed-row tests.
  - [x] Add non-destructive SwiftData migration/disposition tests for LLM chat schema mismatch.
  - [x] Add reflection SwiftData schema and in-memory fallback tests.
  - [x] Add repository duplicate-name write-boundary regression for CloudKit-backed project names.

## Phase 4: Home Architecture Decomposition

- [ ] Extract `HomeNavigationCoordinator`.
  - [x] Move notification route decisions into `HomeNavigationCoordinator` with delegate-backed presentation.
- [ ] Extract `HomeReloadCoordinator`.
  - [x] Move Home task mutation chart-refresh debounce and search invalidation into `HomeReloadCoordinator`.
- [ ] Extract Needs Replan view model/use-case boundary.
- [ ] Extract pure timeline snapshot projection builder.
- [ ] Replace broad NotificationCenter mutation handling with typed domain event adapters.
- [ ] Move test seeding out of `HomeViewController.viewDidAppear`.

## Phase 5: Query And Performance Work

- [ ] Move Needs Replan candidate selection into repository-level predicates/projections.
- [ ] Reduce Home timeline builder main-thread work.
- [ ] Add or verify Core Data fetch indexes for Home projection predicates.
- [ ] Reduce `UIHostingController` churn in Home.
- [ ] Gate LLM/search/insights prewarm by device, memory pressure, thermal state, and recent usage.
- [ ] Add performance baselines for launch, Home, filtering, timeline, Add Task, search, and chat.

## Phase 6: SwiftUI Screen Cleanup

- [ ] Split oversized SwiftUI files into models, containers, sections, rows, and formatting helpers.
- [ ] Remove unnecessary `AnyView` in task-list headers/footers and chat hosts.
- [ ] Replace formatter creation in view helpers with cached formatters or `FormatStyle`.
  - [x] Move Add Habit month/feedback labels from shared mutable `DateFormatter` statics to `FormatStyle`.
- [ ] Make compact controls meet 44x44 minimum hit targets.
- [ ] Move heavy view-model side effects out of initializers into explicit `start()`/`load()` methods.
- [ ] Add snapshot and accessibility coverage for major screens.

## Phase 7: Rollout, Monitoring, And Cleanup

- [ ] Add MetricKit or existing telemetry checkpoints for performance baselines.
- [ ] Add diagnostics for persistence repair, duplicate merges, SwiftData degraded mode, Home reload timing, and chat cancellation.
  - [x] Log duplicate Core Data row repair.
  - [x] Log malformed task row repair.
  - [x] Log and surface SwiftData degraded chat storage.
  - [x] Emit Home task mutation chart refresh trace events.
  - [x] Log chat generation/slash-command cancellation.
- [ ] Remove dead hooks after coordinator extraction.
- [ ] Document new architecture boundaries and async bridge rules.
- [ ] Move to Swift 6 mode after strict-concurrency diagnostics are clean.
