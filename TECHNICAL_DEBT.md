# Tasker iOS - Technical Debt & Future Work

**Version:** 1.2
**Last Updated:** January 13, 2026
**Last Audit:** January 13, 2026
**Status:** Active Development

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Clean Architecture Migration Status](#clean-architecture-migration-status) *(NEW - Audit Results)*
3. [Critical Technical Debt (High Priority)](#critical-technical-debt-high-priority)
4. [Medium Priority Technical Debt](#medium-priority-technical-debt)
5. [Low Priority Technical Debt](#low-priority-technical-debt)
6. [Incomplete Features](#incomplete-features)
7. [Testing Gaps](#testing-gaps)
8. [Performance Optimizations](#performance-optimizations)
9. [Recommended Action Plan](#recommended-action-plan)

---

## Executive Summary

Tasker is currently at **~75% Clean Architecture migration** with 189 files organized across domain, use case, state, and presentation layers. The **core architecture foundation is solid** with proper layers implemented. Recent improvements include removing UIKit dependencies from Domain layer and properly wiring ViewModels to ViewControllers. The **presentation layer (ViewControllers) remains the area needing gradual migration** to fully use ViewModels.

### Key Statistics

- **Total Files**: 189 Swift files
- **Clean Architecture Coverage**: ~75% migrated, ~25% legacy (ViewControllers still using direct CoreData in some places)
- **Domain Layer Compliance**: 100% (no UIKit imports, Foundation only)
- **Unit Test Coverage**: ~10% (Domain/Use Cases)
- **UI Test Coverage**: <5%
- **Technical Debt Hours**: Estimated 300-450 hours (38-56 work days)
- **Code Quality**: Mixed (Clean Architecture areas: A, Legacy areas: C)

### Priority Breakdown

| Priority | Items | Est. Hours | Impact |
|----------|-------|------------|---------|
| **High** | 3 | 200-300h | Architecture integrity, testability, feature completeness |
| **Medium** | 4 | 80-120h | Feature accessibility, automation, UX |
| **Low** | 3 | 50-80h | Platform expansion, convenience features |
| **Total** | 10 | 330-500h | 41-63 work days (2-2.5 months full-time) |

---

## Clean Architecture Migration Status

### Audit Date: January 13, 2026

### Overall Assessment: **~75% Complete**

The Clean Architecture migration has made significant progress since the last audit. Key improvements:

1. **Domain Layer Now 100% Clean**: Removed UIKit imports from `TaskPriorityConfig.swift` and `ProjectEnums.swift`. Colors are now represented as hex strings with UIKit bridge extensions in the View layer.

2. **ProjectTaskValidator Moved to State Layer**: The validator that requires CoreData has been properly relocated from Domain to State layer.

3. **ViewModels Properly Wired**: `HomeViewModel`, `AddTaskViewModel`, and `ProjectManagementViewModel` are now properly integrated with their respective ViewControllers through `PresentationDependencyContainer`.

4. **Use Cases Exposed via Coordinator**: `DeleteTaskUseCase` now properly exposed through `UseCaseCoordinator` instead of being instantiated directly in ViewModels.

The primary remaining work is gradually removing direct CoreData access from **ViewControllers** and ensuring all data flows through ViewModels.

---

### Layer-by-Layer Assessment

#### 1. Domain Layer ✅ **COMPLETE (100%)**

**Status**: 🟢 **Excellent - Fully Clean Architecture Compliant**

| Component | Files | Status | Notes |
|-----------|-------|--------|-------|
| **Models** | 12 | ✅ Complete | `Task.swift`, `Project.swift`, `User.swift`, enums - All pure Swift with Foundation only |
| **Interfaces/Protocols** | 7 | ✅ Complete | `TaskRepositoryProtocol`, `ProjectRepositoryProtocol`, `CacheServiceProtocol`, etc. |
| **Events** | 4 | ✅ Complete | `DomainEventPublisher`, `TaskEvents`, `ProjectEvents`, `DomainEvent` |
| **Constants** | 1 | ✅ Complete | `ProjectConstants.swift` with Inbox UUID (`00000000-0000-0000-0000-000000000001`) |
| **Services** | 1 | ✅ Complete | `UUIDGenerator.swift` |
| **Mappers** | 2 | ⚠️ Acceptable | CoreData import required for entity conversion - documented exception |

**January 2026 Improvements**:
- ✅ Removed UIKit from `TaskPriorityConfig.swift` - Colors now use hex strings (`colorHex: String`)
- ✅ Removed UIKit from `ProjectEnums.swift` - Colors now use hex strings (`hexString: String`)
- ✅ Moved `ProjectTaskValidator.swift` to State layer (requires CoreData)
- ✅ UIKit bridge extensions added to View layer (`ToDoColors.swift`)

**Note on Mappers**: `TaskMapper.swift` and `ProjectMapper.swift` import CoreData for entity conversion. This is architecturally acceptable as mappers bridge Domain ↔ Infrastructure. They remain in Domain for organizational consistency but could be moved to State layer in future.

**Verified Clean (Foundation only)**:
- ✅ `Task.swift` - Pure domain model with business logic
- ✅ `Project.swift` - Pure domain model
- ✅ `TaskPriority.swift` - Enum with scoring logic
- ✅ `TaskPriorityConfig.swift` - Pure Swift with hex color strings
- ✅ `ProjectEnums.swift` - Pure Swift with hex color strings
- ✅ `ProjectConstants.swift` - Inbox UUID constant
- ✅ `DomainEventPublisher.swift` - Combine-based event bus

---

#### 2. Use Cases Layer ✅ **COMPLETE (100%)**

**Status**: 🟢 **Excellent - Properly Implemented**

| Component | Files | Status | Notes |
|-----------|-------|--------|-------|
| **UseCaseCoordinator** | 1 | ✅ Complete | Factory pattern, protocol injection, Foundation only |
| **Task Use Cases** | 18 | ✅ Complete | `GetTasksUseCase`, `CreateTaskUseCase`, `CompleteTaskUseCase`, etc. |
| **Project Use Cases** | 4 | ✅ Complete | `ManageProjectsUseCase`, `EnsureInboxProjectUseCase`, etc. |
| **Analytics Use Cases** | 2 | ✅ Complete | `AnalyticsUseCase`, `DashboardUseCase` |
| **Collaboration Use Cases** | 2 | ⚠️ Skeleton | `TaskCollaborationUseCase` - defined but no backend |

**Verified Correct Pattern**:
```swift
// UseCaseCoordinator.swift - Correct protocol injection ✅
public class UseCaseCoordinator {
    private let taskRepository: TaskRepositoryProtocol  // Protocol, not concrete
    private let projectRepository: ProjectRepositoryProtocol
    private let cacheService: CacheServiceProtocol?

    public init(taskRepository: TaskRepositoryProtocol,
                projectRepository: ProjectRepositoryProtocol,
                cacheService: CacheServiceProtocol?) { ... }
}
```

---

#### 3. State Layer ✅ **COMPLETE (95%)**

**Status**: 🟢 **Excellent - Properly Organized**

| Component | Files | Status | Notes |
|-----------|-------|--------|-------|
| **DI Container** | 1 | ✅ Complete | `EnhancedDependencyContainer.swift` - proper registration |
| **Repositories** | 3 | ✅ Complete | `TaskRepositoryAdapter`, `CoreDataTaskRepository`, `CoreDataProjectRepository` |
| **Cache** | 1 | ✅ Complete | `InMemoryCacheService.swift` with TTL support |
| **Validators** | 1 | ✅ Complete | `ProjectTaskValidator.swift` (moved from Domain) |
| **Sync** | 1 | ⚠️ Partial | `CloudKitSyncService` - basic implementation |

**January 2026 Improvements**:
- ✅ `ProjectTaskValidator.swift` moved from Domain layer (proper location for CoreData-dependent validation)
- ✅ State layer now contains all CoreData-dependent infrastructure code

**Verified Components**:
- ✅ `EnhancedDependencyContainer.swift` - Registers all repositories and use cases correctly
- ✅ `TaskRepositoryAdapter.swift` - Bridges legacy CoreData with clean protocols
- ✅ `InMemoryCacheService.swift` - Thread-safe with expiration/TTL
- ✅ `ProjectTaskValidator.swift` - Data integrity validation with CoreData

---

#### 4. Presentation Layer ⚠️ **PARTIAL (70%)**

**Status**: 🟡 **Good Progress - ViewModels integrated with ViewControllers**

| Component | Files | Status | Notes |
|-----------|-------|--------|-------|
| **ViewModels** | 3 | ✅ Complete | `HomeViewModel`, `AddTaskViewModel`, `ProjectManagementViewModel` |
| **DI Container** | 1 | ✅ Complete | `PresentationDependencyContainer.swift` - receives deps from State layer |
| **ViewController Integration** | 3+ | ✅ Partial | Core VCs now have ViewModel support enabled |

**January 2026 Improvements**:
- ✅ `PresentationDependencyContainer` now properly configured from State layer
- ✅ `AddTaskViewController` now conforms to `AddTaskViewControllerProtocol` with ViewModel injection
- ✅ `HomeViewModel` now uses `useCaseCoordinator.deleteTask` instead of creating use case directly
- ✅ ViewController protocols defined for dependency injection (`HomeViewControllerProtocol`, `AddTaskViewControllerProtocol`, `ProjectManagementViewControllerProtocol`)

**Remaining Work**: Some ViewControllers still have legacy code paths that bypass ViewModels. Gradual migration recommended.

---

#### 5. ViewControllers ❌ **LEGACY (~35% of codebase)**

**Status**: 🔴 **Critical - Direct CoreData Access**

**Files with `import CoreData` (13 ViewControllers)**:

| File | Lines | CoreData Usage | Migration Priority |
|------|-------|----------------|-------------------|
| `HomeViewController.swift` | 600+ | NSFetchRequest, NTask entities | **Critical** |
| `FluentUIToDoTableViewController.swift` | 1500+ | NSFetchRequest, NTask, Projects | **Critical** |
| `AddTaskViewController.swift` | 1000+ | Has inline `InlineProjectRepository` class (218 lines!) | **High** |
| `HomeViewController+TableView.swift` | 400+ | NSFetchRequest | **High** |
| `HomeViewController+ProjectFiltering.swift` | 200+ | NSFetchRequest | **High** |
| `NewProjectViewController.swift` | 300+ | NSFetchRequest, Projects | **Medium** |
| `TaskListViewController.swift` | 300+ | NSFetchRequest | **Medium** |
| `LGSearchViewController.swift` | 200+ | NSFetchRequest | **Medium** |
| `LGSearchViewModel.swift` | 150+ | NSFetchRequest (partially migrated) | **Medium** |
| `SettingsPageViewController.swift` | 200+ | NSFetchRequest | **Low** |
| `HomeCalendarExtention.swift` | 150+ | NSFetchRequest | **Low** |
| `AddTaskCalendarExtention.swift` | 100+ | NSFetchRequest | **Low** |
| `ToDoList.swift` | 200+ | NSFetchRequest | **Low** |

**Anti-Patterns Found**:

1. **Placeholder ViewModels in ViewControllers** (violates DRY, blocks real ViewModel usage):
   ```swift
   // ❌ AddTaskViewController.swift:254-264 - Duplicates real ViewModel
   class AddTaskViewModel {
       @Published var isLoading: Bool = false  // Placeholder!
   }
   ```

2. **Direct CoreData Access** (bypasses repository layer):
   ```swift
   // ❌ FluentUIToDoTableViewController.swift:103-104
   let request: NSFetchRequest<NTask> = NTask.fetchRequest()
   let tasks = try context.fetch(request)
   ```

3. **Inline Repository Classes** (massive code duplication):
   ```swift
   // ❌ AddTaskViewController.swift:25-243 - 218 lines of duplicated repo code!
   fileprivate class InlineProjectRepository: ProjectRepositoryProtocol {
       // Full repository implementation duplicated inside ViewController!
   }
   ```

4. **TODO Comments Indicating Incomplete Migration**:
   ```swift
   // FluentUIToDoTableViewController.swift:13
   import CoreData  // TODO: Migrate away from NSFetchRequest to use repository pattern

   // FluentUIToDoTableViewController.swift:101
   // TODO: Use repository once it has fetchAllTasks method
   ```

---

### Migration Summary Table

| Layer | Status | Completion | Remaining Work |
|-------|--------|------------|----------------|
| **Domain** | ✅ Complete | 100% | None - UIKit removed, Foundation only |
| **Use Cases** | ✅ Complete | 100% | None |
| **State** | ✅ Complete | 95% | CloudKit sync enhancements |
| **Presentation (ViewModels)** | ⚠️ Good | 70% | Expand ViewModel usage in VCs |
| **ViewControllers** | ⚠️ Partial | 25% | Gradually remove direct CoreData access |

---

### What's Needed to Complete Migration

#### Immediate Actions (8-16 hours)

1. **Remove Placeholder ViewModels** from ViewControllers:
   - Delete inline `AddTaskViewModel` class from `AddTaskViewController.swift`
   - Delete inline `HomeViewModel` stub from `HomeViewController.swift` (if present)
   - Import and use real ViewModels from `Presentation/ViewModels/`

2. **Add Presentation Files to Xcode Target** (if not already):
   - Ensure `Presentation/ViewModels/*.swift` files are in the app target
   - Ensure `Presentation/DI/PresentationDependencyContainer.swift` is accessible

#### Short-term Actions (40-80 hours)

3. **Integrate Real ViewModels into ViewControllers**:
   - Inject `HomeViewModel` into `HomeViewController`
   - Inject `AddTaskViewModel` into `AddTaskViewController`
   - Inject `ProjectManagementViewModel` into project-related VCs
   - Replace all direct CoreData calls with ViewModel methods

4. **Remove Inline Repository Classes**:
   - Delete `InlineProjectRepository` from `AddTaskViewController.swift` (218 lines)
   - Use injected repository from DI container instead

#### Medium-term Actions (80-120 hours)

5. **Remove All Direct CoreData Access**:
   - Replace all `NSFetchRequest` calls with repository/use case calls
   - Remove `import CoreData` from all 13 ViewControllers
   - Update `FluentUIToDoTableViewController` to use domain `Task` instead of `NTask`

6. **Move Mappers to State Layer** (optional, 4 hours):
   - Move `TaskMapper.swift` from `Domain/Mappers/` to `State/Mappers/`
   - Move `ProjectMapper.swift` similarly
   - Update imports in affected files

**Total Estimated Effort to Complete Migration**: **132-200 hours (16-25 work days)**

---

### Recommendations for Next Steps

**This Week**:
1. Add `Presentation/ViewModels/` files to Xcode target (if not already)
2. Delete placeholder ViewModel classes from ViewControllers
3. Wire real ViewModels via `PresentationDependencyContainer`

**Next 2 Weeks**:
1. Start with `HomeViewController` migration (highest traffic screen)
2. Then `AddTaskViewController` (critical user flow)
3. Then `FluentUIToDoTableViewController` (task list display)

**Next Month**:
1. Migrate remaining ViewControllers
2. Remove all `import CoreData` from presentation layer
3. Add unit tests for ViewModels

---

## Critical Technical Debt (High Priority)

### 1. Legacy UIKit ViewControllers (~35% of Codebase)

**Status**: 🔴 **CRITICAL** *(Updated based on Jan 10, 2026 audit)*

**Problem**: ~35% of ViewControllers still use CoreData directly, bypassing Clean Architecture principles. **ViewModels exist in `Presentation/ViewModels/` but are not integrated** - ViewControllers contain placeholder/duplicate ViewModel classes instead.

**Affected Files** (13 files with `import CoreData` confirmed):
- `HomeViewController.swift` (600+ lines, highest traffic) - **Critical**
- `HomeViewController+TableView.swift` - **High**
- `HomeViewController+ProjectFiltering.swift` - **High**
- `AddTaskViewController.swift` (1000+ lines, has 218-line inline repository!) - **High**
- `FluentUIToDoTableViewController.swift` (1500+ lines, task list view) - **Critical**
- `NewProjectViewController.swift` - **Medium**
- `TaskListViewController.swift` - **Medium**
- `LGSearchViewController.swift` - **Medium**
- `LGSearchViewModel.swift` (partially migrated) - **Medium**
- `SettingsPageViewController.swift` - **Low**
- `HomeCalendarExtention.swift` - **Low**
- `AddTaskCalendarExtention.swift` - **Low**
- `ToDoList.swift` - **Low**

**Key Finding**: Real ViewModels already exist in `Presentation/ViewModels/`:
- ✅ `HomeViewModel.swift` - Ready to use
- ✅ `AddTaskViewModel.swift` - Ready to use
- ✅ `ProjectManagementViewModel.swift` - Ready to use

The ViewControllers just need to be wired to use these instead of their inline placeholders.

**Specific Issues**:
1. **Direct CoreData Access**:
   ```swift
   // ❌ WRONG: Direct context access in HomeViewController
   let fetchRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
   let tasks = try viewContext.fetch(fetchRequest)
   ```

2. **NSFetchedResultsController Usage**: Multiple ViewControllers use `NSFetchedResultsController` for table view updates, tightly coupling UI to CoreData.

3. **Manual Entity-to-Domain Mapping**: ViewControllers manually convert `NTask` entities to `Task` models instead of using `TaskMapper`.

4. **No ViewModels**: Business logic and state management mixed with view code.

**Impact**:
- ❌ **Breaks Clean Architecture principles** (presentation depends on infrastructure)
- ❌ **Difficult to test** (no mocking CoreData)
- ❌ **Tight coupling** (changes to CoreData schema require UI changes)
- ❌ **Code duplication** (same logic repeated across ViewControllers)
- ❌ **Hard to maintain** (mixed concerns, difficult to understand)

**Estimated Effort**: 132-200 hours (16-25 work days) *(Reduced - ViewModels already exist)*

**Breakdown** *(Updated based on audit)*:
- **Remove placeholder ViewModels from VCs**: 8-16 hours (quick wins)
- `HomeViewController` integration: 32-48 hours (most complex, highest traffic)
- `AddTaskViewController` integration: 24-32 hours (includes removing 218-line inline repo)
- `FluentUIToDoTableViewController` integration: 24-40 hours (largest file, uses NTask extensively)
- Other ViewControllers (9 files): 44-64 hours (4-8h each)

**Recommended Approach** *(Updated)*:
1. **Add Presentation files to Xcode target** (if not already - check Build Phases)
2. **Delete placeholder ViewModel classes** from ViewControllers (they duplicate real ones)
3. **Delete inline repository classes** (e.g., `InlineProjectRepository` in AddTaskViewController)
4. **Inject real ViewModels** via `PresentationDependencyContainer`
5. **Replace NSFetchRequest calls** with ViewModel methods
6. **Remove `import CoreData`** from all ViewControllers
7. **Migrate incrementally**, starting with HomeViewController

**Example Migration** (HomeViewController):
```swift
// ✅ CORRECT: Clean Architecture ViewModel

public final class HomeViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var morningTasks: [Task] = []
    @Published var eveningTasks: [Task] = []
    @Published var completedTasks: [Task] = []
    @Published var overdueTasks: [Task] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let useCaseCoordinator: UseCaseCoordinator
    private var cancellables = Set<AnyCancellable>()

    public init(useCaseCoordinator: UseCaseCoordinator) {
        self.useCaseCoordinator = useCaseCoordinator
        subscribeToEvents()
    }

    public func loadTodayTasks() {
        isLoading = true
        useCaseCoordinator.getTasks.getTodayTasks { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let tasksResult):
                    self?.todayTasks = tasksResult.allTasks
                    self?.morningTasks = tasksResult.morningTasks
                    self?.eveningTasks = tasksResult.eveningTasks
                    self?.completedTasks = tasksResult.completedTasks
                    self?.overdueTasks = tasksResult.overdueTasks
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }

    public func completeTask(_ task: Task) {
        useCaseCoordinator.completeTask.completeTask(task.id) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadTodayTasks() // Refresh
                case .failure(let error):
                    self?.error = error
                }
            }
        }
    }

    private func subscribeToEvents() {
        // Subscribe to domain events for real-time updates
        DomainEventPublisher.shared.taskEvents
            .filter { $0.eventType == "TaskCreated" || $0.eventType == "TaskUpdated" || $0.eventType == "TaskDeleted" }
            .sink { [weak self] _ in
                self?.loadTodayTasks()
            }
            .store(in: &cancellables)
    }
}
```

**Success Criteria**:
- ✅ All ViewControllers use UseCaseCoordinator exclusively
- ✅ Zero direct CoreData imports in presentation layer
- ✅ All ViewModels have unit tests (70%+ coverage)
- ✅ UI updates always on main thread via `DispatchQueue.main.async`
- ✅ Domain events used for cross-cutting updates

---

### 2. Incomplete Collaboration Features

**Status**: 🟡 **HIGH PRIORITY (Planned Feature)**

**Problem**: Collaboration use cases defined but not implemented. Major feature gap for team/family use.

**What Exists** (Use Case Skeletons):
- `TaskCollaborationUseCase.swift` (831 lines, full skeleton)
- `TaskCollaborationSyncService.swift` (sync service skeleton)
- Supporting models: `SharedTask`, `TaskSharingResult`, `CollaborationPermissions`, `TaskComment`, `CollaborationActivity`, etc.

**What's Missing**:
1. **Repository Implementation**: `CollaborationRepositoryProtocol` defined but no CoreData/CloudKit implementation
2. **User Management System**: No user profiles, authentication, or user discovery
3. **CloudKit Record Sharing**: No CKShare integration for sharing tasks
4. **Real-Time Sync**: `TaskCollaborationSyncService` is a skeleton (no CloudKit subscriptions)
5. **UI Screens**: Zero UI for sharing, comments, or collaboration views
6. **Notification System**: No push notifications for collaboration events

**Estimated Effort**: 320-480 hours (40-60 work days)

**Breakdown**:
- **User Management System** (80-120 hours):
  - User model and repository (16-24h)
  - Authentication (Firebase Auth or CloudKit) (24-32h)
  - User profiles and settings (16-24h)
  - User search and discovery (24-40h)

- **Task Sharing Backend** (120-160 hours):
  - `CollaborationRepositoryProtocol` CoreData implementation (32-40h)
  - CloudKit record sharing (CKShare) (40-56h)
  - Permission system (view/edit/full access) (24-32h)
  - Conflict resolution for shared tasks (24-32h)

- **Comments & Activity** (60-80 hours):
  - Comment model and repository (16-24h)
  - Activity tracking and logging (16-24h)
  - Real-time sync for comments (16-20h)
  - Mention system (@username) (12-16h)

- **UI Implementation** (60-120 hours):
  - Share task screen (16-24h)
  - Manage collaborators screen (16-24h)
  - Task comments view (16-24h)
  - Activity feed view (12-16h)
  - Shared tasks list (FluentUI) (16-24h)
  - Notification UI (8-12h)

**Impact**:
- ❌ **Major Feature Gap**: No collaboration features for teams/families
- ⚠️ **App Store Positioning**: Cannot market as "team task management"
- ⚠️ **Competitive Disadvantage**: Other apps (Todoist, Asana, Things) have sharing

**Recommended Approach**:
1. **Phase 1: User Management** (4-6 weeks)
   - Implement Firebase Auth or CloudKit user authentication
   - Build user profile system
   - User search and friend system

2. **Phase 2: Task Sharing MVP** (6-8 weeks)
   - Implement `CollaborationRepositoryProtocol` with CoreData
   - CloudKit record sharing (CKShare)
   - Share task screen (single task sharing only)
   - Permission system (view/edit/full access)

3. **Phase 3: Comments & Activity** (3-4 weeks)
   - Comment model and repository
   - Real-time sync for comments
   - Activity tracking and feed

4. **Phase 4: Advanced Features** (4-6 weeks)
   - Task assignment
   - Team task templates
   - Collaborative sessions
   - Bulk sharing (task collections)

**Success Criteria**:
- ✅ Users can share tasks with others via email/user ID
- ✅ Permissions enforced (view-only, edit, full access)
- ✅ Real-time sync for shared tasks
- ✅ Comments and activity tracking functional
- ✅ Push notifications for collaboration events
- ✅ CloudKit record sharing working reliably

---

### 3. Missing Unit Tests

**Status**: 🔴 **CRITICAL**

**Problem**: Insufficient test coverage across all layers. Regression risk is high.

**Current Coverage**:
- **Domain Layer**: ~10% coverage
  - Task.swift: 5% (only basic validation tested)
  - Project.swift: 5%
  - Mappers: 0%
  - Domain Events: 0%
- **Use Cases Layer**: ~0% coverage
  - All 28 use cases: 0% tests
- **State Layer**: ~5% coverage
  - Repositories: minimal smoke tests only
  - Cache: 0%
  - Sync: 0%
- **Presentation Layer**: 0% (ViewModels not fully adopted)

**Affected Files** (108 files untested):
- `To Do List/UseCases/**/*.swift` (28 use cases)
- `To Do List/Domain/Models/*.swift` (12 models)
- `To Do List/Domain/Mappers/*.swift` (2 mappers)
- `To Do List/State/Repositories/*.swift` (3 repositories)
- `To Do List/State/Cache/*.swift` (1 cache service)
- `To Do List/Presentation/ViewModels/*.swift` (3 ViewModels)

**Impact**:
- ❌ **High Regression Risk**: Changes break existing features without detection
- ❌ **Difficult Refactoring**: Can't safely refactor without breaking things
- ❌ **Slow Development**: Manual testing slows down every change
- ❌ **Low Confidence**: Uncertain if code works as intended

**Estimated Effort**: 240-320 hours (30-40 work days)

**Breakdown**:
- **Use Case Tests** (160-200 hours):
  - Task use cases (18 files): 120-160h (6-8h each)
  - Project use cases (4 files): 16-24h
  - Analytics use cases (2 files): 12-16h
  - UseCaseCoordinator complex workflows: 12-16h

- **Domain Model Tests** (32-48 hours):
  - Task model business logic: 16-24h
  - Project model business logic: 8-12h
  - Enum tests: 8-12h

- **Mapper Tests** (16-24 hours):
  - TaskMapper (all conversion paths): 8-12h
  - ProjectMapper: 8-12h

- **Repository Tests** (24-32 hours):
  - CoreDataTaskRepository (with in-memory store): 12-16h
  - CoreDataProjectRepository: 8-12h
  - TaskRepositoryAdapter: 4-8h

- **Cache Tests** (8-12 hours):
  - InMemoryCacheService (TTL, expiration, thread safety): 8-12h

**Recommended Approach**:
1. **Start with Domain Layer** (highest ROI, easiest to test):
   - Pure Swift models with no dependencies
   - Test all business logic methods
   - Test all validation rules

2. **Move to Use Cases** (most important for business logic):
   - Mock repository protocols
   - Test success and failure paths
   - Test business rule enforcement
   - Test domain event publishing

3. **Repository Tests** (use in-memory CoreData):
   - In-memory persistent store for speed
   - Test CRUD operations
   - Test UUID generation and mapping
   - Test cache integration

4. **ViewModel Tests** (once ViewModels are adopted):
   - Mock UseCaseCoordinator
   - Test state management
   - Test error handling
   - Test domain event subscription

**Success Criteria**:
- ✅ **Domain Layer**: 80%+ coverage
- ✅ **Use Cases Layer**: 70%+ coverage
- ✅ **State Layer**: 60%+ coverage
- ✅ **Presentation Layer**: 50%+ coverage (ViewModels)
- ✅ **CI Integration**: Tests run on every commit
- ✅ **Fast Tests**: Full suite runs in <2 minutes

**Example Test** (Use Case):
```swift
import XCTest
@testable import Tasker

final class CreateTaskUseCaseTests: XCTestCase {
    var sut: CreateTaskUseCase!
    var mockTaskRepository: MockTaskRepository!
    var mockProjectRepository: MockProjectRepository!
    var mockNotificationService: MockNotificationService!

    override func setUp() {
        super.setUp()
        mockTaskRepository = MockTaskRepository()
        mockProjectRepository = MockProjectRepository()
        mockNotificationService = MockNotificationService()

        sut = CreateTaskUseCase(
            taskRepository: mockTaskRepository,
            projectRepository: mockProjectRepository,
            notificationService: mockNotificationService
        )
    }

    func testExecute_WithValidRequest_CreatesTask() {
        // Given
        let request = CreateTaskRequest(
            name: "Test Task",
            details: "Test details",
            type: .morning,
            priority: .high,
            dueDate: Date(),
            project: nil,
            alertReminderTime: nil
        )
        let expectation = expectation(description: "Task created")

        // When
        sut.execute(request: request) { result in
            // Then
            switch result {
            case .success(let task):
                XCTAssertEqual(task.name, "Test Task")
                XCTAssertEqual(task.projectID, ProjectConstants.inboxProjectID) // Defaults to Inbox
                XCTAssertEqual(task.priority, .high)
                XCTAssertTrue(self.mockTaskRepository.createTaskCalled)
                expectation.fulfill()
            case .failure:
                XCTFail("Expected success")
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testExecute_WithEmptyName_ReturnsValidationError() {
        // Given
        let request = CreateTaskRequest(
            name: "",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: nil,
            alertReminderTime: nil
        )
        let expectation = expectation(description: "Validation error")

        // When
        sut.execute(request: request) { result in
            // Then
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertTrue(error is TaskValidationError)
                XCTAssertEqual(error as? TaskValidationError, .emptyName)
                XCTAssertFalse(self.mockTaskRepository.createTaskCalled)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testExecute_WithPastDueDate_AdjustsToToday() {
        // Given
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let request = CreateTaskRequest(
            name: "Late Task",
            details: nil,
            type: .morning,
            priority: .high,
            dueDate: yesterday,
            project: nil,
            alertReminderTime: nil
        )
        let expectation = expectation(description: "Task created with adjusted date")

        // When
        sut.execute(request: request) { result in
            // Then
            switch result {
            case .success(let task):
                let today = Calendar.current.startOfDay(for: Date())
                let taskDate = Calendar.current.startOfDay(for: task.dueDate!)
                XCTAssertEqual(taskDate, today) // Should be adjusted to today
                expectation.fulfill()
            case .failure:
                XCTFail("Expected success")
            }
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
```

---

### 4. No UI/E2E Tests

**Status**: 🟡 **HIGH PRIORITY**

**Problem**: No end-to-end tests for critical user flows. Manual testing is time-consuming and error-prone.

**Current State**:
- **E2E Testing Infrastructure**: Exists (`To Do ListUITests/` folder)
- **Accessibility Identifiers**: Implemented (`ACCESSIBILITY_IDENTIFIERS_GUIDE.md`)
- **Page Objects Pattern**: Documented (`To Do ListUITests/PageObjects/`)
- **Test Coverage**: <5% (minimal placeholder tests only)

**What Exists**:
- `SettingsUITests.swift` (sample test file)
- Page Object base classes (`BasePage.swift` pattern)
- Helper utilities (`To Do ListUITests/Helpers/`)
- Accessibility identifiers on key UI elements

**What's Missing**:
1. **Critical Flow Tests**:
   - Task creation flow (from home → add task → save → verify)
   - Task completion flow (mark complete → verify score update)
   - Task editing flow (edit task → update properties → save)
   - Task deletion flow (swipe to delete → confirm)
   - Project creation/management flow
   - Filter and search flows
   - Analytics dashboard navigation

2. **Regression Tests**:
   - No tests for previously fixed bugs
   - No smoke tests for app launch
   - No tests for data migration scenarios

3. **Integration Tests**:
   - No tests for CoreData + CloudKit sync
   - No tests for notification scheduling
   - No tests for background refresh

**Impact**:
- ❌ **Manual Testing Burden**: Every release requires extensive manual testing
- ❌ **Regression Risk**: Fixed bugs can resurface undetected
- ❌ **Slow Release Cycle**: Fear of breaking things slows down releases
- ❌ **Deployment Confidence**: Low confidence in release stability

**Estimated Effort**: 160-240 hours (20-30 work days)

**Breakdown**:
- **Critical Flow Tests** (80-120 hours):
  - Task creation flow: 16-24h
  - Task completion flow: 12-16h
  - Task editing flow: 12-16h
  - Task deletion flow: 8-12h
  - Project management flow: 16-24h
  - Filter and search flows: 16-24h

- **Page Objects Implementation** (40-60 hours):
  - HomePageObject: 8-12h
  - AddTaskPageObject: 8-12h
  - TaskDetailPageObject: 8-12h
  - ProjectManagementPageObject: 8-12h
  - SettingsPageObject: 8-12h

- **Test Infrastructure** (24-32 hours):
  - XCUITest setup and configuration: 8-12h
  - Test data generation utilities: 8-12h
  - CI/CD integration (GitHub Actions or similar): 8-12h

- **Regression Tests** (16-24 hours):
  - Bug regression tests: 8-12h
  - Smoke tests (app launch, navigation): 8-12h

**Recommended Approach**:
1. **Start with Smoke Tests** (quick wins):
   - App launches successfully
   - All tabs navigable
   - No crashes on basic interactions

2. **Implement Critical Flow Tests** (highest impact):
   - Task creation (most used feature)
   - Task completion (core gamification)
   - Task editing

3. **Build Page Objects** (maintainability):
   - Abstract UI element access
   - Reusable actions (tap, swipe, type)
   - Consistent wait strategies

4. **Add Regression Tests** (stability):
   - Test every fixed bug
   - Prevent regressions

5. **CI/CD Integration** (automation):
   - Run on every PR
   - Run nightly
   - Report failures immediately

**Success Criteria**:
- ✅ **Smoke Tests**: App launch and basic navigation tested
- ✅ **Critical Flows**: Top 5 user flows covered (40%+ coverage)
- ✅ **Page Objects**: All major screens abstracted
- ✅ **CI Integration**: Tests run automatically on commits
- ✅ **Fast Execution**: Full suite runs in <10 minutes
- ✅ **Reliable Tests**: <5% flakiness rate

**Example E2E Test**:
```swift
import XCTest

final class TaskCreationFlowUITests: XCTestCase {
    var app: XCUIApplication!
    var homePage: HomePageObject!
    var addTaskPage: AddTaskPageObject!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()

        homePage = HomePageObject(app: app)
        addTaskPage = AddTaskPageObject(app: app)
    }

    func testCreateTask_WithValidInput_AddsTaskToList() {
        // Given: User is on home screen
        XCTAssertTrue(homePage.isDisplayed())
        let initialTaskCount = homePage.taskCount

        // When: User creates a new task
        homePage.tapAddTaskButton()
        XCTAssertTrue(addTaskPage.isDisplayed())

        addTaskPage.enterTaskName("Buy groceries")
        addTaskPage.enterTaskDetails("Milk, eggs, bread")
        addTaskPage.selectPriority(.high)
        addTaskPage.selectTaskType(.morning)
        addTaskPage.tapSaveButton()

        // Then: Task appears in the list
        XCTAssertTrue(homePage.isDisplayed())
        XCTAssertEqual(homePage.taskCount, initialTaskCount + 1)
        XCTAssertTrue(homePage.hasTaskWithName("Buy groceries"))
    }

    func testCreateTask_WithEmptyName_ShowsValidationError() {
        // Given: User is on home screen
        homePage.tapAddTaskButton()

        // When: User tries to save without entering name
        addTaskPage.tapSaveButton()

        // Then: Validation error is shown
        XCTAssertTrue(addTaskPage.hasValidationError())
        XCTAssertEqual(addTaskPage.validationErrorMessage, "Task name cannot be empty")
    }
}

// Page Object
class HomePageObject {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var isDisplayed: Bool {
        return app.navigationBars["Today"].exists
    }

    var taskCount: Int {
        return app.tables["TaskTableView"].cells.count
    }

    func tapAddTaskButton() {
        app.buttons["AddTaskButton"].tap()
    }

    func hasTaskWithName(_ name: String) -> Bool {
        return app.tables["TaskTableView"].cells.staticTexts[name].exists
    }
}
```

---

## Medium Priority Technical Debt

### 5. Habit Builder UI Missing

**Status**: 🟡 **MEDIUM PRIORITY (Use Case Implemented, UI Pending)**

**Problem**: Full habit builder use case implemented but no UI. Feature is invisible to users.

**What Exists**:
- `TaskHabitBuilderUseCase.swift` (691 lines, fully implemented)
- Complete domain models:
  - `HabitDefinition`, `HabitTask`, `HabitTemplate`, `HabitProgress`
  - `HabitFrequency`, `HabitTimeOfDay`, `HabitReminder`
  - `HabitMomentum`, `HabitMilestone`, `HabitSuggestion`
- Habit creation, completion tracking, progress analytics
- Habit templates (exercise, reading, meditation, etc.)
- Habit suggestions based on patterns

**What's Missing**:
1. **Habit Creation UI**:
   - Habit template selection screen
   - Habit customization form (frequency, time, duration, tags)
   - Preview of generated habit schedule

2. **Habit Dashboard**:
   - List of active habits
   - Habit progress cards (streak, completion rate, momentum)
   - Habit milestones display

3. **Habit Detail Screen**:
   - Historical completion chart
   - Streak calendar view
   - Habit suggestions panel
   - Pause/resume/delete actions

4. **Habit Integration with Main App**:
   - Habit tasks in today's task list (marked as "Habit")
   - Habit completion from main task list
   - Habit-specific analytics in dashboard

**Impact**:
- ⚠️ **Hidden Feature**: Fully functional feature not accessible
- ⚠️ **Missed Value**: Habit tracking is valuable for user retention
- ⚠️ **Competitive Gap**: Other apps (Streaks, Habitica) have habit tracking

**Estimated Effort**: 120-160 hours (15-20 work days)

**Breakdown**:
- **Habit Template Selection Screen** (24-32 hours):
  - FluentUI list of templates
  - Template categories (health, learning, wellness)
  - Template customization sheet

- **Habit Creation Form** (32-40 hours):
  - Frequency picker (daily, weekdays, weekly, custom)
  - Time of day picker
  - Duration input
  - Reminder settings
  - Tag input

- **Habit Dashboard** (40-56 hours):
  - Active habits list (FluentUI)
  - Habit cards with progress indicators
  - Momentum indicators (building, stable, declining)
  - Milestone badges

- **Habit Detail Screen** (24-32 hours):
  - Historical completion chart (DGCharts)
  - Streak calendar (FSCalendar)
  - Habit suggestions panel
  - Pause/resume/delete actions

**Recommended Approach**:
1. **Phase 1: Basic Habit Creation** (4-6 days):
   - Template selection screen
   - Basic habit creation form

2. **Phase 2: Habit Dashboard** (6-8 days):
   - Active habits list
   - Progress indicators

3. **Phase 3: Habit Details** (4-6 days):
   - Detail screen with charts
   - Suggestions panel

4. **Phase 4: Integration** (2-3 days):
   - Habit tasks in main task list
   - Habit-specific analytics

**Success Criteria**:
- ✅ Users can create habits from templates
- ✅ Users can customize habit frequency and time
- ✅ Habit dashboard shows all active habits
- ✅ Habit progress visible with charts
- ✅ Habit tasks integrated into main task list
- ✅ Habit-specific analytics in dashboard

---

### 6. Task Time Tracking Incomplete

**Status**: 🟡 **MEDIUM PRIORITY (Partially Implemented)**

**Problem**: Domain model supports time tracking but no timer UI or efficiency analytics.

**What Exists**:
- Task model properties:
  - `estimatedDuration: TimeInterval?`
  - `actualDuration: TimeInterval?`
- Task business logic:
  - `func calculateEfficiencyScore() -> Double` (estimated / actual)
- Use case placeholder: `TaskTimeTrackingUseCase` (referenced but not implemented)

**What's Missing**:
1. **Timer UI**:
   - Start/stop timer button on task detail screen
   - Active timer indicator in task list
   - Background timer support (app backgrounded)

2. **Time Tracking Use Case**:
   - `startTracking(taskId: UUID)` - Begin tracking
   - `stopTracking(taskId: UUID)` - End tracking and save actual duration
   - `getEfficiencyMetrics()` - Calculate efficiency analytics

3. **Efficiency Analytics**:
   - Category efficiency (which categories are fast/slow)
   - Time-of-day efficiency (productivity peaks/troughs)
   - Estimate improvement suggestions ("Your reading tasks typically take 1.5x longer")

4. **UI for Estimates**:
   - Estimated duration input in task creation/editing
   - Suggested estimates based on similar tasks

**Impact**:
- ⚠️ **Incomplete Feature**: Time tracking data collected but not actionable
- ⚠️ **Missed Insights**: No efficiency analytics to improve estimates

**Estimated Effort**: 80-120 hours (10-15 work days)

**Breakdown**:
- **Timer UI** (32-48 hours):
  - Timer button on task detail screen (8-12h)
  - Active timer indicator (8-12h)
  - Background timer support (8-12h)
  - Timer persistence (across app restarts) (8-12h)

- **Time Tracking Use Case** (24-32 hours):
  - Start/stop tracking logic (8-12h)
  - Actual duration calculation (4-8h)
  - Repository updates (8-12h)
  - Domain events (4h)

- **Efficiency Analytics** (24-40 hours):
  - Category efficiency calculation (8-12h)
  - Time-of-day efficiency (8-12h)
  - Estimate improvement suggestions (8-16h)

**Recommended Approach**:
1. **Phase 1: Timer UI** (4-6 days):
   - Basic start/stop timer
   - Active timer indicator

2. **Phase 2: Time Tracking Use Case** (3-4 days):
   - Tracking logic
   - Duration persistence

3. **Phase 3: Efficiency Analytics** (3-5 days):
   - Category/time-of-day analytics
   - Estimate suggestions

**Success Criteria**:
- ✅ Users can start/stop timer for tasks
- ✅ Actual duration saved on task completion
- ✅ Efficiency score calculated and displayed
- ✅ Efficiency analytics available in dashboard
- ✅ Estimate suggestions provided for new tasks

---

### 7. Priority Optimizer Not Automated

**Status**: 🟡 **MEDIUM PRIORITY (Implemented but Not Triggered)**

**Problem**: `TaskPriorityOptimizerUseCase` fully implemented but not triggered automatically.

**What Exists**:
- `TaskPriorityOptimizerUseCase.swift` (fully implemented):
  - `optimizeAllPriorities()` - Batch optimization
  - `suggestPriorityAdjustment(task:)` - Single task suggestion
  - `generatePriorityInsights()` - Optimization report
- Priority optimization factors:
  - Deadline proximity
  - Overdue status
  - Dependencies
  - User pattern learning
  - Category importance
  - Estimated duration

**What's Missing**:
1. **Automatic Triggering**:
   - Background job for nightly optimization
   - iOS background fetch integration
   - Trigger on app launch (if last run >24h ago)

2. **User Approval Flow**:
   - Show optimization suggestions in UI
   - User can approve/reject suggestions
   - Learn from user adjustments

3. **Optimization Insights UI**:
   - Show optimization report in analytics
   - "12 tasks were auto-prioritized based on deadlines"

**Impact**:
- ⚠️ **Hidden Feature**: Valuable optimization not used
- ⚠️ **Manual Prioritization**: Users must adjust priorities manually

**Estimated Effort**: 40-60 hours (5-7 work days)

**Breakdown**:
- **Background Job Setup** (16-24 hours):
   - iOS background fetch configuration (4-8h)
   - Background task scheduling (BGTaskScheduler) (8-12h)
   - Last run tracking (UserDefaults) (4h)

- **User Approval Flow** (16-24 hours):
   - Optimization suggestions UI (8-12h)
   - Approve/reject actions (4-8h)
   - Learning from adjustments (4-8h)

- **Optimization Insights UI** (8-12 hours):
   - Insights panel in analytics (4-8h)
   - Optimization history (4h)

**Recommended Approach**:
1. **Phase 1: Background Triggering** (2-3 days):
   - Configure background fetch
   - Schedule nightly optimization

2. **Phase 2: User Approval** (2-3 days):
   - Suggestions UI
   - Approve/reject flow

3. **Phase 3: Insights** (1-2 days):
   - Optimization report UI

**Success Criteria**:
- ✅ Optimization runs automatically nightly
- ✅ Users can approve/reject suggestions
- ✅ Optimization insights visible in analytics
- ✅ User adjustments fed back to optimizer

---

### 8. No Export/Import

**Status**: 🟡 **MEDIUM PRIORITY (User Data Portability)**

**Problem**: No way to export or import task data. Users cannot backup or migrate data manually.

**What Exists**:
- CloudKit sync (automatic iCloud backup)
- CoreData persistence (local backup via iTunes/Finder)

**What's Missing**:
1. **Export**:
   - JSON export (all tasks, projects, analytics)
   - CSV export (tasks only, for Excel/Google Sheets)
   - Manual iCloud backup trigger

2. **Import**:
   - JSON import (restore from backup)
   - CSV import (import tasks from other apps)
   - Duplicate detection and merge strategy

3. **Settings UI**:
   - Export button in settings
   - Import button in settings
   - Format selection (JSON/CSV)
   - Progress indicator

**Impact**:
- ⚠️ **Data Portability**: Users cannot manually backup data
- ⚠️ **Migration Barrier**: Difficult to switch to/from other apps

**Estimated Effort**: 80-120 hours (10-15 work days)

**Breakdown**:
- **Export Implementation** (32-48 hours):
   - JSON serialization (12-16h)
   - CSV generation (12-16h)
   - File export UI (share sheet) (8-16h)

- **Import Implementation** (32-48 hours):
   - JSON deserialization (12-16h)
   - CSV parsing (12-16h)
   - Duplicate detection (8-16h)

- **Settings UI** (16-24 hours):
   - Export/import buttons (4-8h)
   - Format selection (4-8h)
   - Progress indicators (8-12h)

**Recommended Approach**:
1. **Phase 1: JSON Export** (4-6 days):
   - JSON serialization
   - Share sheet integration

2. **Phase 2: JSON Import** (4-6 days):
   - JSON deserialization
   - Duplicate detection

3. **Phase 3: CSV Support** (2-3 days):
   - CSV export/import

**Success Criteria**:
- ✅ Users can export data to JSON/CSV
- ✅ Users can import data from JSON/CSV
- ✅ Duplicate detection works reliably
- ✅ Export/import progress visible

---

## Low Priority Technical Debt

### 9. No Widget Support

**Status**: 🟢 **LOW PRIORITY (Convenience Feature)**

**Problem**: No iOS widgets for today's tasks or streaks.

**What's Missing**:
- Today's tasks widget (small, medium, large)
- Streak widget (small)
- Quick add task widget (small)

**Estimated Effort**: 80-120 hours (10-15 work days)

---

### 10. No Watch App

**Status**: 🟢 **LOW PRIORITY (Platform Expansion)**

**Problem**: No Apple Watch app for quick task capture or completion.

**What's Missing**:
- Watch app with task list
- Quick task capture
- Task completion
- Complications for Watch faces

**Estimated Effort**: 160-240 hours (20-30 work days)

---

### 11. No Siri Shortcuts

**Status**: 🟢 **LOW PRIORITY (Accessibility Feature)**

**Problem**: No voice commands for task creation or completion.

**What's Missing**:
- "Add task" shortcut
- "Complete task" shortcut
- "Show today's tasks" shortcut

**Estimated Effort**: 40-60 hours (5-7 work days)

---

## Incomplete Features

### Summary of Incomplete Features

| Feature | Status | Use Case | UI | Backend | Effort (hours) |
|---------|--------|----------|----|---------|--------------------|
| **Task Time Tracking** | Partial | ⚠️ Placeholder | ❌ Missing | ⚠️ Partial (domain model only) | 80-120 |
| **Collaboration** | Planned | ✅ Skeleton | ❌ Missing | ❌ Missing | 320-480 |
| **Habit Builder** | Partial | ✅ Complete | ❌ Missing | ✅ Complete | 120-160 |
| **Priority Optimizer Automation** | Partial | ✅ Complete | ⚠️ Partial | ✅ Complete | 40-60 |
| **Export/Import** | Missing | ❌ Missing | ❌ Missing | ❌ Missing | 80-120 |
| **Widgets** | Missing | ❌ Missing | ❌ Missing | ❌ Missing | 80-120 |
| **Watch App** | Missing | ❌ Missing | ❌ Missing | ❌ Missing | 160-240 |
| **Siri Shortcuts** | Missing | ❌ Missing | ❌ Missing | ❌ Missing | 40-60 |

---

## Testing Gaps

### Unit Testing Gaps

| Layer | Coverage | Priority | Effort (hours) |
|-------|----------|----------|----------------|
| **Domain Models** | ~10% | High | 32-48 |
| **Use Cases** | ~0% | Critical | 160-200 |
| **Repositories** | ~5% | High | 24-32 |
| **Mappers** | 0% | High | 16-24 |
| **Cache Service** | 0% | Medium | 8-12 |
| **ViewModels** | 0% | High | 32-48 |

### UI Testing Gaps

| Flow | Coverage | Priority | Effort (hours) |
|------|----------|----------|----------------|
| **Task Creation** | 0% | Critical | 16-24 |
| **Task Completion** | 0% | Critical | 12-16 |
| **Task Editing** | 0% | High | 12-16 |
| **Task Deletion** | 0% | High | 8-12 |
| **Project Management** | 0% | Medium | 16-24 |
| **Filter & Search** | 0% | Medium | 16-24 |
| **Analytics Navigation** | 0% | Low | 8-12 |

---

## Performance Optimizations

### Identified Performance Issues

1. **Large Task Lists** (Low Priority):
   - Problem: Slow scrolling with 500+ tasks
   - Solution: Table view cell recycling optimization
   - Effort: 16-24 hours

2. **Analytics Calculation** (Medium Priority):
   - Problem: Slow analytics computation on large datasets
   - Solution: Incremental analytics updates, pre-computed aggregates
   - Effort: 24-32 hours

3. **CloudKit Sync Batch Size** (Low Priority):
   - Problem: Large sync operations timeout
   - Solution: Batch sync in chunks of 50 records
   - Effort: 8-12 hours

---

## Recommended Action Plan

### Q1 2026 (Jan-Mar): Architecture & Stability

**Focus**: Complete Clean Architecture migration, establish testing foundation

**Priorities**:
1. **Legacy ViewController Migration** (6-8 weeks):
   - HomeViewController (2 weeks)
   - AddTaskViewController (1.5 weeks)
   - FluentUIToDoTableViewController (1 week)
   - Other ViewControllers (2-2.5 weeks)
   - ✅ **Outcome**: 100% Clean Architecture compliance

2. **Unit Testing Foundation** (4-6 weeks):
   - Domain model tests (1 week)
   - Use case tests (2-3 weeks)
   - Repository tests (1 week)
   - Mapper tests (0.5 week)
   - ✅ **Outcome**: 70%+ use case coverage, 80%+ domain coverage

3. **Habit Builder UI** (2-3 weeks):
   - Template selection (0.5 week)
   - Habit creation form (1 week)
   - Habit dashboard (1-1.5 weeks)
   - ✅ **Outcome**: Habit tracking accessible to users

**Total Q1 Effort**: 12-17 weeks (3-4 months if 1 developer full-time)

---

### Q2 2026 (Apr-Jun): Collaboration & Testing

**Focus**: Implement collaboration features, establish E2E testing

**Priorities**:
1. **User Management System** (4-6 weeks):
   - Firebase Auth integration (1 week)
   - User profiles (1 week)
   - User search (2-3 weeks)
   - ✅ **Outcome**: User system ready for collaboration

2. **Task Sharing MVP** (6-8 weeks):
   - Collaboration repository (2 weeks)
   - CloudKit record sharing (2-3 weeks)
   - Share UI (2-3 weeks)
   - ✅ **Outcome**: Users can share tasks

3. **E2E Testing** (4-6 weeks):
   - Critical flow tests (2-3 weeks)
   - Page Objects (1-2 weeks)
   - CI integration (1 week)
   - ✅ **Outcome**: 40%+ E2E coverage, automated testing

**Total Q2 Effort**: 14-20 weeks

---

### Q3 2026 (Jul-Sep): Intelligence & Optimization

**Focus**: Complete task intelligence features, optimize performance

**Priorities**:
1. **Task Time Tracking** (2-3 weeks):
   - Timer UI (1-1.5 weeks)
   - Time tracking use case (1 week)
   - Efficiency analytics (0.5-1 week)
   - ✅ **Outcome**: Time tracking fully functional

2. **Priority Optimizer Automation** (1-2 weeks):
   - Background job setup (0.5-1 week)
   - User approval flow (0.5-1 week)
   - ✅ **Outcome**: Automatic priority optimization

3. **Comments & Activity** (3-4 weeks):
   - Comment model/repository (1 week)
   - Activity tracking (1 week)
   - Real-time sync (1-2 weeks)
   - ✅ **Outcome**: Collaboration features complete

4. **Performance Optimizations** (2-3 weeks):
   - Large list optimization (1 week)
   - Analytics computation (1-1.5 weeks)
   - CloudKit batching (0.5 week)
   - ✅ **Outcome**: App performs well with large datasets

**Total Q3 Effort**: 8-12 weeks

---

### Q4 2026 (Oct-Dec): Platform Expansion & Polish

**Focus**: Expand to more platforms, add convenience features

**Priorities**:
1. **iOS Widgets** (2-3 weeks)
2. **Apple Watch App** (6-8 weeks)
3. **Siri Shortcuts** (1-2 weeks)
4. **Export/Import** (2-3 weeks)

**Total Q4 Effort**: 11-16 weeks

---

## Summary

### Total Technical Debt

- **Critical (High Priority)**: 320-480 hours (40-60 work days)
- **Medium Priority**: 280-420 hours (35-53 work days)
- **Low Priority**: 280-420 hours (35-53 work days)
- **Total**: 880-1320 hours (110-165 work days, ~22-33 weeks full-time)

### Recommended 12-Month Plan

| Quarter | Focus | Effort (weeks) | Key Outcomes |
|---------|-------|----------------|--------------|
| **Q1 2026** | Architecture & Stability | 12-17 | 100% Clean Architecture, 70%+ test coverage, Habit Builder UI |
| **Q2 2026** | Collaboration & Testing | 14-20 | Task sharing MVP, E2E tests, User management |
| **Q3 2026** | Intelligence & Optimization | 8-12 | Time tracking, Auto-prioritization, Performance |
| **Q4 2026** | Platform Expansion | 11-16 | Widgets, Watch app, Siri shortcuts |
| **Total** | | **45-65 weeks** | Fully polished, tested, feature-complete app |

### Success Metrics

**By Q1 2026 End**:
- ✅ 100% Clean Architecture compliance
- ✅ 70%+ use case test coverage
- ✅ 80%+ domain model test coverage
- ✅ Habit Builder accessible to users

**By Q2 2026 End**:
- ✅ Task sharing MVP launched
- ✅ 40%+ E2E test coverage
- ✅ User management system complete

**By Q3 2026 End**:
- ✅ Time tracking fully functional
- ✅ Automatic priority optimization active
- ✅ Collaboration features complete

**By Q4 2026 End**:
- ✅ iOS widgets, Watch app, Siri shortcuts launched
- ✅ Export/import functional
- ✅ App fully tested and stable

---

**End of Technical Debt Document**
