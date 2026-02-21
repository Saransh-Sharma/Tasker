# Task Detail Rehaul TODO

- [x] Add clear-flag semantics to `UpdateTaskDefinitionRequest`
- [x] Wire clear flags in CoreData repository update path
- [x] Add TaskDetailViewModel with full field parity + autosave + child-step operations
- [x] Rebuild `TaskDetailSheetView` with action-first layout and progressive disclosure
- [x] Update Home + Search integration contracts for new TaskDetail callbacks and child ops
- [x] Add HomeViewModel + LGSearchViewModel wrappers for child load/create/update/delete
- [x] Add accessibility identifiers and VoiceOver labels/hints for task detail controls
- [x] Deprecate/remove unused UIKit `TaskDetailView`
- [x] Add/adjust tests for clear flags + key task detail flows
- [x] Run focused build validation

## Notes

- Running an individual unit test is currently blocked by scheme/test-plan setup (`To Do ListTests` is not included in the active `To Do List` scheme test plan from CLI).
