# fn-2.3 Fix AddTaskViewModel projectID nil issue

## Description
TBD

## Acceptance
- [ ] Resolve projectID by looking up selectedProject in projects array
- [ ] Find Project whose name matches selectedProject and use its id
- [ ] Handle case when no match is found (leave nil or surface error)


## Done summary
- Added lookup to resolve projectID from selectedProject name
- Uses projects.first(where: { $0.name == selectedProject })?.id
- If no match found, projectID remains nil (downstream supports this)

**Why:**
- Task-to-project association was being lost because projectID was always nil

**Verification:**
- Code review confirms correct lookup pattern
## Evidence
- Commits: b9d0e82852b6ce3e81040b38f59be58e47b24020
- Tests:
- PRs: