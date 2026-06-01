# Home Strangler Refactor TODO

This tracks the move-only and behavior-extraction sequence for the Home, Timeline, and Add Task refactor.

## Guardrails

- [ ] Keep move-only PRs limited to file moves, imports, target membership, and temporary access-control changes.
- [ ] Preserve public/internal symbol names, accessibility identifiers, `.id(...)` behavior, modal presentation styles, sheet detents, animation constants, state transitions, and keyboard focus.
- [ ] Add behavior parity tests before replacing day-swipe, timeline overlap, or Add Task collaborator logic.
- [ ] Add every new production Swift file only to the `LifeBoard` target unless it is intentionally shared.
- [ ] Add every new test file only to `LifeBoardTests` or `LifeBoardUITests`.
- [ ] Run `scripts/check-xcode-target-membership.sh` after adding or moving Swift files.
- [ ] Split any refactor PR that grows beyond roughly 1,000 changed lines.
- [ ] Clean up any temporary `fileprivate` access before the final cleanup pass.

## Baseline Build And Test Commands

- [ ] Build app on iPhone: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6' build`
- [ ] Build app on iPad: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=18.6' build`
- [ ] Build widgets when shared/widget code is touched: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoardWidgets -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6' build`
- [ ] Build watch widgets when watch/widget code is touched: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoardWatchWidgets build`
- [ ] Focused unit tests: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6' test -only-testing:LifeBoardTests/HomeViewControllerLifecycleTests -only-testing:LifeBoardTests/HomeSunriseLayoutMetricsTests -only-testing:LifeBoardTests/HomeBottomBarStateTests`
- [ ] Focused UI tests: `xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.6' test -only-testing:LifeBoardUITests/HomeTimelineSeededUITests -only-testing:LifeBoardUITests/HomeReplanDayUITests -only-testing:LifeBoardUITests/Tests/Critical/TaskCreationTests`

## Current Verified Status

- [x] Last verified slice: split Home controller, Home view-model support, Home shell face, and pure timeline support into move-only files.
- [x] Latest structural checks passed: Home controller extensions, Home view-model view-state/timeline/widget/daily-summary support, `HomeSunriseFace`, timeline preference keys, time-block packing, phone render models, and renderer models live in dedicated files.
- [x] Latest project checks passed: `plutil -lint LifeBoard.xcodeproj/project.pbxproj` and `scripts/check-xcode-target-membership.sh`.
- [x] Latest app verification passed on iPhone 16 Pro Max iOS 18.6 and iPad Pro 13-inch (M4) iOS 18.6.
- [ ] Latest focused Home tests did not pass: focused unit tests ran `272` tests with `5` failures; selected timeline/replan UI tests ran `8` tests with `3` failures; full `LifeBoardTests` ran `1348` tests with `81` failures and `3` skipped.
- [ ] Known non-blocking noise remains: app extension `CFBundleVersion` mismatch, multiple matching simulator destination warning, app-group entitlement warnings in tests, and existing Swift concurrency/deprecation warnings in tests.
- [ ] Temporary access-control cleanup remains: several moved Home controller/view-model methods and properties were widened from `private` to internal to keep the first pass move-only.

## Next Major Phase

- [ ] Continue splitting `SunriseAppShellView.swift` in small move-only slices.
  - [x] Move iPad shell support types into a dedicated file under `Presentation/Home/Shell`.
  - [x] Move pure Sunrise layout support into `Presentation/Home/Shell`.
  - [x] Move Home day-swipe resolver into `Presentation/Home/Shell`.
  - [x] Move Home search support into `Presentation/Home/Search`.
  - [x] Move small timeline column layout support into `Presentation/Home/Timeline`.
  - [ ] Defer timeline pane/cache composition if moving it touches timeline behavior, layout logic, cache invalidation semantics, or requires parity fixtures.
  - [ ] Defer day-swipe extraction until parity fixtures exist.
  - [ ] Stop and split smaller if the next extraction requires broad rewiring beyond imports, target membership, and narrow access-control changes.

## Sequence

- [x] Reuse target-membership guardrail script.
- [x] Add markdown TODO tracking for this refactor.
- [x] Move Home render/state value types and stores out of `HomeViewController.swift`.
- [ ] Split Home shell/controller extensions.
  - [x] Move shell top-level layout/host/container/policy types into `Presentation/Home/Shell`.
  - [x] Move bindings, render pipeline, keyboard, bottom bar mounting, and shell construction extensions.
- [ ] Split Home navigation, modals, iPad construction, and UI test seeding.
  - [x] Move self-contained Home modal/support view types into `Presentation/Home/Modals`.
  - [x] Move UI test workspace seeding into `TestingSupport`.
  - [x] Move navigation/deep-link/reload delegate extensions, modal presentation methods, and iPad helpers.
- [ ] Extract Home task-detail modal adapter.
- [ ] Split `SunriseAppShellView.swift`.
  - [x] Move `NeedsReplanTrayView` and `NeedsReplanLauncherSheet` into `Presentation/Home/Replan`.
  - [x] Move needs-replan card and summary floating overlays into `Presentation/Home/Replan`.
  - [x] Move primary widget pager/rail into `Presentation/Home/Widgets`.
  - [x] Move rescue sheet into `Presentation/Home/Modals`.
  - [x] Move iPad shell support types.
  - [x] Move pure Sunrise layout support types.
  - [x] Move Home day-swipe resolver.
  - [x] Move Home search support.
  - [x] Move `HomeSunriseFace` into `Presentation/Home/Shell`.
  - [ ] Move timeline pane/cache composition.
    - [x] Move timeline snapshot render cache.
    - [x] Move timeline column layout support.
- [ ] Add day-swipe parity fixtures and extract `HomeDaySwipeController`.
- [ ] Split `SunriseTimelineSurface.swift`.
  - [x] Move timeline preference keys, time-block packing, phone render/flock models, and renderer models into `Presentation/Home/Timeline`.
- [ ] Add timeline golden fixtures and extract pure overlap layout engine.
- [ ] Split Add Task UI.
- [ ] Extract Add Task ViewModel collaborators in the approved order.
- [ ] Cleanup temporary access control and imports.
