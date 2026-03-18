# Tasker Architecture Docs Index (V3 Runtime)

**Last validated against code on 2026-03-18**

This folder is the implementation-facing source of truth for Tasker's shipped V3 runtime.
The runtime is V3-only (`TaskModelV3`, V3 bootstrap cutover, `TaskDefinition`-centric contracts).

## Naming Convention Note

Several filenames still use a `-v2` suffix for link stability across older PRs and external references.
That suffix no longer means the runtime is V2.
Treat these docs as the current V3 architecture references unless explicitly marked archived.

## Primary Source Anchors

- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`
- `To Do List/TaskModelV3.xcdatamodeld/.xccurrentversion`
- `To Do List/TaskModelV3.xcdatamodeld/TaskModelV3_Gamification.xcdatamodel/contents`
- `To Do List/Domain/Interfaces/*`
- `To Do List/Domain/Models/*`
- `To Do List/UseCases/*`
- `To Do List/State/Repositories/*`
- `To Do List/State/Services/*`
- `To Do List/LLM/*`

## Document Map

| Document | Purpose | Update when... |
| --- | --- | --- |
| `docs/architecture/data-model-v2.md` | Entity map, identity rules, compatibility columns, ownership of writes | schema/domain fields/identity rules change |
| `docs/architecture/clean-architecture-v2.md` | Layer boundaries, DI composition, fail-closed runtime | AppDelegate/DI/runtime bootstrapping changes |
| `docs/architecture/usecases-v2.md` | Usecase inventory, contracts, side effects, orchestration flows | Usecase APIs/dependencies/flow semantics change |
| `docs/architecture/state-repositories-and-services-v2.md` | State layer repository/service internals and data ownership | repository/service implementations change |
| `docs/architecture/domain-events-and-observability-v2.md` | Domain event bus, handler rules, observability expectations | event schemas/handlers/logging behavior change |
| `docs/architecture/notifications-local-strategy-v3.md` | Local notification catalog, defaults, routing, action handling, schedule reconciliation | notification behavior, UX copy, action categories, or reconciliation logic changes |
| `docs/architecture/gamification-v2-engine.md` | Gamification engine contracts, ledger mutation signal path, reconciliation loop prevention, and widgets | `UseCases/Gamification/*`, `CoreDataGamificationRepository`, `InsightsViewModel` refresh strategy, `HomeViewModel` mutation handling, or `AppDelegate` remote-change reconciliation changes |
| `docs/architecture/insights-analytics-surface.md` | Insights screen contract, widget inventory, projection inputs, and tab refresh semantics | Insights widget inventory, view-model state payloads, tab intent split, accessibility IDs, or motion/empty-state contracts change |
| `docs/architecture/llm-assistant-stack-v2.md` | LLM runtime contract: MLX chat pipeline, request modes, quality, persistence, and assistant boundaries | `/LLM` or `/UseCases/LLM` runtime changes |
| `docs/architecture/llm-feature-integration-handbook.md` | Mixed engineering/product view of AI surfaces, routing, flags, and release expectations | AI behavior, user-facing semantics, or release policy changes |
| `docs/architecture/risk-register-v2.md` | Active technical risk register and mitigations | risk posture/guardrails/release criteria change |
| `docs/architecture/v3-runtime-cutover-todo.md` | Active migration and release gate tracker | gate status or verification evidence changes |
| `docs/architecture/v2-hardcut-execution-todo.md` | Archived historical tracker | almost never (historical context only) |

## Source-Of-Truth Boundaries

- Product outcomes and roadmap: `PRODUCT_REQUIREMENTS_DOCUMENT.md`
- Runtime implementation contracts: this folder
- CI/release operations: `docs/operations/*`
- Archived/non-canonical material: `docs/archive/*`

## Maintenance Policy

1. Update architecture docs in the same PR as code changes.
2. Keep statements code-verifiable with file anchors.
3. Prefer canonical runtime terms: `TaskDefinition`, `TaskDefinitionSliceResult`, `TaskModelV3`, `assertV3RuntimeReady`.
4. Keep archived docs explicitly marked and non-gating.
5. Keep `docs/architecture/v3-runtime-cutover-todo.md` aligned with actual gate execution status.
6. Update both canonical LLM docs in the same PR whenever `/LLM` runtime behavior changes.

## Required Update Matrix

| Code area changed | Required doc updates |
| --- | --- |
| `To Do List/Domain/Models/*` or model schema | `data-model-v2.md`, `risk-register-v2.md` |
| `To Do List/UseCases/*` | `usecases-v2.md`, `risk-register-v2.md` |
| `To Do List/UseCases/Gamification/*`, `To Do List/State/Repositories/CoreDataGamificationRepository.swift`, `To Do List/Presentation/ViewModels/InsightsViewModel.swift`, `To Do List/AppDelegate.swift` (gamification remote-change path) | `gamification-v2-engine.md`, `insights-analytics-surface.md`, `usecases-v2.md`, `state-repositories-and-services-v2.md`, `domain-events-and-observability-v2.md`, `risk-register-v2.md` |
| `To Do List/State/Repositories/*`, `To Do List/State/Services/*` | `state-repositories-and-services-v2.md`, `clean-architecture-v2.md` |
| `To Do List/Domain/Events/*` | `domain-events-and-observability-v2.md`, `usecases-v2.md` |
| `To Do List/LLM/*`, `To Do List/UseCases/LLM/*` | `llm-assistant-stack-v2.md`, `llm-feature-integration-handbook.md`, `usecases-v2.md`, `risk-register-v2.md` |
| `AppDelegate` + DI containers + runtime guardrails | `clean-architecture-v2.md`, `risk-register-v2.md`, `v3-runtime-cutover-todo.md` |

## Quick Read Order

1. `docs/architecture/clean-architecture-v2.md`
2. `docs/architecture/data-model-v2.md`
3. `docs/architecture/usecases-v2.md`
4. `docs/architecture/gamification-v2-engine.md` (for XP/reconciliation/widgets/live-update paths)
5. `docs/architecture/insights-analytics-surface.md` (for Insights widgets, state, and refresh behavior)
6. `docs/architecture/state-repositories-and-services-v2.md`
7. `docs/architecture/risk-register-v2.md`
8. `docs/architecture/llm-assistant-stack-v2.md`
9. `docs/architecture/llm-feature-integration-handbook.md`
