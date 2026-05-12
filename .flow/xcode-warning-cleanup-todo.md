# Xcode Warning Cleanup TODO

- [x] Capture current warning baseline from `LifeBoard` scheme build log.
- [x] Add safe `Sendable` conformances to domain/query/result value types.
- [x] Add and then recover broad asynchronous completion `@Sendable` changes after they inflated downstream warnings.
- [x] Fix app-owned Core Data repository warning clusters without moving managed objects across queues.
  - [x] Remove `CoreDataProjectRepository` sendability warnings with a confined callback delivery boundary.
- [x] Fix service/use-case/view-model actor isolation and captured mutable state warnings.
  - [x] Replace shared mutable DispatchGroup load state in `ChatHostViewController`.
  - [x] Replace shared mutable DispatchGroup load state in `LGSearchViewModel`.
  - [x] Replace shared mutable DispatchGroup load state in weekly planner/review view models.
  - [x] Replace shared mutable DispatchGroup load state in `ProjectManagementViewModel`.
  - [x] Remove unnecessary main-actor isolation from pure habit tracking row formatting.
  - [x] Replace shared mutable task-detail metadata load state in `HomeViewModel`.
  - [x] Replace shared mutable habit agenda/mutation load state in `HomeViewModel`.
- [x] Rebuild `LifeBoard` and iterate until app-owned warnings are close to zero.
  - [x] Restore a successful clean build after Sendable/concurrency fixes.
  - [x] Add explicit `@Sendable` callback contracts through app-owned async/result APIs.
  - [x] Add `Sendable` protocol boundaries and `@unchecked Sendable` service/repository conformances where instances are immutable facades over confined queues.
  - [x] Reduce largest remaining UI/main-actor callback clusters from latest clean count.

## Baseline

- Build command: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Build status: succeeded.
- Largest app-owned warning files:
  - `LifeBoard/State/Repositories/CoreDataProjectRepository.swift`: 106
  - `LifeBoard/UseCases/Sync/ReconcileExternalRemindersUseCase.swift`: 59
  - `LifeBoard/LLM/Models/LLMContextProjectionService.swift`: 37
  - `LifeBoard/UseCases/LLM/AssistantActionPipelineUseCase.swift`: 33
  - `LifeBoard/State/Repositories/CoreDataWeeklyRepositories.swift`: 32
  - `LifeBoard/State/Repositories/CoreDataGamificationRepository.swift`: 32

## Latest Clean Build

- Build status: succeeded.
- Date: 2026-05-04.
- Build command: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -destination 'platform=iOS Simulator,id=85D27BEE-BDBE-41BD-BBD9-9073BC374AE0' -derivedDataPath /tmp/LifeBoardWarningPlanDerivedData build CODE_SIGNING_ALLOWED=NO build`
- Build log: `/tmp/lifeboard-warning-cleanup-device-build.log`
- App-owned warning lines: 0.
- Unique app-owned warnings: 0.
- Total warning lines: 0.
- Third-party/generated warning buckets:
  - None in the latest app build log.
- Largest current app-owned clusters: none.

## Swift 6 Check

- Command-line `SWIFT_VERSION=6.0` should still not be passed globally because CocoaPods targets inherit the override.
- App-owned strict-concurrency warnings are now clean in the Debug iOS Simulator build.
- Next Swift 6 step: set Swift 6 language mode target-by-target for app-owned targets only, then rebuild each target independently so Pods stay in their current language mode.

## Focused Tests

- Home/task focused command: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -destination 'platform=iOS Simulator,id=85D27BEE-BDBE-41BD-BBD9-9073BC374AE0' -derivedDataPath /tmp/LifeBoardWarningPlanDerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:LifeBoardTests/DeleteTaskDefinitionUseCaseTests -only-testing:LifeBoardTests/GetHomeFilteredTasksUseCaseTests -only-testing:LifeBoardTests/HomeTaskMutationPayloadTests -only-testing:LifeBoardTests/LifeBoardAppShortcutsTests`
- Home/task focused result: passed 22 tests, 0 failures. Log: `/tmp/lifeboard-warning-cleanup-focused-tests.log`.
- Shortcut focused command: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -destination 'platform=iOS Simulator,id=85D27BEE-BDBE-41BD-BBD9-9073BC374AE0' -derivedDataPath /tmp/LifeBoardWarningPlanDerivedData test CODE_SIGNING_ALLOWED=NO -only-testing:LifeBoardTests/LifeBoardShortcutDeepLinkTests -only-testing:LifeBoardTests/ShortcutHandoffStoreTests -only-testing:LifeBoardTests/PersistentStoreLocationServiceTests -only-testing:LifeBoardTests/PersistentRuntimeInitializerTests -only-testing:LifeBoardTests/InboxTaskCaptureServiceTests -only-testing:LifeBoardTests/FocusSessionShortcutRecoveryTests`
- Shortcut focused result: passed 15 tests, 0 failures. Log: `/tmp/lifeboard-warning-cleanup-shortcut-tests.log`.
- Test-target warning backlog: the latest shortcut test compile has 0 app target warning lines, but still has 4567 `LifeBoardTests`/`LifeBoardUITests` warning lines, 9 third-party warning lines, and remaining App Intents metadata warnings from Pods/auxiliary targets.
- Previous note retained: `AppOnboardingTests` had a known copy-quality failure for the pre-existing phrase `chief of staff`.
