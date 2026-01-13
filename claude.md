# Tasker iOS - Clean Architecture Guide

**iOS 16.0+ | Swift 5+ | 189 files, 28 use cases | Clean Architecture (60% migrated)**

Gamified task management with priority scoring (P0=7, P1=4, P2=3, P3=2pts), UUID-based CloudKit sync, Inbox project (`00000000-0000-0000-0000-000000000001`), SwiftUI/Combine + legacy UIKit. Build: `./taskerctl build`. Stack: Firebase, MicrosoftFluentUI, DGCharts, FSCalendar.

---

## Architecture

**Flow**: `View → ViewModel → UseCaseCoordinator → UseCase → RepositoryProtocol → Adapter → Mapper ↔ CoreData`

**Layer Rules**:

| Layer | Path | Imports | Does | Never |
|-------|------|---------|------|-------|
| **Domain** | `Domain/` | Foundation only | Pure models, business logic, validation | Import UIKit/CoreData, depend on infrastructure |
| **UseCases** | `UseCases/` | Domain protocols | Orchestrate workflows, apply business rules | Import CoreData, manage UI state, direct DB access |
| **State** | `State/` | CoreData allowed | CRUD, caching (TTL), sync, Entity↔Domain mapping | Business logic beyond data constraints, UI concerns |
| **Presentation** | `Presentation/` | Combine, domain | @Published state, coordinate use cases, events | Import CoreData, bypass use cases, business logic |

**Critical Rule**: Dependencies flow inward. Use cases depend on repository *protocols*, never concrete types.

```swift
// ✅ CORRECT: Protocol injection
class GetTasksUseCase {
    private let repository: TaskRepositoryProtocol
    init(repository: TaskRepositoryProtocol) { self.repository = repository }
}

// ❌ WRONG: Hardcoded dependency
class GetTasksUseCase {
    private let repository = CoreDataTaskRepository()  // Can't swap, can't test
}
```

---

## 5 Critical Patterns

### 1. UUID Architecture
**All entities use UUID**. Inbox has fixed UUID. Legacy data without UUID gets deterministic generation.

```swift
// Domain/Constants/ProjectConstants.swift:12
public static let inboxProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

// Domain/Mappers/TaskMapper.swift:69 - Backward compatibility
public static func toDomain(from entity: NTask) -> Task {
    let id = entity.taskID ?? generateUUID(from: entity.objectID)  // Deterministic
    return Task(id: id, ...)
}
```

### 2. Mapper Pattern
**NEVER manual mapping**. Always use mappers for Entity↔Domain conversion.

```swift
// ✅ CORRECT
let tasks = TaskMapper.toDomainArray(from: entities)

// ❌ WRONG: Manual property copy (error-prone, no defaults, no backward compat)
let tasks = entities.map { Task(id: $0.taskID ?? UUID(), name: $0.name ?? "", ...) }
```

**Mapper methods**: `toDomain(from:)`, `toEntity(from:in:)`, `updateEntity(_:from:)`, `toDomainArray(from:)`

**Location**: `Domain/Mappers/TaskMapper.swift:12`, `Domain/Mappers/ProjectMapper.swift`

### 3. Repository Adapter (Bridge Pattern)
**TaskRepositoryAdapter** bridges legacy CoreData with clean protocols. Enables gradual migration.

```swift
// State/Repositories/TaskRepositoryAdapter.swift:12
final class TaskRepositoryAdapter: TaskRepositoryProtocol {
    private let legacyRepository: CoreDataTaskRepository
    private let cacheService: CacheServiceProtocol?

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let entities = try context.fetch(NTask.fetchRequest())
        let tasks = TaskMapper.toDomainArray(from: entities)  // ✅ Use mapper
        cacheService?.cacheTasks(tasks, forDate: Date(), ttl: .minutes(15))
        completion(.success(tasks))
    }
}
```

### 4. Domain Events (Combine)
**Publish events** for cross-cutting concerns (analytics, notifications, UI refresh). **Subscribe in ViewModels**.

```swift
// In UseCase - Publish
let event = TaskCompletedEvent(aggregateId: task.id, scoreEarned: task.score)
DomainEventPublisher.shared.publish(event)

// In ViewModel - Subscribe
DomainEventPublisher.shared.taskEvents
    .filter { $0.eventType == "TaskCompleted" }
    .sink { [weak self] _ in self?.loadAnalytics() }
    .store(in: &cancellables)
```

**Files**: `Domain/Events/DomainEventPublisher.swift:21`, `Domain/Events/TaskEvents.swift`

