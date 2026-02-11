# fn-6.1 Fix add-task priority selection mapping and unify UI decoding

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Implemented a priority mapping consistency fix centered on the add-task flow and all major read/edit surfaces.

Key updates:
- Added canonical segment mapping helpers to TaskPriority (`uiOrder`, `fromSegmentIndex`, `segmentIndex`).
- Fixed AddTask segmented-control behavior to honor `None/Low/High/Max` selections.
- Aligned default segmented selection with model state in AddTask screens.
- Removed legacy reversed raw-value mappings from task detail, task list, Fluent UI edit modal, and priority icon helpers.
- Updated score calculation helper (`NTask.getTaskScore`) to use `TaskPriorityConfig.scoreForRawValue`.
- Updated legacy data repair default for missing priority to canonical `.low` raw value.

Validation:
- Built iOS app target successfully via xcodebuild (`** BUILD SUCCEEDED **`).
## Evidence
- Commits:
- Tests:
- PRs: