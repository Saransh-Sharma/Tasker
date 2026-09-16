# Milestone 1 continuation

- [x] Verify drafted work compiles; targeted tests green (2026-09-16).
- [x] Separate When from Deadline; one planned-day rule across Day/Week/Backlog/capacity.
- [x] Serialized autosave (flush waits for in-flight save); When default time.
- [x] Plan header → one orientation bar (day, capacity, Timeline/Agenda toggle) + decision line.
- [x] Canvas craft: scroll-to-now fix, short hour labels, minute-accurate shading, quiet open windows, day swipe, breathing now dot, ghost block + snap ticks + landing caustic.
- [x] Unscheduled drawer (floats over canvas, sized to content, Place button); Anytime row above canvas.
- [x] Rescue entry restored on Plan (decision line + Agenda card).
- [x] Receipts on ReceiptBar (composer with Open, task editor, Home repair).
- [x] Home: mode chip on the date line, one-line quiet day, repair state machine with diff rows.
- [x] Composer token autocomplete (#tag, +project, @context).
- [ ] Composer highlighting — attempted with an AttributedString TextEditor; dropped keystrokes and stuck Send, reverted.
- [x] Task editor chips read their values.
- [x] PRD capture commit-boundary sentence amended.
- [ ] Open: Plan store does not reload after a Plan-launched Overdue Rescue closes (UI test testFoundationOpenDayLaunchesOverdueRescueAndKeepsTaskInPlannedWork, last step).
- [ ] Open: triage remaining Foundation UI failures against a clean-HEAD run (Home hero/signals, a11y-size, visual evidence).
- [ ] Deferred: split Home out of the Gallery file.

Preserve existing edits; no commits.

## Next phase (2026-09-16, evening)

- [x] A1 Plan reloads after Rescue (environment-carried refresh generation; roots are cached by `StableDestinationRoot`).
- [x] A2 Foundation UI suite vs clean HEAD: 9 failures are baseline; 4 regressions fixed (plan.header stamping, quiet-day Add button, fasting scroll, rescue).
- [ ] A3 Split Home out of the Gallery file.
- [x] B1 `TaskModelV3_HabitProgress`: `Occurrence.recordedValue` (+ migration test; model-count baseline test fixed).
- [x] B2 `LogHabitAmountUseCase` + `HabitAmountRule` (tested).
- [x] B3 `HabitProgressRing`: tap +step, hold to target, hold-and-slide scrub, completion morph + burst, failure shake, stepper at accessibility sizes.
- [x] B4 Habit Board Day lens ring (UI test) and **Home "Habits today"** (UI test: check-in completes on hold, receipt with Undo). Old Sunrise `HomeHabitRowView` is unused in the live app; its hold change was reverted.
- [x] M3 resilience notes (`HabitResilienceCopy`), stable tile order, context menu moved off the ring.
- [ ] M4 firstLight on the first completion of the day.
- [ ] B5 template gallery + targets; B6 interactive habit widget.
- [x] C1 Live Activity pause/resume/end act in place (`FocusLiveActivityCommandIntent` + app bridge), Dynamic Island progress ring, "Done · N min" end state for 60 s. **Not yet exercised on a device/simulator Live Activity.**
- [ ] C2 reflection at session end, C3 focus history, C4 presets/Control, C5 remove legacy `FocusSessionUseCase`.

Concurrent work in this tree (onboarding/LifeWeave refactor, `FoundationPlanRoutes.swift` commit 2319efd03) currently fails token-law (`LifeWeaveShapeSteps.swift:21`) and module-boundaries (`LifeBoardTranscription` import); neither is from this work.
