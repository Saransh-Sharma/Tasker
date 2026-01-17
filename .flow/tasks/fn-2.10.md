# fn-2.10 Add duplicate name check in NewProjectViewController

## Description
Add project name uniqueness check before creating a project in NewProjectViewController to prevent duplicate project names consistently across the codebase.

## Acceptance
- [x] Add isProjectNameAvailable check before createProject
- [x] Return duplicate-name error if name already exists
- [x] Proceed with save only if name is available


## Done summary
- Added isProjectNameAvailable check before creating project in createProject function
- Returns error 409 (Conflict) with descriptive message if name already exists
- Only proceeds with entity creation and save if name is available

**Why:**
- createProject was missing duplicate name validation that CoreDataProjectRepository has
- Prevents duplicate project names consistently across the codebase

**Verification:**
- Code review confirms validation is applied before save
## Evidence
- Commits: cc9c8ed5bb08f2d34d83693384a58b7ed2150851
- Tests:
- PRs: