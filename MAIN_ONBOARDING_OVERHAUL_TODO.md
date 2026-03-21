# Main Onboarding Overhaul TODO

- [x] Add shared onboarding accessibility identifiers in app code.
- [x] Add an onboarding host adapter seam to reduce direct coordinator coupling.
- [x] Redesign the main onboarding flow for a calmer premium visual system.
- [x] Rework welcome, life areas, projects, first task, focus room, success, and prompt surfaces.
- [x] Apply the restraint pass across Setup, Areas, Projects, First win, Finish, and Done.
- [x] Remove mixed premium/concierge vocabulary and standardize CTA naming.
- [x] Compress Projects to one active project per area with on-demand options.
- [x] Slim the sticky footer and simplify success handoff.
- [x] Preserve the existing onboarding flow order and CTA/accessibility contracts.
- [x] Add unit regression coverage for restore, replay, and queue behavior.
- [x] Update UI coverage for onboarding resume, custom-task round trip, and new CTA wording.
- [x] Run a clean project build and onboarding test pass.

Verification:
- `xcodebuild -workspace Tasker.xcworkspace -scheme 'To Do List' -destination 'platform=iOS Simulator,id=0477D2A9-9449-4797-8762-410788F0B90C' build`
- `xcodebuild -workspace Tasker.xcworkspace -scheme 'To Do List' -destination 'platform=iOS Simulator,id=0477D2A9-9449-4797-8762-410788F0B90C' -only-testing:'To Do ListTests/AppOnboardingTests' test`
