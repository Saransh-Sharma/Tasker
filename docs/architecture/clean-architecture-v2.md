# Tasker V3 Clean Architecture Runtime

**Last validated against code on 2026-02-20**

## Scope

This document describes the shipped runtime composition and dependency boundaries for Tasker.
It focuses on:
- App bootstrap and persistent store cutover behavior
- DI container wiring and fail-closed readiness checks
- Layer boundaries and forbidden dependencies
- Command-side vs read-model responsibilities
- Runtime feature flags and failure surfaces

Primary source anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`
- `To Do List/Services/V2FeatureFlags.swift`
- `To Do List/State/Repositories/CoreDataTaskDefinitionRepository.swift`
- `To Do List/State/Repositories/CoreDataTaskReadModelRepository.swift`

## Runtime Snapshot

| Concern | Current state |
| --- | --- |
| Persistent model | `TaskModelV3` |
| Store files | `TaskModelV3-cloud.sqlite`, `TaskModelV3-local.sqlite` (+ wal/shm) |
| Cloud container | `iCloud.TaskerCloudKitV3` |
| Cutover epoch key | `tasker.v3.store.epoch` |
| Runtime readiness assertions | `assertV3RuntimeReady()` in both DI containers |
| Runtime mode | V3-only (legacy task bridge contracts removed from production paths) |

## Layer Responsibilities

| Layer | Owns | Must not own |
| --- | --- | --- |
| Presentation | ViewModels/UI orchestration and intent forwarding | direct CoreData mutation and persistence rules |
| UseCases | business workflows and transactional orchestration | UIKit/UI state handling |
| Domain | models, contracts, business semantics | infrastructure implementation details |
| State | repository/service implementations and wiring | presentation concerns |
| Infrastructure | CoreData/CloudKit/EventKit/background task integrations | UI behavior decisions |

## Composition Sequence

```mermaid
sequenceDiagram
    participant AD as AppDelegate
    participant EDC as EnhancedDependencyContainer
    participant PDC as PresentationDependencyContainer
    participant UCC as UseCaseCoordinator

    AD->>AD: performV3BootstrapCutoverIfNeeded()
    AD->>AD: bootstrapV3PersistentContainer()
    AD->>EDC: configure(with: persistentContainer)
    AD->>EDC: assertV3RuntimeReady()
    EDC->>UCC: build coordinator and usecases
    AD->>PDC: configure(taskReadModelRepository, projectRepository, useCaseCoordinator)
    AD->>PDC: assertV3RuntimeReady()
    AD->>AD: ensureV3Defaults() + repairProjectIdentityIfNeeded()
    AD->>AD: configure LLMContextRepositoryProvider
```

## DI Wiring Details

### State container (`EnhancedDependencyContainer`)
- Constructs all repository implementations and state services.
- Builds `UseCaseCoordinator` with required `V2Dependencies` bundle.
- Marks runtime ready only after required dependencies are present.
- Exposes `assertV3RuntimeReady()` for fail-closed bootstrap.

### Presentation container (`PresentationDependencyContainer`)
- Requires:
  - `taskReadModelRepository`
  - `projectRepository`
  - `useCaseCoordinator`
- Computes explicit failure reason string when dependencies are missing.
- Exposes `assertV3RuntimeReady()` for fail-closed bootstrap.

## Command Side vs Read Model Side

| Side | Primary contracts | Purpose |
| --- | --- | --- |
| Command side | `TaskDefinitionRepositoryProtocol` + companion repositories (`TaskTagLinkRepositoryProtocol`, `TaskDependencyRepositoryProtocol`) | canonical mutation path for `TaskDefinition` graph |
| Read model side | `TaskReadModelRepositoryProtocol` returning `TaskDefinitionSliceResult` | optimized query/search/pagination/aggregate reads |

## Store Bootstrap and Cutover Behavior

| Behavior | Implementation summary | Source |
| --- | --- | --- |
| Epoch-based cutover | if stored epoch != `v3StoreEpoch`, wipe store files and clear legacy preference keys | `To Do List/AppDelegate.swift` |
| Store wipe set | removes both legacy `TaskModelV2-*` and current `TaskModelV3-*` sqlite/wal/shm files during cutover | `To Do List/AppDelegate.swift` |
| Two-config load | loads `CloudSync` and `LocalOnly` store descriptions | `To Do List/AppDelegate.swift` |
| Retry strategy | incompatible/missing-config load failures trigger wipe + recovery bootstrap pass | `To Do List/AppDelegate.swift` |
| Fail-closed mode | unresolved bootstrap/dependency errors produce bootstrap failure state and skip runtime wiring | `To Do List/AppDelegate.swift` |

## Background Runtime Loops

| Loop | Trigger | Core dependencies |
| --- | --- | --- |
| Occurrence maintenance refresh | app background + scheduled refresh task | `MaintainOccurrencesUseCase`, occurrence + tombstone repositories |
| Reminders refresh/reconcile | gated background refresh task | `ReconcileExternalRemindersUseCase`, external sync repo, reminders provider |

## Feature Flag Gates (Current)

| Flag | Used in | Behavior when disabled |
| --- | --- | --- |
| `remindersSyncEnabled` | reminders link/reconcile flows and reminder-notification scheduling side effects | sync paths return disabled error/skip work; notification scheduling side effects are suppressed |
| `assistantApplyEnabled` | assistant apply flow | blocks apply with explicit error |
| `assistantUndoEnabled` | assistant undo flow | blocks undo with explicit error |
| `remindersBackgroundRefreshEnabled` | background reminders scheduling/execution | no reminders BG refresh scheduling |

## Failure Surface Matrix

| Failure point | Detection | Runtime behavior | Signal |
| --- | --- | --- | --- |
| persistent store load incompatibility | load report has compatibility errors or missing configs | wipe + retry bootstrap path | `persistent_store_bootstrap_retry` |
| persistent store unrecoverable | recovery load still unhealthy | app enters bootstrap failure mode | `persistent_store_bootstrap_failed_after_retry` |
| state DI missing required dependencies | `assertV3RuntimeReady()` throws | setup fails closed | `v3_runtime_not_ready` |
| presentation DI missing required dependencies | `assertV3RuntimeReady()` throws | setup fails closed | `v3_runtime_not_ready` |
| reminders BG dependencies missing | guard checks in background handler | skip reconcile and mark task failed | `bg_reminders_missing_dependencies` |
| reconcile timeout/partial failure | per-project timeout/failure handling | continues with partial accounting | `bg_reminders_project_timeout` |

## Forbidden Dependency Patterns

1. Presentation calling CoreData APIs directly.
2. UseCases depending on concrete repository classes instead of protocols.
3. Alternate runtime wiring paths that bypass `AppDelegate -> EnhancedDependencyContainer -> PresentationDependencyContainer`.
4. Side-effectful reminders/assistant flows without explicit feature-flag checks.
5. Reintroduction of legacy singleton runtime paths (`DependencyContainer.shared`).

## Integration Rules For UI

1. Create ViewModels through `PresentationDependencyContainer`.
2. Read list/search surfaces via read-model-backed usecases.
3. Route mutations through usecases/coordinator (never direct entity edits in UI).
4. Handle disabled-feature error paths for reminders sync and assistant apply/undo flows.

## Cross-Links

- `docs/architecture/data-model-v2.md`
- `docs/architecture/usecases-v2.md`
- `docs/architecture/state-repositories-and-services-v2.md`
- `docs/architecture/risk-register-v2.md`
