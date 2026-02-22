# Tasker Architecture Docs Index (V3 Runtime)

**Last validated against code on 2026-02-21**

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
- `To Do List/TaskModelV3.xcdatamodeld/TaskModelV3.xcdatamodel/contents`
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
| `docs/architecture/uxdesign-design-system-v2.md` | Canonical UX design system contracts: tokens, themes, adapters, motion, accessibility, migration, and component recipes | design token/theme/adapter/motion/accessibility contracts change |
| `docs/architecture/llm-assistant-stack-v2.md` | LLM context pipeline and assistant transaction boundaries | `/LLM` or `/UseCases/LLM` changes |
| `docs/architecture/llm-feature-integration-handbook.md` | Mixed engineering/PM guide for AI surfaces, safety model, rollout, and incident triage | AI behavior, UX surfaces, kill-switch strategy, or release evidence model changes |
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

## Required Update Matrix

| Code area changed | Required doc updates |
| --- | --- |
| `To Do List/Domain/Models/*` or model schema | `data-model-v2.md`, `risk-register-v2.md` |
| `To Do List/UseCases/*` | `usecases-v2.md`, `risk-register-v2.md` |
| `To Do List/State/Repositories/*`, `To Do List/State/Services/*` | `state-repositories-and-services-v2.md`, `clean-architecture-v2.md` |
| `To Do List/Domain/Events/*` | `domain-events-and-observability-v2.md`, `usecases-v2.md` |
| `To Do List/DesignSystem/*` | `uxdesign-design-system-v2.md`, `risk-register-v2.md` |
| `To Do List/LLM/*`, `To Do List/UseCases/LLM/*` | `llm-assistant-stack-v2.md`, `llm-feature-integration-handbook.md`, `usecases-v2.md`, `risk-register-v2.md` |
| `AppDelegate` + DI containers + runtime guardrails | `clean-architecture-v2.md`, `risk-register-v2.md`, `v3-runtime-cutover-todo.md` |
| release evidence, guardrails, and AI validation workflows | `docs/operations/ci-release-and-guardrails.md`, `docs/release-gate-v2-efgh.md`, `docs/architecture/v3-runtime-cutover-todo.md` |

## Quick Read Order

1. `docs/architecture/clean-architecture-v2.md`
2. `docs/architecture/data-model-v2.md`
3. `docs/architecture/usecases-v2.md`
4. `docs/architecture/state-repositories-and-services-v2.md`
5. `docs/architecture/uxdesign-design-system-v2.md`
6. `docs/architecture/risk-register-v2.md`
7. `docs/architecture/llm-assistant-stack-v2.md`
8. `docs/architecture/llm-feature-integration-handbook.md`
