# Sunrise Glass Presentation Migration TODO

Scope: main iOS app presentation layer. Onboarding screens stay, but onboarding-launched task, habit, and detail sheets must use Sunrise Glass.

## Route Migration

- [x] Keep Home, Schedule, Add Task, Task Detail, Habit Detail, and Insights on active Sunrise surfaces.
- [x] Replace onboarding task creation with `SunriseAddTaskSheetView`.
- [x] Replace onboarding habit creation with `SunriseAddHabitSheetView`.
- [x] Replace habit library and life management habit creation with `SunriseAddHabitSheetView`.
- [x] Replace old weekly planner/review visuals with Sunrise equivalents.
- [x] Replace daily reflection and focus visuals with Sunrise equivalents.
- [x] Replace project management creation and legacy UIKit project screen with Sunrise equivalents.
- [x] Finish Sunrise settings, chat, and search cleanup.

## Deletion Gates

- [x] `AddTaskSheetView`, `AddItemComposerView`, `AddTaskForedropView`, and `AddHabitForedropView` have no required references.
  - [x] Deleted `AddTaskSheetView`, `AddItemComposerView`, `AddTaskForedropView`, `AddItemViewModel`, and `AddItemPresentationContracts`.
  - [x] Extracted `SunriseHabitLibraryView` from `AddHabitForedropView.swift`, then deleted the old habit composer file.
- [x] Legacy LiquidGlass / `LG*` search naming has been neutralized or deleted.
- [x] Obsolete storyboard scenes and visual-only UIKit controllers are unreferenced.
- [x] `project.pbxproj` no longer compiles deleted legacy presentation files.

## Remaining Sunrise Cleanup

- [x] migrate: replaced `HomeBackdropForedropRootView` / `HomeiPadSplitShellView` with Sunrise-named app shell types.
- [x] migrate: replaced task list support with `SunriseTaskListView`, `SunriseTaskSectionView`, and `SunriseTaskRowView`.
- [x] migrate: replaced `TimelineForedropView` app/onboarding usage with `SunriseTimelineSurface`.
- [x] migrate: replaced `HomeEvaLegacySheetViews` and Eva sheet types with Sunrise-named sheets.
- [x] migrate: renamed active Home day-swipe support to `SunriseDaySwipe*`.
- [x] migrate: renamed Home compact header and advanced filters to Sunrise-named chrome/sheet types.
- [x] rename/extract: migrated active focus and reflection support surfaces to Sunrise names.
- [x] delete: removed inactive DGCharts analytics leaf pipeline and chart-card view models from the build graph.
- [x] delete: removed unused `HomeGlassBottomBar`, `ProjectPillCell`, `FilterPill`, and stale Eva V2 sheet files.
- [x] delete: removed stale Insights leaf views once `SunriseInsightsContentView` remained the only routed Insights UI.
- [x] delete: removed old `SettingsView` and unused UIKit settings cells after route checks.
- [x] migrate: replaced recurring-task and chat-detail-unavailable UIKit alerts with Sunrise SwiftUI sheets.
- [x] guardrail: removed project/search UI-test fallbacks to deleted legacy identifiers and added a UI-test guardrail check.
- [x] onboarding-only exception: documented the accepted onboarding `legacyTaskIDMap` guardrail hit.

## Verification

- [x] Workspace build passes with `LifeBoard.xcworkspace`.
- [x] Final app build is warning-free on iPhone 16 iOS 18.6.
- [x] Sunrise Home UI tests are updated for the new header/filter behavior.
- [x] `QuickFilterChromeTests` has no failures in the current UI-test launch state; seeded Sunrise content-filter coverage passes and non-reachable launch-state checks skip.
- [ ] Full task creation, habit creation, onboarding composer launch, habit board, settings, chat, and calendar UI suites pass.
- [x] Focused unit coverage passes: `SunriseHeaderAssetTests`, `HomeCalendarIntegrationTests`, `HabitBoardPresentationBuilderTests`, `HabitBoardViewModelTests`, `SettingsViewModelTests`, `SunriseFocusZoneStatusTests`, `SunriseFocusZonePresentationTests`, `HomeSunriseLayoutMetricsTests`, and `HomeSunriseHintEligibilityTests`.
- [x] Focused Sunrise Insights UI coverage passes: `LifeBoardUITests/AnalyticsAndChartsTests/testInsightsUpdatesAfterCompletion`.
- [x] Legacy runtime/test guardrail scripts pass.
  - [x] `scripts/validate_legacy_test_guardrails.sh` passes.
  - [x] `scripts/validate_legacy_runtime_guardrails.sh` allows only the accepted onboarding `legacyTaskIDMap` hit in `LifeBoard/Onboarding/AppOnboarding.swift`.
