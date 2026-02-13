Completed app-wide runtime log pruning and retained-log migration for critical paths:
- Removed/neutralized high-volume startup and chart/radar telemetry chatter.
- Refactored priority hotspots to keep only actionable warnings/errors:
  - `To Do List/Services/ChartDataService.swift`
  - `To Do List/Services/ProjectSelectionService.swift`
  - `To Do List/Views/Cards/RadarChartCard.swift`
  - `To Do List/ViewControllers/AddTaskViewController.swift`
  - `To Do List/ViewControllers/AddTaskViewController+Foredrop.swift`
  - `To Do List/Repositories/CoreDataTaskRepository.swift`
  - `To Do List/State/Repositories/CoreDataTaskRepository+Domain.swift`
  - `To Do List/View/TaskDetailSheetView.swift`
  - `To Do List/Data/Services/InboxProjectInitializer.swift`
  - `To Do List/Data/Migration/DataMigrationService.swift`
- Rewrote retained warning/error logs in these flows to structured event calls (`event/message/fields`) and removed message-style warning calls from production code.
- Removed noisy runtime categories from code paths (`HOME_DI`, `HOME_DATA`, `HOME_UI_MODE`, `[RADAR]`).
- Added local+CI print guardrails and policy docs as part of the same remediation stream.

Verification performed:
- `./scripts/check-no-print-logs.sh` passes.
- `rg -n "\\blogWarning\\(\\s*\"" "To Do List" -g '*.swift'` returns no matches (no message-style warning logs).
- `rg -n "HOME_DI|HOME_DATA|HOME_UI_MODE|\\[RADAR\\]" "To Do List" -g '*.swift'` returns no matches.
- `rg -n "customClassName=\"\\[(UUID|String)\\]\"" "To Do List/TaskModel.xcdatamodeld/TaskModel.xcdatamodel/contents"` returns no matches.

Build verification is pending manual run by user.