### 5. Caching with TTL
**Repository-level caching** for performance. Cache check → DB fetch → cache result. **Invalidate on write**.

```swift
// State/Cache/InMemoryCacheService.swift:11
func cacheTasks(_ tasks: [Task], forDate date: Date) {
    set(tasks, forKey: "tasks_\(date.cacheKey)", expiration: .minutes(15))
}

// Invalidate on write
func createTask(_ task: Task, completion: ...) {
    // ... save to DB ...
    cacheService?.invalidateCache(for: task.dueDate)
}
```

---

## Development Workflows

### Add UseCase (5 Steps)

```swift
// 1. Define Request/Response (UseCases/Task/MyUseCase.swift)
public struct MyRequest { let param: String }
public struct MyResponse { let result: [Task] }

// 2. Implement UseCase
public class MyUseCase {
    private let repository: TaskRepositoryProtocol  // Protocol!

    public init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(request: MyRequest, completion: @escaping (Result<MyResponse, Error>) -> Void) {
        repository.fetchAllTasks { result in
            // Business logic here
            let event = MyEvent(...)
            DomainEventPublisher.shared.publish(event)
            completion(.success(MyResponse(...)))
        }
    }
}

// 3. Register in UseCaseCoordinator.swift
public let myUseCase: MyUseCase

self.myUseCase = MyUseCase(taskRepository: taskRepository)

// 4. Call from ViewModel
useCaseCoordinator.myUseCase.execute(request: req) { [weak self] result in
    DispatchQueue.main.async {  // ✅ CRITICAL: Main thread for UI
        self?.data = try? result.get()
    }
}

// 5. Wire UI (SwiftUI)
viewModel.performAction()
```

### Add Repository (4 Steps)

```swift
// 1. Define Protocol (Domain/Interfaces/MyRepositoryProtocol.swift)
public protocol MyRepositoryProtocol {
    func fetchItems(completion: @escaping (Result<[Item], Error>) -> Void)
    func createItem(_ item: Item, completion: @escaping (Result<Item, Error>) -> Void)
}

// 2. Implement Repository (State/Repositories/CoreDataMyRepository.swift)
final class CoreDataMyRepository: MyRepositoryProtocol {
    func fetchItems(completion: @escaping (Result<[Item], Error>) -> Void) {
        let entities = try context.fetch(NItem.fetchRequest())
        let items = ItemMapper.toDomainArray(from: entities)  // ✅ Mapper
        completion(.success(items))
    }
}

// 3. Register in EnhancedDependencyContainer.swift:49
self.myRepository = CoreDataMyRepository(container: container)

// 4. Inject into UseCases
myUseCase = MyUseCase(myRepository: myRepository)
```

### Add Domain Model (4 Steps)

```swift
// 1. Create Model (Domain/Models/Label.swift)
public struct Label: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public func validate() throws {
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}

// 2. Create Core Data Entity (Xcode UI)
// Entity: NLabel
// Attributes: labelID (UUID), name (String), color (String)

// 3. Create Mapper (Domain/Mappers/LabelMapper.swift)
public class LabelMapper {
    static func toDomain(from entity: NLabel) -> Label {
        Label(id: entity.labelID ?? UUID(), name: entity.name ?? "")
    }

    static func toEntity(from label: Label, in context: NSManagedObjectContext) -> NLabel {
        let entity = NLabel(context: context)
        entity.labelID = label.id
        entity.name = label.name
        return entity
    }
}

// 4. Update Task model if needed
public var labelIDs: [UUID] = []  // Add to Task.swift
```

---

## File Map

| Component | Path | Key Files |
|-----------|------|-----------|
| **Domain Models** | `Domain/Models/` | Task.swift:12 (business logic), TaskPriority.swift (P0/P1/P2/P3), TaskType.swift (morning/evening) |
| **Protocols** | `Domain/Interfaces/` | TaskRepositoryProtocol.swift:12, CacheServiceProtocol.swift |
| **Mappers** | `Domain/Mappers/` | TaskMapper.swift:12 (toDomain/toEntity), ProjectMapper.swift |
| **Constants** | `Domain/Constants/` | ProjectConstants.swift:12 (Inbox UUID: 00...001) |
| **Events** | `Domain/Events/` | DomainEventPublisher.swift:21 (Combine), TaskEvents.swift |
| **Use Cases** | `UseCases/` | Coordinator/UseCaseCoordinator.swift:10 (factory), Task/GetTasksUseCase.swift:42, Task/CompleteTaskUseCase.swift |
| **Repositories** | `State/Repositories/` | TaskRepositoryAdapter.swift:12 (bridge), CoreDataTaskRepository.swift |
| **Cache** | `State/Cache/` | InMemoryCacheService.swift:11 (thread-safe, TTL) |
| **DI Container** | `State/DI/` | EnhancedDependencyContainer.swift:13 (manual injection) |
| **ViewModels** | `Presentation/ViewModels/` | HomeViewModel.swift:13 (@Published, Combine) |
| **Legacy VCs** | `ViewControllers/` | HomeViewController.swift:32 (⚠️ still uses CoreData directly) |
| **Migration** | `Data/Migration/` | DataMigrationService.swift (UUID assignment on launch) |
| **Core Data** | `TaskModel.xcdatamodeld/` | NTask, NProject entities |

---

## Anti-Patterns

| ❌ Wrong | ✅ Correct | Why |
|----------|-----------|-----|
| `let context: NSManagedObjectContext` in UseCase | `let repository: TaskRepositoryProtocol` | Use cases must not know about persistence |
| `import CoreData` in Domain | `import Foundation` only | Domain = pure Swift, no framework deps |
| `Task(id: entity.taskID ?? UUID(), ...)` | `TaskMapper.toDomain(from: entity)` | Mapper handles defaults, backward compat |
| `let score = priority == .high ? 7 : 4` in ViewModel | `task.score` (computed in domain) | Business logic belongs in domain/use case |
| `repository.fetch { self.tasks = $0 }` | `DispatchQueue.main.async { self.tasks = $0 }` | UI updates MUST be on main thread |
| `private let repo = CoreDataTaskRepository()` | `init(repo: TaskRepositoryProtocol)` | Protocol injection enables testing, swapping |
| Bypass mapper for "simple" mapping | Always use mapper | Mappers ensure consistency, handle edge cases |

---

## Migration Rules

**New features**: MUST use Clean Architecture. No exceptions.

```
✅ Create use case (UseCases/[Category]/)
✅ Use TaskRepositoryProtocol (NOT CoreDataTaskRepository)
✅ Use domain models (Task, Project structs)
✅ Register in UseCaseCoordinator
✅ Inject via constructor (protocol-based)
✅ Publish domain events

❌ NEVER import CoreData in use cases
❌ NEVER access NSManagedObjectContext directly
❌ NEVER bypass repository layer
```

**Modifying legacy code**:
- Bug fix (<10 lines) → Modify in place
- Substantial change → Migrate to Clean Architecture FIRST
- Business logic change → Extract to use case

**Migration on launch** (AppDelegate.swift):
```swift
EnhancedDependencyContainer.shared.configure(with: persistentContainer)
EnsureInboxProjectUseCase(...).execute()  // Guarantee Inbox exists
AssignOrphanedTasksToInboxUseCase(...).execute()  // Fix old data
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Task has nil UUID | Migration not run | Run `DataMigrationService` on launch |
| ViewModel not updating | Not on main thread | Wrap completion in `DispatchQueue.main.async` |
| Cache always misses | Service not injected | Check `EnhancedDependencyContainer.shared.cacheService` |
| "No such table" | CoreData model not loaded | Clean build folder (Cmd+Shift+K), rebuild |
| Merge conflict error | Concurrent saves | Use separate background contexts per operation |
| Tasks missing projectID | Orphaned data | Run `AssignOrphanedTasksToInboxUseCase` |

**Debug CoreData**: Edit Scheme → Run → Arguments: `-com.apple.CoreData.SQLDebug 1`

**Verify UUID**:
```swift
print("Task UUID: \(task.taskID?.uuidString ?? "NIL")")  // Should NOT be nil
print("Inbox UUID: \(ProjectConstants.inboxProjectID)")   // Should be 00...001
```

---

## Quick Reference

### Decision Tree: Where Does Code Go?

```
New feature?
├─ Business workflow → UseCase (UseCases/[Category]/)
├─ Data persistence → Repository (State/Repositories/)
├─ Business model → Domain Model (Domain/Models/)
└─ UI state → ViewModel (Presentation/ViewModels/)

