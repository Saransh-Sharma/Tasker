# Tasker iOS - Technical Debt

**Last Updated:** January 13, 2026
**Clean Architecture:** ~70% migrated
**Status:** Active Development

---

## Summary

| Priority | Count | Total Effort |
|----------|-------|--------------|
| P0 - Critical | 1 | 200-300h |
| P1 - High | 3 | 80-150h |
| P2 - Medium | 4 | 60-100h |
| P3 - Low | 2 | 30-50h |
| **Total** | **10** | **370-600h** |

---

## Clean Architecture Migration Status

| Layer | Files | Compliance | Status |
|-------|-------|------------|--------|
| Domain | 30 | 80% | Mappers import CoreData, business logic in Task model |
| UseCases | 28 | 96% | Excellent—protocol injection, no CoreData |
| State | 9 | 85% | DI container has UIKit import |
| Presentation | 4 | 95% | ViewModels clean |
| ViewControllers | 47 | 42% | 23 files with NSFetchRequest (gradual migration) |
| **Overall** | **118** | **~70%** | Weighted average |

See **[CLAUDE.md](CLAUDE.md)** for detailed migration breakdown.

---

## Active Debt Items

### P0 - Critical (Do This Week)

#### DEBT-001: ViewControllers CoreData Access
- **Priority**: P0
- **Files**: 23 ViewControllers with NSFetchRequest
- **Effort**: 200-300h
- **Description**: Direct CoreData access violates Clean Architecture. ViewControllers should use ViewModels and UseCases.

| File | Issue |
|------|-------|
| `HomeViewController.swift` | NSFetchRequest, NTask entities |
| `FluentUIToDoTableViewController.swift` | NSFetchRequest, NTask, Projects |
| `AddTaskViewController.swift` | Inline `InlineProjectRepository` (obsolete) |
| `HomeViewController+ProjectFiltering.swift` | NSFetchRequest |
| `NewProjectViewController.swift` | NSFetchRequest, inline repo |
| `TaskListViewController.swift` | NSFetchRequest |
| `LGSearchViewController.swift` | NSFetchRequest |
| `LGSearchViewModel.swift` | NSFetchRequest in ViewModel |
| `SettingsPageViewController.swift` | NSFetchRequest |
| Delegates (4 files) | NSFetchRequest |

**Note**: Inline repositories are obsolete—State/Presentation folders ARE in Xcode target.

---

### P1 - High (Do This Sprint)

#### DEBT-002: Mappers in Domain Layer
- **Priority**: P1
- **Files**: `TaskMapper.swift`, `ProjectMapper.swift`
- **Location**: `Domain/Mappers/`
- **Effort**: 8-16h
- **Description**: Mappers import CoreData (violates Domain purity). Should be in State layer or accepted as bridge pattern.

#### DEBT-003: Task Model Business Logic
- **Priority**: P1
- **File**: `Domain/Models/Task.swift`
- **Effort**: 16-24h
- **Description**: Business logic in domain model (score, overdue, dueToday computed properties). Should move to UseCases.

#### DEBT-004: UIKit in State DI Container
- **Priority**: P1
- **File**: `State/DI/EnhancedDependencyContainer.swift`
- **Effort**: 4-8h
- **Description**: UIKit imports in DI container for legacy `@objc` configuration. Remove when legacy pattern deprecated.

---

### P2 - Medium (Backlog)

#### DEBT-005: Habit Builder UI Missing
- **Priority**: P2
- **File**: `UseCases/Task/TaskHabitBuilderUseCase.swift` (691 lines, no UI)
- **Effort**: 40-60h
- **Description**: Use case exists but no UI to create/use habits.

#### DEBT-006: Task Time Tracking Incomplete
- **Priority**: P2
- **File**: `UseCases/Task/TaskTimeTrackingUseCase.swift`
- **Effort**: 20-30h
- **Description**: Domain model exists but no UI for time tracking.

#### DEBT-007: Priority Optimizer Not Automated
- **Priority**: P2
- **File**: `UseCases/Task/TaskPriorityOptimizerUseCase.swift`
- **Effort**: 16-24h
- **Description**: Auto-prioritization logic exists but not integrated into UI.

#### DEBT-008: Collaboration Features No Backend
- **Priority**: P2
- **Files**: `TaskCollaborationUseCase.swift` (831 lines), `TaskCollaborationSyncService.swift`
- **Effort**: 120-200h
- **Description**: Collaboration features defined but no backend implementation.

---

### P3 - Low (Consider)

#### DEBT-009: Unit Test Coverage
- **Priority**: P3
- **Coverage**: ~10% (Domain/UseCases only)
- **Effort**: 60-100h
- **Description**: Increase test coverage to 80% target. Add ViewModels and UseCases tests.

#### DEBT-010: UI/E2E Tests
- **Priority**: P3
- **Coverage**: <5%
- **Effort**: 40-60h
- **Description**: Add critical user flow tests (task creation, completion, project management).

---

## Legacy Migration Notes

**Inline Repositories**: Some ViewControllers contain inline repository classes (e.g., `InlineProjectRepository` in `HomeViewController+ProjectFiltering.swift`). These are obsolete—State/Presentation folders ARE confirmed in Xcode target. These should be removed and replaced with proper dependency injection.

**ViewModel Integration**: `HomeViewModel`, `AddTaskViewModel`, `ProjectManagementViewModel` are wired via `PresentationDependencyContainer`. ViewControllers should use these instead of direct CoreData access.

---

## Recommendations

1. **Focus on P0 first**: Migrate ViewControllers to use ViewModels and UseCases
2. **Gradual migration**: Tackle one ViewController at a time
3. **Test as you go**: Add unit tests for migrated UseCases
4. **Delete obsolete code**: Remove inline repositories once migration confirmed

---

**See Also**: [CLAUDE.md](CLAUDE.md) for architecture rules and patterns.
