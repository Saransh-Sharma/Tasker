---
title: "Sunrise Glass Presentation Layer Report"
subtitle: "LifeBoard UI Migration Status"
date: "May 2026"
author: "LifeBoard"
toc: true
toc-depth: 2
geometry: margin=0.75in
fontsize: 10.5pt
mainfont: DejaVu Sans
monofont: DejaVu Sans Mono
colorlinks: true
linkcolor: blue
urlcolor: blue
---

# Executive Summary

The main iOS app presentation layer is now migrated to Sunrise Glass for non-onboarding routes. UIKit remains only where it hosts SwiftUI, manages bootstrap, or owns navigation. Onboarding screens remain intentionally outside the redesign, but onboarding-launched task, habit, and detail presentations use Sunrise surfaces.

This report reflects the current worktree after the remaining cleanup pass. Domain models, repositories, Core Data, SwiftData, assistant pipeline behavior, and onboarding layout were not changed.

# Active Sunrise Coverage

| Area | Current Sunrise Surface |
|---|---|
| App shell | `SunriseAppShellView`, `SunriseiPadSplitShellView` |
| Home task surface | `SunriseHomeScreen`, `SunriseTaskListView`, `SunriseTaskSectionView`, `SunriseTaskRowView`, `SunriseDaySwipe*`, `SunriseCompactHeaderChrome` |
| Timeline | `SunriseTimelineSurface`, `SunriseTimelineBar`, `SunriseTimelineRendererPolicy` |
| Schedule | `SunriseScheduleScreen` |
| Creation | `SunriseAddTaskSheetView`, `SunriseAddHabitSheetView` |
| Detail | `SunriseTaskDetailScreen`, `SunriseHabitDetailScreen` |
| Habits | `SunriseHabitLibraryView` plus existing habit board Sunrise presentation |
| Weekly/reflection/focus | `SunriseWeeklyPlannerView`, `SunriseWeeklyReviewView`, `SunriseDailyReflectionView`, `SunriseFocusTimerView`, `SunriseFocusZone`, `SunriseFocusSessionSummaryView` |
| Projects | `SunriseProjectManagementView` |
| Insights | `SunriseInsightsView` via `SunriseInsightsContentView` |
| Settings | `SettingsRootView`, `LifeManagementView`, LLM/chat/model/data privacy settings |
| Chat | Sunrise chat chrome/content state in chat SwiftUI surfaces |

# Cleanup Completed

- Replaced the active Home shell with Sunrise-named shell types.
- Replaced task list, task section, task row, timeline, Eva sheet, focus zone, focus session summary, reflection composer, and quiet tracking composer symbols with Sunrise names.
- Replaced Home and UI-test accessibility naming from `home.foredrop.*` to `home.sunrise.*`.
- Removed the inactive DGCharts analytics leaf pipeline: old chart cards, chart view models, formatters, markers, and animation helpers are no longer compiled.
- Replaced chart-specific Home reload invalidation naming with Insights-neutral refresh naming.
- Deleted `HomeGlassBottomBar.swift`; Home now uses the canonical `LBBottomDock` directly.
- Deleted unused `ProjectPillCell.swift`, `FilterPill.swift`, and the stale Eva triage V2 sheet file.
- Replaced recurring-task delete and chat detail-unavailable `UIAlertController` usage with Sunrise SwiftUI sheets.
- Removed legacy project/search/settings UI-test fallback identifiers and added guardrail coverage for those UI-test fallbacks.
- Renamed stale analytics UI-test chart/radar assertions to Sunrise Insights terminology and removed unused chart accessibility constants.
- Deleted stale compiled Insights leaf views: `InsightsTodayView.swift`, `InsightsWeekView.swift`, and `InsightsSystemsView.swift`.
- Deleted old `SettingsView.swift`.
- Deleted unused UIKit settings cells: `DarkModeToggleCell.swift`, `ThemeSelectionCell.swift`, and `UnifiedThemePickerCell.swift`.
- Removed the deleted files from `LifeBoard.xcodeproj/project.pbxproj`.
- Updated runtime guardrails so the only allowed `legacyTask` production hit is onboarding's `legacyTaskIDMap`.

