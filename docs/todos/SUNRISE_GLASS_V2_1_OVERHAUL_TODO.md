# Sunrise Glass v2.1 Overhaul TODO

- [x] Phase 0: Update `LifeBoardSunriseGlassDesign.md` to v2.1.0 with Day Compass, onboarding, and creation-sheet rules.
- [x] Phase 1: Implement Day Compass state arbitration, snoozes, Home top-card UI, routing, notification deep links, and focused tests.
- [x] Phase 2: Polish Home timeline, inbox shelf, assistant prompts, empty/loading/error states, and habit board presentation.
- [x] Phase 3: Polish creation sheets, native habit reminder pickers, shared creation chips, and success feedback.
- [ ] Phase 4: Migrate onboarding to the 8-step Sunrise Glass flow while preserving enum raw-value compatibility.
- [ ] Verification: run target membership, diff token guardrail, focused tests, and Catalyst build-for-testing.

Notes:

- Preserve existing uncommitted `LifeBoard/Localizable.xcstrings` changes unless explicitly editing localized strings.
- Keep marketing web under `src/` out of scope.
- Commit each phase separately on `sunrise-glass-v2-1-overhaul`.
