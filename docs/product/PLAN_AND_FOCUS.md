# Plan, Focus, Repair, and Review

**Classification:** Canonical feature contract

**Root:** Plan
**Related:** [Adaptive Home](./HOME.md), [Calendar + Timeline](../calendar/README.md), [Insights and EVA](./INSIGHTS_AND_EVA.md)

## Promise and user jobs

Plan turns intent into a realistic sequence without pretending fixed calendar commitments are editable LifeBoard work. It supports daily execution, weekly allocation, backlog triage, focused sessions, and recovery when the plan no longer fits.

Users come to Plan to:

- place tasks around fixed commitments;
- understand capacity before committing;
- review Day, Week, and Backlog at the appropriate density;
- start or resume a Focus session;
- repair conflicts, overdue work, or an overloaded day;
- review the week and carry forward decisions intentionally.

## Information architecture

Plan owns Day, Week, Backlog, Focus, Weekly Planner, and Weekly Review. Typed routes preserve the selected root and stable entity/session identities.

### Day

Day is the primary execution lens. Its hierarchy is date/capacity, schedule lens, current/next work, fixed calendar context, planned tasks/time blocks, unplaced work, and repair actions. Adding or moving a LifeBoard item updates canonical planning metadata; external events remain read-only.

### Week

Week distributes commitments and exposes imbalance. Compact layouts may use a selectable list; regular-width iPad presents seven stable day columns. Each day retains an accessible identity, summary, capacity story, and route into Day.

### Backlog

Backlog collects unplaced or deferred work. It supports search/filter, selection, scheduling, edit, archive/delete where available, and receipt-backed Undo. It must not become a second task repository.

### Focus

Focus starts from an exact task or an intentional unscoped session. A deep link for a stable session ID opens only a matching active session. Ended, missing, stale, or repository-failed states are explained rather than replaced with another session.

### Weekly Planner and Review

Weekly Planner helps allocate rather than merely list work. Weekly Review summarizes evidence, unfinished commitments, and reflection prompts without manufacturing conclusions. Carry-forward and repair actions remain explicit and reviewable.

## Planning interaction contract

- Overlap-safe capacity calculations distinguish fixed events, flexible work, and open gaps.
- Drag/direct manipulation preserves gesture velocity, provides a button/keyboard alternative, and commits only after crossing a documented intent threshold.
- Mutations produce a persisted receipt or explicit failure.
- Delete and bulk changes require confirmation and preserve stable identity through the supported tombstone/receipt contract.
- Undo replays the persisted inverse exactly and communicates when it is no longer available.
- EVA repair is a proposal path: explain, preview/diff, Apply/Edit/Not Now, receipt, Undo.
- Concurrent operations freeze only affected controls; unrelated navigation and reading remain available.

## Overdue Rescue in Plan

When launched for a selected planning day, Rescue uses that day as its decision anchor. “Keep” means keep/place on that selected day, not necessarily today. The launch context, session key, accessible action label, move-date resolver, and planning metadata update must agree. Closing or relaunching restores the correct scoped session.

## State matrix

| State | Required presentation | Recovery |
|---|---|---|
| Populated | Capacity and current decision precede detail | Plan, focus, or repair |
| Empty day | Show fixed commitments and open capacity honestly | Add/capture or pull from Backlog |
| Empty backlog | Confirm there is no unplaced work | Return to Day |
| Loading | Preserve Day/Week geometry and current lens | Keep navigation available |
| Stale calendar | Label external schedule freshness | Refresh calendar projection |
| Calendar denied | Keep task planning functional | Explain read-only integration and Settings path |
| Offline | Preserve local planning and queued work | Retry external sync later |
| Conflict | Show both commitments and the nature of overlap | Move, shorten, defer, or ask EVA |
| Mutation failure | Preserve the draft/selection | Retry or cancel |
| Destructive | Explain records/history affected | Confirm, then receipt/Undo where supported |

## UI/UX contract

- One compact header owns date, lens, and capacity; avoid repeated title cards.
- Day prioritizes “now/next” and conflict resolution over analytics.
- Week emphasizes comparison across days without shrinking labels below readable sizes.
- Backlog uses efficient rows and batch controls; destructive controls remain separated from primary scheduling.
- Focus removes nonessential chrome while preserving exit, timer status, task identity, and accessibility controls.
- Completion and scheduling feedback use named motion/haptics; no continuous celebration loop.

## Responsive and accessibility behavior

- Compact iPhone uses a single schedule/agenda lens with explicit mode controls.
- Accessibility sizes stack time, metadata, and actions and provide non-drag alternatives.
- Regular iPad uses the seven-day board and stable per-day accessibility targets.
- Catalyst supports keyboard navigation, commands for capture/focus where implemented, pointer feedback, and window resizing without clipping.
- Reduce Motion converts shared-element/direct-manipulation transitions to stable crossfades or immediate state updates.

## Implementation and evidence

Primary anchors include `LifeBoardPlanViews`, planning repositories/models, canonical mutation coordinator, `LifeBoardAppRouter`, Focus activity/deep-link coordinators, and the shared receipt/Undo presentation.

Primary flags are `planningCoreV1Enabled`, `planDestinationV1Enabled`, `focusExecutionV2Enabled`, and `evaPlanRepairV1Enabled`. Flag rollback hides staged surfaces without discarding planning metadata, focus history, or receipts.

Recorded evidence covers deterministic ranking/repair, overlap-safe capacity, route identity, Day capture, seven-day iPad Week, Backlog deletion/Undo/relaunch, and focused interaction policies. Interaction-freeze closure, all shared-element relationships, signed-device Live Activity behavior, and full degraded-state evidence remain active gates.
