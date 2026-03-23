# Tasker Habits Documentation Hub

Last validated against code on 2026-03-22

This folder is the canonical documentation package for the habits feature.
It covers product behavior, runtime and data-model contracts, risk management, and forward product planning.

## Scope

This package documents habits as a first-class recurring behavior system built on:
- `HabitDefinitionRecord`
- `ScheduleTemplateDefinition` + `ScheduleRuleDefinition`
- `OccurrenceDefinition` + `OccurrenceResolution`
- Home, Library, Detail, analytics, gamification, Eva, and LLM habit projections

This package does not document generic task, project, or reminder behavior except where those systems intersect with habits.

## Source-of-Truth Boundaries

- Product strategy and broad app promise: `README.md`, `PRODUCT_REQUIREMENTS_DOCUMENT.md`
- Habit feature behavior and UX contract: `docs/habits/product-feature.md`
- Habit runtime/data model and engineering contracts: `docs/habits/data-model-and-runtime.md`
- Habit-specific delivery and correctness risks: `docs/habits/risk-register.md`
- Habit-only PM roadmap and release phases: `docs/habits/roadmap.md`
- Generic app-wide architecture references: `docs/architecture/*`

## Primary Source Anchors

- `To Do List/Domain/Models/HabitDefinition.swift`
- `To Do List/Domain/Models/HabitTypes.swift`
- `To Do List/Domain/Interfaces/HabitRuntimeReadRepositoryProtocol.swift`
- `To Do List/UseCases/Habit/HabitRuntimeUseCases.swift`
- `To Do List/State/Repositories/CoreDataHabitRepository.swift`
- `To Do List/State/Repositories/CoreDataHabitRuntimeReadRepository.swift`
- `To Do List/State/Repositories/CoreDataScheduleRepository.swift`
- `To Do List/State/Repositories/CoreDataOccurrenceRepository.swift`
- `To Do List/State/Services/CoreSchedulingEngine.swift`
- `To Do List/Presentation/ViewModels/AddHabitViewModel.swift`
- `To Do List/Presentation/Models/HomeHabitRow.swift`
- `To Do List/View/AddHabitForedropView.swift`
- `To Do List/View/HomeHabitRowView.swift`
- `To Do List/UseCases/Analytics/CalculateAnalyticsUseCase.swift`
- `To Do List/LLM/Models/LLMContextProjectionService.swift`
- `To Do List/LLM/Models/DailyBriefService.swift`

## Reading Order

1. `docs/habits/product-feature.md`
2. `docs/habits/data-model-and-runtime.md`
3. `docs/habits/risk-register.md`
4. `docs/habits/roadmap.md`

## Update Policy

Update this package in the same PR when any of the following change:
- habit domain types, habit schema fields, or occurrence semantics
- habit create/update/pause/archive/resolve/maintenance logic
- habit read projections for Home, Library, analytics, Eva, or LLM context
- habit-specific accessibility, state, or management behavior
- habit risk posture, accepted partials, or roadmap priorities

## Current Truth

Habits are no longer accurately described as a small `ManageHabitsUseCase` CRUD subsystem.
The shipped runtime is a focused habit stack with dedicated use cases, a dedicated read repository, Home projections, analytics snapshots, and AI signal consumers.

