# iPad UI Rehaul TODO

## Recovery Workstream
- [x] Switch app target to universal (`TARGETED_DEVICE_FAMILY = "1,2"` for Tasker target).
- [x] Keep widget target iPhone-only.
- [x] Add `UISupportedInterfaceOrientations~ipad` with all orientations.
- [x] Restrict iPhone orientations to portrait + upside-down.
- [x] Add runtime orientation resolver (`DeviceOrientationPolicyResolver`) in `AppDelegate`.

## Shell Reliability and Routing
- [x] Harden layout classification for zero-width host views via window/scene fallback.
- [x] Defer first shell mount until stable non-zero layout metrics exist.
- [x] Keep remount behavior on width-class/layout-class transitions.
- [x] Replace compact add-task destination side-effect with explicit modal request channel.
- [x] Apply layout-class context to iPad fallback sheet roots (add task/task detail).

## iPad Surface Completion
- [x] Home/Search/Analytics routed through iPad split shell destinations.
- [x] Add Task inspector on `padExpanded` with sheet fallback on smaller iPad classes.
- [x] Task Detail inspector mode on `padExpanded` with sheet/fullscreen fallback on smaller classes.
- [x] Settings and Projects integrated in split-first iPad flow.
- [x] Chat split behavior keyed off layout class (`padRegular`/`padExpanded`), not idiom.
- [x] Remove duplicate project-management V2 implementation path.
- [x] Restore iPhone chat title casing regression (`"chats"`).

## Accessibility and Testability
- [x] Keep minimum 44x44 target sizing in iPad shell controls.
- [x] Keep minimum 8pt spacing between adjacent interactive controls.
- [x] Add explicit iPad shell accessibility identifiers for destinations/inspector/toggle.
- [x] Preserve reduced-motion handling in existing animated surfaces.

## Validation
- [x] Build succeeds on iPad simulator destination.
- [x] Build succeeds on iPhone simulator destination.
- [x] Unit tests pass for orientation resolver + layout resolver fallback.
- [x] Add orientation-policy UI tests (iPhone landscape blocked + iPad all orientations).
- [x] Add iPad destination-switch UI test coverage for split-shell surfaces (tasks/search/analytics/add/settings/projects).
- [ ] Run full iPhone UI regression suite.
- [ ] Run full iPad UI regression suite across split/Stage Manager widths.

## Premium UI Overhaul
- [x] Add a shared premium surface treatment with iOS 26-aware fallback styling.
- [x] Rebuild home top chrome, quick filters, and search face hierarchy.
- [x] Upgrade analytics tab chrome and card surfaces into the shared visual system.
- [x] Refresh chat thread, chats list, and composer hierarchy.
- [x] Bring legacy UIKit search visuals closer to the shared SwiftUI language.
- [ ] Validate home redesigned chrome on iPhone and iPad.
- [ ] Validate analytics redesigned tabs and premium cards on iPhone and iPad.
- [ ] Validate chat redesigned header, composer, and thread states.
- [ ] Validate quick-filter dropdown and advanced filter sheet flows.
- [ ] Validate legacy UIKit search parity against the SwiftUI search chrome.
