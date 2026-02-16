# fn-2.8 Fix Add Task keyboard Done submit+dismiss regression

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Implemented Add Task submit+dismiss regression fix in SwiftUI add flow.

Changes completed:
- AddTask sheet now uses fresh modal-scoped view model via PresentationDependencyContainer.makeNewAddTaskViewModel().
- Removed immediate resetForm() call after successful createTask() so isTaskCreated remains true long enough for sheet-level observer dismissal.
- Centralized submit gating in AddTaskForedropView.submitTask() and wired it to top Done button, bottom Create button, and title-field keyboard submit.
- Extended AddTaskTitleField with onSubmit callback and connected .onSubmit to that callback.
- Added AddTaskPage helper for keyboard Done submission in UI tests.
- Strengthened TaskCreationTests by asserting save-path dismissal and added regressions for:
  - keyboard Done creates task + dismisses sheet
  - keyboard Done with empty title does not dismiss
  - rapid keyboard submits create only one task row

Validation notes:
- Build validation attempted with xcodebuild; blocked by environment dependency resolution errors (Firebase/FluentIcons/etc missing module dependencies from current workspace state), not by edited files.
## Evidence
- Commits:
- Tests:
- PRs: