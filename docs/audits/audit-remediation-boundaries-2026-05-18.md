# Audit Remediation Boundaries - 2026-05-18

> **Classification: Audit snapshot and architecture reference.** It preserves dated evidence and does not override current product behavior or completion status.

This note records the internal contracts introduced or hardened during the phase 1-4 remediation pass and the first phase 5 implementation slice.

## Home Navigation And Reload

- `HomeNavigationEventAdapter` owns parsing external notification/deep-link payloads into typed navigation intents.
- `HomeNavigationCoordinator` owns applying those intents through delegate-backed UI presentation. Payload parsing should not move back into `HomeViewController`.
- `HomeReloadEventAdapter` owns mapping lifecycle, domain, workspace, calendar, habit, gamification, and persistent-sync notifications into typed reload events.
- `HomeReloadCoordinator` owns debounce/search invalidation/reload side effects. Notification callbacks should stay as adapters plus coordinator calls.

## Home Timeline Projection

- `HomeViewModel` owns gathering state from repositories, preferences, hidden-event stores, and selected-day context.
- `HomeTimelineSnapshotProjectionInput` is the value boundary for timeline construction. It carries injected `now`, `Calendar`, preferences, hidden-event state, task/habit/calendar inputs, task/project/life-area lookup data, and replan state.
- `HomeTimelineSnapshotProjectionBuilder.build(input:cached:)` owns snapshot assembly, week summaries, visible task/calendar item projection, hidden calendar filtering, actionable gaps, active item selection, and layout mode decisions.
- Remaining phase 5 work should push query predicates and sorting closer to repository projections before constructing this input.

## Core Data Identity Validation

- CloudKit-backed entities must not use Core Data uniqueness constraints unless CloudKit compatibility has been explicitly revalidated.
- Business identities are enforced at repository write boundaries and repair/canonicalization flows.
- Historical duplicate checks compare trimmed, case/diacritic-folded names for `LifeArea`, project-scoped `ProjectSection`, and global `Tag` identities so old whitespace/mixed-case rows cannot bypass write validation.
- Malformed-row handling should fail loudly in fetch validation or follow an explicit deterministic repair path with diagnostics.

## Async Bridge And Cancellation Rules

- Continuation bridges should check cancellation before and after awaited work, and cancellation-owned state should live in named policy/accumulator objects instead of captured mutable locals.
- `ChatGenerationCancellationPolicy` owns chat disappear, stop, slash-command, evaluator-phase, and thread-switch cancellation decisions.
- `LockedResultAccumulator` is the shared mutable aggregation boundary for callback-heavy Home loading paths. New callback aggregation should use this or an equivalent checked synchronization primitive.
- TSan is now part of the readiness gate for chat cancellation, semantic indexing, Core Data write paths, Home reload, onboarding install, and real Home launch.

## LLM Prewarm Policy

- `LLMPrewarmEligibilityPolicy` owns chat-entry prewarm eligibility and skip reasons.
- Current gates cover unsupported models, already-ready models, cancellation, thermal pressure, low-power mode, active session pressure, stale recent usage, missing model size, and memory budget by device class.
- Future search/insight prewarm should either reuse this policy shape or introduce sibling policies with the same explicit `Decision`/`SkipReason` model and tests.

## Swift 6 Readiness Gates

- Stay in Swift 5 language mode with complete strict concurrency until selected and broad test builds have no Swift 6 diagnostics that would become errors.
- Reduce or justify remaining `@unchecked Sendable` sites by domain before switching language mode.
- Do not mark the Swift 6 migration ready until a clean build, focused simulator tests, focused TSan tests, no-print, token-law, and Core Data codegen guardrails are recorded.
