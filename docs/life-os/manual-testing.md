# Life OS Manual Test Playbook

> **Classification: Canonical manual-test reference.** Use with the [product handbook](../product/README.md), [UI/UX guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md), and active [Unified Completion Status](./LIFEBOARD_UNIFIED_COMPLETION_STATUS.md).

> Audience: Product, design, engineering, accessibility, privacy, and QA
> Capability status: Current workspace scenario inventory; results require a dated run
> Source authority: Current feature catalog and runtime routes
> Last verified: 2026-08-11

Use this playbook while product/design and engineering test the implementation together.

## Start state

1. Run the `LifeBoard` scheme in Debug. No launch arguments are required.
2. Confirm the first visible destination is the new warm-paper Adaptive Home.
3. Confirm the dock reads Home, Plan, Track, Insights, and Eva.
4. Confirm Home remains canonical without a legacy-host comparison path; the
   obsolete `-LIFEBOARD_DISABLE_ADAPTIVE_HOME_V2` argument no longer exists.

## End-to-end scenario: build a life structure

- Complete every onboarding stage and interrupt/relaunch after each stage to verify resumability.
- Select all seven starter areas, then repeat with a minimal selection. Verify Work & Career, Life Admin, Health & Self, Relationships, Learning & Growth, Creativity & Fun, and Money are editable canonical areas.
- Exercise friction profile, guide/persona, day shape, modules, first task, contextual permissions, and starter-pack review.
- In Life Management, create a nested project, sections, and tags; move it between areas; archive and restore/Undo where supported; inspect delete consequences.
- Follow `area → project/goal → task/habit/routine → day/week → evidence/review` and verify every link opens the same stable record.

## Adaptive Home smoke test

- Identify the current mode, daypart, date, and primary next action in two seconds.
- Switch Smart → Work → Personal → Low Energy and confirm order/size do not change.
- In Low Energy, verify reduced density, “One small thing,” essential care, recovery capacity, and nonjudgmental progress language.
- Open daypart control, choose each manual daypart, verify “Return to Auto,” and test expiry across the next natural boundary.
- Toggle Calm/Balanced/Playful, Reduce Motion, Reduce Transparency, high contrast, and accessibility text sizes.
- With Health/Calendar unavailable, verify setup language rather than zero values or fake precision.

## Customization

- Enter from the grid control, explicit Customize action, and a widget long press.
- Reorder, step through supported semantic sizes, configure, hide, add another multi-instance widget, and remove it.
- Cancel and verify no changes persist.
- Repeat, tap Done, force quit, and verify restoration.
- Reset and verify the curated narrative order.
- Switch modes and verify customization remains shared.

## Capture and Track

- Open capture from the inline widget and persistent orb.
- Create a task, habit, tracker entry, Journal thought, and Note through their
  canonical capture flows.
- Create boolean, count, quantity, rating, and duration trackers.
- Create medication and schedule states; verify Scheduled/Taken/Skipped/Snoozed/Rescheduled/Unresolved language.
- Let a window pass and verify it becomes Unresolved, never automatically Missed.
- Start/end a neutral fasting timer and verify no health coaching claims.
- Request Health access from the Health surface; test allowed, denied, and no-data states.
- Use Universal Capture for Mood + Energy, Hydration, Medication Event, and Routine Run.

## Plan

- Open Day and confirm usable capacity, known planned work, missing-estimate confidence, internal blocks, and overload language remain understandable within two seconds.
- Move between dates, add/resize/split/remove a LifeBoard block, and confirm no external calendar mutation occurs.
- Plan and unplan a task, toggle Must Do/Waiting/Paused, start Focus, force quit, and verify planning state restores.
- Open Week, inspect seven load cards, select a day, then use Backlog to inspect Inbox/This Week/Next Week/Later/Someday/Waiting/Paused groups.
- Test sparse, realistic, and overloaded data at accessibility text sizes; verify the agenda remains readable without compressed timeline geometry.

## This Week and overdue recovery

- Enter the This Week workspace from both week and overdue routes; verify the compatibility weekly-planner route does not open an obsolete wizard.
- Populate Overdue, Inbox, and Anytime lanes. Place work into Today, the next two concrete days, and Later This Week.
- Compare capacity bars with fixed meetings; add an intention; search/filter/select; bulk distribute; dismiss/reopen and confirm immediate persistence.
- Undo the distribution from its receipt. Force a partial batch failure and verify applied/unapplied identities remain visible and retry does not duplicate success.
- Recover an overloaded week by completing, clarifying, moving, unscheduling, and deleting reviewed work.

## Focus execution and recovery

- Start scoped and unscoped sessions with multiple durations; pause, resume, record interruptions, finish with each supported outcome, and add a reflection.
- Force quit during every phase and verify startup repair selects the same canonical session.
- Exercise notification, Live Activity, deep-link, and history continuation; verify missing permission or stale activity does not create a second session.
- Confirm rewards/history are idempotent and Undo/correction behavior matches the visible receipt.

## Track Foundations

- Log hydration through +250/+500 and Universal Capture; confirm target-missing state is honest and units remain canonical.
- Record multiple Mood + Energy signals and a private sleep-context record.
- Resolve Scheduled/Unresolved medication as Taken, Skipped, or Snoozed; confirm Unresolved/Scheduled remain excluded from adherence.
- Preview every starter pack, deselect items, confirm, and verify only selected supported records are created.
- Start a routine, exercise choice branching, interrupt/relaunch, continue, and abandon; verify history is not rewritten after routine edits.
- Add a goal and confirm unlinked or incomplete sources do not fabricate progress.

