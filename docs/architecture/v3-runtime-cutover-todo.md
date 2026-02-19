# V3 Runtime Cutover TODO

**Last updated: 2026-02-20**

This tracker is the release-gating source of truth for V3 hard-cut completion.

## Baseline Verification (Recorded)

- [x] `bash /Users/saransh1337/Developer/Projects/Tasker/scripts/validate_legacy_runtime_guardrails.sh`
- [x] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -configuration Debug -destination "generic/platform=iOS Simulator" build`
- [x] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" -only-testing:TaskerTests test`

## Phase Status

- [x] Phase 1: Core Data V3 model wiring and project cleanup
- [x] Phase 2: AppDelegate V3 runtime cutover naming and store files
- [x] Phase 3: Domain/read contract hard-cut (`TaskDefinitionSliceResult`, remove `DomainTask`, remove compatibility aliases)
- [x] Phase 4: Presentation DI fail-closed readiness checks
- [x] Phase 5: Strict test-shim migration to V3 contracts
- [x] Phase 6: Guardrails + docs alignment
- [ ] Phase 7: Final verification gates

## Release Gates

### Completed

- [x] `bash /Users/saransh1337/Developer/Projects/Tasker/scripts/validate_legacy_runtime_guardrails.sh`
- [x] `bash /Users/saransh1337/Developer/Projects/Tasker/scripts/validate_legacy_test_guardrails.sh`
- [x] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" build`
- [x] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" -only-testing:TaskerTests test`
- [x] `rg -n '/Users/saransh1337' /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcodeproj/project.pbxproj`
- [x] `rg -n 'TaskRepositoryProtocol|UpdateTaskRequest|TaskSliceResult|DomainTask' '/Users/saransh1337/Developer/Projects/Tasker/To Do List' '/Users/saransh1337/Developer/Projects/Tasker/To Do ListTests'`

### Pending (Deferred for now)

- [ ] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" -only-testing:TaskerUITests/TaskCompletionTests test`
- [ ] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" -only-testing:TaskerUITests/TaskEditingTests test`
- [ ] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" -only-testing:TaskerUITests/TaskDeletionTests test`
- [ ] `xcodebuild -workspace /Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace -scheme "To Do List" -destination "platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608" test`
- [ ] `git ls-files --others --exclude-standard | rg -v '^build/' | rg -v '^build_debug/' | rg -v '^build_test/'`

## Deferred Test Summary (Captured)

- `TaskerTests` passed baseline: `Executed 143 tests, 0 failures, 2 skipped`.
- Focused UI pass succeeded:
  - `TaskCompletionTests/testCompletedTaskShowsStrikethrough` (`1 test, 0 failures`).
- Partial UI batch succeeded for:
  - `testCompleteTaskUpdatesScore_P0`
  - `testCompleteTaskUpdatesScore_P1`
  - `testCompleteTaskUpdatesStreak`
  - `testCompleteTaskViaBEMCheckbox`
  - `testTaskOpenDoneOpenUpdatesInlineRowStateWithoutRelaunch`
- Known pending issue in deferred UI runs:
  - `testTaskCompletionPerformance` threshold miss (`1.6857s > 0.3s`) in current simulator environment.

## Decision Log

- Full V3 rename is in effect for runtime naming and readiness assertions.
- Strict legacy test-shim cleanup is in place.
- Remaining UI/full-scheme test gates are intentionally deferred for a dedicated verification pass.

## Next Verification Pack (When Tests Resume)

```bash
xcodebuild -workspace '/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace' -scheme 'To Do List' -destination 'platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608' -only-testing:TaskerUITests/TaskCompletionTests test
xcodebuild -workspace '/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace' -scheme 'To Do List' -destination 'platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608' -only-testing:TaskerUITests/TaskEditingTests test
xcodebuild -workspace '/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace' -scheme 'To Do List' -destination 'platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608' -only-testing:TaskerUITests/TaskDeletionTests test
xcodebuild -workspace '/Users/saransh1337/Developer/Projects/Tasker/Tasker.xcworkspace' -scheme 'To Do List' -destination 'platform=iOS Simulator,id=E42763AD-6602-4583-A3AD-DFCDC8151608' test
```
