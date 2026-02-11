# fn-5.1 Clean project graph and pbxproj duplicates

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Completed project graph remediation in Tasker.xcodeproj/project.pbxproj.

Changes made:
- Removed duplicate compile source entries for TaskModel.xcdatamodeld, AddTaskViewController+Foredrop.swift, CreateTaskRequest.swift, and duplicate LLM view files.
- Removed duplicate PBXFileReference/PBXGroup objects for duplicate LLM Chat/Onboarding/Settings subtree.
- Removed root-group duplicate file memberships for State files that caused malformed multi-group warnings.
- Consolidated TaskModel.xcdatamodeld to a single XCVersionGroup reference.

Validation:
- `xcodebuild -workspace Tasker.xcworkspace -list` now runs without malformed project/file-reference warnings.
## Evidence
- Commits:
- Tests:
- PRs: