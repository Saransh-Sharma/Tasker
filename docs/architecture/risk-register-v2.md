# Tasker V3 Risk Register and Guardrails

**Last validated against code on 2026-02-20**

This register tracks technical risks that can regress V3 runtime correctness, data integrity, and release safety.

Primary source anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/TaskModelV3.xcdatamodeld/TaskModelV3.xcdatamodel/contents`
- `To Do List/State/Repositories/*.swift`
- `To Do List/UseCases/Sync/ReconcileExternalRemindersUseCase.swift`
- `To Do List/UseCases/Sync/ReminderMergeEngine.swift`
- `To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift`
- `To Do List/Services/V2FeatureFlags.swift`

## Active Risk Register

| ID | Risk | Severity | Impact | Trigger | Mitigation |
| --- | --- | --- | --- | --- | --- |
| `R-001` | Compatibility-column drift (`title/name`, priority aliases, project aliases) | High | inconsistent reads/scores and migration regressions | one write path updates only compatibility columns | canonical-write rules in repositories + alias-aware regression checks |
| `R-002` | Runtime DI incompleteness despite successful bootstrap | High | crashes/503 behavior in presentation/usecase paths | missing repository/service wiring at startup | enforce `assertV3RuntimeReady()` in both DI containers and fail closed |
| `R-003` | Identity divergence (`id` vs `taskID/projectID`) in historical rows | High | duplicate logical entities, broken links | repairs/canonicalization bypassed or regressed | keep identity repair/canonicalization helpers and startup repair path intact |
| `R-004` | External reminders reconcile partial failures | High | stale mappings, duplicate reminders, sync drift | provider failures/timeouts during multi-item reconcile | preserve per-item failure accounting, merge-clock persistence, targeted retries |
| `R-005` | Tombstone/merge-clock regressions | High | deleted entities resurrect or conflict resolution becomes unstable | merge envelope encoding/clock logic changes | keep merge-engine envelope compatibility + purge lifecycle checks |
| `R-006` | Assistant apply/undo contract drift | High | irreversible or partially rolled-back assistant actions | schema/allowlist/undo-plan regressions | enforce schema bounds, allowlist checks, deterministic undo validation |
| `R-007` | Feature-flag guard omission in side-effect flows | Medium | disabled features still mutate state/provider | new flow added without explicit gate | require explicit `V2FeatureFlags` checks for reminders and assistant paths |
| `R-008` | Background refresh reliability degradation | Medium | stale occurrence/reminder state | repeated BG task timeout/failure signals | preserve scheduling retries, timeout logging, and dependency checks |
| `R-009` | Documentation/runtime drift | Medium | incorrect engineering decisions and release mistakes | docs not updated with code changes | enforce same-PR doc updates and release-gate evidence in tracker doc |

## Detection Signals and Containment

| Risk ID | Detection signals | Containment action |
| --- | --- | --- |
| `R-001` | inconsistent task/project display values across screens/tests | re-run canonicalization and alias-sync checks; block release until reconciled |
| `R-002` | `v3_runtime_not_ready` errors or missing dependency reasons | fail closed and fix DI wiring before build promotion |
| `R-003` | duplicate inbox candidates / identity repair warnings | run repair flows and verify post-repair counts |
| `R-004` | reconcile summaries show persistent failures/timeouts | retry targeted projects, inspect mapping state and provider permissions |
| `R-005` | merge decisions flip unexpectedly across runs | validate clock/tombstone serialization round-trip and reconcile replay |
| `R-006` | assistant apply/undo failures (`409/410/422`) | disable apply/undo flags if needed; fix envelope/schema/undo plan logic |
| `R-007` | feature-disabled scenarios still execute side effects | add/restore explicit guard checks and disabled-path tests |
| `R-008` | repeated BG timeout/failure events | tune timeout strategy and dependency readiness, then re-run BG smoke |
| `R-009` | stale architecture statements detected in review | update docs before merge; refresh `v3-runtime-cutover-todo.md` |

## Guardrails (Do Not Bypass)

1. Do not bypass `assertV3RuntimeReady()` checks in startup wiring.
2. Do not introduce presentation-layer CoreData mutations.
3. Do not add sync mutations outside merge-envelope/tombstone-aware flows.
4. Do not add assistant commands without allowlist + undo strategy.
5. Do not remove canonical ID validation/canonicalization helpers.
6. Do not change compatibility columns without documenting migration rationale.
7. Do not weaken guardrail scripts without replacing equivalent coverage.

## High-Risk Invariants to Preserve

| Invariant | Why it matters | Source anchors |
| --- | --- | --- |
| Inbox project identity remains canonical | prevents orphan tasks and project-link drift | `AppDelegate.swift`, `CoreDataProjectRepository.swift` |
| `Occurrence.occurrenceKey` remains immutable | deterministic recurrence identity | `CoreDataOccurrenceRepository.swift` |
| External mapping uniqueness and merge clocks are preserved | stable two-way sync conflict resolution | `CoreDataExternalSyncRepository.swift`, `ReminderMergeEngine.swift` |
| Assistant apply requires confirmed runs and valid undo payloads | transactional safety and user trust | `AssistantActionPipelineUseCase.swift` |
| Tombstone lifecycle (write -> expire -> purge) is intact | prevents deletion regressions and sync churn | `DeleteTaskDefinitionUseCase.swift`, `MaintainOccurrencesUseCase.swift` |

## Review Checklist (Required in PRs Touching Architecture)

- [ ] Data model/schema changes reflected in `docs/architecture/data-model-v2.md`.
- [ ] Usecase contract changes reflected in `docs/architecture/usecases-v2.md`.
- [ ] Runtime/DI/bootstrapping changes reflected in `docs/architecture/clean-architecture-v2.md`.
- [ ] State repository/service changes reflected in `docs/architecture/state-repositories-and-services-v2.md`.
- [ ] LLM/assistant changes reflected in `docs/architecture/llm-assistant-stack-v2.md`.
- [ ] `docs/architecture/v3-runtime-cutover-todo.md` gate evidence updated when release-gating behavior changed.

## Escalation Guidance

Escalate for architecture review before merge when a change:
- touches identity columns or canonicalization paths,
- changes reconcile merge semantics or tombstone handling,
- changes assistant command schema/allowlist/undo contracts,
- modifies runtime bootstrap readiness or fail-closed behavior.

## Cross-Links

- `docs/architecture/clean-architecture-v2.md`
- `docs/architecture/data-model-v2.md`
- `docs/architecture/state-repositories-and-services-v2.md`
- `docs/architecture/usecases-v2.md`
- `docs/architecture/v3-runtime-cutover-todo.md`
