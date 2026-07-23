# Life OS Implementation Hub

> **Classification: Canonical implementation and architecture hub.**

This package is the canonical handoff for the LifeBoard-to-Life-OS program. It describes what is implemented, how to turn it on, which contracts later phases must preserve, and what remains before public promotion. Current completion status is owned by the [remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md); the [implementation and design audit](../audits/LIFEBOARD_5_IMPLEMENTATION_AND_DESIGN_AUDIT_2026-07-23.md) records the evidence boundary.

Product and UI behavior is now canonical in the [LifeBoard 5.0 Product Handbook](../product/README.md) and [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md). This package remains the implementation, activation, invariant, and release-gate handoff.

## Current state

| Phase | State | Product outcome |
|---|---|---|
| Phase I — Foundation | Implemented behind typed rollout controls | Stable shell, routes, capture arbitration, daypart/theme context, atmospheric policy, and versioned dashboard persistence |
| Phase II — Unified Adaptive Home | Implemented for internal/manual testing | Screenshot-calibrated Adaptive Home, one shared customizable layout, Smart/Work/Personal/Low Energy modes, Trackers/Health/care, shared-package Journal, and structured Notes |
| Phase III — Planning Core | Feature-complete vertical slice; promotion gates remain | Planning schema, EventKit/free windows, Day/Week/Backlog, receipts/undo, Focus V2 + Live Activity, deterministic ranking/repair, and Home projections |
| Phase IV — Track Foundations | Integrated vertical slice; Journal/Notes and promotion gaps remain | Goals/routines/resilience/care schema, canonical habit/goal samples, linked mutations, care loops, reversible starter packs, Track Today, Universal Capture, and Home projections |
| Public promotion | Not yet approved | Requires physical-device, populated-iCloud, accessibility, privacy, performance, and founder scenario gates |

Detailed references:

- [Phase I implementation handoff](../phase-1-life-os-foundation.md)
- [Phase II implementation handoff](./phase-2-adaptive-home.md)
- [Manual test playbook](./manual-testing.md)
- [Roadmap to the complete Life OS](./roadmap.md)
- [Phase III/IV implementation status](./phase-3-4-implementation.md)
- [LifeBoard visual contract](../../DESIGN.md)
- [LifeBoard product handbook](../product/README.md)

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
- Daypart, contrast, rendering-policy, router/restoration, capture arbitration, shared layout, unknown-widget, medication, Journal insight, and shared Journal asset tests.
- Foundation/dependency and token-law guardrails.
- Plain Debug launch into Adaptive Home with all Phase II surfaces enabled.
- Phase III/IV and foundation focused contract suite (44 tests), including planning-day identity, overlap-safe capacity, deterministic ranking/repair, Focus command idempotency, Activity payload limits, habit resilience, routine idempotency, goals, hydration, sleep privacy, appearance independence, serialized schemas, and repository round trips.
- Runtime smoke launches of the new Plan and Track destinations on iPhone 17 Pro simulator.

The full legacy `LifeBoardTests` target includes inherited failures outside the focused Foundation work. Compare it through `scripts/run-baseline-aware-tests.sh`; do not represent historical totals as a clean current run. The focused Life OS suite has recorded evidence, while public promotion still requires the physical-device gates below.

## Release gates still requiring external conditions

- Upgrade a production-style populated database on a signed physical iPhone and iPad.
- Exercise iCloud enabled, disabled, signed out, account switched, offline edits, and remote merges.
- Verify Watch and widgets against the shared production App Group.
- Capture cold-launch, warm mode switch, capture latency, memory, energy, and scroll hitch metrics on matched hardware.
- Complete VoiceOver, Switch Control, keyboard, Dynamic Type, Reduce Motion, Reduce Transparency, high contrast, Low Power, and thermal-pressure passes.
- Review Health and Speech permission copy, App Privacy responses, exported privacy manifest, and external-surface redaction.
- Approve morning, afternoon, evening, and night reference screenshots across iPhone and iPad.
