# Seeded UI Test Suite TODO

- [x] Review existing UI test harness, seeders, and route handling.
- [x] Add suite launch flags and post-seed route support.
- [x] Add deterministic seeded data for Overdue Rescue, Reflect & Plan, and Focus Now.
- [x] Add stable accessibility identifiers for tested interactive surfaces.
- [x] Add page objects and seeded UI test classes.
- [x] Wire new files into `LifeBoard.xcodeproj`.
- [x] Run target-membership and legacy guardrail checks.
- [ ] Run targeted seeded UI test runtime verification to completion.

## Verification Notes

- `scripts/check-xcode-target-membership.sh` passes after wiring the new files.
- `scripts/validate_legacy_test_guardrails.sh` exits cleanly.
- `xcodebuild build-for-testing` passes for the selected seeded UI test classes on `platform=iOS Simulator,name=iPhone 17 Pro`.
- Runtime runs were started and surfaced follow-up issues:
  - Focus Now home strip is not found reliably from the new suite launch path yet.
  - Overdue Rescue needed the main sheet root identifier; this was fixed, but the full rescue/reflect runtime pass still needs rerun.
