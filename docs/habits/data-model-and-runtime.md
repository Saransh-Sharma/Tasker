# Habit Data Model And Runtime

This document describes the habit lifecycle, streak semantics, and runtime projection rules that LifeBoard uses for Habit Streaks.

## Core Concepts

- Habit: a recurring behavior with its own identity, history, and action semantics.
- Scheduled day: a day where the habit expects a resolution.
- Success: a day the habit resolved positively.
- Skip: a deliberate bridge day that preserves continuity without counting as success.
- Miss or lapse: a day that breaks continuity.
- Pending: a day that has not resolved yet.
- Future: a scheduled day that has not arrived yet and should not affect streaks.

## Habit Types

- Positive habits
  - Track actions the user wants to build.
  - Resolve with `Done` or `Skip`.
- Negative habits
  - Track behaviors the user wants to reduce or stop.
  - `dailyCheckIn` habits resolve with `Stayed Clean` or `Lapsed`.
  - `lapseOnly` habits stay quiet on clean days and only record explicit lapses.

## Streak Contract

- `currentStreak` counts consecutive scheduled success days up to the most recent relevant day.
- `bestStreak` records the longest historical success run.
- `Skip` and `notScheduled` days preserve continuity but do not increment the streak.
- `Missed` and `Lapsed` days break the streak.
- `Pending` days are neutral until they resolve.
- `Future` days are ignored until they become actionable.
- Recovery is measured by how quickly the habit returns to a success state after a break.

## Runtime Projection

- Home should surface active habits in a mixed due-today area without collapsing them into tasks.
- Habit analytics should stay separate from task analytics and only merge at the presentation layer when needed.
- Paused habits remain historically intact but disappear from active projections.
- Archived habits remain discoverable in management flows but should not appear in default active surfaces.

## Board Semantics

- The Habit Board is the canonical visual streak surface.
- Each row should expose the habit identity, state, streak, history, and recovery cues.
- Each cell should communicate the day state clearly enough to support correction and review.
- Bridge days must remain visible so the user can distinguish rest, skips, and true misses.

## Correction And Recovery

- Recent history corrections must recompute streaks, board visuals, and analytics consistently.
- Editing cadence or reminder windows must not silently destroy past outcomes.
- Paused periods should not generate false misses.
- Lapse-only habits should preserve abstinent history automatically when the app reconstructs streak state.

## Consumers

- Home habit rows
- Habit Board
- Habit Library
- Habit Detail
- Insights and analytics
- EVA / assistant projections

## Invariants

- Habit state must be recoverable from history.
- Visual state and computed state must not diverge.
- Habit outcomes should be truth-preserving, not optimized for vanity metrics.
