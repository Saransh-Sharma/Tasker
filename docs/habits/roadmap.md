# Habits Product Roadmap

Last updated: 2026-03-22

## Summary

This roadmap covers only the habits feature.
It is phased by product outcome, not calendar date.
Each phase defines what the user should gain, what ships, what stays out of scope, and what quality bar must be met before promotion.

## Phase 0: Current Baseline

### User Outcome

Users can create, manage, and act on habits inside the daily execution loop without turning habits into fake tasks.

### Current Scope

- positive and negative habits
- `dailyCheckIn` and negative `lapseOnly`
- Add, Edit, Library, Detail, Home mixed agenda
- pause/unpause and archive
- streaks, risk state, and 14-day history strip
- separate habit analytics snapshot
- habit-specific gamification events
- habit signals feeding Eva/Home insights, daily brief, and LLM context

### Non-goals

- no dedicated habit-only tab
- no overnight reminder-window semantics
- no assistant mutation path for habits
- no punitive lapse scoring

### Success Metrics

- habit create-to-first-check-in rate
- percentage of active days with at least one habit action
- lapse-only logging success without support friction
- habit mutation to Home refresh latency
- same-day analytics freshness after habit mutation

### Quality Gate

- paused habits excluded from downstream signals
- positive normalization and reminder-window validation covered by tests
- long-inactivity `lapseOnly` repair covered by tests

## Phase 1: Correctness and Management Hardening

### User Outcome

Users trust habit state because editing, pausing, archiving, and recovering after inactivity behave consistently.

### Scope

- finish correctness hardening for pause/archive/update flows
- reduce remaining partial-write risk where practical
- improve ownership repair visibility for broken legacy habits
- strengthen management affordances and clarity in library/detail surfaces
- close remaining accessibility and management-state edge cases

### Dependencies

- stronger repository-level mutation guarantees or repair tooling
- additional management UI polish
- risk-register-driven test expansion

### Non-goals

- no major new habit surface or gamification redesign
- no new AI automation behavior

### Success Metrics

- lower rate of support/debug incidents for inconsistent habit state
- zero known stale analytics or paused-signal regressions
- higher successful edit completion rate
- accessibility audit pass for primary habit interactions

### Release Gate

- targeted mutation failure-path tests
- library/detail accessibility verification
- no unresolved P1 correctness risks in `docs/habits/risk-register.md`

## Phase 2: Habit Insights, Retention, and Recovery UX

### User Outcome

Users better understand habit patterns, risk, and recovery opportunities without feeling judged.

### Scope

- richer habit-specific analytics views
- better recovery framing after misses or lapses
- stronger trend surfacing for streak resilience and risk
- habit filters and management ergonomics for larger habit libraries
- improved empty/loading/error states with more coaching value

### Dependencies

- stable habit analytics baseline from Phase 1
- design bandwidth for habit-specific insight surfaces
- clear copy review for shame-free behavior framing

### Non-goals

- no coercive engagement mechanics
- no habit leaderboard or social pressure loops

### Success Metrics

- improved weekly habit engagement retention
- higher recovery-after-lapse rate
- increased use of habit detail/history surfaces
- increased adherence understanding from qualitative feedback

### Release Gate

- product copy review for shame-free framing
- no analytics confusion between task productivity and habit adherence
- instrumentation for habit insight usage and recovery behavior

## Phase 3: Assistive Automation, Coaching, and Ecosystem Depth

### User Outcome

Users get more personalized support around recurring behavior planning, risk reduction, and recovery while keeping explicit control.

### Scope

- assistant read-only coaching on habit state and risk
- explainable suggestions for reminder tuning or schedule adjustment
- optional deeper Eva-style summarization of habit health
- stronger ecosystem integration between habits, daily brief, and planning workflows

### Dependencies

- high-trust signal quality from earlier phases
- clear guardrails for assistant behavior
- stable habit data contracts for AI surfaces

### Non-goals

- no silent habit mutations
- no opaque or manipulative coaching loops
- no medical or therapeutic positioning

### Success Metrics

- increased adoption of habit-related AI summaries
- stable or improved assistant trust metrics
- no increase in undo/destructive friction from habit guidance

### Release Gate

- explicit user-control review
- prompt and output review for judgment-free language
- strong fallback behavior when habit signals are unavailable or partial

## Roadmap Assumptions

- Habits remain a first-class feature distinct from tasks.
- `LifeArea` remains the primary owner and `Project` remains optional context.
- Habit adherence remains analytically separate from task productivity.
- Trust, clarity, and recovery framing are more important than adding volume-oriented engagement features.

## Cross-Links

- `docs/habits/product-feature.md`
- `docs/habits/data-model-and-runtime.md`
- `docs/habits/risk-register.md`
