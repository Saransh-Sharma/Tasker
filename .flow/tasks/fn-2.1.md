# fn-2.1 Implement home focus cockpit, dense rows, and completed behavior

## Description
Implement the Home redesign in SwiftUI by introducing a progress cockpit header (XP + streak safety), a focus strip (top 1-3 ranked tasks), denser task rows, and inline muted completed handling with default collapsed completed subgroup behavior. Reuse HomeViewModel state where possible and add explicit presentation models for progress and row metadata.
## Acceptance
- [ ] Home header shows `XP Today: earned/target`, streak safety copy, and progress bar driven by HomeViewModel state.
- [ ] HomeViewModel exposes `progressState` and deterministic `focusTasks` ranking (overdue, due today, higher XP, earliest due, stable ID).
- [ ] Task rows are compact (~60pt baseline), title-first, single-line metadata, optional note only when present.
- [ ] Completed rows render muted and are grouped inline per section with collapsed-by-default behavior when completed count > 2.
- [ ] Checkbox complete state is subtle (no filled gold coin); swipe right can complete/reopen and swipe left preserves actions.
- [ ] Unit tests cover focus ranking and progress state updates; existing tests continue to pass.
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
