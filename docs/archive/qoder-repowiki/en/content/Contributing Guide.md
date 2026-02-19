# Contributing Guide

<cite>
**Referenced Files in This Document**   
- [README.md](file://README.md) - *Updated in recent commit*
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift) - *Added in recent commit*
- [TaskScoringService.swift](file://To Do List/Services/TaskScoringService.swift) - *Updated in recent commit*
- [DependencyContainer.swift](file://To Do List/DependencyContainer.swift) - *Updated in recent commit*
- [TaskData.swift](file://To Do List/Models/TaskData.swift)
- [NTask+CoreDataProperties.swift](file://To Do List/Models/NTask+CoreDataProperties.swift)
- [To_Do_ListTests.swift](file://To Do ListTests/To_Do_ListTests.swift)
- [To_Do_ListUITests.swift](file://To_Do_ListUITests/To_Do_ListUITests.swift)
</cite>

## Update Summary
**Changes Made**   
- Updated Development Environment Setup to reflect recent architectural changes
- Revised Contribution Workflow to align with new repository pattern and dependency injection
- Updated Testing Guidelines to reflect modern architecture
- Added new section on Clean Architecture Migration
- Removed outdated references to singleton patterns
- Updated section sources with accurate file references and change annotations

## Table of Contents
1. [Development Environment Setup](#development-environment-setup)
2. [Coding Standards](#coding-standards)
3. [Contribution Workflow](#contribution-workflow)
4. [Testing Guidelines](#testing-guidelines)
5. [Bug Reporting](#bug-reporting)
6. [License and Agreements](#license-and-agreements)
7. [Clean Architecture Migration](#clean-architecture-migration)

## Development Environment Setup

To set up the Tasker development environment, follow these steps:

1. Clone the repository from GitHub
2. Navigate to the project root directory
3. Install dependencies using CocoaPods by running `pod install`
4. Open the workspace file `Tasker.xcworkspace` in Xcode
5. Build and run the application on a simulator or physical device

The project relies on several third-party dependencies managed through CocoaPods, including DGCharts for data visualization, Material Design Components for UI elements, FluentUI for modern interface components, and BEMCheckBox for interactive task completion. CloudKit integration requires a valid Apple Developer account for full synchronization testing.

**Section sources**
- [README.md](file://README.md#L16-L20) - *Updated in recent commit*

## Coding Standards

### Swift Style Conventions
The Tasker project follows Swift API Design Guidelines with the following specific conventions:
- Use of `lowerCamelCase` for variables, functions, and properties
- Use of `UpperCamelCase` for types, protocols, and enums
- Clear, descriptive naming that prioritizes readability
- Proper use of Swift access control levels (`private`, `internal`, `public`)
- Consistent spacing and indentation (4 spaces, no tabs)

### Naming Patterns
Core Data entities follow the `NTask` naming convention where the prefix "N" distinguishes managed object classes. This pattern applies to all Core Data models in the project. Custom classes and structs use descriptive names that reflect their purpose, such as `TaskScoringService` for business logic components and `TaskData` for presentation models.

Enum cases use lowercase names when declared with raw values, following the pattern seen in `TaskPriority` and `TaskType` enums. These enums provide type-safe access to priority levels (P0-P3) and task categories (morning, evening, upcoming, inbox).

### Comment Documentation Practices
All public types and functions must be documented using Swift documentation comments. Use triple forward slashes (`///`) for single-line comments and `/** */` for multi-line documentation. Include parameter descriptions, return value explanations, and any thrown errors. Internal and private functions should have brief comments explaining complex logic or non-obvious implementations.

**Section sources**
- [README.md](file://README.md#L1000-L1200) - *Updated in recent commit*
- [NTask+CoreDataProperties.swift](file://To Do List/Models/NTask+CoreDataProperties.swift)
- [TaskScoringService.swift](file://To Do List/Services/TaskScoringService.swift) - *Updated in recent commit*

## Contribution Workflow

### Forking and Branching
1. Fork the Tasker repository on GitHub
2. Create a feature branch from the main branch using the naming convention `feature/descriptive-name` for new features or `bugfix/descriptive-name` for bug fixes
3. Implement your changes following the project's coding standards

### Pull Requests
Submit pull requests to the main repository with the following requirements:
- Clear, descriptive title following conventional commits format
- Detailed description explaining the change, motivation, and implementation approach
- Reference to any related issues using GitHub syntax (#issue-number)
- All tests passing in the CI pipeline
- Code review approval from at least one maintainer

### Code Review Expectations
Contributions will be evaluated based on:
- Code quality and adherence to project standards
- Test coverage for new functionality
- Performance implications of changes
- Compatibility with existing architecture
- Documentation completeness
- Proper handling of edge cases and error conditions

The project has completed migration from a legacy MVC architecture with singleton managers to a clean architecture using protocol-oriented programming and dependency injection. New code should follow the modern pattern using repositories and dependency injection rather than relying on singleton instances. The `TaskRepository` protocol and `DependencyContainer` should be used for all new feature development.

**Section sources**
- [README.md](file://README.md#L800-L900) - *Updated in recent commit*
- [DependencyContainer.swift](file://To Do List/DependencyContainer.swift) - *Updated in recent commit*
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift) - *Added in recent commit*

## Testing Guidelines

### Unit Testing with XCTest
Write unit tests using Apple's XCTest framework to validate business logic, data transformations, and utility functions. Tests should be deterministic, isolated, and fast. Focus on testing the public interface of components while mocking dependencies where appropriate.

The repository contains two test targets:
- `To_Do_ListTests`: Unit and integration tests for model, service, and repository layers
- `To_Do_ListUITests`: UI tests for critical user flows and screen interactions

### Test Organization
Place new unit tests in the `To_Do_ListTests` target following the same directory structure as the production code. For example, tests for classes in the `Services` directory should go in a corresponding `Services` folder within the test target. Name test files by appending `Tests` to the original filename (e.g., `TaskScoringServiceTests.swift`).

### Test Coverage Priorities
When adding new functionality, prioritize tests for:
- Core business logic in services like `TaskScoringService`
- Data transformation and validation rules
- Repository implementations and protocol conformance
- Complex algorithms and calculations
- Edge cases and error handling scenarios

The project now has comprehensive test coverage for the repository layer and business logic components, with a focus on contract testing for protocol implementations and integration testing for data flow.

**Section sources**
- [README.md](file://README.md#L1500-L1600) - *Updated in recent commit*
- [To_Do_ListTests.swift](file://To Do ListTests/To_Do_ListTests.swift)
- [To_Do_ListUITests.swift](file://To_Do_ListUITests/To_Do_ListUITests.swift)

## Bug Reporting

Report bugs by creating issues in the GitHub repository with the following information:
- Clear, descriptive title summarizing the problem
- Detailed steps to reproduce the issue
- Expected behavior vs. actual behavior
- Device and iOS version information
- Screenshots or screen recordings when applicable
- Console logs and error messages
- Any relevant configuration settings

For crashes, include the full stack trace and, if possible, the state of relevant variables. When reporting performance issues, provide timing measurements and device conditions (battery level, background processes, etc.). For UI-related bugs, specify the screen size and orientation.

The application uses Firebase Crashlytics for production crash reporting, but development bugs should be reported through GitHub issues for tracking and discussion.

**Section sources**
- [README.md](file://README.md#L1600-L1617) - *Updated in recent commit*
- [LoggingService.swift](file://To Do List/Utilities/LoggingService.swift)

## License and Agreements

Tasker is released under the MIT License, which allows for free use, modification, and distribution with proper attribution. The full license text is available in the repository.

Contributors must agree to the terms of the MIT License when submitting code to the project. There is no formal Contributor License Agreement (CLA) required at this time. By contributing to the project, you assert that you have the right to license your contributions under the project's license terms.

The project includes third-party dependencies with their own licensing terms, documented in the `Podfile` and managed through CocoaPods. Contributors should be aware that adding new dependencies may introduce additional licensing requirements that must be compatible with the project's MIT License.

**Section sources**
- [README.md](file://README.md#L1610-L1617) - *Updated in recent commit*

## Clean Architecture Migration

The Tasker project has completed a comprehensive migration from a legacy MVC architecture with singleton managers to a clean architecture based on the Repository pattern and dependency injection. This migration was completed in six phases:

1. **Domain Models & Interfaces**: Created pure Swift domain models and interface protocols
2. **State Management Layer**: Implemented repository pattern with proper abstraction
3. **Use Cases / Business Layer**: Extracted business logic into stateless use case classes
4. **Presentation Layer Decoupling**: Implemented ViewModels and removed business logic from ViewControllers
5. **Singleton Removal**: Completely removed `TaskManager` and `ProjectManager` singletons
6. **Testing Infrastructure**: Implemented comprehensive testing at architectural boundaries

All new contributions should follow the clean architecture pattern using protocol-based dependencies, dependency injection via `DependencyContainer`, and the repository pattern for data access. The legacy singleton patterns should not be used in new code.

**Section sources**
- [README.md](file://README.md#L2000-L2500) - *Updated in recent commit*
- [DependencyContainer.swift](file://To Do List/DependencyContainer.swift) - *Updated in recent commit*
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift) - *Added in recent commit*