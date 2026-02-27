# Tasker V3 Risk Register and Guardrails

**Last validated against code on 2026-02-27**

This register tracks technical risks that can regress V3 runtime correctness, data integrity, and release safety.

Primary source anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/TaskModelV3.xcdatamodeld/.xccurrentversion`
- `To Do List/TaskModelV3.xcdatamodeld/TaskModelV3_Gamification.xcdatamodel/contents`
- `To Do List/State/Repositories/*.swift`
- `To Do List/UseCases/Sync/ReconcileExternalRemindersUseCase.swift`
- `To Do List/UseCases/Sync/ReminderMergeEngine.swift`
- `To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift`
- `To Do List/UseCases/Gamification/GamificationEngine.swift`
- `To Do List/LLM/Views/Chat/ChatView.swift`
- `To Do List/LLM/Models/AssistantCardPayload.swift`
- `To Do List/LLM/Models/TaskSemanticRetrievalService.swift`
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
| `R-008` | Background refresh reliability degradation | Medium | stale occurrence/reminder/brief state | repeated BG task timeout/failure signals | preserve scheduling retries, timeout logging, and dependency checks |
| `R-009` | Documentation/runtime drift | Medium | incorrect engineering decisions and release mistakes | docs not updated with code changes | enforce same-PR doc updates and release-gate evidence in tracker doc |
| `R-010` | LLM context staleness or under-specified context payload | High | poor/incorrect assistant proposals | one-time injection, dropped task metadata, missing timezone/tag context | rebuild context per request, include enriched metadata, log `assistant_context_built` |
| `R-011` | Semantic retrieval quality or availability regression | Medium | irrelevant search/chat context ranking | embedding runtime unavailable or stale index | lexical fallback + explicit `assistant_semantic_fallback_lexical` event + index rebuild hooks |
| `R-012` | Chat plan/apply repeated failures within a session | Medium | user distrust and repeated mutation failures | consecutive apply failures from stale/invalid proposals | session circuit breaker after 3 apply failures and explicit user message |
| `R-013` | Card transport payload corruption or incompatible decoding | Medium | proposal/undo cards fail to render or actions target wrong run | malformed sentinel payload or status mismatch | enforce sentinel prefix contract, decode guards, and run/thread ownership checks |
| `R-014` | Notification deep-link seeding drift (brief/triage) | Medium | wrong chat mode/prompt seeded or no chat open on tap | pending keys diverge between producers/consumer | centralize key names and verify open-chat signal path |
| `R-015` | Semantic index performance drift under mutation volume | Medium | UI lag or stale semantic ranking | rebuild-heavy path used too often instead of incremental updates | prefer incremental upsert/remove and bounded rebuild fallback |
| `R-016` | AI cold-start and surface latency regression | Medium | users perceive assistant as stalled on first interaction | model not warmed, heavy route chosen, or long generation budgets | staged status UX + current-model prewarm + fast-first fallback + latency telemetry |
| `R-017` | Gamification remote-change reconciliation loop regression | High | sustained write churn, WAL checkpoint flood, delayed UI mutation handling | local writes re-trigger full reconcile path | keep persistent-history author/context qualification + serial coalescing coordinator |
| `R-018` | Gamification stale read-after-write snapshot | High | XP charts lag until restart; inconsistent same-session values | read context not reset/merged after writes | enforce `readContext.reset()` post-write and keep read/write context split contract explicit |
| `R-019` | Missed ledger mutation signal in UI observers | High | XP updates not reflected live on Home/Insights | observer not attached or event dropped during heavy churn | use ledger-mutation watchdog fallback refresh + notification-path tests |
| `R-020` | Gamification doc/runtime drift | Medium | incidents prolonged due to incorrect runbook assumptions | runtime changed without architecture docs update | require same-PR updates for `gamification-v2-engine.md` and linked architecture docs |

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
| `R-010` | proposal quality drops after mid-thread task mutations | inspect context logs and ensure per-request context rebuild remains enabled |
| `R-011` | semantic hits absent for ambiguous queries | verify embedding availability, index freshness, and lexical fallback path |
| `R-012` | 3+ assistant apply failures in one session | stop plan/apply for session, triage root cause before re-enable |
| `R-013` | card decode failures, missing `run_id` warnings, card action mismatch | validate sentinel payload generation and decode guards; block action on invalid payload |
| `R-014` | daily brief open path does not seed chat thread/prompt | verify pending key writes and `.assistantOpenChatRequested` notification path |
| `R-015` | frequent full index rebuild logs, degraded search latency | tune mutation observer handling and keep incremental upsert/remove active |
| `R-016` | first-token and surface latency drift beyond SLO | inspect warmup events, routing mode, and generation profile budgets; tune fast-first paths |
| `R-017` | elevated remote-change volume and repeated reconcile starts | inspect persistent-history classifier results and ensure only qualified CloudKit imports trigger reconcile |
| `R-018` | immediate post-write fetch does not reflect updated XP/profile/aggregate | verify gamification repository finalize-write reset behavior and canonical row selection |
| `R-019` | completion/focus/reflection XP visible only after restart | inspect `gamificationLedgerDidMutate` emission/observer path and watchdog fallback logs |
| `R-020` | stale architecture references during review/incident triage | block merge until gamification architecture docs are updated and cross-linked |

## AI Telemetry Signals to Watch

| Event | Why it matters |
| --- | --- |
| `assistant_context_built` | verifies enriched context generation and payload metadata |
| `assistant_plan_mode_activated` | confirms discoverability/usage of plan mode |
| `assistant_proposal_generated` | baseline proposal generation health |
| `assistant_apply_failed` | key mutation safety/error signal |
| `assistant_undo_invoked` / `assistant_undo_expired` | validates bounded reversibility UX |
| `assistant_overdue_triage_shown` / `assistant_overdue_triage_applied` | monitors proactive triage path health |
| `assistant_daily_brief_generated` / `assistant_daily_brief_opened` | validates brief generation + deep-link behavior |
| `assistant_semantic_fallback_lexical` | confirms graceful behavior when embeddings unavailable |
| `assistant_model_warmup_started` / `assistant_model_warmup_completed` / `assistant_model_warmup_failed` | verifies prewarm lifecycle and startup readiness |
| `assistant_first_token_latency` | tracks cold vs warm chat responsiveness |
| `assistant_surface_latency` / `assistant_surface_timeout` | tracks non-chat AI surface latency and timeout rates |
| `assistant_fast_fallback_used` | confirms fast-first heuristic rendering occurred before refine |

## Guardrails (Do Not Bypass)

1. Do not bypass `assertV3RuntimeReady()` checks in startup wiring.
2. Do not introduce presentation-layer CoreData mutations.
3. Do not add sync mutations outside merge-envelope/tombstone-aware flows.
4. Do not add assistant commands without allowlist + undo strategy.
5. Do not remove canonical ID validation/canonicalization helpers.
6. Do not change compatibility columns without documenting migration rationale.
7. Do not weaken guardrail scripts without replacing equivalent coverage.
8. Do not add chat-layer task mutation paths outside `AssistantActionPipelineUseCase`.

## High-Risk Invariants to Preserve

| Invariant | Why it matters | Source anchors |
| --- | --- | --- |
| Inbox project identity remains canonical | prevents orphan tasks and project-link drift | `AppDelegate.swift`, `CoreDataProjectRepository.swift` |
| `Occurrence.occurrenceKey` remains immutable | deterministic recurrence identity | `CoreDataOccurrenceRepository.swift` |
| External mapping uniqueness and merge clocks are preserved | stable two-way sync conflict resolution | `CoreDataExternalSyncRepository.swift`, `ReminderMergeEngine.swift` |
| Assistant apply requires confirmed runs and valid undo payloads | transactional safety and user trust | `AssistantActionPipelineUseCase.swift` |
| Tombstone lifecycle (write -> expire -> purge) is intact | prevents deletion regressions and sync churn | `DeleteTaskDefinitionUseCase.swift`, `MaintainOccurrencesUseCase.swift` |
| Card actions require run/thread ownership checks | prevents cross-thread accidental mutation operations | `ChatView.swift`, `ConversationView.swift` |
| Gamification mutation signal emitted post-commit only | prevents stale pre-write UI reads | `GamificationEngine.swift`, `HomeViewModel.swift`, `InsightsViewModel.swift` |
| Remote-change reconcile only for qualified external transactions | prevents local-write reconciliation loops | `AppDelegate.swift` (`GamificationRemoteChangeCoordinator`) |

## Review Checklist (Required in PRs Touching Architecture)

- [ ] Data model/schema changes reflected in `docs/architecture/data-model-v2.md`.
- [ ] Usecase contract changes reflected in `docs/architecture/usecases-v2.md`.
- [ ] Runtime/DI/bootstrapping changes reflected in `docs/architecture/clean-architecture-v2.md`.
- [ ] State repository/service changes reflected in `docs/architecture/state-repositories-and-services-v2.md`.
- [ ] LLM/assistant changes reflected in `docs/architecture/llm-assistant-stack-v2.md`.
- [ ] Mixed audience AI behavior docs updated in `docs/architecture/llm-feature-integration-handbook.md`.
- [ ] `docs/architecture/v3-runtime-cutover-todo.md` gate evidence updated when release-gating behavior changed.

## Escalation Guidance

Escalate for architecture review before merge when a change:
- touches identity columns or canonicalization paths,
- changes reconcile merge semantics or tombstone handling,
- changes assistant command schema/allowlist/undo contracts,
- modifies runtime bootstrap readiness or fail-closed behavior,
- changes AI telemetry names/required fields,
- changes semantic index lifecycle (incremental vs rebuild behavior).

## Cross-Links

- `docs/architecture/clean-architecture-v2.md`
- `docs/architecture/data-model-v2.md`
- `docs/architecture/state-repositories-and-services-v2.md`
- `docs/architecture/usecases-v2.md`
- `docs/architecture/llm-assistant-stack-v2.md`
- `docs/architecture/llm-feature-integration-handbook.md`
- `docs/architecture/v3-runtime-cutover-todo.md`