# Remaining Exceptions

- Onboarding screen layout is intentionally retained.
- `legacyTaskIDMap` remains in `LifeBoard/Onboarding/AppOnboarding.swift` as an onboarding compatibility map and is explicitly allowed by the runtime guardrail.
- Non-presentation domain/state code may still contain "Legacy" terminology for persistence migrations or compatibility logic. That is outside the Sunrise presentation migration scope.

# Verification Snapshot

| Check | Status | Notes |
|---|---|---|
| Baseline simulator build | Passed | Before remaining cleanup. |
| Post-cleanup simulator build | Passed | `LifeBoard.xcworkspace` / `LifeBoard` on iPhone 16 iOS 18.6; no build warnings or errors in the final run. |
| Legacy runtime guardrail | Passed | Allows only onboarding's `legacyTaskIDMap` compatibility hit. |
| Legacy test guardrail | Passed | Includes UI-test fallback checks for old project/search/settings identifiers. |
| Focused unit tests | Passed | 285 selected migration tests passed with 0 failures. |
| Focused UI test | Passed | `LifeBoardUITests/AnalyticsAndChartsTests/testInsightsUpdatesAfterCompletion`; the UI-test target still emits pre-existing Swift concurrency warnings in test stubs/page objects. |
| QuickFilter UI tests | No current failures | Seeded Sunrise content-filter coverage passed in the earlier cleanup pass; broader launch-state checks can still skip when their old chrome state is not reachable. |
| Full UI tests | Not completed | Broader UI suite still needs a clean end-to-end run for task creation, habit creation, onboarding composer launch, habit board, settings, chat, and calendar. |

# Open Verification Work

- Run the broader UI-test suite to cover task creation, habit creation, onboarding composer launch, habit board, settings, chat, and calendar after stabilizing simulator timeouts.
- Investigate existing weekly review view-model failures seen outside the focused migration slice before treating the full unit suite as green.

# Final Cleanup Checks

These checks should remain empty outside accepted onboarding or non-presentation compatibility exceptions:

```sh
rg "\b(AddTaskSheetView|AddItemComposerView|AddTaskForedropView|AddHabitForedropView)\b" LifeBoard LifeBoard.xcodeproj/project.pbxproj
rg "LGSearch|LiquidGlass|ToDoColors|ToDoFont|CardViewModifier|MaterialComponents" LifeBoard LifeBoard.xcodeproj/project.pbxproj
rg "Foredrop|foredrop" LifeBoard LifeBoard.xcodeproj/project.pbxproj
rg "HomeDayLiquidSwipe|LiquidSwipe|ToDoAnimations|TinyPieChart|ProjectPillCell|ChartCardsScrollView|ChartCardViewModel|RadarChartCardViewModel|BalloonMarker|RadarChart|radarChart|chartView|ChartView|DGCharts|LineChart" LifeBoard LifeBoardTests LifeBoardUITests LifeBoard.xcodeproj/project.pbxproj
rg "legacyView|legacyComposer|legacyIdentifier|legacyProjectFilter|Legacy Why|legacy fallback|AccessibilityIdentifiers\.(ProjectManagement|NewProject)|home\.projectFilterButton" LifeBoardUITests
rg "NewProjectViewController|WeeklyViewController|InboxViewController|UpcominngTasksViewController|ThemeSelectionViewController" LifeBoard LifeBoard.xcodeproj/project.pbxproj LifeBoard/Storyboards
scripts/validate_legacy_runtime_guardrails.sh
scripts/validate_legacy_test_guardrails.sh
```

# Assumptions

- Main app UI migration excludes onboarding screen layout.
- UIKit hosting/navigation controllers can remain when they do not own legacy visual screen UI.
- Sunrise styling continues to use `LifeBoardDesign` and `LB*` tokens.
- Accessibility identifiers may change only when tests are migrated in the same pass.
