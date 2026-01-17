# fn-2.8 Consolidate getTaskFromTaskListItem implementations

## Description
TBD

## Acceptance
- [ ] Remove broken async getTaskFromTaskListItem from HomeViewController+Helpers.swift
- [ ] Keep synchronous TableView version
- [ ] Update all callers to use the correct synchronous function


## Done summary
- Removed duplicate async getTaskFromTaskListItem from HomeViewController+Helpers.swift
- Kept the synchronous TableView version which works correctly with CoreData fetch
- Added comment directing developers to the TableView implementation

**Why:**
- Two implementations with different signatures caused confusion
- TableView version is synchronous and works correctly for UI needs

**Verification:**
- Grep confirms only one implementation remains (in TableView)
## Evidence
- Commits: 3a1127b7ff1c0a76193d71ee68812d64ef5f62e5
- Tests:
- PRs: