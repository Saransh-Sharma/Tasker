# LifeBoard Cleanup Audit - 2026-05-16

> **Classification: Audit snapshot.** It preserves dated cleanup evidence and does not define current product behavior or completion status.

## Executive Summary

This is the first audit-only deliverable for the LifeBoard iOS cleanup plan. It records candidates and verification gates before any broad deletion, dependency removal, project rewrite, or architecture split.

Working tree note: the audit was captured on branch `sunriseGlassRedesign`, which already had many unrelated edits and deletions in progress. Preserve that work and keep cleanup PRs small.

### Audit TODOs

- [x] Capture dependency inventory across CocoaPods, SPM, linked frameworks, and direct imports.
- [x] Capture module map, target list, build settings, Info.plist, and entitlements.
- [x] Capture static warning-style counts and no-print guardrail status.
- [x] Capture size baselines for Swift files and resources.
- [x] Identify candidate cleanup PRs with risk and verification commands.
- [x] Capture current build baseline with signing disabled.
- [ ] Re-run build baseline after each cleanup PR.
- [ ] Run Periphery or equivalent dead-code scan once the project builds cleanly.
- [ ] Confirm asset/resource target membership before deleting any resources.

## 1. Dependency Inventory And Unused Dependency Candidates

### Active Targets

`xcodebuild -list -workspace LifeBoard.xcworkspace` reported these first-party schemes/targets:

- `LifeBoard`
- `LifeBoardTests`
- `LifeBoardUITests`
- `LifeBoardWidgets`
- `LifeBoardWatch`
- `LifeBoardWatchWidgets`

The workspace also exposes many CocoaPods-generated schemes, so scheme cleanup must distinguish first-party schemes from Pods schemes.

### CocoaPods

Direct pods declared in `Podfile`:

- Firebase: `Firebase/Analytics`, `Firebase/Crashlytics`, `Firebase/Performance`
- UI/utilities: `SemiModalViewController`, `CircleMenu`, `MaterialComponents`, `ViewAnimator`, `FSCalendar`, `DGCharts`

Important config drift:

- `Podfile` platform: iOS `16.0`
- LifeBoard app build setting: `IPHONEOS_DEPLOYMENT_TARGET = 18.6`
- Pods post-install pins pods back to iOS `16.0`

Direct Swift import scan found no app-source imports for `CircleMenu`, `SemiModalViewController`, `MaterialComponents`, `ViewAnimator`, `FSCalendar`, or `DGCharts`. They remain linked through `OTHER_LDFLAGS`, so they are dependency cleanup candidates after storyboard, project, binary, and runtime-reference checks.

Risk classification:

| Dependency | Evidence | Risk | Next Action |
| --- | --- | --- | --- |
| `CircleMenu` | No direct Swift import; linked in Pods flags | Medium | Verify no storyboard/class-name/runtime string usage, then remove in isolated PR. |
| `SemiModalViewController` | No direct Swift import; linked in Pods flags | Medium | Verify no presentation controller subclass/runtime usage, then remove in isolated PR. |
| `ViewAnimator` | No direct Swift import; linked in Pods flags | Medium | Verify no dynamic animation calls, then remove in isolated PR. |
| `FSCalendar` | No direct Swift import; linked in Pods flags | Medium | Verify old calendar UI/storyboard usage is gone, then remove in isolated PR. |
| `DGCharts` | Chart files are already deleted in the dirty tree; no direct Swift import found | Medium | Finish chart removal PR, then remove pod and generated project refs. |
| `MaterialComponents` | No direct Swift import, but many Podfile/lock/project references and material image assets remain | Medium/High | Audit old design-system assets and runtime references before removal. |
| Firebase family | `AppDelegate` imports `Firebase`; Remote Config services use `canImport(FirebaseRemoteConfig)` | High | Keep until analytics/crash/performance/remote-config startup usage is mapped. |

### Swift Package Manager

Resolved SPM packages include:

- Direct app links in `project.pbxproj`: `Lottie`, `MLX`, `MLXRandom`, `MLXLLM`, `MLXLMCommon`, `Hub`, `Tokenizers`, `MarkdownUI`
- Transitive packages: `EventSource`, `NetworkImage`, `swift-asn1`, `swift-atomics`, `swift-cmark`, `swift-collections`, `swift-crypto`, `swift-huggingface`, `swift-jinja`, `swift-nio`, `swift-numerics`, `swift-syntax`, `swift-system`, `yyjson`

Direct import evidence:

- `MLXLMCommon`: 31 imports across app and tests.
- `MLX`, `MLXLLM`, `MLXRandom`, `Hub`, `Tokenizers`: used in LLM runtime/inference files.
- `MarkdownUI`: used in chat views.
- `Lottie`: used in `MoonAnimationView` and `EvaMediaView`.
- `EventSource` and `NetworkImage`: no direct app imports found; likely transitive from MLX/HuggingFace/Markdown packages and should not be removed directly unless package graph confirms they are direct/unneeded.

## 2. Dead-Code Candidates

### Immediate Low-Risk Candidates

The no-print guardrail fails on exactly three direct `print` calls:

- `LifeBoard/View/AddTaskInlineCreator.swift:84`
- `LifeBoard/View/AddTaskInlineCreator.swift:85`
- `LifeBoard/View/AddTaskProjectBar.swift:107`

These are the safest cleanup PR because behavior impact is negligible and `scripts/check-no-print-logs.sh` verifies the result.

### Dirty-Tree Deletion Candidates Already In Progress

The working tree already contains deletions in chart-related files:

- `LifeBoard/ViewControllers/Charts/BalloonMarker.swift`
- `LifeBoard/ViewControllers/Charts/DayAxisValueFormatter.swift`
- `LifeBoard/ViewControllers/Charts/LineChart.swift`
- `LifeBoard/ViewControllers/Charts/TinyPieChart.swift`
- `LifeBoard/ViewControllers/Charts/WeekDayAxisValueFormatter.swift`
- `LifeBoard/Views/Cards/ChartCard.swift`
- `LifeBoard/Views/Cards/ChartCardsScrollView.swift`
- `LifeBoard/Views/Cards/RadarChartCard.swift`
- `LifeBoard/Presentation/ViewModels/ChartCardViewModel.swift`
- `LifeBoard/Presentation/ViewModels/RadarChartCardViewModel.swift`

Treat these as an active chart-removal branch, not as new audit-owned deletions. Verify `DGCharts` removal only after this branch builds and tests.

### Dead-Code Scan Status

Periphery was not run in this pass because the project is actively dirty and the plan requires a clean build baseline before broad dead-code deletion. Use Periphery after the current redesign/charts changes compile.

Recommended command:

```sh
periphery scan --workspace LifeBoard.xcworkspace --schemes LifeBoard,LifeBoardTests,LifeBoardUITests --retain-public
```

## 3. Unused Asset And Resource Candidates

Resource baseline:

- Swift files across app/widgets/watch/tests: `554`
- Asset catalog sets: `43`
- Localized string keys in `LifeBoard/Localizable.xcstrings`: `372`
- Storyboards/XIBs: `2`
- Core Data model bundles: `2`
- Mascot sprite files in app plus loose organized folder: `53`

Largest resources observed:

| Resource | Size | Notes |
| --- | ---: | --- |
| `LifeBoard/LLM/EvaLottie00-lite.json` | 2.8 MB | Keep until Lottie/Eva activation usage is confirmed. |
| `LifeBoard/LLM/MascotSprites/*/spritesheet.webp` | 1.3-2.4 MB each | App-bundled runtime candidate; high risk. |
| `Organized Mascot Sprites/*/spritesheet.webp` | 1.3-2.4 MB each | Looks like duplicate loose source art; verify target membership before deletion. |
| `LifeBoard/Assets.xcassets/3D_icons/charts.imageset/charts.png` | 1.5 MB | Candidate if analytics/charts UI removal is final. |
| `LifeBoard/Assets.xcassets/3D_icons/{settings,search,inbox,chat,plus}` | 1.3-1.4 MB each | Referenced; keep unless redesigned. |
| `LifeBoard/Presentation/ViewModels/TaskIconSymbolManifest.generated.json` | 1.2 MB | Generated data; verify app bundle need. |

Asset sets with zero text references outside the asset catalog:

- `LifeBoard/Assets.xcassets/Buttons/icon_menu.imageset`
- `LifeBoard/Assets.xcassets/Buttons/icon_search.imageset`
- `LifeBoard/Assets.xcassets/Buttons/notifications-btn.imageset`
- `LifeBoard/Assets.xcassets/Buttons/settings-btn.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/material_add_White.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/material_close.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/material_day_White.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/material_done_White.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/material_evening_White.imageset`
- `LifeBoard/Assets.xcassets/Material_Icons/materialBackDrop/backdropFrontImage.imageset`
- `LifeBoard/Assets.xcassets/TableViewCell/at-12x12.imageset`
- `LifeBoard/Assets.xcassets/TableViewCell/excelIcon.imageset`
- `LifeBoard/Assets.xcassets/TableViewCell/shared-12x12.imageset`
- `LifeBoard/Assets.xcassets/TableViewCell/success-12x12.imageset`

Risk note: zero text references are not enough to delete assets. Confirm target membership, storyboard references, generated name lookup, and runtime `UIImage(named:)`/`Image(...)` construction before removal.

## 4. Stale Feature Flag Candidates

Primary flag surface:

- `LifeBoard/Services/V2FeatureFlags.swift`
- `LifeBoard/Services/GamificationRemoteKillSwitchService.swift`
- `LifeBoard/Services/LiquidMetalCTARemoteConfigService.swift`
- `LifeBoardWidgets/LifeBoardWidgetBundle.swift`
- `LifeBoardWidgets/TaskWidgetDesignSystemCompat.swift`

Flag families:

- Reminders sync/background refresh
- Task auto-icons
- Assistant apply/undo/copilot/semantic retrieval/fast mode/breakdown
- LLM prewarm/context/executive context/slash pins/haptics/runtime smoke
- Eva focus/triage/rescue/planning/composer/review/voice/scan
- iPad shell/performance flags
- Gamification v2/widgets/focus sessions/overhaul
- Task-list widgets and interactive widgets
- Remote Firebase kill switches for gamification and liquid-metal CTA

Staleness candidates:

- Flags defaulting to `true` and used mainly as guards around completed behavior should be reviewed first: `gamificationV2Enabled`, `assistantApplyEnabled`, `assistantUndoEnabled`, `assistantCopilotEnabled`, `assistantBreakdownEnabled`, `iPadNativeShellEnabled`, and iPad performance v2/v3 flags.
- Flags defaulting to `false` should not be deleted automatically; some appear to gate deferred roadmap work: `evaTimelineInlineDiff`, `evaAppliedRunHistory`, `evaVoiceDeferred`, `evaScanDeferred`, selected LLM diagnostics/smoke flags.
- Remote-kill-switch-backed flags are higher risk and should remain until remote config usage and App Store rollback needs are explicitly decided.

## 5. Large-File And God-Class Candidates

Largest production files:

| File | Lines | Candidate Split |
| --- | ---: | --- |
| `LifeBoard/Presentation/ViewModels/HomeViewModel.swift` | 10,528 | Extract widget snapshot service, Eva focus/triage/rescue orchestration, persistence adapters, mutation reducers, formatting/builders. |
| `LifeBoard/Onboarding/AppOnboarding.swift` | 10,494 | Split state/domain types, persistence store, coordinator, SwiftUI screens, subviews, model install flow. |
| `LifeBoard/View/SunriseAppShellView.swift` | 7,612 | Extract shell sections, sheets, analytics face, search chrome, routing/actions. |
| `LifeBoard/View/SunriseTimelineSurface.swift` | 7,417 | Extract rows, layout calculations, gesture state, rendering helpers. |
| `LifeBoard/ViewControllers/HomeViewController.swift` | 6,213 | Extract navigation/presentation coordinator, analytics surface coordinator, notification/deeplink handling, UIKit hosting helpers. |
| `LifeBoard/Presentation/ViewModels/InsightsViewModel.swift` | 2,695 | Extract calculations and presentation models. |
| `LifeBoard/Views/Settings/LifeManagementView.swift` | 2,641 | Extract sections and destructive flow UI. |
| `LifeBoard/UseCases/Habit/HabitRuntimeUseCases.swift` | 2,490 | Split focused use cases. |
| `LifeBoard/LLM/Models/AssistantPlannerService.swift` | 2,265 | Extract prompt building, validation, tool/action mapping. |
| `LifeBoard/LLM/Views/Chat/ChatView.swift` | 2,243 | Extract composer, transcript, context, and action panels. |

Concurrency and lifecycle hotspots:

- `@unchecked Sendable`: `176` occurrences.
- `DispatchQueue`/`OperationQueue`: `143` occurrences.
- `Task {}`/task-group patterns: `355` occurrences.
- `NotificationCenter`: `113` occurrences.
- `Timer`: `8` occurrences.
- Combine-related `AnyCancellable`/`@Published`/publisher usage: `459` occurrences.

These counts are audit baselines, not direct bugs. Use targeted reviews before changing concurrency behavior.

## 6. Obsolete Project Configuration Candidates

### Build Settings And Project Structure

Observed settings for `LifeBoard`:

- `SWIFT_VERSION = 5.0`
- `SWIFT_STRICT_CONCURRENCY = complete`
- `IPHONEOS_DEPLOYMENT_TARGET = 18.6`
- `CODE_SIGN_ENTITLEMENTS = LifeBoard.entitlements`
- `INFOPLIST_FILE = LifeBoard/Info.plist`
- `DEAD_CODE_STRIPPING = YES`
- `ENABLE_USER_SCRIPT_SANDBOXING = NO`
- `OTHER_LDFLAGS` still links all CocoaPods frameworks, including cleanup candidates.

Project cleanup candidates:

