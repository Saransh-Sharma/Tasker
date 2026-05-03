# Tasker iOS - V2-Only Architecture Guide

**iOS 16.0+ | Swift 5+ | TaskDefinition-first runtime**

Tasker is now V2-only for task domain/runtime flows.
Legacy task contracts (`Task`, `TaskRepositoryProtocol`, bridge adapters, legacy task usecases) are removed from production runtime.

## Runtime Composition

Flow:
`View/ViewController -> ViewModel -> UseCaseCoordinator -> UseCase -> RepositoryProtocol -> State Repository -> CoreData`

Canonical boot/runtime anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`

## Canonical Task Contracts

- Domain task model: `TaskDefinition` (`To Do List/Domain/Models/Task.swift`)
- Read model query contracts: `TaskReadQuery`, `TaskSliceResult` (`To Do List/Domain/Models/TaskReadQueries.swift`)
- Task read repository: `TaskReadModelRepositoryProtocol`
- Task write repository: `TaskDefinitionRepositoryProtocol`
- View-layer alias: `DomainTask = TaskDefinition` (`To Do List/Domain/Models/DomainTask.swift`)

## Dependency Rules

- Use cases depend only on domain protocols.
- State repositories own CoreData access and mapping.
- Presentation never imports CoreData.
- Runtime is fail-closed if required V2 dependencies are missing.

## Local LLM / EVA

The local assistant architecture is documented in `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

LLM-driven task changes still follow the V2 runtime boundaries: UI routes user intent, the planner emits schema-validated commands, `AssistantActionPipelineUseCase` validates and applies mutations, and repositories persist state. Chat or proposal UI must not write task state directly.

Timeline-aware Eva guidance follows the same rule. Calendar and timeline projections may inform chat answers and proposal rationale, but external calendar events remain read-only and Tasker-owned task changes still flow through the assistant action pipeline.

## Cutover Policy

- Store epoch key: `tasker.v3.store.epoch`
- CoreData model container name: `TaskModelV2`
- CloudKit container: `iCloud.TaskerCloudKitV3`
- Upgrade policy: destructive reset accepted for this hard cut.

## Guardrails

Run before merge/release:

```bash
xcodebuild -workspace Tasker.xcworkspace -scheme "To Do List" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16" build
./scripts/validate_legacy_runtime_guardrails.sh
```

Guardrail script enforces absence of banned legacy symbols in production code.