## Habits, goals, routines, and care depth

- Create binary, quantity, and count habits with schedule, target, reminders, pause, archive, and delete paths.
- Log through Today, Quiet Tracking, Board, detail calendar, widget, and Watch projection; correct a prior occurrence and exercise resilience recovery.
- Create typed goal samples and link tasks, habits, routines, and trackers; check milestones, trajectory, revision, completion, and archive.
- Run ordered and branching routine definitions containing task, habit, check-in, timer, instruction, and choice steps; verify linked mutations happen once and partial completion/history remain interpretable after definition edits.
- Log/correct generic trackers, hydration, mood/energy, and medication/care with source identity and explicit zero.

## Health, nutrition, fasting, and Life Moments

- For activity, energy, hydration, nutrition, body, workouts, sleep, and fasting, exercise not-requested, granted, denied/restricted, no-data, stale, partial, protected-data, and background/foreground refresh states.
- Confirm activity/energy/sleep/fasting are read-only; verify supported hydration/nutrition/body/workout write-back, source precedence, deduplication, outbox retry, and manual fallback.
- Search the food library, convert servings, create recipe/template, log a meal, edit its source food, and verify the logged macro snapshot remains immutable.
- Exercise explicit remote barcode lookup, offline local search, unknown/duplicate resolution, reports/recent meals/goals, deletion, and Undo.
- Start/finish early/cancel/keep-running a fast; test reminders, history correction, duplicate-active repair, and Apple Health boundaries.
- Create each Life Moment/countdown type across timezone and recurrence boundaries; search/archive, opt into Home/widget, and verify privacy-safe projection/export semantics.

## Journal

- Capture mood, then optional energy; repeat twice on one day.
- Add text, photo, protected audio, and optional transcription.
- Play and stop local audio, relaunch, and confirm availability on the same device.
- Use voice search and verify the temporary search recording is deleted after transcription.
- Search text, filter by mood/date/star, star/unstar, and delete a day with confirmation.
- Check Today, Library, and Insights; verify every insight links to evidence counts and avoids diagnostic claims.
- Deny microphone, photo, and speech permissions individually and verify recoverable states.

## Notes

- Create a space, nested folders, and notes.
- Exercise paragraph, headings, lists, checklist, quote/callout, code, divider, table, collapsible, image, file, rich bookmark, and note-link blocks.
- Add tags, pin/favorite, connect two notes, inspect backlinks, then disconnect.
- Search and filter, attach a supported file, and verify oversized/failed files surface an error.
- Open graph, pan/zoom/search/filter/open, and verify it limits the default viewport to relevant nodes.

## Insights, gamification, and EVA

- Open every insight lens/report, switch timeframe, inspect evidence, and verify insufficient data, textual chart equivalents, non-causal language, and non-clinical health wording.
- Trigger XP, levels, badges/achievements, habit streak relationships, Focus rewards, widgets, and celebrations twice through retry/reprojection; verify idempotency and reduced-motion/quiet policies.
- Activate EVA with each supported model path and persona; test download/unavailable/offline states, chats/threads, chips, slash commands, attachments, day overview, semantic retrieval, memory controls, streaming, Stop, Continue, and Retry.
- Ask EVA to propose task, habit, and plan changes. Inspect diffs; use Apply, Edit, and Not Now; force partial application; verify receipts and Undo.
- Revoke each remote context category and confirm subsequent requests fail closed without affecting widgets, Watch, notifications, Spotlight, or lock-screen content.

## System continuity

- Exercise every App Intent/shortcut, widget family and interactive action, Capture Control, Focus/Fasting/Routine Live Activity, notification action, Spotlight result, typed deep link, and share-extension payload.
- Capture task/note/journal/audio on Watch while the phone is unavailable; verify outbox identity, retry, acknowledgment, and no duplicate import.
- Verify task/habit controls never act on a substituted record when their stable identity is missing or stale.

## Data and recovery

- Force quit on every destination and verify route restoration.
- Open simultaneous capture/deep-link requests and verify one deterministic presentation.
- Test offline edits, reconnect, account sign-out/in, and remote edits on two devices.
- Verify private text/audio/health/medication values do not appear in notifications, widgets, Spotlight excerpts, or app switcher snapshots.
- Disable each feature flag after creating data; re-enable and verify the data is intact.

## Cross-feature state and accessibility pass

- Exercise populated, empty, loading, explicit zero, stale, denied, offline, locked, error, and destructive states where the feature supports them.
- At accessibility XXXL, verify all five roots, Universal Capture, primary Save/Cancel/Retry actions, protected Journal unlock, Plan repair, and Track capture remain reachable.
- With VoiceOver, verify the semantic order is title/state, primary action, evidence/context, then secondary controls.
- With Reduce Motion and Reduce Transparency, verify the experience remains complete and glass chrome receives an opaque fallback.
- On regular/wide iPad, verify split navigation, 8/12-column Home, seven-day Week, and modal/editor actions.
- On Catalyst, verify keyboard traversal, commands, pointer feedback, menus, and narrow/wide window resizing.
- Verify cross-root typed routes select the destination before appending the leaf and active-root reselection returns to root.
- Verify mutation failure preserves input, proposal Apply produces a receipt, Undo consumes the canonical inverse, and expired Undo is explicit.
- Verify widgets, Spotlight, notifications, Watch, and diagnostics contain no protected Journal content or sensitive health detail.

## Review record

For each test run, record device/OS, build SHA, database provenance, iCloud state, permissions, accessibility settings, rendering tier, failures, screenshots, launch/capture timings, and whether the two-second founder proxy passed.
