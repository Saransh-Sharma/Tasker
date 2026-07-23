# Phase III/IV Implementation Status

> **Classification: Historical implementation record.** Current Plan/Track product behavior is canonical in the [product handbook](../product/README.md); active completion is owned by the [remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md).

This file is the repository-local execution checklist for the approved 30-week Phase III/IV plan. It distinguishes the implemented foundation vertical slice from work that still requires product, device, entitlement, or legacy-domain integration.

## Implemented

- [x] Serialize `TaskModelV3_PlanningCore` after `TaskModelV3_KnowledgeNotes`.
- [x] Serialize `TaskModelV3_TrackFoundations` after Planning Core and make it current.
- [x] Add task planning-day/commitment/availability/context fields, project execution mode, focus execution fields, internal blocks, working hours, and mutation receipts.
- [x] Add goals/links, habit groups/resilience, routines/steps/runs/events, hydration, sleep context, and starter-pack installation entities.
- [x] Keep managed objects behind background-context repositories and expose Sendable values.
- [x] Implement date-only `PlanningDay`, overlap-safe capacity, dependency cycles/readiness, deterministic 100-point Focus ranking, repair proposals, and estimate calibration.
- [x] Implement Day/Week/Backlog Plan projections and a production destination with internal block editing and task planning-state actions.
- [x] Implement 30-day habit-grade/streak/recovery rules, routine branching/idempotency/version snapshots, goal completeness confidence, and hydration conversion.
- [x] Implement Track Today with routines, care tiles, goals, Journal/Notes links, sleep privacy, and starter-pack preview/partial selection.
- [x] Add Mood, Hydration, Medication Event, and Routine Run Universal Capture providers.
- [x] Feed Home immutable Plan/Track snapshots and deterministic Focus explanations.
- [x] Preserve legacy schedule, weekly planner, Habit, and Phase II Track surfaces as rollback adapters.
- [x] Validate the app build, focused migration/contracts, repository round trips, and simulator runtime composition.
- [x] Read EventKit commitments without mutation, derive free windows, and expose denied/not-determined states honestly.
- [x] Persist working hours, planning mutations/receipts, Focus V2 sessions/commands, routine schedules, linked-mutation receipts, and starter-pack ownership.
- [x] Add exact-once Focus commands, restoration, ActivityKit/Lock Screen presentation, orphan reconciliation, and deep-link command handling.
- [x] Add task-to-free-window drag/drop plus menu/keyboard block move, resize, split, and remove alternatives.
- [x] Connect canonical habit evidence, typed goal samples, and canonical routine-linked task/habit mutations.
- [x] Complete routine authoring/scheduling/timers, hydration target/correction/history, medication lifecycle/reconciliation, fasting target/correction/history, mood history, and sleep history.
- [x] Install and remove starter-pack habits/reminders through canonical use cases with compensating rollback and history-preserving archive.
- [x] Separate daypart atmosphere from system appearance, including a warm lunar Light appearance.
- [x] Add the Focus Live Activity widget and align app/widget versions.
- [x] Remove XCTest-only APNs, background-task, App Group refresh, and gamification persistent-history noise.

## Remaining before Phase III public promotion

- [x] Connect EventKit read-only commitments to capacity/free-window projections.
- [x] Add phone task-to-window drag/drop and menu/keyboard equivalents for block editing.
- [x] Persist backlog bulk mutations and exact undo receipts.
- [x] Finish Focus V2 persistence, state transitions, restoration, ActivityKit, Lock Screen commands, and duplicate-command handling.
- [x] Apply plan repairs through durable typed mutation receipts and undo.
- [ ] Replace the remaining Week compatibility summary with the complete weekly outcomes/review/triage workflow and prove iPad board pointer interactions.
- [ ] Finish Eva’s conversational receipt/evidence presentation around the deterministic explanation and repair pipeline.
- [ ] Add the full seeded Plan UI/accessibility suite and matched signed-device performance baselines.

## Remaining before Phase IV public promotion

- [x] Connect canonical habit occurrence evidence so production grades, streaks, off days, and recovery feed Track/Home projections.
- [ ] Add habit group/resilience editors and the full 30-day history surface.
- [x] Add typed goal links and normalized samples from tasks, habits, routines, projects, and trackers.
- [x] Route routine linked task/habit completion through canonical mutation use cases exactly once.
- [x] Complete reversible starter-pack goal/routine/habit/reminder installation with retained history.
- [x] Add hydration correction/history/target editing, medication scheduling/unresolved/snooze flows, fasting correction/history, multiple mood check-ins, and sleep history.
- [ ] Replace raw UUID entry in goal/routine link editors with searchable source pickers.
- [ ] Complete mood trend visualization and edit/delete semantics; add full hydration and sleep history filtering.
- [ ] Finish the advertised structured Notes block semantics (table, bookmark metadata, image/file lifecycle, and note-link blocks) and nested-folder navigation.
- [ ] Finish the selected Journal parity scope: resilient audio/transcription retry, media editing, complete semantic memory/rebuild controls, reflection versions, exports, and lock/privacy controls.
- [ ] Add normalized Insights/Eva receipts with sensitivity authorization and explicit external-surface redaction tests.
- [ ] Complete the Phase IV seeded UI/accessibility/privacy/performance matrix on signed physical devices.

## Verification commands

```sh
xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' build

xcodebuild -workspace LifeBoard.xcworkspace -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -only-testing:LifeBoardTests/LifeBoardPlanningTrackFoundationTests \
  -only-testing:LifeBoardTests/LifeOSFoundationContractTests test
```

Latest local result (2026-07-14): iOS Simulator and Mac Catalyst builds succeeded; 44 focused tests passed with zero failures. The runtime visual audit also passed the Night + Light-appearance independence check. Public completion remains blocked by the explicit unchecked items above and signed-device/manual gates; this file must not be used to claim full Phase I–IV promotion before those checks close.
