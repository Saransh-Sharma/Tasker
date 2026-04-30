# Habit Streaks Product Feature

Tasker Habit Streaks turn repeat behaviors into a calm visual system that helps users stay consistent without forcing perfection.

## Product Philosophy

- Habits are recurring behaviors, not finite tasks.
- Consistency matters more than flawless attendance.
- A missed day should be visible, but it should not become a shame loop.
- The interface should help the user restart quickly instead of punishing them for a break.

## User-Facing Model

- Positive habits are built with daily check-ins.
- Negative habits can be tracked with either daily check-ins or lapse-only tracking.
- Every habit belongs to a Life Area. A Project can provide additional context, but it is optional.
- Habit rows and the Habit Board surface the current streak, best streak, recent history, and risk state in a compact format.

## Visual Streaks

- Streaks are represented as a chain of visually consistent successes.
- Depth and color progression make growth easy to scan at a glance.
- Skip and not-scheduled days preserve continuity without pretending to be successes.
- Missed and lapsed days remain visible, but they do not trigger punitive styling.
- Negative habits visualize clean days as progress toward abstinence or reduction.

## Logging Behavior

- Positive habits support `Done` and `Skip`.
- Negative daily check-in habits support `Stayed Clean` and `Lapsed`.
- Negative lapse-only habits support `Log Lapse` when a lapse occurs and remain quiet when clean.
- Today's cell is resolved explicitly rather than inferred from background behavior.

## Recovery Behavior

- Habit recovery language should emphasize restart, recovery, and getting back on track.
- Gentle reminders can follow a missed day, but the product should avoid loud or guilt-heavy escalation.
- Repeated misses should surface simplification opportunities, such as shrinking scope, changing cadence, or pausing a habit.

## Habit Board Experience

- The board is the main visual surface for habit consistency.
- It should show one row per active habit and one day cell per calendar day within the supported window.
- The board must make success, bridge days, misses, and pending days visually distinct.
- Users should be able to sort and group habits by the dimensions that matter for recovery and attention.

## Editing And Management

- Habit detail should be read-first and edit-second.
- Editing must preserve history.
- Cadence, reminder windows, icon, ownership, and notes remain editable without destroying streak context.
- Paused and archived states should stay intelligible and recoverable.

## Why It Works

- The streak chain creates a fast feedback loop.
- The board turns abstract consistency into something the user can understand immediately.
- Flexible skip and recovery behavior keeps the system grounded in real life.
