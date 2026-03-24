# UI Remediation TODO

- [x] Create shared presentation scaffolding for agenda rows and analytics modules.
- [x] Remove `Add Task` as an iPad sidebar destination and keep creation as an action.
- [x] Simplify Home top chrome to reduce competing utility actions.
- [x] Unify task and habit rows around one agenda grammar.
- [x] Rebuild Analytics around one hero plus support modules per tab.
- [x] Calm Search and Chat utility surfaces.
- [x] Simplify Add Task and Add Habit flows.
- [x] Apply copy, motion, accessibility, and polish pass.
- [ ] Run targeted verification on iPhone and iPad layouts.

## Verification Notes

- [x] Focused unit coverage passed for agenda presentation mapping, `HomeBand` ordering, and insights visibility planning.
- [x] Focused iPhone UI checks passed for add-task summary gating and add-habit advanced disclosure behavior.
- [ ] Focused iPhone search UI checks are currently blocked by simulator storage exhaustion (`No space left on device` while installing the app on simulator `0477D2A9-9449-4797-8762-410788F0B90C`).
- [x] iPad toolbar-only task creation passed on simulator `F1BE717E-AC18-4A39-BEEE-6D0B680CFBA3` after hardening the interruption/retry path in the UITest.
- [ ] iPad sidebar/content destination verification still skips in the simulator run because `home.ipad.destination.*` controls are not exposed to the test harness.
