# Semantic Swift File Naming Cleanup TODO

## Preparation
- [x] Confirm working tree scope before edits.
- [x] Build a rename manifest with old path, new path, and pure rename vs split.
- [x] Use `git mv` for pure renames.
- [x] Update `LifeBoard.xcodeproj/project.pbxproj` for every renamed or split Swift file.

## Implementation
- [x] Rename `HomeViewModelCore.swift` to `HomeViewModelRoot.swift`.
- [x] Rename `HomeViewModelCoreBindings.swift` to `HomeViewModel+Bindings.swift`.
- [x] Replace all remaining `+PartNN.swift` files with semantic filenames.
- [x] Split mixed HomeViewModel extension files by responsibility.
- [x] Split mixed SunriseAppShell extension files by responsibility.
- [x] Rename/split timeline, onboarding, rescue, settings, and chat extension files.
- [x] Keep compatibility root files at original public paths.
- [x] Preserve method bodies and access control except import/whitespace cleanup.

## Verification
- [x] `find LifeBoard -name '*+Part*.swift'` returns zero files.
- [x] No duplicate Swift basenames under `LifeBoard/**/*.swift`.
- [x] No renamed/new semantic-pass Swift file over 500 lines.
- [x] `scripts/check-xcode-target-membership.sh`.
- [x] `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'generic/platform=iOS Simulator' build`.
- [x] Targeted tests: `HomeViewModelPersistenceTests`, `ChatTranscriptSnapshotTests`, `SettingsViewModelTests`, `EvaHomeIntelligenceUseCasesTests`.

## Completion Notes
- Removed every `+PartNN.swift` file under `LifeBoard`.
- Kept several cohesive semantic files instead of forcing ultra-small fragments where the resulting names were clearer, for example `SunriseAppShellView+FacesAndSearchChat.swift`, `MessageView+EvaProposalAndDayOverview.swift`, and `LifeManagementView+DetailsComposerAndOverlays.swift`.
- Removed stale `HomeViewModel+HabitReconciliationAndFocusWhy.swift` after its responsibilities were split into `HomeViewModel+HabitReconciliation.swift`, `HomeViewModel+RescueEligibility.swift`, and `HomeViewModel+FocusWhyCandidates.swift`.
- Broader size audit still shows older non-`Part` files over 500 lines, such as HomeViewController extension files and other pre-existing views. Those are outside this naming stabilization pass and remain deferred to avoid starting a new decomposition wave.
