# Project Overview

<cite>
**Referenced Files in This Document**   
- [README.md](file://README.md)
- [NTask+CoreDataClass.swift](file://To Do List/NTask+CoreDataClass.swift)
- [NTask+CoreDataProperties.swift](file://To Do List/NTask+CoreDataProperties.swift)
- [NTask+Extensions.swift](file://To Do List/NTask+Extensions.swift)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift)
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift)
- [AddTaskViewController.swift](file://To Do List/ViewControllers/AddTaskViewController.swift)
- [AppDelegate.swift](file://To Do List/AppDelegate.swift)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Target Audience](#target-audience)
3. [Core Features](#core-features)
4. [Technical Stack and Architecture](#technical-stack-and-architecture)
5. [Key Differentiators](#key-differentiators)
6. [User Workflows](#user-workflows)
7. [Codebase Terminology](#codebase-terminology)
8. [Further Exploration](#further-exploration)

## Introduction

Tasker is a time-based task management application designed exclusively for iOS users seeking a structured, gamified approach to productivity. Unlike conventional to-do list apps, Tasker emphasizes temporal organization by categorizing tasks into **Morning** and **Evening** segments, encouraging users to plan their day with intentionality. The app leverages **iCloud synchronization** via Core Data and CloudKit to ensure seamless task continuity across all Apple devices. A unique **daily scoring system** transforms task completion into a rewarding experience, providing users with quantifiable feedback on their productivity. This combination of time segmentation, cloud sync, project grouping, and performance analytics makes Tasker a powerful tool for individuals aiming to build consistent, high-impact daily routines.

**Section sources**
- [README.md](file://README.md#L1-L50)

## Target Audience

Tasker is tailored for **productivity-focused iOS users** who are looking for more than a simple checklist. The ideal user is someone who values structure, seeks to optimize their daily workflow, and is motivated by measurable progress. This includes professionals managing complex workloads, students balancing academic and personal tasks, and anyone striving to develop disciplined habits. The app's scoring and analytics features particularly appeal to users who respond well to gamification and data-driven insights into their behavior.

## Core Features

Tasker offers a comprehensive suite of features designed to enhance personal organization and productivity:

- **Task Creation & Management**: Users can create tasks with a title, description, priority level (P0 to P3), and assign them to a specific project. Tasks are automatically categorized as Morning, Evening, or Upcoming based on their due date and time.
- **Time-Based Categorization**: The app's core innovation is its division of tasks into **Morning** and **Evening** categories, promoting a balanced approach to daily planning and preventing task overload.
- **iCloud Synchronization**: Built on **Core Data with CloudKit**, Tasker ensures that all tasks, projects, and completion status are automatically synced across an iCloud user's iPhone, iPad, and Mac.
- **Project Grouping**: Users can create custom projects to organize related tasks. The app features a default "Inbox" project for uncategorized items, and tasks can be easily filtered and viewed by project.
- **Daily Scoring & Analytics**: Each completed task contributes to a daily score based on its priority (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts). The `HomeViewController` displays interactive charts powered by the DGCharts framework, providing visual insights into completion trends, streaks, and overall productivity over time.

**Section sources**
- [README.md](file://README.md#L51-L100)
- [NTask+CoreDataProperties.swift](file://To Do List/NTask+CoreDataProperties.swift#L1-L20)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L1-L50)

## Technical Stack and Architecture

Tasker is built using **Swift** and the **UIKit** framework, ensuring a native iOS experience. The data persistence layer is powered by **Core Data**, which is seamlessly integrated with **CloudKit** for automatic iCloud synchronization. For analytics and data visualization, the app uses the **DGCharts** framework to render interactive bar and line charts.

The application follows a **Model-View-Controller (MVC)** architectural pattern, which is being progressively refactored to incorporate the **Repository pattern** for improved testability and separation of concerns. The primary data model is the `NTask` entity, a Core Data-managed object that stores all task attributes. To decouple the UI from the data layer, a `TaskData` struct is used as a presentation model.

The data access logic is abstracted through a `TaskRepository` protocol. The concrete implementation, `CoreDataTaskRepository`, handles all interactions with the Core Data stack, including fetching, creating, and updating `NTask` objects. This repository is injected into view controllers, moving away from the legacy singleton `TaskManager` pattern and paving the way for a cleaner, more maintainable codebase.

**Section sources**
- [README.md](file://README.md#L101-L200)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L30)
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift#L1-L20)
- [NTask+CoreDataClass.swift](file://To Do List/NTask+CoreDataClass.swift#L1-L17)

## Key Differentiators

Tasker distinguishes itself from standard to-do apps through two primary mechanisms: **time segmentation** and **scoring mechanics**. While most apps simply list tasks, Tasker forces a temporal decision by requiring users to place tasks in a morning or evening context. This encourages mindful planning and helps prevent the common pitfall of an overly ambitious, unstructured list.

The **scoring system** adds a layer of gamification that transforms task completion from a mundane chore into a rewarding activity. By assigning higher point values to higher-priority tasks, the app incentivizes users to tackle the most important work first. The daily score, visible on the home screen, provides a clear, immediate sense of accomplishment, while the historical analytics foster long-term motivation by showing progress over days and weeks.

## User Workflows

### Adding a Task
A user navigates to the task creation screen (typically via a floating action button). They input a task name, select a priority, choose a project, and specify whether it is a morning or evening task. Upon saving, the task is immediately stored in the local Core Data database by the `CoreDataTaskRepository` and synced to iCloud. The `HomeViewController` then updates to display the new task in the appropriate list.

### Viewing Daily Score
When the user opens the app, the `HomeViewController` queries the `TaskRepository` for all tasks completed today. The `TaskScoringService` calculates the total score by summing the points for each completed task based on its priority. This score is prominently displayed, and the accompanying chart is updated to reflect the user's performance, potentially showing a streak of consecutive days with completed tasks.

**Section sources**
- [AddTaskViewController.swift](file://To Do List/ViewControllers/AddTaskViewController.swift#L1-L40)
- [HomeViewController.swift](file://To Do List/ViewControllers/HomeViewController.swift#L100-L150)

## Codebase Terminology

The Tasker codebase uses specific terminology that reflects its architecture and domain:
- **`NTask`**: The Core Data entity that represents a single task. This is the fundamental data model object.
- **`TaskRepository`**: A protocol that defines the interface for all task data operations (fetch, create, update, delete), promoting loose coupling.
- **`CoreDataTaskRepository`**: The concrete class that implements the `TaskRepository` protocol, handling all interactions with the Core Data persistent store.

**Section sources**
- [NTask+CoreDataClass.swift](file://To Do List/NTask+CoreDataClass.swift#L1-L17)
- [TaskRepository.swift](file://To Do List/Repositories/TaskRepository.swift#L1-L20)
- [CoreDataTaskRepository.swift](file://To Do List/Repositories/CoreDataTaskRepository.swift#L1-L15)

## Further Exploration

For a deeper understanding of the Tasker application, explore the following sections of the documentation:
- **Architecture Overview**: A detailed diagram of the MVC and Repository pattern integration.
- **Data Model Reference**: A complete Entity-Relationship diagram for the `NTask` and `Projects` entities.
- **Use-Case Sequence Flows**: Step-by-step diagrams of core user interactions, such as task creation and completion.
- **Testing Strategy Roadmap**: An outline of the planned unit and integration tests for the new repository layer.