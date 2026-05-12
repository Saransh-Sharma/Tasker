# Notification Recovery TODO (P0/P1/P2 Closeout)

- [x] `P0.1` Make notification action handling completion-safe (`AppDelegate` + completion-aware action handler with one-shot completion gate + timeout fallback)
- [x] `P1.1` Make reconcile idempotent/content-aware (`added/updated/removed/unchanged` diff and fingerprint compare)
- [x] `P1.2` Generate one due-soon nudge per window (primary + additional-count copy)
- [x] `P1.3` Extend schedule horizon (overdue today+tomorrow slots; daily today+2 days)
- [x] `P1.4` Stop auto-opening task detail for `.homeToday(taskID:)` route
- [x] `P1.5` Include `task.snooze.*` in managed reconciliation + task-bound cancellation cleanup
- [x] `P2.1` Harden typed-notification protocol defaults (remove unsafe UUID fallback behavior)
- [x] `P2.2` Expand unit tests for completion callback, diff reconciliation, due-soon dedupe, horizon coverage, route semantics, snooze cleanup
- [x] `P2.3` Documentation updates
- [x] Root `README.md` notification strategy section (product + technical decisions)
- [x] New architecture spec `docs/architecture/notifications-local-strategy-v3.md`
- [x] Docs indexes updated (`docs/README.md`, `docs/architecture/README.md`, README catalog row)

## Daily Summary Notification Modals (Morning + Nightly)

- [x] Add new notification route enum support (`LifeBoardDailySummaryKind` + `.dailySummary(kind:dateStamp:)`)
- [x] Add route payload encode/decode support (`daily_summary:<kind>:<yyyyMMdd>`)
- [x] Route morning/nightly scheduled notifications to `.dailySummary(...)`
- [x] Add summary models (`SummaryTaskRow`, `MorningPlanSummary`, `NightlyRetrospectiveSummary`, `DailySummaryModalData`)
- [x] Add summary aggregation use case (`GetDailySummaryModalUseCase`) with deterministic ranking
- [x] Add `HomeViewModel` entrypoints for loading summary, tracking modal/CTA/action events, and end-of-day cleanup wrapper
- [x] Update `HomeViewController` route handling to present a custom daily-summary sheet
- [x] Implement Morning Plan modal sections + CTA wiring
- [x] Implement Nightly Retrospective modal sections + CTA wiring
- [x] Add accessibility identifiers for modal root, hero metrics, task rows, and CTAs
- [x] Add unit coverage for route payload roundtrip and summary derivation
- [x] Extend orchestrator tests to assert daily route targets for morning/nightly requests

## Stabilization + Fixes Added In This Pass

- [x] Wire `LifeBoardTests/TestSupport/V3TestHarness.swift` into `LifeBoardTests` target (`project.pbxproj`)
- [x] Fix test compile regressions in `LifeBoardTests.swift`
- [x] Fix task initializer argument order for `recurrenceSeriesID` and `isComplete/isEveningTask`
- [x] Fix optional fire-date assertion in snooze test
- [x] Add launch-route helper defaults for UI tests (`skip onboarding`, `disable cloud sync`)
- [x] Add UIKit-level accessibility identifier on daily-summary hosting view (`home.dailySummaryModal`)
- [x] Add fallback daily-summary presentation path when summary loading fails (show modal with zero-state data instead of dropping route)

## Notification Personalization + Quiet Hours (This Pass)

- [x] Extend notification preferences model with advanced personalization fields:
  - due-soon lead time (`15/30/45/60/90/120`)
  - quiet-hours start/end
  - quiet-hours apply-to-task-alerts toggle
  - quiet-hours apply-to-daily-summaries toggle
- [x] Add backward-compatible preference decoding defaults + store migration (`v1` -> `v2` key fallback)
- [x] Apply quiet-hours enforcement in orchestrator scheduling for task alerts and daily summaries (based on per-category toggles)
- [x] Apply quiet-hours enforcement to snoozed notifications in action handler
- [x] Make due-soon scheduling use configurable lead-time from preferences
- [x] Refactor Settings into dedicated notification sections:
  - `Notification Types`
  - `Notification Schedule & Quiet Hours`
- [x] Add quiet-hours controls to Settings:
  - enable/disable toggle
  - quiet start / quiet end pickers
  - apply-to-task-alerts toggle
  - apply-to-daily-summaries toggle
- [x] Add due-soon lead-time picker to Settings
- [x] Keep permission row integrated with new sections + disabled-state behavior
- [x] Trigger reconcile on all relevant notification personalization changes
- [x] Add unit tests for:
  - configurable due-soon lead-time
  - quiet-hours deferral for task reminders
  - quiet-hours deferral for daily summaries
  - quiet-hours-aware snooze behavior

## Verification Log

- [x] `xcodebuild -workspace LifeBoard.xcworkspace -scheme "LifeBoard" -destination 'generic/platform=iOS Simulator' build-for-testing` succeeded once after fixes (test compile unblocked)
- [x] `xcodebuild test-without-building ... -only-testing:LifeBoardTests/TaskNotificationOrchestratorTests -only-testing:LifeBoardTests/LifeBoardNotificationActionHandlerTests` succeeded (11 tests, 0 failures)
- [ ] `xcodebuild test-without-building ... -only-testing:LifeBoardUITests/DailySummaryModalTests` still failing (modal not detected in UI tests)
- [ ] Rebuild reliability issue remains in this environment: intermittent `AssetCatalogSimulatorAgent/CoreSimulator` failures while building pods asset catalogs
- [x] `xcrun swiftc -frontend -parse` on updated files:
  - `LifeBoard/Domain/Interfaces/NotificationServiceProtocol.swift`
  - `LifeBoard/Services/LocalNotificationService.swift`
  - `LifeBoard/ViewControllers/SettingsPageViewController.swift`
  - `LifeBoardTests/LifeBoardTests.swift`
- [ ] Full simulator `xcodebuild test` for latest quiet-hours changes still pending (workspace dependency build is long-running in this environment)
