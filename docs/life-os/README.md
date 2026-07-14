# Life OS Implementation Hub

This package is the canonical handoff for the LifeBoard-to-Life-OS program. It describes what is implemented, how to turn it on, which contracts later phases must preserve, and what remains before public promotion.

## Current state

| Phase | State | Product outcome |
|---|---|---|
| Phase I — Foundation | Implemented behind typed rollout controls | Stable shell, routes, capture arbitration, daypart/theme context, atmospheric policy, and versioned dashboard persistence |
| Phase II — Unified Adaptive Home | Implemented for internal/manual testing | Screenshot-calibrated Adaptive Home, one shared customizable layout, Smart/Work/Personal/Low Energy modes, Trackers/Health/care, OffRecord-derived Journal, and structured Notes |
| Phase III — Planning Core | Foundation vertical slice implemented | Additive planning schema, deterministic capacity/ranking/repair services, Day/Week/Backlog destination, internal blocks, task planning states, Focus routing, and Home projections |
| Phase IV — Track Foundations | Foundation vertical slice implemented | Additive goals/routines/resilience/care schema, Track Today, hydration/mood/medication/sleep loops, routine runner, starter-pack preview, Universal Capture, and Home projections |
| Public promotion | Not yet approved | Requires physical-device, populated-iCloud, accessibility, privacy, performance, and founder scenario gates |

Detailed references:

- [Phase I implementation handoff](../phase-1-life-os-foundation.md)
- [Phase II implementation handoff](./phase-2-adaptive-home.md)
- [Manual test playbook](./manual-testing.md)
- [Roadmap to the complete Life OS](./roadmap.md)
- [Phase III/IV implementation status](./phase-3-4-implementation.md)

## Developer activation

All Life OS and Phase II surfaces default to enabled in Debug builds. A normal Run from Xcode should open Adaptive Home without launch arguments.

Explicit enable arguments remain available for CI:

```text
-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION
-LIFEBOARD_ENABLE_ADAPTIVE_HOME_V2
-LIFEBOARD_ENABLE_DASHBOARD_CUSTOMIZATION_V2
-LIFEBOARD_ENABLE_TRACKERS_V1
-LIFEBOARD_ENABLE_HEALTH_INTEGRATIONS_V1
-LIFEBOARD_ENABLE_JOURNAL_V1
-LIFEBOARD_ENABLE_KNOWLEDGE_NOTES_V1
-LIFEBOARD_ENABLE_PLANNING_CORE_V1
-LIFEBOARD_ENABLE_PLAN_DESTINATION_V1
-LIFEBOARD_ENABLE_FOCUS_EXECUTION_V2
-LIFEBOARD_ENABLE_EVA_PLAN_REPAIR_V1
-LIFEBOARD_ENABLE_TRACK_FOUNDATIONS_V2
-LIFEBOARD_ENABLE_HABIT_RESILIENCE_V2
-LIFEBOARD_ENABLE_GOALS_ROUTINES_V1
-LIFEBOARD_ENABLE_CARE_MODULES_V2
-LIFEBOARD_ENABLE_STARTER_PACKS_V1
```

Replace `ENABLE` with `DISABLE` to isolate or roll back a surface during a Debug run. Release builds do not inherit Debug defaults.

## Invariants for future phases

- The shared Home layout is one ordered placement set. Mode is context, never a persistence key.
- Widget sizes are semantic: `compact`, `standard`, `wide`, and `tall`.
- Unknown widget kinds/configurations must survive migrations and downgrades without becoming visible.
- Managed objects never cross actor, route, or repository boundaries.
- Journal, mood, health, and biometrics are `privateSensitive`; ordinary personal planning data is `privateStandard`.
- Shared/collaborative records must be explicit whitelist projections, never direct exposure of private records.
- Audio, embeddings, semantic chunks, caches, drafts, graph positions, and diagnostic derivatives remain local-only.
- Daypart changes atmosphere; system appearance and accessibility control functional surfaces.
- Static rendering is a complete experience, not a degraded error state.
- Eva may explain and propose, but consequential mutations require an explicit review/apply boundary.

## Verification snapshot

The implementation currently passes:

- Generic iOS Simulator Debug build.
- Phase I/II focused contract suite, including the full additive model migration chain.
- Stable-ID migration from every bundled TaskModelV3 version to `TaskModelV3_KnowledgeNotes`.
- In-memory repository round trips for Trackers, Journal, and Knowledge Notes.
- Daypart, contrast, rendering-policy, router/restoration, capture arbitration, shared layout, unknown-widget, medication, Journal insight, and OffRecord asset tests.
- Foundation/dependency and token-law guardrails.
- Plain Debug launch into Adaptive Home with all Phase II surfaces enabled.
- Phase III/IV focused contract suite (13 tests), including planning-day identity, overlap-safe capacity, deterministic ranking/repair, habit resilience, routine idempotency, goals, hydration, sleep privacy, serialized schemas, and repository round trips.
- Runtime smoke launches of the new Plan and Track destinations on iPhone 17 Pro simulator.

The full legacy `LifeBoardTests` target currently reports pre-existing failures outside this implementation. Those failures are recorded as repository debt and must not be represented as Phase II regressions without comparison against a clean baseline. The focused Life OS suite is green; public promotion still requires the physical-device gates below.

## Release gates still requiring external conditions

- Upgrade a production-style populated database on a signed physical iPhone and iPad.
- Exercise iCloud enabled, disabled, signed out, account switched, offline edits, and remote merges.
- Verify Watch and widgets against the shared production App Group.
- Capture cold-launch, warm mode switch, capture latency, memory, energy, and scroll hitch metrics on matched hardware.
- Complete VoiceOver, Switch Control, keyboard, Dynamic Type, Reduce Motion, Reduce Transparency, high contrast, Low Power, and thermal-pressure passes.
- Review Health and Speech permission copy, App Privacy responses, exported privacy manifest, and external-surface redaction.
- Approve morning, afternoon, evening, and night reference screenshots across iPhone and iPad.
