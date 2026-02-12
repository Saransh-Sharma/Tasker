# fn-7.1 Fix non-scrollable Home task list and migrate row actions to native swipeActions

## Description
Implement Home grouping modes and persistent project ordering on the SwiftUI `TaskListView` path.

Scope:
- Add quick-filter `Group by` modes (`Prioritize Overdue` default, `Group by Projects`).
- Render Today home sections according to selected grouping mode.
- Support drag-reorder of custom project headers on Home and persist order.
- Persist grouping mode and custom project order across app sessions.
- Keep Inbox fixed and non-reorderable.
## Acceptance
- [ ] Home quick filters include a `Group by` section with chips for `Prioritize Overdue` and `Group by Projects`.
- [ ] `Prioritize Overdue` (Today only) renders sections as `Inbox -> Overdue (grouped by project headers) -> Custom projects`, without overdue duplication in custom sections.
- [ ] `Group by Projects` (Today only) renders `Inbox + custom projects` where each section includes non-overdue tasks first and overdue tasks after.
- [ ] User can drag and reorder custom project headers directly on Home; Inbox is fixed and not reorderable.
- [ ] Selected grouping mode and reordered custom-project order persist across app restarts.
- [ ] Existing non-Today quick views (`Upcoming`, `Done`, `Morning`, `Evening`) keep current behavior.
- [ ] Unit tests cover HomeFilterState backward-compatible decoding defaults and grouping/order behavior.
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
