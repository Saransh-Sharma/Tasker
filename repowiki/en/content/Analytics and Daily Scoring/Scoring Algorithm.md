# Scoring Algorithm

<cite>
**Referenced Files in This Document**   
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Scoring System Overview](#scoring-system-overview)
3. [Core Scoring Logic](#core-scoring-logic)
4. [Method Overloads and Data Layer Integration](#method-overloads-and-data-layer-integration)
5. [Business Logic and Gamification Strategy](#business-logic-and-gamification-strategy)
6. [Edge Case Handling](#edge-case-handling)
7. [Performance Considerations](#performance-considerations)
8. [Usage Examples](#usage-examples)
9. [Conclusion](#conclusion)

## Introduction
The TaskScoringService implements a gamified scoring system designed to motivate users by assigning point values to completed tasks based on their priority levels. This document details the algorithm's implementation, its integration across data layers, and its role in enhancing user engagement through positive reinforcement.

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L1-L10)

## Scoring System Overview
The scoring system follows a priority-based point allocation model where tasks are assigned points according to their importance:

- **High Priority**: 7 points
- **Medium Priority**: 4 points
- **Low Priority**: 2 points
- **Very Low Priority**: 1 point

This tiered approach incentivizes users to complete higher-priority tasks while still rewarding completion of lower-priority items. The system is implemented in the TaskScoringService class, which serves as the central authority for all scoring operations within the application.

```mermaid
flowchart TD
A[Task Completion] --> B{Determine Priority}
B --> |High| C[Assign 7 Points]
B --> |Medium| D[Assign 4 Points]
B --> |Low| E[Assign 2 Points]
B --> |Very Low| F[Assign 1 Point]
B --> |Unknown| G[Default to 1 Point]
C --> H[Add to Total Score]
D --> H
E --> H
F --> H
G --> H
```

**Diagram sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L15-L28)

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L15-L28)

## Core Scoring Logic
The primary scoring logic is implemented in the `calculateScore(for:)` method that accepts a `TaskPriority` enum parameter. This method uses a switch statement to map each priority level to its corresponding point value. The implementation ensures deterministic scoring behavior and provides a foundation for consistent calculations throughout the application.

The scoring values were selected to create meaningful differentiation between priority levels while maintaining a reasonable point range that supports long-term user engagement. High-priority tasks are worth nearly double medium-priority tasks (7 vs 4), creating a strong incentive to focus on important items.

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L15-L28)

## Method Overloads and Data Layer Integration
The TaskScoringService provides multiple overloads of the `calculateScore(for:)` method to support different data types across the application's architecture:

```mermaid
classDiagram
class TaskScoringService {
+calculateScore(for : TaskPriority) Int
+calculateScore(for : TaskData) Int
+calculateScore(for : NTask) Int
+calculateTotalScore(for : using : completion : ) void
}
class TaskData {
+priority : TaskPriority
}
class NTask {
+taskPriority : Int32
+priority : TaskPriority
}
TaskScoringService --> TaskPriority : "uses"
TaskScoringService --> TaskData : "reads"
TaskScoringService --> NTask : "reads"
TaskData --> TaskPriority : "contains"
NTask --> TaskPriority : "computed property"
```

**Diagram sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L30-L55)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L15-L25)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L45-L55)

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L30-L55)
- [TaskData.swift](file://To%20Do%20List/Models/TaskData.swift#L15-L25)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L45-L55)

The overloads enable seamless scoring across different layers:
- `calculateScore(for: TaskPriority)` - Core logic implementation
- `calculateScore(for: TaskData)` - Presentation layer integration
- `calculateScore(for: NTask)` - Core Data persistence layer integration

Each overload ultimately delegates to the primary `TaskPriority`-based implementation, ensuring consistency and eliminating duplication.

## Business Logic and Gamification Strategy
The scoring algorithm plays a crucial role in the application's gamification strategy by providing immediate positive feedback for task completion. The point system transforms routine task management into a rewarding experience that encourages consistent usage.

The business logic behind the point allocation reflects a balance between motivation and realism:
- High-priority tasks receive substantial rewards to encourage focus on important items
- Medium-priority tasks offer moderate rewards for regular productivity
- Low and very low priority tasks still provide points to maintain engagement

For example, completing three high-priority tasks yields 21 points (3 × 7), creating a tangible sense of accomplishment. This cumulative scoring system supports longer-term goals and streak tracking, which are key elements of user retention in productivity applications.

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L15-L28)
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L75-L105)

## Edge Case Handling
The scoring system includes robust edge case handling to ensure reliability and future-proofing:

1. **Unknown Enum Values**: The `@unknown default` clause in the switch statement returns 1 point for any unrecognized priority value, preventing crashes and maintaining application stability.

2. **Data Conversion Safety**: When converting from Core Data's `Int32` representation to the `TaskPriority` enum, the code uses nil-coalescing operators (`??`) to provide safe defaults (.low or .medium) when raw values don't match defined cases.

3. **Empty Task Lists**: The `calculateTotalScore` method gracefully handles cases where no tasks exist for a given date, returning 0 rather than failing.

```mermaid
flowchart LR
A[Input Priority] --> B{Valid Case?}
B --> |Yes| C[Return Defined Points]
B --> |No| D[Return Default 1 Point]
D --> E[Prevent Crashes]
D --> F[Future-Proofing]
```

**Diagram sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L25-L28)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L45-L50)

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L25-L28)
- [NTask+Extensions.swift](file://To%20Do%20List/NTask+Extensions.swift#L45-L50)

## Performance Considerations
The scoring calculations are implemented synchronously, which is appropriate given their lightweight nature. The `calculateScore(for:)` methods perform simple lookups without database access or complex computations, making them suitable for immediate execution on the main thread when needed.

However, aggregate calculations like `calculateTotalScore` and `calculateStreak` use asynchronous completion handlers to prevent UI blocking when processing potentially large numbers of tasks. The streak calculation employs a synchronous dispatch group pattern that limits processing to a maximum of 30 days, preventing excessive resource consumption.

The current implementation in `NTask+CoreDataProperties.swift` contains a redundant `getTaskScore` method with different scoring values (7, 4, 3, 2, 1), which creates inconsistency with the primary scoring service. This discrepancy should be addressed to ensure a single source of truth for scoring logic.

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L57-L105)
- [NTask+CoreDataProperties.swift](file://To%20Do%20List/NTask+CoreDataProperties.swift#L45-L53)

## Usage Examples
The scoring system can be utilized in various contexts throughout the application:

- **Daily Score Calculation**: Summing points for all tasks completed on a specific date
- **User Progress Tracking**: Displaying cumulative scores over time
- **Achievement Systems**: Unlocking badges based on score milestones
- **Leaderboards**: Comparing scores between users in shared task environments

The primary method usage follows this pattern:
```swift
let score = TaskScoringService.shared.calculateScore(for: .high) // Returns 7
```

Aggregate operations use asynchronous patterns:
```swift
TaskScoringService.shared.calculateTotalScore(for: Date(), using: repository) { total in
    // Update UI with total score
}
```

**Section sources**
- [TaskScoringService.swift](file://To%20Do%20List/Services/TaskScoringService.swift#L15-L55)

## Conclusion
The TaskScoringService implements a robust, priority-based scoring algorithm that serves as the foundation for the application's gamification strategy. By providing consistent point values across different data layers and handling edge cases gracefully, the system enhances user motivation while maintaining technical reliability. The clear separation of concerns and use of Swift's type safety features make the implementation maintainable and extensible for future enhancements.