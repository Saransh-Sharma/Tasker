//
//  HomeUITestWorkspaceSeeder.swift
//  LifeBoard
//

import Foundation

@MainActor
final class HomeUITestWorkspaceSeeder {
    private static var hasSeededUITestEstablishedWorkspace = false
    private static var hasSeededUITestSearchWorkspace = false
    private static var hasSeededUITestRescueWorkspace = false
    private static var hasSeededUITestReflectPlanWorkspace = false
    private static var hasSeededUITestFocusWorkspace = false
    private static var hasSeededUITestHabitBoardWorkspace = false
    private static var hasSeededUITestQuietTrackingWorkspace = false
    private static var hasSeededUITestFullTimelineWorkspace = false

    func seedUITestEstablishedWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestEstablishedWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestEstablishedWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Career",
                    color: "#293A18",
                    icon: "briefcase.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Ship one thing",
                        description: "UI test workspace seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateTaskDefinitionRequest(
                        title: "Draft update",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Send recap",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        title: "Plan next step",
                        details: "UI test established-workspace seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: DatePreset.today.resolvedDueDate(),
                        createdAt: Date()
                    )
                ]

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_onboarding_workspace_seed_failed",
                    message: "Failed to seed established workspace for onboarding UI test",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestSearchWorkspaceIfNeeded(
        presentationDependencyContainer: PresentationDependencyContainer?,
        viewModel: HomeViewModel?,
        completion: @escaping () -> Void
    ) {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_SEARCH_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestSearchWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestSearchWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition
                let completeTaskDefinition = presentationDependencyContainer.coordinator.completeTaskDefinition
                let createHabit = presentationDependencyContainer.coordinator.createHabit
                let resolveHabitOccurrence = presentationDependencyContainer.coordinator.resolveHabitOccurrence
                let calendar = Calendar.current
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Career",
                    color: "#293A18",
                    icon: "briefcase.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Ship one thing",
                        description: "UI test search seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let completedTaskID = UUID(uuidString: "40000000-0000-0000-0000-000000000004") ?? UUID()
                let requests = [
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000001") ?? UUID(),
                        title: "Meeting with Team",
                        details: "UI test search seed",
                        projectID: project.id,
                        projectName: project.name,
                        iconSymbolName: "person.3.fill",
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 10, to: startOfDay),
                        priority: .high,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000002") ?? UUID(),
                        title: "Meeting Prep",
                        details: "UI test search seed",
                        projectID: project.id,
                        projectName: project.name,
                        iconSymbolName: "doc.text.fill",
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .day, value: -1, to: startOfDay),
                        priority: .max,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000003") ?? UUID(),
                        title: "Review Code",
                        details: "UI test search seed",
                        projectID: project.id,
                        projectName: project.name,
                        iconSymbolName: "curlybraces",
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 13, to: startOfDay),
                        priority: .low,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: completedTaskID,
                        title: "Coffee Break",
                        details: "UI test search seed",
                        projectID: project.id,
                        projectName: project.name,
                        iconSymbolName: "cup.and.saucer.fill",
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 15, to: startOfDay),
                        priority: .none,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "40000000-0000-0000-0000-000000000005") ?? UUID(),
                        title: "Sprint Planning",
                        details: "UI test search seed",
                        projectID: project.id,
                        projectName: project.name,
                        iconSymbolName: "calendar.badge.clock",
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .day, value: 1, to: startOfDay),
                        priority: .low,
                        createdAt: now
                    )
                ]

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
                _ = try await completeTaskDefinition.setCompletionAsync(taskID: completedTaskID, to: true)

                let missedHabitID = UUID(uuidString: "40000000-0000-0000-0000-000000000006") ?? UUID()
                let habitCreatedAt = calendar.date(byAdding: .day, value: -5, to: startOfDay) ?? now
                let missedHabit = try await createHabit.executeAsync(
                    request: CreateHabitRequest(
                        id: missedHabitID,
                        title: "Search recovery habit",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "repeat.circle.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily(),
                        createdAt: habitCreatedAt
                    )
                )
                let missedDate = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? now
                try await resolveHabitOccurrence.executeAsync(
                    habitID: missedHabit.id,
                    action: .lapsed,
                    on: missedDate
                )

                viewModel?.invalidateTaskCaches()
            } catch {
                logError(
                    event: "ui_test_search_workspace_seed_failed",
                    message: "Failed to seed search workspace for Search UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestRescueWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, viewModel: HomeViewModel?, completion: @escaping () -> Void) {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldSeedExpandedRescue = arguments.contains("-LIFEBOARD_TEST_SEED_RESCUE_WORKSPACE")
        let shouldSeedCompactRescue = arguments.contains("-LIFEBOARD_TEST_SEED_COMPACT_RESCUE_WORKSPACE")
        let shouldSeedRescueTimeline = arguments.contains("-LIFEBOARD_TEST_SEED_RESCUE_TIMELINE_WORKSPACE")
        let shouldSeedRescueSuite = arguments.contains("-LIFEBOARD_TEST_SEED_OVERDUE_RESCUE_SUITE")
        guard shouldSeedExpandedRescue || shouldSeedCompactRescue || shouldSeedRescueTimeline || shouldSeedRescueSuite else {
            completion()
            return
        }
        guard Self.hasSeededUITestRescueWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestRescueWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition

                let calendar = Calendar.current
                let now = Date()
                let anchorDay = calendar.startOfDay(for: now)
                let includeHiddenRescueRow = shouldSeedExpandedRescue

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Operations",
                    color: "#624A2E",
                    icon: "shippingbox.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Recovery Queue",
                        description: "UI test rescue seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                var requests: [CreateTaskDefinitionRequest]
                var seededRescueTimelineTaskID: UUID?
                if shouldSeedRescueTimeline {
                    let taskID = UUID(uuidString: "20000000-0000-0000-0000-000000000101") ?? UUID()
                    seededRescueTimelineTaskID = taskID
                    let overdueDay = calendar.date(byAdding: .day, value: -15, to: anchorDay) ?? anchorDay
                    let scheduledStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: overdueDay) ?? overdueDay
                    let scheduledEnd = scheduledStart.addingTimeInterval(45 * 60)
                    logDebug(
                        "UI_TEST_RESCUE_TIMELINE seed task_id=\(taskID.uuidString) " +
                        "due=\(scheduledStart) scheduled_start=\(scheduledStart) scheduled_end=\(scheduledEnd) is_all_day=false"
                    )
                    requests = [
                        CreateTaskDefinitionRequest(
                            id: taskID,
                            title: "Rescue timeline quick win",
                            details: "UI test rescue timeline seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: scheduledStart,
                            scheduledStartAt: scheduledStart,
                            scheduledEndAt: scheduledEnd,
                            isAllDay: false,
                            priority: .high,
                            estimatedDuration: 45 * 60,
                            createdAt: now
                        )
                    ]
                } else if shouldSeedRescueSuite {
                    requests = [
                        CreateTaskDefinitionRequest(
                            id: UUID(uuidString: "21000000-0000-0000-0000-000000000001") ?? UUID(),
                            title: "Rescue suite keep first",
                            details: "UI test overdue rescue suite seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -21, to: anchorDay),
                            scheduledStartAt: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: -21, to: anchorDay) ?? anchorDay),
                            scheduledEndAt: calendar.date(bySettingHour: 9, minute: 15, second: 0, of: calendar.date(byAdding: .day, value: -21, to: anchorDay) ?? anchorDay),
                            isAllDay: false,
                            priority: .max,
                            estimatedDuration: 45 * 60,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            id: UUID(uuidString: "21000000-0000-0000-0000-000000000002") ?? UUID(),
                            title: "Rescue suite move later",
                            details: "UI test overdue rescue suite seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -18, to: anchorDay),
                            priority: .low,
                            estimatedDuration: 20 * 60,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            id: UUID(uuidString: "21000000-0000-0000-0000-000000000003") ?? UUID(),
                            title: "Rescue suite edit me",
                            details: "UI test overdue rescue suite seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -16, to: anchorDay),
                            priority: .high,
                            estimatedDuration: 30 * 60,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            id: UUID(uuidString: "21000000-0000-0000-0000-000000000004") ?? UUID(),
                            title: "Rescue suite delete guarded",
                            details: "This task has details so delete requires confirmation.",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -15, to: anchorDay),
                            priority: .high,
                            createdAt: now
                        )
                    ]
                } else {
                    requests = [
                        CreateTaskDefinitionRequest(
                            title: "Rescue oldest",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -20, to: anchorDay),
                            priority: .max,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            title: "Rescue middle",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -18, to: anchorDay),
                            priority: .high,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            title: "Rescue newest",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -16, to: anchorDay),
                            priority: .low,
                            createdAt: now
                        ),
                        CreateTaskDefinitionRequest(
                            title: "Today focus seed",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .hour, value: 10, to: anchorDay),
                            priority: .high,
                            createdAt: now
                        )
                    ]
                }

                if includeHiddenRescueRow && shouldSeedRescueTimeline == false {
                    requests.insert(
                        CreateTaskDefinitionRequest(
                            title: "Rescue hidden",
                            details: "UI test rescue seed",
                            projectID: project.id,
                            projectName: project.name,
                            lifeAreaID: lifeArea.id,
                            dueDate: calendar.date(byAdding: .day, value: -15, to: anchorDay),
                            priority: .high,
                            createdAt: now
                        ),
                        at: 3
                    )
                }

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
                viewModel?.invalidateTaskCaches()
                if let seededRescueTimelineTaskID {
                    logDebug("UI_TEST_RESCUE_TIMELINE seeded task_id=\(seededRescueTimelineTaskID.uuidString)")
                }
            } catch {
                logError(
                    event: "ui_test_rescue_workspace_seed_failed",
                    message: "Failed to seed rescue workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestReflectPlanWorkspaceIfNeeded(
        presentationDependencyContainer: PresentationDependencyContainer?,
        viewModel: HomeViewModel?,
        completion: @escaping () -> Void
    ) {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_REFLECT_PLAN_SUITE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestReflectPlanWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestReflectPlanWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition
                let updateTaskDefinition = presentationDependencyContainer.coordinator.updateTaskDefinition
                let createHabit = presentationDependencyContainer.coordinator.createHabit
                let resolveHabitOccurrence = presentationDependencyContainer.coordinator.resolveHabitOccurrence
                let reflectionStore = presentationDependencyContainer.coordinator.dailyReflectionStore

                let calendar = Calendar.current
                let now = Date()
                let today = calendar.startOfDay(for: now)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                let completedAt = calendar.date(bySettingHour: 17, minute: 20, second: 0, of: yesterday) ?? yesterday

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Reflection Systems",
                    color: "#6A4E8A",
                    icon: "sparkles"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Reflect Plan Suite",
                        description: "UI test reflect and plan seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let completedTaskID = UUID(uuidString: "22000000-0000-0000-0000-000000000001") ?? UUID()
                let completedSecondID = UUID(uuidString: "22000000-0000-0000-0000-000000000002") ?? UUID()
                let taskRequests = [
                    CreateTaskDefinitionRequest(
                        id: completedTaskID,
                        title: "Reflect shipped proposal",
                        details: "Completed yesterday for reflect and plan UI tests",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: yesterday),
                        priority: .max,
                        estimatedDuration: 60 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: completedSecondID,
                        title: "Reflect closed inbox",
                        details: "Second completed yesterday seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: yesterday),
                        priority: .high,
                        estimatedDuration: 30 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "22000000-0000-0000-0000-000000000003") ?? UUID(),
                        title: "Reflect carryover contract",
                        details: "Open carryover from yesterday",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: yesterday),
                        priority: .high,
                        estimatedDuration: 45 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "22000000-0000-0000-0000-000000000004") ?? UUID(),
                        title: "Plan API review",
                        details: "Top task candidate for today",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today),
                        priority: .max,
                        estimatedDuration: 90 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "22000000-0000-0000-0000-000000000005") ?? UUID(),
                        title: "Plan customer reply",
                        details: "Planning candidate",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today),
                        priority: .high,
                        estimatedDuration: 25 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "22000000-0000-0000-0000-000000000006") ?? UUID(),
                        title: "Plan 15 min cleanup",
                        details: "Quick stabilizer candidate",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today),
                        priority: .low,
                        estimatedDuration: 15 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: UUID(uuidString: "22000000-0000-0000-0000-000000000007") ?? UUID(),
                        title: "Plan swap candidate",
                        details: "Swap picker replacement candidate",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today),
                        priority: .low,
                        estimatedDuration: 20 * 60,
                        createdAt: now
                    )
                ]

                for request in taskRequests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }

                _ = try await updateTaskDefinitionAsync(
                    updateTaskDefinition,
                    request: UpdateTaskDefinitionRequest(
                        id: completedTaskID,
                        isComplete: true,
                        dateCompleted: completedAt
                    )
                )
                _ = try await updateTaskDefinitionAsync(
                    updateTaskDefinition,
                    request: UpdateTaskDefinitionRequest(
                        id: completedSecondID,
                        isComplete: true,
                        dateCompleted: completedAt.addingTimeInterval(30 * 60)
                    )
                )

                let habitID = UUID(uuidString: "22000000-0000-0000-0000-000000000101") ?? UUID()
                let habit = try await createHabit.executeAsync(
                    request: CreateHabitRequest(
                        id: habitID,
                        title: "Protect shutdown ritual",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "moon.stars.fill", categoryKey: "reflection"),
                        colorHex: HabitColorFamily.purple.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily(),
                        createdAt: calendar.date(byAdding: .day, value: -8, to: today) ?? now
                    )
                )
                try await resolveHabitOccurrence.executeAsync(
                    habitID: habit.id,
                    action: .lapsed,
                    on: yesterday
                )

                if ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_REFLECT_PLAN_COMPLETED") {
                    let payload = ReflectionPayload(
                        reflectionDate: yesterday,
                        planningDate: today,
                        mode: .catchUpYesterday,
                        mood: .good,
                        energy: .okay,
                        frictionTags: [.tooMuchPlanned],
                        note: "Seeded completed reflection"
                    )
                    _ = try reflectionStore.markCompleted(on: yesterday, completedAt: now, payload: payload)
                }

                viewModel?.invalidateTaskCaches()
            } catch {
                logError(
                    event: "ui_test_reflect_plan_workspace_seed_failed",
                    message: "Failed to seed Reflect and Plan workspace for UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestFocusWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, completion: @escaping () -> Void) {
        let arguments = ProcessInfo.processInfo.arguments
        let shouldSeedFocusWorkspace = arguments.contains("-LIFEBOARD_TEST_SEED_FOCUS_WORKSPACE")
        let shouldSeedFocusNowSuite = arguments.contains("-LIFEBOARD_TEST_SEED_FOCUS_NOW_SUITE")
        guard shouldSeedFocusWorkspace || shouldSeedFocusNowSuite else {
            completion()
            return
        }
        guard Self.hasSeededUITestFocusWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestFocusWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Focus Systems",
                    color: "#5A3121",
                    icon: "scope"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Today Focus",
                        description: "UI test focus seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let anchor = DatePreset.today.resolvedDueDate() ?? Date()
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: anchor)
                let focusRowID = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
                let focusAID = UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID()
                let focusBID = UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID()
                let focusCID = UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID()
                let focusDID = UUID(uuidString: "10000000-0000-0000-0000-000000000005") ?? UUID()
                let requests = [
                    CreateTaskDefinitionRequest(
                        id: focusRowID,
                        title: "Focus Row Opens Detail",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 8, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 900,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusAID,
                        title: "Pinned Focus A",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 9, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 900,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusBID,
                        title: "Pinned Focus B",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 10, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 1_200,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusCID,
                        title: "Pinned Focus C",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 11, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 2_400,
                        createdAt: Date()
                    ),
                    CreateTaskDefinitionRequest(
                        id: focusDID,
                        title: "Pinned Focus D",
                        details: "UI test focus seed",
                        projectID: project.id,
                        projectName: project.name,
                        lifeAreaID: lifeArea.id,
                        dueDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay),
                        priority: .high,
                        estimatedDuration: 2_400,
                        createdAt: Date()
                    )
                ]

                for request in requests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }

                let habitRequests = [
                    CreateHabitRequest(
                        title: "Reset desk before shutdown",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "sparkles", categoryKey: "focus"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No doomscrolling after dinner",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in habitRequests {
                    _ = try await createHabit.executeAsync(request: request)
                }

                let pinnedIDs = shouldSeedFocusNowSuite
                    ? [focusRowID.uuidString, focusAID.uuidString, focusBID.uuidString]
                    : [focusRowID.uuidString]
                UserDefaults.standard.set(pinnedIDs, forKey: "home.focus.pinnedTaskIDs.v2")
                UserDefaults.standard.removeObject(forKey: "home.eva.recentShuffleTaskIDs.v1")
            } catch {
                logError(
                    event: "ui_test_focus_workspace_seed_failed",
                    message: "Failed to seed focus workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    private func updateTaskDefinitionAsync(
        _ useCase: UpdateTaskDefinitionUseCase,
        request: UpdateTaskDefinitionRequest
    ) async throws -> TaskDefinition {
        try await withCheckedThrowingContinuation { continuation in
            useCase.execute(request: request) { result in
                continuation.resume(with: result)
            }
        }
    }

    func seedUITestHabitBoardWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_HABIT_BOARD_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestHabitBoardWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestHabitBoardWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Health",
                    color: "#4E9A2F",
                    icon: "heart.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Daily Rhythm",
                        description: "UI test habit board seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateHabitRequest(
                        title: "Drink water after breakfast",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
                        colorHex: HabitColorFamily.green.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "Choose tomorrow's top priority before bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "moon.stars.fill", categoryKey: "planning"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No phone in bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "sleep"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in requests {
                    _ = try await createHabit.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_habit_board_seed_failed",
                    message: "Failed to seed habits for Habit Board UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestQuietTrackingWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, completion: @escaping () -> Void) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-LIFEBOARD_TEST_SEED_QUIET_TRACKING_WORKSPACE")
            || arguments.contains("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestQuietTrackingWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestQuietTrackingWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let lifeArea = try await manageLifeAreas.createAsync(
                    name: "Recovery",
                    color: "#D26A5C",
                    icon: "bandage.fill"
                )
                let project = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Quiet Tracking Seed",
                        description: "UI test quiet tracking seed",
                        lifeAreaID: lifeArea.id
                    )
                )

                let requests = [
                    CreateHabitRequest(
                        title: "No phone in bed",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "sleep"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    ),
                    CreateHabitRequest(
                        title: "No doomscrolling after dinner",
                        lifeAreaID: lifeArea.id,
                        projectID: project.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily()
                    )
                ]

                for request in requests {
                    _ = try await createHabit.executeAsync(request: request)
                }
            } catch {
                logError(
                    event: "ui_test_quiet_tracking_workspace_seed_failed",
                    message: "Failed to seed quiet tracking workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }

    func seedUITestFullTimelineWorkspaceIfNeeded(presentationDependencyContainer: PresentationDependencyContainer?, viewModel: HomeViewModel?, completion: @escaping () -> Void) {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE") else {
            completion()
            return
        }
        guard Self.hasSeededUITestFullTimelineWorkspace == false else {
            completion()
            return
        }
        guard let presentationDependencyContainer else {
            completion()
            return
        }

        Self.hasSeededUITestFullTimelineWorkspace = true

        Task { @MainActor in
            do {
                let manageLifeAreas = presentationDependencyContainer.coordinator.manageLifeAreas
                let manageProjects = presentationDependencyContainer.coordinator.manageProjects
                let createTaskDefinition = presentationDependencyContainer.coordinator.createTaskDefinition
                let completeTaskDefinition = presentationDependencyContainer.coordinator.completeTaskDefinition
                let createHabit = presentationDependencyContainer.coordinator.createHabit

                let workArea = try await manageLifeAreas.createAsync(
                    name: "Timeline Work",
                    color: "#2F5B8A",
                    icon: "briefcase.fill"
                )
                let healthArea = try await manageLifeAreas.createAsync(
                    name: "Timeline Health",
                    color: "#3B8A5D",
                    icon: "heart.fill"
                )
                let recoveryArea = try await manageLifeAreas.createAsync(
                    name: "Timeline Recovery",
                    color: "#C46A54",
                    icon: "moon.zzz.fill"
                )

                let launchProject = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Timeline Launch",
                        description: "Full timeline UI test seed",
                        lifeAreaID: workArea.id
                    )
                )
                let opsProject = try await manageProjects.createProjectAsync(
                    request: CreateProjectRequest(
                        name: "Timeline Ops",
                        description: "Full timeline UI test support seed",
                        lifeAreaID: workArea.id
                    )
                )

                let calendar = Calendar.current
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)
                let designReviewStart = calendar.date(byAdding: .hour, value: 10, to: startOfDay) ?? now
                let overlapStart = calendar.date(byAdding: .minute, value: 10, to: designReviewStart) ?? designReviewStart
                let overlapEnd = calendar.date(byAdding: .minute, value: 45, to: overlapStart) ?? overlapStart
                let deepWorkStart = calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? now
                let deepWorkEnd = calendar.date(byAdding: .minute, value: 50, to: deepWorkStart) ?? deepWorkStart
                let completedStart = calendar.date(byAdding: .hour, value: 8, to: startOfDay) ?? now
                let completedEnd = calendar.date(byAdding: .minute, value: 25, to: completedStart) ?? completedStart
                let overdueDate = calendar.date(byAdding: .day, value: -2, to: startOfDay) ?? now

                let overlapTaskID = UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID()
                let deepWorkTaskID = UUID(uuidString: "20000000-0000-0000-0000-000000000002") ?? UUID()
                let inboxTaskID = UUID(uuidString: "20000000-0000-0000-0000-000000000003") ?? UUID()
                let overdueTaskID = UUID(uuidString: "20000000-0000-0000-0000-000000000004") ?? UUID()
                let completedTaskID = UUID(uuidString: "20000000-0000-0000-0000-000000000005") ?? UUID()

                let taskRequests = [
                    CreateTaskDefinitionRequest(
                        id: overlapTaskID,
                        title: "Timeline overlap task",
                        details: "Overlaps Design Review for conflict-block UI coverage",
                        projectID: launchProject.id,
                        projectName: launchProject.name,
                        iconSymbolName: "rectangle.stack.fill",
                        lifeAreaID: workArea.id,
                        dueDate: overlapStart,
                        scheduledStartAt: overlapStart,
                        scheduledEndAt: overlapEnd,
                        priority: .max,
                        type: .morning,
                        context: .computer,
                        estimatedDuration: overlapEnd.timeIntervalSince(overlapStart),
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: deepWorkTaskID,
                        title: "Timeline deep work block",
                        details: "Standalone scheduled task for timeline detail coverage",
                        projectID: launchProject.id,
                        projectName: launchProject.name,
                        iconSymbolName: "scope",
                        lifeAreaID: workArea.id,
                        dueDate: deepWorkStart,
                        scheduledStartAt: deepWorkStart,
                        scheduledEndAt: deepWorkEnd,
                        priority: .high,
                        type: .morning,
                        context: .computer,
                        estimatedDuration: deepWorkEnd.timeIntervalSince(deepWorkStart),
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: inboxTaskID,
                        title: "Timeline inbox capture",
                        details: "Unscheduled inbox task for fill-open-time coverage",
                        projectID: ProjectConstants.inboxProjectID,
                        projectName: ProjectConstants.inboxProjectName,
                        iconSymbolName: "tray.fill",
                        lifeAreaID: workArea.id,
                        dueDate: nil,
                        priority: .low,
                        type: .morning,
                        context: .anywhere,
                        estimatedDuration: 20 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: overdueTaskID,
                        title: "Timeline overdue rescue",
                        details: "Overdue task for critical triage coverage",
                        projectID: opsProject.id,
                        projectName: opsProject.name,
                        iconSymbolName: "exclamationmark.triangle.fill",
                        lifeAreaID: workArea.id,
                        dueDate: overdueDate,
                        priority: .high,
                        type: .morning,
                        context: .office,
                        estimatedDuration: 30 * 60,
                        createdAt: now
                    ),
                    CreateTaskDefinitionRequest(
                        id: completedTaskID,
                        title: "Timeline completed report",
                        details: "Completed timeline task for persistence coverage",
                        projectID: opsProject.id,
                        projectName: opsProject.name,
                        iconSymbolName: "checkmark.seal.fill",
                        lifeAreaID: workArea.id,
                        dueDate: completedStart,
                        scheduledStartAt: completedStart,
                        scheduledEndAt: completedEnd,
                        priority: .low,
                        type: .morning,
                        context: .computer,
                        estimatedDuration: completedEnd.timeIntervalSince(completedStart),
                        createdAt: now
                    )
                ]

                for request in taskRequests {
                    _ = try await createTaskDefinition.executeAsync(request: request)
                }
                _ = try await completeTaskDefinition.setCompletionAsync(taskID: completedTaskID, to: true)

                let habitRequests = [
                    CreateHabitRequest(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001") ?? UUID(),
                        title: "Timeline hydrate",
                        lifeAreaID: healthArea.id,
                        projectID: launchProject.id,
                        kind: .positive,
                        trackingMode: .dailyCheckIn,
                        icon: HabitIconMetadata(symbolName: "drop.fill", categoryKey: "health"),
                        colorHex: HabitColorFamily.green.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily(),
                        createdAt: now
                    ),
                    CreateHabitRequest(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002") ?? UUID(),
                        title: "Timeline no phone in bed",
                        lifeAreaID: recoveryArea.id,
                        projectID: opsProject.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "bed.double.fill", categoryKey: "sleep"),
                        colorHex: HabitColorFamily.coral.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily(),
                        createdAt: now
                    ),
                    CreateHabitRequest(
                        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003") ?? UUID(),
                        title: "Timeline no doomscrolling after dinner",
                        lifeAreaID: recoveryArea.id,
                        projectID: opsProject.id,
                        kind: .negative,
                        trackingMode: .lapseOnly,
                        icon: HabitIconMetadata(symbolName: "moon.zzz.fill", categoryKey: "recovery"),
                        colorHex: HabitColorFamily.blue.canonicalHex,
                        targetConfig: HabitTargetConfig(targetCountPerDay: 1),
                        cadence: .daily(),
                        createdAt: now
                    )
                ]

                for request in habitRequests {
                    _ = try await createHabit.executeAsync(request: request)
                }

                UserDefaults.standard.removeObject(forKey: "home.eva.recentShuffleTaskIDs.v1")
                viewModel?.invalidateTaskCaches()
            } catch {
                logError(
                    event: "ui_test_full_timeline_workspace_seed_failed",
                    message: "Failed to seed full timeline workspace for Home UI tests",
                    fields: ["error": error.localizedDescription]
                )
            }

            completion()
        }
    }
}
