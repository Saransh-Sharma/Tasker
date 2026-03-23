# Habits Risk Register

Last validated against code on 2026-03-22

## Summary

This register tracks habit-specific risks that affect correctness, UX trust, performance, and delivery safety.
It is intentionally more detailed than the generic app-wide architecture risk register.

Primary source anchors:
- `To Do List/UseCases/Habit/HabitRuntimeUseCases.swift`
- `To Do List/State/Repositories/CoreDataHabitRuntimeReadRepository.swift`
- `To Do List/State/Services/CoreSchedulingEngine.swift`
- `To Do List/Presentation/ViewModels/AddHabitViewModel.swift`
- `To Do List/View/AddHabitForedropView.swift`
- `To Do List/View/HomeHabitRowView.swift`
- `To Do List/UseCases/Analytics/CalculateAnalyticsUseCase.swift`
- `To Do List/Presentation/ViewModels/HomeViewModel.swift`
- `To Do List/LLM/Models/LLMContextProjectionService.swift`
- `To Do List/LLM/Models/DailyBriefService.swift`

## Active Risks

| ID | Risk | Severity | Impact | Trigger | Mitigation | Detection | Release gate |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `H-001` | Paused habits leak into downstream signal consumers | High | Home/analytics/Eva/LLM show habits the user explicitly paused | signal query forgets pause filtering | filter paused habits at repository boundary | paused-habit signal regression tests, analytics mismatch reports | blocked |
| `H-002` | `lapseOnly` inactivity repair regresses and leaves old days pending | High | broken streaks, false misses, corrupted history | maintenance window is truncated or skipped | finalize unresolved pre-today lapse-only abstinent days during maintenance | long-inactivity tests at 8/30/90 day gaps | blocked |
| `H-003` | Invalid `kind + trackingMode` pair persists | High | impossible UX states such as positive habit showing lapse semantics | validation only exists in UI | normalize at use-case boundary | create/update normalization tests | blocked |
| `H-004` | Daily analytics cache serves stale habit metrics after mutation | High | analytics panels disagree with Home state | same-day cache ignores current habit signals | fingerprint cache by habit signals and invalidate on habit mutation | same-day mutation analytics tests | blocked |
| `H-005` | Reminder windows invert due time | High | due-at before scheduled-at, broken agenda ordering | invalid start/end accepted or legacy invalid data read | validate and clamp reminder windows | reminder-window validation tests and due-time assertions | blocked |
| `H-006` | Partial write rollback leaves habit, schedule, and occurrence data inconsistent | High | orphaned templates/rules or mismatched activity state | downstream save/maintenance fails after partial success | best-effort rollback today; keep mutation paths narrow and well tested | targeted failure-path tests and bug reports | review required |
| `H-007` | Read-query scaling degrades as habit count grows | Medium | slow Home, library, analytics, or AI refresh | fetch-all or wide history windows reappear | keep predicate-driven read paths and source-ID-scoped occurrence fetches | profiling and repo-level query review | review required |
| `H-008` | View-model loader concurrency regresses | Medium | duplicated, missing, or unstable editor/library data | shared scratch state mutated from multiple callbacks | marshal aggregation onto main actor or use locking | UI flake reports and view-model tests | review required |
| `H-009` | Life-area invariant drift persists | Medium | habit appears without valid ownership, causing repair/fallback behavior | legacy data or weak validation | reject new writes without life area and exclude broken ownership from active projections | ownership audit scripts and targeted read tests | review required |
| `H-010` | Accessibility regressions in habit controls | Medium | users cannot reliably operate day selectors, action pills, or history strip | tap areas, labels, or summary text regress | maintain explicit accessibility labels, 44pt targets, and strip summary | VoiceOver/tap-target audits | review required |
| `H-011` | Documentation drifts back to legacy CRUD framing | Medium | engineers implement against old mental model | habit docs not updated with runtime changes | same-PR updates to `docs/habits/*` | review catches stale `ManageHabitsUseCase` framing | review required |

## Accepted Partials

| ID | Partial | Why accepted now | Constraint |
| --- | --- | --- | --- |
| `HP-001` | `lifeAreaID` is still optional at parts of the model/storage surface | large cross-cutting migration to make it truly non-optional | product and read paths treat missing ownership as repair-needed, not normal |
| `HP-002` | mutation atomicity is rollback-based rather than a single cross-repository transaction | protocol and repository boundaries are not transaction-composed today | docs and tests must state this clearly |

## Watchlist

| ID | Watch item | Concern |
| --- | --- | --- |
| `HW-001` | Home agenda density as habits grow | risk of clutter or action overload in the mixed agenda |
| `HW-002` | Habit analytics and task analytics presentation blending | users may misread adherence and productivity if the UI merges them poorly |
| `HW-003` | AI interpretations of lapse/risk signals | assistant language can become judgmental if prompts drift |
| `HW-004` | Schedule/history repair cost for very large datasets | maintenance windows and streak recomputation may become more expensive |

## Detection and Containment

| Risk ID | Detection signal | Containment action |
| --- | --- | --- |
| `H-001` | paused habit appears in analytics, daily brief, or LLM payload | inspect repository predicates and block release |
| `H-002` | old lapse-only days remain pending after maintenance | inspect `finalizeLapseOnlySuccesses` behavior and rerun streak repair |
| `H-003` | positive habit shows `Log Lapse` or lapse-only semantics | inspect create/update normalization path and patch use-case validation |
| `H-004` | Home shows fresh habit state but analytics panel lags | invalidate analytics cache and inspect signal fingerprint path |
| `H-005` | due row appears before its own scheduled window | inspect reminder validation and `CoreSchedulingEngine.dueDate` clamping |
| `H-006` | orphaned template/rule or mismatched pause/archive behavior | apply repair path, investigate rollback failure, and block promotion |
| `H-007` | long reloads for Home/library/brief generation | profile repository fetches and narrow predicates or windows |
| `H-008` | edit screen loads inconsistent projects/life areas or flaky state | serialize callbacks and add regression coverage |
| `H-009` | active habit has missing ownership | treat as repair-needed and keep it out of active projections |
| `H-010` | VoiceOver or tap-target audit fails | fix control labeling and hit area before ship |
| `H-011` | docs mention habits only via `ManageHabitsUseCase` | update habit package and linked architecture docs before merge |

## Release Checklist For Habit-Touching PRs

- [ ] Product contract in `docs/habits/product-feature.md` matches shipped behavior.
- [ ] Runtime and data model doc reflects current use cases, repository contracts, and invariants.
- [ ] Habit-specific risk register updated for new correctness, UX, or scale risk.
- [ ] Root docs and architecture index link to the habit package.
- [ ] No stale primary references to `ManageHabitsUseCase` remain in canonical docs.
- [ ] Regression tests exist for any changed invariant.

## Cross-Links

- `docs/habits/product-feature.md`
- `docs/habits/data-model-and-runtime.md`
- `docs/habits/roadmap.md`
- `docs/architecture/risk-register-v2.md`

