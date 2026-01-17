# fn-2.6 Fix HomeViewController+Helpers async callback bug

## Description
TBD

## Acceptance
- [ ] Change getTaskFromTaskListItem to async function or add completion handler
- [ ] Remove synchronous return of foundTask
- [ ] Move return logic into fetchTask completion handler


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
- Tests:
- PRs: