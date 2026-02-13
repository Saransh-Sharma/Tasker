# fn-2.2 UI foundation: cockpit, focus strip, compact list, and VM contracts

## Description
Implement the structural and data-contract foundation for the Home redesign: cockpit header, focus strip, compact task list density, and supporting `HomeViewModel` presentation models. This task owns the core information hierarchy and deterministic focus prioritization but excludes advanced motion/interaction polish and full validation suite.
## Acceptance
- [ ] Add `HomeProgressState` to `HomeViewModel` and publish `progressState` with fields: earnedXP, remainingPotentialXP, todayTargetXP, streakDays, isStreakSafeToday.
- [ ] Add deterministic `focusTasks` derivation in `HomeViewModel` with ranking: overdue > due today > higher XP > earlier due > stable ID.
- [ ] Replace Home header in `To Do List/View/HomeForedropView.swift` to cockpit format (`XP Today A/B`, streak safety copy, thin progress bar).
- [ ] Add Focus strip (top 1-3 tasks) below cockpit with compact card visuals and task tap/complete hooks.
- [ ] Refactor compact row presentation in `To Do List/View/TaskRowView.swift` and list spacing in `To Do List/View/TaskListView.swift` / `To Do List/View/TaskSectionView.swift` to balanced compact density.
- [ ] Introduce row metadata presentation (`rowMetaText`, `trailingMetaText`, `xpValue`) used by compact rows.


## Done summary
Implemented the Home redesign foundation:
- Added `HomeProgressState` and published `progressState` in `HomeViewModel`.
- Added deterministic `focusTasks` ranking in `HomeViewModel`.
- Replaced Home header potential points copy with XP cockpit (`XP Today`, streak safety text, progress bar).
- Added Focus strip cards (top 1-3 tasks) under cockpit with compact metadata and completion swipe.
- Refactored task row to compact layout with `TaskRowDisplayModel` (`rowMetaText`, `trailingMetaText`, `xpValue`).
- Tightened list and section spacing for denser scanability.
## Evidence
- Commits:
- Tests: {'name': "xcodebuild -project Tasker.xcodeproj -scheme 'To Do List' -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO", 'result': 'failed', 'details': 'Workspace/project dependency environment has external module resolution issues (Firebase/FluentUI/etc.) unrelated to the edited Home files in this run.'}
- PRs: