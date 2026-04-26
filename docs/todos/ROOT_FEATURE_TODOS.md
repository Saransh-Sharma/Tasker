# Root Feature TODO Tracker

Consolidated from former project-root TODO files on March 31, 2026. Keep feature and refactor trackers here instead of the project root.

## Life Management Console Overhaul

Source: `.codex-task-list.md`

- [x] Extend habit domain/runtime data for unified appearance and lifecycle
- [x] Add destructive-flow coordinator for safe reassignment deletes
- [x] Refactor `LifeManagementViewModel` to scope-based state and actions
- [x] Rebuild `LifeManagementView` into overview/areas/projects/habits/archive console
- [x] Update DI and supporting UI entrypoints for habit detail/create routing
- [x] Polish Life Management accessibility, copy, adaptive layouts, and habit-flow presentation
- [x] Add and update tests for data, view model, and lifecycle flows
- [x] Redesign Life Management add area and add project flows as adaptive composers

## Analytics Insights Overhaul

Source: `ANALYTICS_INSIGHTS_OVERHAUL_TODO.md`

- [x] Wire `InsightsViewModel` to task, reminder, and analytics dependencies.
- [x] Add rich projection models for Today, Week, and Systems analytics.
- [x] Redesign `InsightsTodayView` with richer cards, charts, and action-first copy.
- [x] Redesign `InsightsWeekView` with momentum, mix, leaderboard, and trend modules.
- [x] Redesign `InsightsSystemsView` with system-health modules and progression framing.
- [x] Update Home/DI integration for the new insights dependencies.
- [x] Expand unit coverage for projections and refresh behavior.
- [ ] Run targeted tests for insights and validate build health.

## Analytics Performance Remediation

Source: `PERF_ANALYTICS_REMEDIATION_TODO.md`

- [x] 1) Isolate analytics recomposition surface in Home
- [x] 2) Refactor Insights refresh policy to lazy per-tab with event-driven in-flight guards
- [x] 3) Coalesce XP mutation refreshes (debounced)
- [x] 4) Move gamification read IO off main thread and make reads non-destructive
- [x] 5) Fix weekly tab diff identity and micro-inefficiencies
- [x] 6) Replace geometry-heavy progress/bar layouts with fixed-cost layouts
- [x] 7) Guard Home preference writes and remove non-essential height animations
- [x] 8) Add accessibility/testability hooks for insights performance
- [x] 9) Add focused regression + perf tests
- [x] 10) Build and build-for-testing verification

## Calendar + Timeline Documentation Refresh

Source: `docs/calendar/README.md`

- [x] Create the canonical calendar + timeline documentation package
- [x] Document the read-only schedule-context contract and timeline terminology
- [x] Document runtime contracts for authorization, selection, refresh, and derived projections
- [x] Document calendar and timeline risks, non-goals, and phased roadmap
- [x] Link the package from the root README and docs index
- [x] Link the package from the product requirements document
- [ ] Review markdown links and confirm no stale duplicate calendar/timeline contract docs remain

## Home Rescue Follow-Through

Source: `TODO.home-rescue-followthrough.md`

- [ ] Fix Add Task UI automation save/create path so Home UI suites are runnable again
- [x] Add Rescue page-object coverage in `To Do ListUITests/PageObjects/HomePage.swift`
- [x] Add Rescue UI tests for header visibility, collapsed preview rows, expand/collapse, and `Start rescue`
- [x] Reset Rescue expansion override when Rescue state meaningfully changes
- [x] Gate Rescue band and CTA consistently with the Rescue feature flag
- [x] Localize new Rescue strings
- [x] Remove legacy overdue-header rescue action path from shared task list surfaces
- [x] Implement Focus Now replace/promote flow from Today Agenda
- [ ] Add restrained Rescue/Focus motion polish with Reduce Motion support
- [ ] Run targeted unit tests, Rescue UI tests, and blocked Home UI suites

## XP Correctness And Analytics Performance V4

Source: `XP_CORRECTNESS_ANALYTICS_V4_TODO.md`

- [x] Add canonical post-commit ledger mutation notification + payload (`gamificationLedgerDidMutate`).
- [x] Emit ledger mutation from `GamificationEngine.recordEvent` after persistence paths (success + idempotent/no-op).
- [x] Route Home gamification state updates from ledger mutation payloads instead of early task mutation timing.
- [x] Route Insights updates from ledger mutation payloads with incremental projection updates.
- [x] Remove stale-read races by resetting gamification read context after each write completion.
- [x] Fix reflection UX no-op path: keep sheet open on `0 XP` and show explicit already-completed state.
- [x] Remove duplicate mutation triggers where canonical ledger mutation already covers refresh.
- [x] Avoid redundant post-focus/post-reflection gamification fetches (`loadDailyAnalytics(includeGamificationRefresh: false)`).
- [x] Add regression coverage for read-after-write freshness and ledger-mutation projection updates.
- [x] Add HomeViewModel regression coverage for ledger mutation notification state propagation.
- [x] Fix streak ordering in `GamificationEngine`: emit ledger mutation after streak update completes.
- [x] Add regression test verifying ledger mutation streak reflects post-update streak state.
- [ ] Full manual smoke audit: task completion XP, reflection first/second claim UX, insights tab values, top nav pie, widget snapshot freshness.
- [ ] Full UI perf audit on seeded data set (rapid tab switch + per-tab scroll + mutation burst).

