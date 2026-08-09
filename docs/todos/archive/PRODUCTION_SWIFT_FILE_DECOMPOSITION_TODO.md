# Production Swift File Decomposition TODO

> **Classification: Engineering implementation record.** It does not define product behavior or release completion.

- [x] Split `LifeBoard/Onboarding/AppOnboarding.swift` into models, services, coordinator, views, and components.
- [x] Split `LifeBoard/Presentation/ViewModels/HomeViewModel.swift` into owner type plus focused support files.
- [x] Split `LifeBoard/View/SunriseTimelineSurface.swift` into timeline geometry, layout, rail, surface, cards, compact, agenda, and backdrop files.
- [x] Split `LifeBoard/View/SunriseAppShellView.swift` into shell root, state, overlays, sheets, day-swipe, and action helper files.
- [x] Split `LifeBoard/Presentation/Home/Modals/EvaOverdueRescueSheetV2.swift` into rescue domain, view model, root sheet, deck, sheets, and decorative views.
- [x] Split `LifeBoard/Views/Settings/LifeManagementView.swift` into root, browser rows, details, composers, pickers, and sheets.
- [x] Split low-risk chat/LLM SwiftUI files over 2k lines into focused components.
- [x] Add all new Swift files to the `LifeBoard` app target.
- [x] Build `LifeBoard` after each feature slice.
- [x] Run targeted tests for moved logic.

Verification notes:

- `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'generic/platform=iOS Simulator' build` succeeded after the final split.
- Target-folder file-size audit has no non-data Swift files over 500 lines; `LifeBoard/Onboarding/Models/StarterWorkspaceCatalog.swift` remains as a catalog/data exception.
- Targeted unit test command executed 112 tests; `ChatTranscriptSnapshotTests`, `EvaHomeIntelligenceUseCasesTests`, and `SettingsViewModelTests` passed, while `HomeViewModelPersistenceTests` had 5 existing assertion failures to triage separately.