Bug fix?
├─ <10 lines → Fix in place
└─ Substantial → Migrate to Clean Architecture first
```

### Checklist: New Feature
- [ ] Domain model (Domain/Models/)
- [ ] Repository protocol (Domain/Interfaces/)
- [ ] Repository implementation (State/Repositories/)
- [ ] Mapper (Domain/Mappers/)
- [ ] Use case (UseCases/[Category]/)
- [ ] Register in UseCaseCoordinator
- [ ] ViewModel (Presentation/ViewModels/)
- [ ] Wire UI
- [ ] Tests

### Build Commands
```bash
./taskerctl setup              # Install dependencies
./taskerctl build              # Build simulator
./taskerctl build device       # Build physical device
./taskerctl clean --all        # Clean build
./taskerctl doctor             # Diagnostics
```

---

## Critical Rules (Memorize)

1. **Protocol Injection**: NEVER hardcode dependencies. Always `init(repo: RepoProtocol)`.
2. **Mapper Usage**: NEVER manually map. Use `TaskMapper.toDomain/toEntity`.
3. **UUID Everywhere**: All entities have UUIDs. Inbox = `00000000-0000-0000-0000-000000000001`.
4. **Main Thread**: UI updates MUST use `DispatchQueue.main.async`.
5. **Domain Purity**: NO CoreData/UIKit imports in Domain layer.
6. **Use Cases Own Logic**: Business logic goes in use cases, NOT ViewModels/Views.
7. **Repository Abstraction**: Use cases call protocols, never concrete repos.
8. **Domain Events**: Publish for cross-cutting (analytics, notifications, UI refresh).
9. **Cache Invalidation**: Invalidate cache on write operations.
10. **Clean for New**: ALL new features use Clean Architecture. No legacy patterns.

---

## Example: Complete Feature (Condensed)

```swift
// 1. DOMAIN (Domain/Models/Label.swift)
public struct Label: Codable, Identifiable {
    public let id: UUID; public var name: String
    public func validate() throws { guard !name.isEmpty else { throw ValidationError.emptyName } }
}

// 2. PROTOCOL (Domain/Interfaces/LabelRepositoryProtocol.swift)
public protocol LabelRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[Label], Error>) -> Void)
}

// 3. MAPPER (Domain/Mappers/LabelMapper.swift)
public class LabelMapper {
    static func toDomain(from entity: NLabel) -> Label { Label(id: entity.labelID ?? UUID(), name: entity.name ?? "") }
    static func toEntity(from label: Label, in ctx: NSManagedObjectContext) -> NLabel {
        let e = NLabel(context: ctx); e.labelID = label.id; e.name = label.name; return e
    }
}

// 4. REPOSITORY (State/Repositories/CoreDataLabelRepository.swift)
final class CoreDataLabelRepository: LabelRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[Label], Error>) -> Void) {
        let entities = try context.fetch(NLabel.fetchRequest())
        completion(.success(LabelMapper.toDomainArray(from: entities)))
    }
}

// 5. USE CASE (UseCases/Label/GetLabelsUseCase.swift)
public class GetLabelsUseCase {
    private let repository: LabelRepositoryProtocol
    public func execute(completion: @escaping (Result<[Label], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }
}

// 6. COORDINATOR (UseCases/Coordinator/UseCaseCoordinator.swift)
public let getLabels: GetLabelsUseCase
self.getLabels = GetLabelsUseCase(repository: labelRepository)

// 7. VIEWMODEL (Presentation/ViewModels/LabelViewModel.swift)
public final class LabelViewModel: ObservableObject {
    @Published var labels: [Label] = []
    func load() { coordinator.getLabels.execute { DispatchQueue.main.async { self.labels = try? $0.get() ?? [] } } }
}

// 8. VIEW (SwiftUI)
List(viewModel.labels) { Text($0.name) }.onAppear { viewModel.load() }
```

**Template**: `GetTasksUseCase.swift:42`, `CompleteTaskUseCase.swift` for reference patterns.

<!-- BEGIN FLOW-NEXT -->
## Flow-Next

This project uses Flow-Next for task tracking. Use `.flow/bin/flowctl` instead of markdown TODOs or TodoWrite.

**Quick commands:**
```bash
.flow/bin/flowctl list                # List all epics + tasks
.flow/bin/flowctl epics               # List all epics
.flow/bin/flowctl tasks --epic fn-N   # List tasks for epic
.flow/bin/flowctl ready --epic fn-N   # What's ready
.flow/bin/flowctl show fn-N.M         # View task
.flow/bin/flowctl start fn-N.M        # Claim task
.flow/bin/flowctl done fn-N.M --summary-file s.md --evidence-json e.json
```

**Rules:**
- Use `.flow/bin/flowctl` for ALL task tracking
- Do NOT create markdown TODOs or use TodoWrite
- Re-anchor (re-read spec + status) before every task

**More info:** `.flow/bin/flowctl --help` or read `.flow/usage.md`
<!-- END FLOW-NEXT -->
