# fn-4.6 Restore legacy XP task detail sheet and remove Fluent detail path

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
# fn-4.6 completion summary

Implemented full rollback from Fluent detail modal to legacy `TaskDetailSheetView` (XP badge) across Home and Search, and removed Fluent detail infrastructure.

## What changed

- Home task tap now presents `TaskDetailSheetView` page sheet from `HomeViewController+TaskSelection.swift`.
- Search task tap now presents the same `TaskDetailSheetView` page sheet directly from `LGSearchViewController.swift` (no Home presenter dependency).
- Added Home/Search refresh callbacks for save, toggle, and delete actions.
- Updated `TaskDetailSheetView` persistence:
  - completion toggle writes `task.isComplete` + `task.dateCompleted` and saves context.
  - save path resolves project name to `Projects` entity and sets both `task.project` + `task.projectID`.
  - added logs: `HOME_DETAIL_SHEET ...` and `HOME_TAP_DETAIL mode=sheet ...`.
- Removed Fluent detail files:
  - `To Do List/View/TaskDetailViewFluent.swift`
  - `To Do List/ViewControllers/HomeViewController+TaskDetailFluent.swift`
  - `To Do List/ViewControllers/HomeViewController+DateTimePicker.swift`
- Removed all related `project.pbxproj` references/build entries.
- Removed stale Fluent-detail state properties from `HomeViewController.swift`.

## Verification

- Verified detail entry points now use legacy sheet:
  - Home: `HomeViewController+TaskSelection.swift`
  - Search: `LGSearchViewController.swift`
  - Existing Fluent table path still uses `TaskDetailSheetView`.
- Verified zero references remain for `TaskDetailViewFluent` / `TaskDetailViewFluentDelegate` in app source and project file.

## Build note

- `./taskerctl build` was attempted, but local environment had conflicting/stale xcodebuild process lock and simulator service issues during follow-up direct xcodebuild verification in this sandbox. Source-level and reference-level verification completed successfully.
## Evidence
- Commits:
- Tests:
- PRs: