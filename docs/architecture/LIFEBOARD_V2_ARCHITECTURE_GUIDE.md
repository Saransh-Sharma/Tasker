# LifeBoard iOS - V2-Only Architecture Guide

> **Classification: Canonical architecture reference.** Product and interaction behavior lives in the [LifeBoard 5.0 product handbook](../product/README.md); current completion is owned by the [remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md).

**iOS 16.0+ | Swift 5+ | TaskDefinition-first runtime**

LifeBoard is now V2-only for task domain/runtime flows.
Legacy task contracts (`Task`, `TaskRepositoryProtocol`, bridge adapters, legacy task usecases) are removed from production runtime.

## Runtime Composition

Flow:
`View/ViewController -> ViewModel -> UseCaseCoordinator -> UseCase -> RepositoryProtocol -> State Repository -> CoreData`

Canonical boot/runtime anchors:
- `LifeBoard/AppDelegate.swift`
- `LifeBoard/State/DI/EnhancedDependencyContainer.swift`
- `LifeBoard/Presentation/DI/PresentationDependencyContainer.swift`
- `LifeBoard/UseCases/Coordinator/UseCaseCoordinator.swift`

## Canonical Task Contracts

- Domain task model: `TaskDefinition` (`LifeBoard/Domain/Models/Task.swift`)
- Read model query contracts: `TaskReadQuery`, `TaskSliceResult` (`LifeBoard/Domain/Models/TaskReadQueries.swift`)
- Task read repository: `TaskReadModelRepositoryProtocol`
- Task write repository: `TaskDefinitionRepositoryProtocol`
- View-layer alias: `DomainTask = TaskDefinition` (`LifeBoard/Domain/Models/DomainTask.swift`)

## Dependency Rules

- Use cases depend only on domain protocols.
- State repositories own CoreData access and mapping.
- Presentation never imports CoreData.
- Runtime is fail-closed if required V2 dependencies are missing.

## Local LLM / EVA

The local assistant architecture is documented in `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

LLM-driven task changes still follow the V2 runtime boundaries: UI routes user intent, the planner emits schema-validated commands, `AssistantActionPipelineUseCase` validates and applies mutations, and repositories persist state. Chat or proposal UI must not write task state directly.

Timeline-aware Eva guidance follows the same rule. Calendar and timeline projections may inform chat answers and proposal rationale, but external calendar events remain read-only and LifeBoard-owned task changes still flow through the assistant action pipeline.

## Cutover Policy

- Store epoch key: `lifeboard.v3.store.epoch`
- CoreData model container name: `TaskModelV2`
- CloudKit container: `iCloud.TaskerCloudKitV3`
- Upgrade policy: destructive reset accepted for this hard cut.

## Guardrails

Run before merge/release:

```bash
xcodebuild -workspace LifeBoard.xcworkspace -scheme "LifeBoard" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" build
./scripts/validate_legacy_runtime_guardrails.sh
```

Guardrail script enforces absence of banned legacy symbols in production code.

## Release and visual-system authority

The active LifeBoard 5.0 completion tracker is `docs/todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md`; the implementation/design audit records the source and automated evidence supporting its status. `DESIGN.md` is the agent-readable visual contract, while `LifeBoardColorTokens`, companion token groups, and named components remain the runtime source of truth. `lifeOSUnifiedPresentationV2` keeps the legacy Sunrise palette as a one-release rollback path.

Before release, run the build and baseline-aware test script serially with token-law and premium UI guardrails. Signed-device performance, paired Watch, App Group, migration, iCloud/account, and accessibility-device checks cannot be closed by the simulator alone.

Product intent and screen behavior live in `docs/product/README.md`; global interaction and responsive rules live in `docs/design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md`. Architecture documents own runtime composition, dependency direction, persistence, and trust boundaries. Avoid duplicating product requirements here.