- Normalize deployment target between `Podfile` and app targets.
- Review `ENABLE_USER_SCRIPT_SANDBOXING = NO`; keep only if CocoaPods scripts require it.
- Review Pods schemes in shared workspace; do not delete generated Pods schemes manually unless CocoaPods generation is changed.
- Confirm first-party shared schemes are only `LifeBoard`, `LifeBoardWatch`, `LifeBoardWatchWidgets`, and `LifeBoardWidgets`.
- Clean stale build phases only after dependency removals; current shell phases are CocoaPods manifest/framework phases.

### Info.plist And Entitlements

Info.plist candidates requiring product confirmation:

- URL schemes: `lifeboard`, `tasker`
- Background modes: `fetch`, `remote-notification`
- BGTask IDs: occurrences, reminders, daily brief
- Permissions: calendars full access, calendars usage, reminders usage
- `UIRequiredDeviceCapabilities = armv7` is suspicious for a modern iOS 18.6 target and should be verified.

Entitlement candidates requiring runtime confirmation:

- Push: `aps-environment = development`
- iCloud: `CloudKit`, `CloudDocuments`, ubiquity containers, kvstore
- App group: `group.com.saransh1337.tasker.shared`

Do not remove iCloud, app group, push, or background modes until Core Data/CloudKit, widgets, watch sync, notifications, and background refresh are covered.

## 7. Top 10 Safest Cleanup PRs

1. Remove the three direct `print` calls in app sources.
   - Risk: Low
   - Verify: `scripts/check-no-print-logs.sh`, targeted build.

2. Finish and verify the chart UI removal already in the dirty tree.
   - Risk: Medium
   - Verify: `rg "ChartCard|RadarChart|LineChart|DGCharts|Charts" LifeBoard LifeBoardTests LifeBoardUITests`, build, affected analytics tests.

3. Remove `DGCharts` only after chart removal builds cleanly.
   - Risk: Medium
   - Verify: `pod install`, `xcodebuild ... build`, `rg "DGCharts|Charts"`.

4. Remove zero-reference legacy button/table/material image assets in one asset-only PR.
   - Risk: Low/Medium
   - Verify: asset reference scan, target membership scan, build, smoke home/settings/onboarding.

5. Decide and normalize iOS deployment target drift between `Podfile` and Xcode build settings.
   - Risk: Low/Medium
   - Verify: `pod install`, build, `xcodebuild -showBuildSettings`.

6. Remove or route raw demo/preview logging through `LoggingService`.
   - Risk: Low
   - Verify: no-print script and build.

7. Audit and remove one unused CocoaPod with no direct imports, starting with `ViewAnimator` or `CircleMenu`.
   - Risk: Medium
   - Verify: full reference scan, `pod install`, build, launch smoke.

8. Split `HomeViewModel` by extracting `TaskListWidgetSnapshotService` and persistence/widget snapshot logic.
   - Risk: Medium
   - Verify: `HomeViewModelPersistenceTests`, widget snapshot tests, home UI smoke.

9. Split `AppOnboarding.swift` by moving pure state/domain/persistence helpers out first.
   - Risk: Medium
   - Verify: `AppOnboardingTests`, onboarding UI smoke.

10. Concurrency audit pass for `@unchecked Sendable` in repositories and coordinators without changing behavior.
    - Risk: Medium
    - Verify: strict-concurrency build, targeted repository/use-case tests.

## Verification Commands

```sh
git status --short --branch
xcodebuild -list -workspace LifeBoard.xcworkspace
xcodebuild -showBuildSettings -workspace LifeBoard.xcworkspace -scheme LifeBoard | rg "SWIFT_VERSION|SWIFT_STRICT_CONCURRENCY|IPHONEOS_DEPLOYMENT_TARGET|OTHER_LDFLAGS"
scripts/check-no-print-logs.sh
rg "^import " LifeBoard LifeBoardWidgets LifeBoardWatch LifeBoardWatchWidgets LifeBoardTests LifeBoardUITests -g "*.swift"
find LifeBoard LifeBoardWidgets LifeBoardWatch LifeBoardWatchWidgets LifeBoardTests LifeBoardUITests -type f -name "*.swift" -print0 | xargs -0 wc -l | sort -nr | sed -n "1,80p"
find LifeBoard LifeBoardWidgets LifeBoardWatch LifeBoardWatchWidgets public src screenshots SunriseImages "Organized Mascot Sprites" -type f -print0 | xargs -0 du -h | sort -hr | sed -n "1,80p"
xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

## Build Baseline

Build command used:

```sh
xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -configuration Debug -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

Result: build succeeded.

- Log: `/tmp/lifeboard_cleanup_build_20260516.log`
- Warning count: `11`
- Error count: `0`
- Diagnostics: all first-pass warnings were `appintentsmetadataprocessor` metadata extraction warnings stating that no `AppIntents.framework` dependency was found for some metadata-processing contexts.
- Terminal marker: `** BUILD SUCCEEDED **`
