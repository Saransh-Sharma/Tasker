# V2 Hard-Cut Execution TODO

## In Progress

- [ ] Run full scheme verification after latest migration + UITest stabilization changes
  - [ ] `xcodebuild -workspace ... -scheme "To Do List" -destination "iPhone 17 Pro" test` (last full run was interrupted after long UI pass; rerun still pending)

## Remaining Plan Work

- [ ] Close out remaining UITest modernization debt for secondary analytics surfaces
  - [ ] Replace `XCTSkip` guardrails with stable runtime identifiers once focus/foredrop surfaces are exposed in the shipped hierarchy

## Completed

- [x] V2-only task coordinator/DI/usecase wiring
- [x] Remove legacy task protocol/usecases/repository bridge surface
- [x] Add V2 write usecases (`UpdateTaskDefinition`, `DeleteTaskDefinition`, `RescheduleTaskDefinition`)
- [x] Promote `DomainTask = TaskDefinition` and V2 result contracts
- [x] Update epoch/cloud cutover keys (`tasker.v3.store.epoch`, `iCloud.TaskerCloudKitV3`)
- [x] Expand legacy guardrail script with banned-symbol checks
- [x] Remove `FluentIcons` pod dependency from CocoaPods
- [x] Remove `MicrosoftFluentUI` pod dependency and Fluent-specific Podfile hooks
- [x] Remove Fluent-only app/runtime code paths (`NavigationController`, `fluentConfiguration`, `DrawerController`)
- [x] Delete Fluent-only compatibility/source artifacts from target (`FluentUIFramework.swift`, `FluentUI+TokenAdapters.swift`, `FluentUITokenExtensions.swift`)
- [x] Re-run deterministic build gate after dependency cleanup (build succeeded on iPhone 17 Pro simulator)
- [x] Re-run `TaskerTests` suite after V2 migration adjustments (143 tests, 0 failures, 2 skipped)
- [x] Harden UITest page objects for migrated SwiftUI home/add-task surfaces (`home.taskRow.*`, `home.taskCheckbox.*`, dynamic add/settings selectors)
- [x] Rename Core Data entity classes from legacy symbols (`NTask`, `Projects`) to canonical symbols (`TaskDefinitionEntity`, `ProjectEntity`)
- [x] Add model version `TaskModelV2V3.xcdatamodel` and set it as current
- [x] Remove duplicate legacy Core Data attributes from Task/Project entity definitions in V3 model
- [x] Canonicalize project/task field usage in mappers/repositories (ID-first + canonical names)
- [x] Remove Fluent UI pod/runtime usage from app and pod graph
- [x] Guardrail scan passes (`./scripts/validate_legacy_runtime_guardrails.sh`)
- [x] Targeted rerun of failing analytics UI tests now succeeds with runtime-aware skips (4 skipped, 0 failures)
- [x] Phase build gate rerun after latest fixes (`xcodebuild ... clean build` succeeded)
- [x] Unit test gate rerun (`-only-testing:TaskerTests` succeeded: 143 tests, 0 failures, 2 skipped)
