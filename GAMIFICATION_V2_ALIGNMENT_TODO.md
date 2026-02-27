# Gamification V2 Final Alignment TODO

- [x] Activate `TaskModelV3_Gamification` as current Core Data model in project metadata.
- [x] Add migration-safe `DailyXPAggregate` canonical upsert/merge by `dateKey`.
- [x] Add schema guardrail diagnostics where required entities/fields are missing.
- [x] Ensure widget snapshots refresh after XP-affecting events and remote reconciliation.
- [x] Populate all widget snapshot fields (`focusMinutesToday`, `tasksCompletedToday`).
- [x] Enable gamification feature flags by default and preserve kill switch behavior.
- [x] Add App Group entitlement for app + widget shared storage compatibility.
- [x] Wire missing Home focus/reflection/insights entry points and callbacks.
- [x] Add celebration cooldown coordinator wiring (30s suppression).
- [x] Implement reflection nudge policy with max two nudges/day and completion-aware cancellation.
- [x] Enforce Monday-aligned weekly visuals/labels across app and widgets.
- [x] Add deep-link handling for `tasker://focus`.
- [x] Fix protocol test stubs so `build-for-testing` compiles.
- [x] Run `xcodebuild` build + build-for-testing and capture results.
- [ ] Manual Xcode step: create `TaskerWidgets` extension target and attach existing widget source files + `TaskerWidgets.entitlements`.
- [ ] Manual smoke suite: completion XP, focus XP, reflection XP, insights, widgets, celebrations.
- [ ] Telemetry sanity: validate KPI numerator/denominator tracking for 30+ XP DAU.
- [ ] Staging validation: verify remote kill switch disables gamification safely.
