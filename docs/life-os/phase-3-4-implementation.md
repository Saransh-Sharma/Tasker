# Phase III/IV Implementation Status

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

## Remaining before Phase III promotion

- [ ] Connect EventKit read-only commitments to `PlanStore` capacity/free-window projections and calendar detail sheets.
- [ ] Add phone drag/drop and pointer/keyboard iPad board interactions for tasks and blocks.
- [ ] Reuse weekly outcomes/review/triage use cases in the persistent Week lens and implement bulk backlog undo receipts.
- [ ] Finish Focus Execution V2 persistence/state-machine integration, pause/resume recovery, ActivityKit Live Activity, lock-screen controls, and duplicate-command tests.
- [ ] Route deterministic Plan receipts/explanations into Eva and complete diff/confirm/apply/audit/undo repair mutations.
- [ ] Add the complete seeded Plan UI/accessibility suite and matched physical-device performance baselines.

## Remaining before Phase IV promotion

- [ ] Connect the canonical habit occurrence repository to Track Today/history so production grades, streaks, off days, recovery, pause, and archive feed every projection.
- [ ] Add habit group/resilience editors and the full 30-day history surface.
- [ ] Add typed goal-link editing and normalized source samples from tasks, habits, routines, projects, and trackers.
- [ ] Route routine linked task/habit completion through canonical mutation use cases exactly once.
- [ ] Finish starter-pack habit/reminder creation through canonical editors and reversible pack removal while retaining history.
- [ ] Add hydration correction/history/target editing, complete medication schedule/reschedule UI, mood trends, and sleep history.
- [ ] Add normalized Insights/Eva receipts with sensitivity authorization and explicit external-surface redaction tests.
- [ ] Complete the Phase IV seeded UI/accessibility/privacy/performance matrix on signed physical devices.

## Verification commands

```sh
xcodebuild -project LifeBoard.xcodeproj -scheme LifeBoard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -project LifeBoard.xcodeproj -scheme LifeBoard \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LifeBoardTests/LifeBoardPlanningTrackFoundationTests \
  -only-testing:LifeBoardTests/LifeOSFoundationContractTests test
```

Latest local result: build succeeded; 38 focused tests passed with zero failures.
