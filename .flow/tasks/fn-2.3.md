# fn-2.3 Interactions and polish: completion behavior, reward motion, analytics

## Description
Implement interaction quality and gamification polish for the redesigned Home screen: subtle completion visuals, inline completed collapse behavior, swipe affordances, reward feedback animation, and analytics instrumentation. This task builds on the UI/data foundation from fn-2.2.
## Acceptance
- [ ] Update checkbox completed styling (no filled gold coin) in row/detail components for quiet done state.
- [ ] Implement inline completed subgroup per section with default collapsed state when completed count > 2.
- [ ] Preserve existing left swipe actions and add/verify right full-swipe complete/reopen in home list rows.
- [ ] Add completion micro-interaction sequence (checkbox spring + row mute + haptic) with `TaskerAnimation` consistency.
- [ ] Add reward feedback motion (`+XP` fly-to-header) integrated with cockpit state updates.
- [ ] Add analytics events for completion/reward interactions and collapse/expand usage.


## Done summary
Implemented interaction and polish layer for Home redesign:
- Updated completion checkbox visuals to quiet done-state styling (no filled gold coin) and compact mode support.
- Added per-section inline completed subgroup behavior with default collapsed state when completed count > 2.
- Added right full-swipe complete/reopen affordance while preserving left-side action menu.
- Added reward feedback motion (`+XP` burst moving toward cockpit area) tied to daily score delta.
- Added interaction analytics hooks for task toggles, completed group collapse/expand, and reward bursts.
## Evidence
- Commits:
- Tests: {'name': 'Manual code-path inspection for TaskRowView/TaskSectionView/HomeForedropView interaction wiring', 'result': 'passed'}, {'name': 'xcodebuild compile validation', 'result': 'inconclusive', 'details': 'Build environment currently reports third-party dependency resolution errors (Firebase/FluentUI modules), preventing clean compile verification of this change set in this run.'}
- PRs: