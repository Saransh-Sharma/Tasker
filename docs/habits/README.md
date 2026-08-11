# Habit System

> Classification: Canonical feature package
> Audience: Users, support, product, design, engineering, and QA
> Capability status: Current workspace
> Source authority: Habit definitions/schedules/occurrences, Board/library/detail surfaces
> Last verified: 2026-08-11

LifeBoard treats habits as first-class recurring behaviors, separate from finite tasks but visible in the same execution system.

The habit experience is built around visual streaks, calm recovery after misses, and low-friction logging that keeps the system honest without turning completion into punishment.

## What This Package Covers

- [Product feature overview](./product-feature.md)
- [Data model and runtime contract](./data-model-and-runtime.md)
- Current risks, limitations, and evidence gates are consolidated below.

## Current limitations and evidence gates

- Schedule/timezone/DST changes must not duplicate or erase occurrences.
- Binary, quantity, and count targets require different completion/correction semantics; an explicit zero remains data.
- Recovery applies to the intended occurrence and reward effects are idempotent. Pause/archive preserve history; deletion explains loss.
- Notification denial must not block in-app logging. Widget/Watch actions validate stable identity and reconcile stale projections.
- Full notification delivery, paired-Watch retry, timezone travel, haptics, and assistive-technology behavior still require appropriate device evidence when not freshly observed.
- Social challenges, shared habits, and prescriptive health programs are not current scope.

## Core Principles

- Show progress visually, not emotionally.
- Favor restart behavior over reset behavior.
- Keep the next action one tap away.
- Preserve truth about missed days, skipped days, and pause periods.
- Keep habit analytics separate from task analytics.

## Habit Surfaces

- Home habit rows
- Habit Board
- Habit Library
- Habit Detail
- Habit-aware assistant and analytics projections

## Documentation Rule

If a habit behavior is described here, the PRD should reference it rather than rewording it independently.
