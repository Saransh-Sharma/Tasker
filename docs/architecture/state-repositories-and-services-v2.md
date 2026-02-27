# State Repositories and Services (V3 Runtime)

**Last validated against code on 2026-02-27**

This document maps State-layer ownership for persistence repositories, supporting services, and runtime wiring.

Primary source anchors:
- `To Do List/State/Repositories/*.swift`
- `To Do List/State/Services/*.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Domain/Interfaces/V2RepositoryProtocols.swift`
- `To Do List/Domain/Interfaces/TaskReadModelRepositoryProtocol.swift`
- `To Do List/TaskModelV3.xcdatamodeld/.xccurrentversion`
- `To Do List/TaskModelV3.xcdatamodeld/TaskModelV3_Gamification.xcdatamodel/contents`
- `To Do List/LLM/Models/TaskSemanticIndexStore.swift`
- `To Do List/LLM/Models/TaskSemanticRetrievalService.swift`
- `To Do List/LLM/Models/LLMDataController.swift`

## State Topology

```mermaid
flowchart TD
    UC["UseCases"] --> IFACE["Domain protocols"]
    IFACE --> REPO["CoreData repositories"]
    REPO --> CORE["TaskModelV3 entities"]

    UC --> SRV["State services"]
    SRV --> REPO
    SRV --> EXT["EventKit / Notification stack"]

    REPO --> SUP["V2CoreDataRepositorySupport"]

    APP["AppDelegate"] --> SEM["TaskSemanticRetrievalService"]
    SEM --> IDX["TaskSemanticIndexStore"]
```

## Repository Inventory

| File | Types | Protocol surface | Primary entity/data domain |
| --- | --- | --- | --- |
| `State/Repositories/CoreDataTaskDefinitionRepository.swift` | `CoreDataTaskDefinitionRepository`, `CoreDataTaskTagLinkRepository`, `CoreDataTaskDependencyRepository` | `TaskDefinitionRepositoryProtocol`, `TaskTagLinkRepositoryProtocol`, `TaskDependencyRepositoryProtocol` | `TaskDefinition`, `TaskTagLink`, `TaskDependency` |
| `State/Repositories/CoreDataTaskReadModelRepository.swift` | `CoreDataTaskReadModelRepository` | `TaskReadModelRepositoryProtocol` | query slices and task aggregates |
| `State/Repositories/CoreDataProjectRepository.swift` | `CoreDataProjectRepository` | `ProjectRepositoryProtocol` | `Project` |
| `State/Repositories/CoreDataLifeAreaRepository.swift` | `CoreDataLifeAreaRepository` | `LifeAreaRepositoryProtocol` | `LifeArea` |
| `State/Repositories/CoreDataSectionRepository.swift` | `CoreDataSectionRepository` | `SectionRepositoryProtocol` | `ProjectSection` |
| `State/Repositories/CoreDataTagRepository.swift` | `CoreDataTagRepository` | `TagRepositoryProtocol` | `Tag` |
| `State/Repositories/CoreDataHabitRepository.swift` | `CoreDataHabitRepository` | `HabitRepositoryProtocol` | `HabitDefinition` |
| `State/Repositories/CoreDataScheduleRepository.swift` | `CoreDataScheduleRepository` | `ScheduleRepositoryProtocol` | `ScheduleTemplate`, `ScheduleRule`, `ScheduleException` |
| `State/Repositories/CoreDataOccurrenceRepository.swift` | `CoreDataOccurrenceRepository` | `OccurrenceRepositoryProtocol` | `Occurrence`, `OccurrenceResolution` |
| `State/Repositories/CoreDataReminderRepository.swift` | `CoreDataReminderRepository` | `ReminderRepositoryProtocol` | `Reminder`, `ReminderTrigger`, `ReminderDelivery` |
| `State/Repositories/CoreDataGamificationRepository.swift` | `CoreDataGamificationRepository` | `GamificationRepositoryProtocol` | `GamificationProfile`, `XPEvent`, `AchievementUnlock`, `DailyXPAggregate`, `FocusSession` |
| `State/Repositories/CoreDataAssistantActionRepository.swift` | `CoreDataAssistantActionRepository` | `AssistantActionRepositoryProtocol` | `AssistantActionRun` |
| `State/Repositories/CoreDataExternalSyncRepository.swift` | `CoreDataExternalSyncRepository` | `ExternalSyncRepositoryProtocol` | `ExternalContainerMap`, `ExternalItemMap` |
| `State/Repositories/CoreDataTombstoneRepository.swift` | `CoreDataTombstoneRepository` | `TombstoneRepositoryProtocol` | `Tombstone` |
| `State/Repositories/UserDefaultsSavedHomeViewRepository.swift` | `UserDefaultsSavedHomeViewRepository` | `SavedHomeViewRepositoryProtocol` | home-view preference snapshots |
| `State/Repositories/V2CoreDataRepositorySupport.swift` | `V2CoreDataRepositorySupport` | shared helper | ID validation, canonicalization, upsert helpers |

## Service Inventory

| File | Type | Protocol surface | Purpose |
| --- | --- | --- | --- |
| `State/Services/CoreSchedulingEngine.swift` | `CoreSchedulingEngine` | `SchedulingEngineProtocol` | schedule generation, occurrence maintenance/resolution orchestration |
| `State/Services/EventKitAppleRemindersProvider.swift` | `EventKitAppleRemindersProvider` | `AppleRemindersProviderProtocol` | Apple Reminders provider I/O |
| `State/Services/LocalNotificationService.swift` | `LocalNotificationService` | `NotificationServiceProtocol` | in-app reminder notifications |
| `LLM/Models/TaskSemanticRetrievalService.swift` | `TaskSemanticRetrievalService` | retrieval and rerank surface | local semantic indexing and ranking for AI/search |
| `LLM/Models/TaskSemanticIndexStore.swift` | `TaskSemanticIndexStore` | upsert/remove/persist/load operations | local vector/text index persistence |

## Data Ownership Matrix

| Data domain | Canonical writer(s) | Primary consumers |
| --- | --- | --- |
| Task graph (`TaskDefinition`, dependency/tag links) | `CoreDataTaskDefinitionRepository` family | task usecases, sync usecases, assistant pipeline |
| Query slices/aggregates | `CoreDataTaskReadModelRepository` | home/search/analytics/project dashboards |
| Planning hierarchy | project/life-area/section/tag repositories | project and task creation/edit flows |
| Scheduling timeline | schedule + occurrence repositories and scheduling engine | schedule maintenance and reminder orchestration |
| Reminders domain | `CoreDataReminderRepository` + provider service | reminder scheduling and external reconcile |
| External mapping state | `CoreDataExternalSyncRepository` | link/reconcile flows |
| Gamification ledger + daily projections | `CoreDataGamificationRepository` | task completion, focus/reflection, Home XP, Insights, widgets |
| Assistant action runs | `CoreDataAssistantActionRepository` | assistant propose/confirm/apply/undo |
| Tombstones | `CoreDataTombstoneRepository` | maintenance and sync merge flows |
| Semantic embeddings index | `TaskSemanticIndexStore` (local file in Application Support) | chat semantic context and search rerank |
| LLM chat history | SwiftData `LLMDataController` local store | Chat UI thread/message rendering |

## Gamification Repository Threading and Canonicalization

`CoreDataGamificationRepository` uses a split-context model:
- `backgroundContext`: write context with local transaction author (`tasker.gamification.local`).
- `readContext`: dedicated background read context for fetch APIs.

Freshness and safety expectations:
1. Read paths are non-destructive fetches.
2. Write paths apply canonicalization where required:
- profile: singleton canonical row.
- daily aggregate: canonical row per `dateKey`.
- idempotency checks via `XPEvent.idempotencyKey`.
3. After successful writes, repository resets `readContext` to avoid stale registered-object snapshots in-session.
4. Schema guard validates required entities/attributes and fails safely with diagnostics if missing.

## Semantic Index Ownership and Persistence

1. The semantic index is local-only and intentionally excluded from CloudKit sync.
2. Index file path contract: `Application Support/tasker-semantic-index-v1.bin`.
3. Lifecycle ownership:
- load at startup,
- incremental mutation updates from `.homeTaskMutation`,
- full rebuild for recovery or cold initialization,
- persist on app backgrounding.

## Identity and Dedupe Rules (State Layer)

| Rule | Enforced by | Why it matters |
| --- | --- | --- |
| Non-empty UUID IDs required for writes | `V2CoreDataRepositorySupport.requireID` | prevents invalid identity rows |
| Canonical object selection before update/upsert | `V2CoreDataRepositorySupport.canonicalObject`/`upsertByID` | prevents duplicate logical entities |
| Dependency edges deduped by `(taskID, dependsOnTaskID, kind)` | `CoreDataTaskDependencyRepository.replaceDependencies` | prevents duplicate dependency graph edges |
| Tag links replaced as set for a task | `CoreDataTaskTagLinkRepository.replaceTagLinks` | avoids stale links after edits |
| Occurrence identity uses immutable `occurrenceKey` | `CoreDataOccurrenceRepository` | deterministic recurrence lifecycle |
| External item mappings upsert by local/external key | `CoreDataExternalSyncRepository` | stable merge-state evolution |
| Gamification profile canonical singleton | `CoreDataGamificationRepository.saveProfile` | prevents duplicate profile rows and stale level totals |
| Daily aggregate canonical by `dateKey` | `CoreDataGamificationRepository.saveDailyAggregate` | keeps one authoritative row per day for week rendering |
| Read-context reset after gamification writes | `CoreDataGamificationRepository.finalizeWrite` | prevents stale read-after-write snapshots |
| Semantic vectors keyed by `taskID` and replaced on upsert | `TaskSemanticIndexStore` | deterministic semantic refresh behavior |

## LLM SwiftData Reliability Note

`LLMDataController` prioritizes app availability over chat-history durability:
1. normal persistent container create,
2. store recreation retry,
3. in-memory fallback,
4. final hard failure only if all strategies fail.

This keeps the core runtime available even when local chat storage is incompatible.

## Error Surface Summary

| Surface | Common sources | Handling pattern |
| --- | --- | --- |
| CoreData fetch/save | invalid predicates, conflicts, missing entities | propagate as `Result.failure`, no silent swallow |
| Identity mismatches | malformed IDs, duplicate candidates | canonicalization helpers + explicit failures |
| Provider I/O | reminders permission denied, lookup/write failures | propagated through provider and sync usecases |
| Batch reconciliation | partial per-item failures/timeouts | aggregate summary and per-item failure accounting |
| Semantic indexing | embedding unavailable, file persist/load failures | lexical fallback + warning logs + rebuild path |
| LLM chat store bootstrap | model schema incompatibility or store corruption | recreate persistent store, then in-memory fallback |

## Runtime Wiring

`EnhancedDependencyContainer.configure(with:)` is the only runtime entrypoint for State-layer wiring.
It builds repositories/services, constructs `UseCaseCoordinator`, and evaluates readiness through `assertV3RuntimeReady()`.

AI-specific runtime wiring outside the container remains in `AppDelegate` and includes:
- `LLMContextRepositoryProvider` setup,
- `LLMAssistantPipelineProvider` setup,
- semantic retrieval lifecycle orchestration.

## Cross-Links

- `docs/architecture/clean-architecture-v2.md`
- `docs/architecture/data-model-v2.md`
- `docs/architecture/usecases-v2.md`
- `docs/architecture/llm-assistant-stack-v2.md`
- `docs/architecture/llm-feature-integration-handbook.md`
- `docs/architecture/risk-register-v2.md`
