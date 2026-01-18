# fn-2.6 Fix HomeViewController+Helpers async callback bug

## Description
Changed getTaskFromTaskListItem from synchronous return to completion handler pattern to fix the bug where it returned before the async callback ran, always returning nil. The function now uses a completion handler that is called with the correct value after fetchTask completes.

## Acceptance
- [x] Change getTaskFromTaskListItem to async function or add completion handler
- [x] Remove synchronous return of foundTask
- [x] Move return logic into fetchTask completion handler


## Done summary
- Changed getTaskFromTaskListItem from synchronous return to completion handler pattern
- Moved return logic inside the taskRepository.fetchTask callback
- Added error handling for fetch failures

**Why:**
- Previous implementation returned before async callback ran, always returning nil

**Verification:**
- Code review confirms completion handler is called with correct value in all cases
## Evidence
- Commits: 9a22b2782b5873a6292eb61199f65ee97f41418e
- Tests: N/A
- PRs: N/A