## XP Live Update And Core Data Write Loop V5

Source: `XP_LIVE_UPDATE_CORE_DATA_V5_TODO.md`

- [x] Replace raw remote-change reconciliation trigger with persistent-history coordinator.
- [x] Filter reconciliation to qualified CloudKit import transactions only.
- [x] Coalesce burst remote-change notifications into one trailing reconciliation pass.
- [x] Remove direct `fullReconciliation()` call from `handlePersistentStoreRemoteChange`.
- [x] Minimize reconciliation writes (skip unchanged profile / unchanged daily aggregates).
- [x] Avoid `updatedAt` rewrites when business values are unchanged.
- [x] Keep canonical profile/aggregate semantics in repository.
- [x] Reset read context after write completion to prevent stale read-after-write snapshots.
- [x] Add Home ledger-mutation watchdog fallback for missed in-session mutation events.
- [x] Add reflection preflight (`isCompletedToday`) and explicit already-completed UX state.
- [x] Fix non-blocking notification dispatch (`TaskNotificationDispatcher` main async off-main).
- [x] Add partial-write recovery in `GamificationEngine.recordEvent` (reconcile + replay mutation).
- [x] Add regression test for post-event aggregate-write failure recovery path.
- [x] Crash hardening: disable CloudKit mirroring in simulator/XCTest runtime to avoid entitlement trap.
- [x] Validate build gate: `xcodebuild -workspace Tasker.xcworkspace -scheme "To Do List" build`.
- [x] Validate build-for-testing gate: `xcodebuild -workspace Tasker.xcworkspace -scheme "To Do List" -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO build-for-testing`.
- [x] Validate targeted test gate: `xcodebuild ... test -only-testing:TaskerTests/GamificationEngineMutationOrderingTests`.
- [ ] Manual smoke: task complete XP, reflection first/second claim, top pie + insights live updates.
- [ ] Manual smoke: verify no WAL checkpoint flood during idle/normal completion flow.
- [ ] Add remote-change coordinator unit tests (author filter + token progression + coalescing).
- [ ] Add end-to-end UI launch regression for simulator/test runtime CloudKit-disabled path.

## Habit Board Rehaul V1

- [x] Add board-specific habit presentation models and streak semantics
- [x] Rebuild Home habit rows around board-first collapsed and expanded layouts
- [x] Add Home habit section header cards with Recovery and Quiet Tracking grouping
- [x] Add full-screen Habit Board surface with streak/count summary modes
- [x] Upgrade habit appearance editing with palette-first accent selection
- [x] Add focused unit coverage for board mapping semantics
- [ ] Add dedicated UI automation for board rows and Habit Board interactions
- [x] Run targeted build and test verification for Habit Board surfaces

## Weekly Operating Layer Integration

Source: `00_PRD_tasker_weekly_planning_reflection_combined_spec.pdf`

- [x] Extend task/project domain models, requests, and read queries with weekly and motivation fields
- [x] Add weekly domain entities plus repository contracts and dependency registration
- [x] Create and register the real `TaskModelV3_WeeklyPlanning` Core Data version
- [x] Update persistent bootstrap migration path from `TaskModelV3_Habits` to `TaskModelV3_WeeklyPlanning`
- [x] Add mapper/repository/read-model support and post-bootstrap planning-bucket backfill
- [x] Implement weekly planner, weekly review, momentum, capacity, and reflection use cases
- [x] Add Home weekly summary card and planner/review presentation entry points
- [x] Extend Add Task, Task Detail, and Project Management surfaces for weekly planning and motivation
- [x] Build dedicated weekly planner/review/reflection SwiftUI screens with adaptive layouts
- [x] Extend Insights Week, gamification events, and Eva weekly proposal plumbing
- [x] Add focused weekly unit and repository coverage for planner save semantics, transactional review completion, draft-store round trip, recovery insights, AI proposal, and XP category behavior
- [x] Run targeted app build and focused weekly unit validation
- [ ] Add migration regression coverage for `Habits -> WeeklyPlanning` bootstrap upgrades
- [ ] Add broader weekly view-model and UI regression coverage
- [ ] Run migration validation and weekly UI validation flows
