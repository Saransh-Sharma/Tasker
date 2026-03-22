# Habits Product Feature

Last validated against code on 2026-03-22

## Summary

Habits in Tasker are a recurring behavior system for consistency loops, recovery loops, and abstinence tracking.
They are distinct from tasks:
- `Task`: finite work to complete
- `Habit`: repeated behavior to build or avoid
- `LifeArea`: required owner of the habit
- `Project`: optional supporting context

The product promise for habits is consistency without perfection pressure.
The system should help users maintain continuity, recover after misses, and avoid shame-based feedback.

## User Problem and Product Intent

Habits serve users who need:
- a low-friction place to capture recurring behaviors
- a visible loop for consistency and recovery
- different support for building good habits vs quitting harmful ones
- a Home surface that keeps recurring behavior visible without replacing task planning

The habits feature is designed to:
- make recurring behaviors legible inside the daily execution loop
- preserve history instead of treating each day as isolated
- support quick restart after misses
- separate habit adherence from task productivity

## Canonical Product Contract

### Ownership

- Every habit must belong to a `LifeArea`.
- `Project` is optional and acts as secondary context only.
- Missing ownership is treated as repair-needed data, not a normal ideal state.

### Habit Kinds

- `positive`: a behavior the user wants to build
- `negative`: a behavior the user wants to reduce or quit

### Tracking Modes

- `dailyCheckIn`
  - supported for positive and negative habits
  - appears as a due row on Home when relevant
- `lapseOnly`
  - supported only for negative habits
  - user logs a lapse instead of checking in every day
  - abstinent days are finalized automatically by maintenance

### Management States

- Active
  - participates in agenda and signal projections when relevant
- Paused
  - preserves history
  - suppresses active due and downstream signal projections
- Archived
  - soft-archived only
  - preserves history and removes the habit from active management flows

## Main Surfaces

### Add Habit

The add flow supports:
- title
- habit kind
- tracking mode for negative habits
- cadence
- reminder window
- required life area
- optional project
- icon
- notes / why this matters

Behavior rules:
- positive habits always save as `dailyCheckIn` even if the UI had stale state
- invalid same-day reminder windows are rejected
- life area is required to save
- icon selection is searchable and curated

### Edit Habit

Habit detail/edit supports:
- title
- type and tracking mode
- cadence
- reminder window
- ownership
- icon
- notes
- pause/unpause
- archive

Behavior rules:
- editing must preserve history
- cadence changes rebuild unresolved future schedule state
- positive habits cannot remain `lapseOnly`

### Home

Home includes habits in a mixed top agenda without replacing existing task sections.

Row expectations:
- leading icon
- title
- optional `LifeArea / Project` context
- due / overdue / lapse status
- streak chip
- 14-day strip with multi-state marks

Action model:
- positive habit: `Done`, `Skip`
- negative `dailyCheckIn`: `Stayed Clean`, `Lapsed`
- negative `lapseOnly`: no normal due row by default; lapse logging is manual from management/detail surfaces

Ordering expectations:
- habits appear in the mixed agenda with tasks
- overdue items sort ahead of due-today items
- existing task sections stay intact below the mixed agenda

### Habit Library and Detail

The library is the management surface for:
- browse all habits
- filter active vs archived
- inspect streaks and recent history
- open detail/edit state

The detail surface is the canonical management view for:
- configuration edits
- pause/unpause
- archive
- history review
- lapse logging for `lapseOnly`

### Analytics and Insights

Habits contribute to a dedicated adherence snapshot, not task completion rate.

Key product expectations:
- habit adherence is visible separately from task productivity
- positive completions and negative abstinence successes count as success
- lapses are visible without punitive framing
- missed and skipped behavior is explicit
- streak and risk framing should encourage recovery, not all-or-nothing thinking

### Eva and LLM Surfaces

Habits are passed to AI surfaces as behavior signals, not fake tasks.

Current downstream behavior includes:
- Home/Eva insights can consume habit signals
- daily brief generation summarizes due habits, wins, lapses, and risk
- LLM context projection includes habit title, ownership, streak, risk, icon metadata, and outcome

## User Journeys

### Create Habit

| Step | User action | System behavior |
| --- | --- | --- |
| 1 | Open add flow and choose Habit | Show habit-specific composer |
| 2 | Enter title, kind, cadence, ownership, icon, optional notes | Validate life area and reminder window |
| 3 | Save | Create habit definition, schedule template, schedule rules, and initial rolling occurrences |
| 4 | Return to Home/Library | Show habit in active management surfaces |

### Edit Habit

| Step | User action | System behavior |
| --- | --- | --- |
| 1 | Open habit detail | Load latest habit and history state |
| 2 | Modify title/type/cadence/reminder/ownership/icon/notes | Normalize impossible state such as positive + `lapseOnly` |
| 3 | Save | Persist habit changes and rebuild unresolved future schedule state as needed |

### Pause / Unpause

| Step | User action | System behavior |
| --- | --- | --- |
| 1 | Pause habit | Mark habit paused and suppress future active projections |
| 2 | Unpause habit | Re-enable schedule/template activity and projection eligibility |

### Archive

| Step | User action | System behavior |
| --- | --- | --- |
| 1 | Archive habit | Soft-archive only |
| 2 | Browse library later | History remains available |

### Resolve Positive Habit

| Action | Runtime outcome | User meaning |
| --- | --- | --- |
| `Done` | `OccurrenceResolutionType.completed` | completed the habit |
| `Skip` | `OccurrenceResolutionType.skipped` | intentionally skipped without pretending success |

### Resolve Negative Daily Check-In Habit

| Action | Runtime outcome | User meaning |
| --- | --- | --- |
| `Stayed Clean` | `completed` | abstinence success |
| `Lapsed` | `lapsed` and occurrence state `failed` | relapse/lapse logged explicitly |

### Resolve Negative Lapse-Only Habit

| Action | Runtime outcome | User meaning |
| --- | --- | --- |
| `Log Lapse` | materialize same-day occurrence if missing, then resolve `lapsed` | lapse is recorded without requiring daily check-in |
| No action and no lapse | day is auto-finalized as success by maintenance | abstinence is preserved without manual friction |

## UX and State Rules

### Streaks and History

- `currentStreak` and `bestStreak` should always reflect occurrence history, not UI guesswork.
- The 14-day strip must show multiple states:
  - success
  - failure
  - skipped
  - none
  - future
- Streak loss should not be framed as punishment.
- Recovery after a lapse or miss should be visually legible.

### Badges and Status

- Due and overdue states must be explicit.
- Failure/lapse states should be visible but not hostile.
- Risk state may be surfaced as `stable`, `atRisk`, or `broken`.

### Empty, Loading, and Error States

- Empty library should explain what habits are for and how to add one.
- Home should not show broken blank space if there are no due habits.
- Validation errors must be specific:
  - missing life area
  - malformed reminder time
  - reminder end before reminder start

### Accessibility Quality Bar

- Primary actions must meet comfortable tap targets.
- Icon-only controls require explicit accessibility labels.
- Day-of-week selectors require clear labels and selection state.
- The 14-day strip requires textual accessibility summary.
- Reduced-motion and Dynamic Type should preserve meaning, not just layout.

## Boundaries

- Habits are not routed through task recurrence.
- Habits are not represented as fake tasks for analytics or AI.
- Habit adherence and task productivity remain separate concepts, merged only in presentation where appropriate.

## Cross-Links

- `docs/habits/data-model-and-runtime.md`
- `docs/habits/risk-register.md`
- `docs/habits/roadmap.md`

