# Sunrise Glass v2.1 Overhaul TODO

> **Classification: Historical visual migration plan.** Current design behavior is defined by [DESIGN.md](../../DESIGN.md) and the [UI/UX guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md).

- [x] Phase 0: Update `LifeBoardSunriseGlassDesign.md` to v2.1.0 with Day Compass, onboarding, and creation-sheet rules.
- [x] Phase 1: Implement Day Compass state arbitration, snoozes, Home top-card UI, routing, notification deep links, and focused tests.
- [x] Phase 2: Polish Home timeline, inbox shelf, assistant prompts, empty/loading/error states, and habit board presentation.
- [x] Phase 3: Polish creation sheets, native habit reminder pickers, shared creation chips, and success feedback.
- [x] Phase 4: Migrate onboarding to the 8-step Sunrise Glass flow while preserving enum raw-value compatibility.
- [x] Verification: target membership, Swift diff token guardrail, and Catalyst build-for-testing passed; focused test execution is blocked on this host because macOS 26.4.1 is below the LifeBoardTests macOS 26.5 deployment target.

Notes:

- Preserve existing uncommitted `LifeBoard/Localizable.xcstrings` changes unless explicitly editing localized strings.
- Keep marketing web under `src/` out of scope.
- Commit each phase separately on `sunrise-glass-v2-1-overhaul`.
