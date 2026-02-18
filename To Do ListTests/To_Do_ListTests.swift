//
//  To_Do_ListTests.swift
//  To Do ListTests
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import XCTest
import CoreData
@testable import To_Do_List

class To_Do_ListTests: XCTestCase {

    func testUpdateTaskUseCaseUpdatesProjectIDAndNameWhenProjectIDProvided() {
        let inbox = Project.createInbox()
        let workProject = Project(id: UUID(), name: "Work")
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox, workProject])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "project update")
        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(projectID: workProject.id)
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.projectID, workProject.id)
                XCTAssertEqual(updated.project, workProject.name)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePreservesExplicitTypeWhenDueDateAlsoChanges() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Task",
            details: nil,
            type: .evening,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let futureDate = Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date()

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let expectation = expectation(description: "type precedence update")
        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(
                type: .morning,
                dueDate: futureDate
            )
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.type, .morning, "Explicit type should win over due-date auto-type")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateTaskUseCasePostsTaskUpdatedNotification() {
        let inbox = Project.createInbox()
        let initialTask = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "Old Name",
            details: nil,
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )

        let taskRepository = MockTaskRepository(seed: initialTask)
        let projectRepository = MockProjectRepository(projects: [inbox])
        let useCase = UpdateTaskUseCase(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            notificationService: nil
        )

        let notificationExpectation = expectation(description: "TaskUpdated notification")
        let token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TaskUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            notificationExpectation.fulfill()
        }

        useCase.execute(
            taskId: initialTask.id,
            request: UpdateTaskRequest(name: "New Name")
        ) { _ in }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(taskRepository.currentTask.name, "New Name")
        NotificationCenter.default.removeObserver(token)
    }

    func testPerformanceExample() {
        self.measure {
            _ = UUID().uuidString
        }
    }
}

final class ArchitectureBoundaryTests: XCTestCase {
    func testViewLayerDoesNotUseSingletonDependencyContainers() throws {
        let directories = [
            "To Do List/View",
            "To Do List/Views",
            "To Do List/ViewControllers"
        ]
        let forbiddenPatterns = [
            "PresentationDependencyContainer.shared",
            "EnhancedDependencyContainer.shared"
        ]

        for directory in directories {
            let files = try listSwiftFiles(in: directory)
            for fileURL in files {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                for pattern in forbiddenPatterns {
                    XCTAssertFalse(
                        content.contains(pattern),
                        "View-layer file must not reference singleton container `\(pattern)`: \(fileURL.path)"
                    )
                }
            }
        }
    }

    func testTargetedViewsDoNotAccessEnhancedDependencyContainerSingleton() throws {
        let files = [
            "To Do List/Views/Cards/ChartCard.swift",
            "To Do List/Views/Cards/RadarChartCard.swift",
            "To Do List/Views/ProjectSelectionSheet.swift",
            "To Do List/ViewControllers/Delegates/AddTaskCalendarExtention.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared"),
                "View file must not access EnhancedDependencyContainer.shared directly: \(relativePath)"
            )
        }
    }

    func testTargetedControllersDoNotFallbackToEnhancedCoordinatorSingleton() throws {
        let files = [
            "To Do List/ViewControllers/HomeViewController.swift",
            "To Do List/ViewControllers/NewProjectViewController.swift",
            "To Do List/ViewControllers/LGSearchViewController.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("EnhancedDependencyContainer.shared.useCaseCoordinator"),
                "Controller must not fallback to global coordinator singleton: \(relativePath)"
            )
        }
    }

    func testLegacyStoryboardRouteUsesUnreachableIdentifier() throws {
        let storyboard = try loadWorkspaceFile("To Do List/Storyboards/Base.lproj/Main.storyboard")
        XCTAssertFalse(storyboard.contains("storyboardIdentifier=\"addTask\""))
        XCTAssertTrue(storyboard.contains("storyboardIdentifier=\"addTaskLegacy_unreachable\""))
    }

    func testProjectAndRescheduleUseCasesDoNotPostNotificationCenterDirectly() throws {
        let files = [
            "To Do List/UseCases/Project/ManageProjectsUseCase.swift",
            "To Do List/UseCases/Task/RescheduleTaskUseCase.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "Use case must emit via TaskNotificationDispatcher: \(relativePath)"
            )
        }
    }

    func testChartAndProjectSelectionViewsDoNotPublishDirectShowProjectManagementNotifications() throws {
        let files = [
            "To Do List/Views/Cards/ChartCardsScrollView.swift",
            "To Do List/Views/ProjectSelectionSheet.swift"
        ]

        for relativePath in files {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                content.contains("ShowProjectManagement"),
                "View should use injected callback, not broadcast notification: \(relativePath)"
            )
            XCTAssertFalse(
                content.contains("NotificationCenter.default.post"),
                "View should not post direct notifications for project management routing: \(relativePath)"
            )
        }
    }

    func testViewsDirectoryDoesNotDeclarePresentationViewModelTypes() throws {
        let forbiddenDeclarations = [
            "class ChartCardViewModel",
            "class RadarChartCardViewModel",
            "class ProjectSelectionViewModel"
        ]

        let files = try listSwiftFiles(in: "To Do List/Views")
        for fileURL in files {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for forbidden in forbiddenDeclarations {
                XCTAssertFalse(
                    content.contains(forbidden),
                    "View files must not declare presentation view models: \(fileURL.path)"
                )
            }
        }
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let workspaceRoot = workspaceRootURL()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }

    private func listSwiftFiles(in relativeDirectory: String) throws -> [URL] {
        let root = workspaceRootURL().appendingPathComponent(relativeDirectory)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            guard item.pathExtension == "swift" else { continue }
            let values = try item.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(item)
            }
        }
        return files
    }

    private func workspaceRootURL() -> URL {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        return testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
    }
}

final class LaunchResilienceTests: XCTestCase {
    func testMakeLaunchRootModeReturnsHomeWhenStateReady() {
        let delegate = AppDelegate()
        let container = NSPersistentCloudKitContainer(
            name: "TaskModelV2",
            managedObjectModel: NSManagedObjectModel()
        )

        let mode = delegate.makeLaunchRootMode(state: .ready(container))
        XCTAssertEqual(mode, .home)
    }

    func testMakeLaunchRootModeReturnsFailureMessageWhenStateFailed() {
        let delegate = AppDelegate()
        let expectedMessage = "bootstrap failed"
        let mode = delegate.makeLaunchRootMode(state: .failed(expectedMessage))

        guard case let .bootstrapFailure(message) = mode else {
            XCTFail("Expected bootstrapFailure mode")
            return
        }
        XCTAssertEqual(message, expectedMessage)
    }

    func testTryInjectDoesNotCrashWhenContainerMayBeUnconfigured() {
        let dependencyContainer = PresentationDependencyContainer.shared
        let injected = dependencyContainer.tryInject(into: UIViewController())
        XCTAssertEqual(injected, dependencyContainer.isConfiguredForRuntime)
    }
}

final class TaskDefinitionLinkHydrationTests: XCTestCase {
    func testFetchHydratesTagAndDependencyLinksFromLinkTables() throws {
        let container = try makeInMemoryV2Container()
        let taskRepository = CoreDataTaskDefinitionRepository(container: container)
        let tagLinkRepository = CoreDataTaskTagLinkRepository(container: container)
        let dependencyRepository = CoreDataTaskDependencyRepository(container: container)

        let taskID = UUID()
        let projectID = UUID()
        let compatibilityTag = UUID()
        let compatibilityDependency = UUID()
        let linkedTag = UUID()
        let linkedDependency = UUID()

        _ = try awaitResult { completion in
            taskRepository.create(
                request: CreateTaskDefinitionRequest(
                    id: taskID,
                    title: "Hydration Candidate",
                    details: "Initial compatibility values",
                    projectID: projectID,
                    projectName: "Inbox",
                    dueDate: nil,
                    tagIDs: [compatibilityTag],
                    dependencies: [
                        TaskDependencyLinkDefinition(
                            taskID: taskID,
                            dependsOnTaskID: compatibilityDependency,
                            kind: .related
                        )
                    ],
                    createdAt: Date()
                ),
                completion: completion
            )
        }

        _ = try awaitResult { completion in
            tagLinkRepository.replaceTagLinks(taskID: taskID, tagIDs: [linkedTag], completion: completion)
        }
        _ = try awaitResult { completion in
            dependencyRepository.replaceDependencies(
                taskID: taskID,
                dependencies: [
                    TaskDependencyLinkDefinition(
                        taskID: taskID,
                        dependsOnTaskID: linkedDependency,
                        kind: .blocks
                    )
                ],
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let task = try XCTUnwrap(fetched)

        XCTAssertEqual(task.tagIDs, [linkedTag], "Read-side tags must hydrate from TaskTagLink rows")
        XCTAssertEqual(task.dependencies.count, 1)
        XCTAssertEqual(task.dependencies.first?.dependsOnTaskID, linkedDependency)
        XCTAssertEqual(task.dependencies.first?.kind, .blocks)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskDefinitionLinkHydrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class DeterministicFetchTests: XCTestCase {
    func testTaskDefinitionFetchByIDUsesStableSelectionOrderWithDuplicateRows() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                taskID: taskID,
                projectID: projectID,
                title: "Canonical Alpha",
                createdAt: now
            )
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                taskID: taskID,
                projectID: projectID,
                title: "Duplicate Beta",
                createdAt: now.addingTimeInterval(1)
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let first = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        let second = try awaitResult { completion in
            repository.fetchTaskDefinition(id: taskID, completion: completion)
        }

        XCTAssertEqual(first?.title, "Canonical Alpha")
        XCTAssertEqual(second?.title, "Canonical Alpha")
    }

    func testTaskDefinitionFetchAllDoesNotCrashWithoutLegacyCompatibilityAttributes() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskDefinitionRepository(container: container)
        let context = container.viewContext
        let taskID = UUID()
        let projectID = UUID()
        let now = Date()

        var seedError: Error?
        context.performAndWait {
            seedTaskDefinitionRow(
                in: context,
                rowID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                taskID: taskID,
                projectID: projectID,
                title: "No Legacy Compatibility Keys",
                createdAt: now
            )
            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let fetched = try awaitResult { completion in
            repository.fetchAll(query: nil, completion: completion)
        }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, taskID)
        XCTAssertEqual(fetched.first?.tagIDs, [])
        XCTAssertEqual(fetched.first?.dependencies, [])
    }

    func testTaskDefinitionSchemaContractIncludesLifeAreaIDAndExcludesLegacyTagsAttribute() throws {
        let container = try makeInMemoryV2Container()
        guard let taskDefinition = container.managedObjectModel.entitiesByName["TaskDefinition"] else {
            XCTFail("TaskDefinition entity missing from model")
            return
        }

        XCTAssertNotNil(taskDefinition.attributesByName["taskID"])
        XCTAssertNotNil(taskDefinition.attributesByName["projectID"])
        XCTAssertNotNil(taskDefinition.attributesByName["lifeAreaID"])
        XCTAssertNil(taskDefinition.attributesByName["tags"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["tagLinks"])
        XCTAssertNotNil(taskDefinition.relationshipsByName["dependencies"])
    }

    func testExternalContainerFetchUsesDeterministicFirstRowOrdering() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let context = container.viewContext
        let provider = "apple_reminders"
        let projectID = UUID()

        var seedError: Error?
        context.performAndWait {
            let first = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            first.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, forKey: "id")
            first.setValue(provider, forKey: "provider")
            first.setValue(projectID, forKey: "projectID")
            first.setValue("first-container", forKey: "externalContainerID")
            first.setValue(true, forKey: "syncEnabled")
            first.setValue(Date(), forKey: "createdAt")

            let second = NSEntityDescription.insertNewObject(forEntityName: "ExternalContainerMap", into: context)
            second.setValue(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, forKey: "id")
            second.setValue(provider, forKey: "provider")
            second.setValue(projectID, forKey: "projectID")
            second.setValue("second-container", forKey: "externalContainerID")
            second.setValue(true, forKey: "syncEnabled")
            second.setValue(Date(), forKey: "createdAt")

            do {
                try context.save()
            } catch {
                seedError = error
            }
        }
        if let seedError {
            throw seedError
        }

        let firstRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }
        let secondRead = try awaitResult { completion in
            repository.fetchContainerMapping(provider: provider, projectID: projectID, completion: completion)
        }

        XCTAssertEqual(firstRead?.externalContainerID, "first-container")
        XCTAssertEqual(secondRead?.externalContainerID, "first-container")
    }

    private func seedTaskDefinitionRow(
        in context: NSManagedObjectContext,
        rowID: UUID,
        taskID: UUID,
        projectID: UUID,
        title: String,
        createdAt: Date
    ) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(rowID, forKey: "id")
        object.setValue(taskID, forKey: "taskID")
        object.setValue(projectID, forKey: "projectID")
        object.setValue(title, forKey: "title")
        object.setValue(title, forKey: "name")
        object.setValue(ProjectConstants.inboxProjectName, forKey: "project")
        object.setValue(Int32(TaskPriority.low.rawValue), forKey: "priority")
        object.setValue(Int32(TaskPriority.low.rawValue), forKey: "taskPriority")
        object.setValue(Int32(TaskType.morning.rawValue), forKey: "taskType")
        object.setValue(false, forKey: "isComplete")
        object.setValue(createdAt, forKey: "dateAdded")
        object.setValue(false, forKey: "isEveningTask")
        object.setValue("pending", forKey: "status")
        object.setValue(nil, forKey: "lifeAreaID")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(createdAt, forKey: "updatedAt")
        object.setValue(Int32(1), forKey: "version")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "DeterministicFetchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

private final class MockTaskRepository: TaskRepositoryProtocol {
    private var storedTask: Task
    private let lock = NSLock()

    var currentTask: Task { readStoredTask() }

    init(seed: Task) {
        self.storedTask = seed
    }

    private func readStoredTask() -> Task {
        lock.lock()
        defer { lock.unlock() }
        return storedTask
    }

    private func replaceStoredTask(with task: Task) {
        lock.lock()
        storedTask = task
        lock.unlock()
    }

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.isComplete ? [task] : []))
    }

    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        let task = readStoredTask()
        completion(.success(task.type == type ? [task] : []))
    }

    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        let task = readStoredTask()
        DispatchQueue.main.async {
            completion(.success(task.id == id ? task : nil))
        }
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }

    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        replaceStoredTask(with: task)
        DispatchQueue.main.async {
            completion(.success(task))
        }
    }

    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = true
        task.dateCompleted = Date()
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.isComplete = false
        task.dateCompleted = nil
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        var task = readStoredTask()
        task.dueDate = date
        replaceStoredTask(with: task)
        completion(.success(task))
    }

    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success(tasks))
    }

    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([readStoredTask()]))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    private let projectsByID: [UUID: Project]

    init(projects: [Project]) {
        self.projectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projectsByID[id]))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        let match = projectsByID.values.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        completion(.success(match))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(Array(projectsByID.values)))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(Project.createInbox()))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        if var project = projectsByID[id] {
            project.name = newName
            completion(.success(project))
        } else {
            completion(.failure(NSError(domain: "MockProjectRepository", code: 404)))
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        completion(.success([]))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }
}

final class OccurrenceIdentityTests: XCTestCase {
    func testGeneratedOccurrenceKeyContainsTemplateScheduledDateAndSourceID() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date()
        let start = Calendar.current.startOfDay(for: now)

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: start,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let generated = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: start,
                sourceFilter: nil,
                completion: completion
            )
        }

        XCTAssertEqual(generated.count, 1)
        let keyParts = generated[0].occurrenceKey.split(separator: "|").map(String.init)
        XCTAssertEqual(keyParts.count, 3)
        XCTAssertEqual(keyParts[0], templateID.uuidString)
        XCTAssertEqual(keyParts[2], sourceID.uuidString)

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: start,
                windowEnd: start,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Deterministic keying should prevent duplicate generation")
    }

    func testResolveDoesNotMutateOccurrenceKey() throws {
        let now = Date()
        let occurrence = OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "template|2026-01-01T09:00:00Z|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: now,
            dueAt: now,
            state: .pending,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: now,
            updatedAt: now
        )

        let scheduleRepository = InMemoryScheduleRepository()
        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [occurrence]
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        _ = try awaitResult { completion in
            engine.resolveOccurrence(
                id: occurrence.id,
                resolution: .completed,
                actor: .user,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(
                start: now.addingTimeInterval(-60),
                end: now.addingTimeInterval(60),
                completion: completion
            )
        }

        XCTAssertEqual(fetched.first?.occurrenceKey, occurrence.occurrenceKey)
    }
}

final class OccurrenceMaintenanceTests: XCTestCase {
    func testMaintenanceMarksStalePendingAsMissedAndPurgesResolvedIntoTombstones() throws {
        let now = Date()
        let stalePending = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -31, to: now) ?? now,
            state: .pending
        )
        let resolvedOld = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -91, to: now) ?? now,
            state: .completed
        )
        let recentCompleted = makeOccurrence(
            scheduledAt: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now,
            state: .completed
        )

        let occurrenceRepository = InMemoryOccurrenceRepository()
        occurrenceRepository.occurrences = [stalePending, resolvedOld, recentCompleted]
        let tombstoneRepository = InMemoryTombstoneRepository()

        let useCase = MaintainOccurrencesUseCase(
            occurrenceRepository: occurrenceRepository,
            tombstoneRepository: tombstoneRepository
        )

        _ = try awaitResult { completion in
            useCase.execute(completion: completion)
        }

        let missedResolution = occurrenceRepository.resolutions.first {
            $0.occurrenceID == stalePending.id && $0.resolutionType == .missed
        }
        XCTAssertNotNil(missedResolution)

        XCTAssertTrue(occurrenceRepository.deletedOccurrenceIDs.contains(resolvedOld.id))
        XCTAssertFalse(occurrenceRepository.occurrences.contains(where: { $0.id == resolvedOld.id }))
        XCTAssertTrue(occurrenceRepository.occurrences.contains(where: { $0.id == recentCompleted.id }))
        XCTAssertTrue(tombstoneRepository.tombstones.contains(where: { $0.entityID == resolvedOld.id }))
    }

    private func makeOccurrence(scheduledAt: Date, state: OccurrenceState) -> OccurrenceDefinition {
        OccurrenceDefinition(
            id: UUID(),
            occurrenceKey: "\(UUID().uuidString)|\(scheduledAt.timeIntervalSince1970)|\(UUID().uuidString)",
            scheduleTemplateID: UUID(),
            sourceType: .task,
            sourceID: UUID(),
            scheduledAt: scheduledAt,
            dueAt: scheduledAt,
            state: state,
            isGenerated: true,
            generationWindow: "rolling",
            createdAt: scheduledAt,
            updatedAt: scheduledAt
        )
    }
}

final class TombstoneRetentionTests: XCTestCase {
    func testExpiredTombstonesArePurged() throws {
        let now = Date()
        let expired = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now.addingTimeInterval(-10_000),
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(-100)
        )
        let retained = TombstoneDefinition(
            id: UUID(),
            entityType: "Occurrence",
            entityID: UUID(),
            deletedAt: now,
            deletedBy: "system",
            purgeAfter: now.addingTimeInterval(10_000)
        )

        let repository = InMemoryTombstoneRepository()
        repository.tombstones = [expired, retained]
        let useCase = PurgeExpiredTombstonesUseCase(tombstoneRepository: repository)

        _ = try awaitResult { completion in
            useCase.execute(referenceDate: now, completion: completion)
        }

        XCTAssertTrue(repository.deletedIDs.contains(expired.id))
        XCTAssertFalse(repository.deletedIDs.contains(retained.id))
        XCTAssertTrue(repository.tombstones.contains(where: { $0.id == retained.id }))
    }
}

final class V2RepositoryInvariantTests: XCTestCase {
    func testTaskTagLinkUniquenessRejectsDuplicateTaskTagPairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagA, tagB, tagA],
                completion: completion
            )
        }

        let savedTagIDs = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(savedTagIDs), Set([tagA, tagB]))
        XCTAssertEqual(savedTagIDs.count, 2)
    }

    func testExternalMapUpsertsStayDeterministicAcrossCompositeKeys() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)

        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "reminder-1"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }

        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)
        XCTAssertEqual(secondContainerMap.externalContainerID, "container-b")

        let firstItemMap = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let secondItemMap = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-1",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        XCTAssertEqual(firstItemMap.id, secondItemMap.id)

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "V2RepositoryInvariantTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class TaskTagLinkUniquenessTests: XCTestCase {
    func testDuplicateTaskTagLinksCollapseToUniquePairs() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTaskTagLinkRepository(container: container)
        let taskID = UUID()
        let tagA = UUID()
        let tagB = UUID()

        _ = try awaitResult { completion in
            repository.replaceTagLinks(
                taskID: taskID,
                tagIDs: [tagA, tagB, tagA, tagB, tagA],
                completion: completion
            )
        }

        let stored = try awaitResult { completion in
            repository.fetchTagIDs(taskID: taskID, completion: completion)
        }

        XCTAssertEqual(Set(stored), Set([tagA, tagB]))
        XCTAssertEqual(stored.count, 2)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "TaskTagLinkUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ExternalMapUniquenessTests: XCTestCase {
    func testCompositeKeyUpsertsResolveToSingleCanonicalMap() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let projectID = UUID()
        let localEntityID = UUID()
        let externalItemID = "external-map-\(UUID().uuidString)"

        let firstContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-a",
                    syncEnabled: true,
                    lastSyncAt: nil,
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        let secondContainerMap = try awaitResult { completion in
            repository.upsertContainerMapping(provider: provider, projectID: projectID, mutate: { existing in
                ExternalContainerMapDefinition(
                    id: existing?.id ?? UUID(),
                    provider: provider,
                    projectID: projectID,
                    externalContainerID: "container-b",
                    syncEnabled: true,
                    lastSyncAt: Date(),
                    createdAt: existing?.createdAt ?? Date()
                )
            }, completion: completion)
        }
        XCTAssertEqual(firstContainerMap.id, secondContainerMap.id)

        _ = try awaitResult { completion in
            repository.upsertItemMappingByLocalKey(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: nil,
                        lastSeenExternalModAt: nil,
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }
        _ = try awaitResult { completion in
            repository.upsertItemMappingByExternalKey(
                provider: provider,
                externalItemID: externalItemID,
                mutate: { existing in
                    ExternalItemMapDefinition(
                        id: existing?.id ?? UUID(),
                        provider: provider,
                        localEntityType: "task",
                        localEntityID: localEntityID,
                        externalItemID: externalItemID,
                        externalPersistentID: "persisted-42",
                        lastSeenExternalModAt: Date(),
                        externalPayloadData: nil,
                        createdAt: existing?.createdAt ?? Date()
                    )
                },
                completion: completion
            )
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ExternalMapUniquenessTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class ScheduleExceptionRebuildTests: XCTestCase {
    func testSkipExceptionDeletesTargetOccurrenceWithoutMassSkippingFutureRows() throws {
        let templateID = UUID()
        let sourceID = UUID()
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let windowEnd = Calendar.current.date(byAdding: .day, value: 2, to: dayStart) ?? dayStart

        let scheduleRepository = InMemoryScheduleRepository()
        scheduleRepository.templates = [
            ScheduleTemplateDefinition(
                id: templateID,
                sourceType: .task,
                sourceID: sourceID,
                timezoneID: "UTC",
                temporalReference: .anchored,
                anchorAt: dayStart,
                windowStart: "09:00",
                windowEnd: "18:00",
                isActive: true,
                createdAt: now,
                updatedAt: now
            )
        ]

        let occurrenceRepository = InMemoryOccurrenceRepository()
        let engine = CoreSchedulingEngine(
            scheduleRepository: scheduleRepository,
            occurrenceRepository: occurrenceRepository
        )

        let initial = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertGreaterThanOrEqual(initial.count, 2, "Expected at least two occurrences in the generation window")
        let sortedInitial = initial.sorted { $0.scheduledAt < $1.scheduledAt }
        let target = try XCTUnwrap(sortedInitial.first)
        let unaffected = try XCTUnwrap(sortedInitial.dropFirst().first)

        _ = try awaitResult { completion in
            engine.applyScheduleException(
                templateID: templateID,
                occurrenceKey: target.occurrenceKey,
                action: .skip,
                completion: completion
            )
        }

        let fetched = try awaitResult { completion in
            occurrenceRepository.fetchInRange(start: dayStart, end: windowEnd, completion: completion)
        }

        let targetRows = fetched.filter { $0.occurrenceKey == target.occurrenceKey }
        XCTAssertTrue(targetRows.isEmpty, "Skipped occurrence should be removed and not recreated")

        let unaffectedRows = fetched.filter { $0.occurrenceKey == unaffected.occurrenceKey }
        XCTAssertEqual(unaffectedRows.count, 1, "Rebuild should preserve unaffected future occurrence identity")
        XCTAssertEqual(unaffectedRows.first?.state, .pending, "Rebuild must not mass-skip future unresolved occurrences")

        let secondPass = try awaitResult { completion in
            engine.generateOccurrences(
                windowStart: dayStart,
                windowEnd: windowEnd,
                sourceFilter: nil,
                completion: completion
            )
        }
        XCTAssertTrue(secondPass.isEmpty, "Exception rebuild should not recreate skipped occurrence with same key")
    }
}

final class ConcurrencyRaceTests: XCTestCase {
    func testConcurrentTagCreatesConvergeToSingleNormalizedRow() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataTagRepository(container: container)
        let candidateNames = ["Work", "work", " WORK ", "WoRk"]
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            let name = candidateNames[index % candidateNames.count]
            repository.create(TagDefinition(id: UUID(), name: name)) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let tags = try awaitResult { completion in
            repository.fetchAll(completion: completion)
        }
        let normalizedMatches = tags.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "work"
        }
        XCTAssertEqual(normalizedMatches.count, 1)
    }

    func testConcurrentExternalMapUpsertsConvergeToSingleMapIdentity() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataExternalSyncRepository(container: container)
        let provider = "apple_reminders"
        let localEntityID = UUID()
        let externalItemID = "race-item-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<24 {
            group.enter()
            if index.isMultiple(of: 2) {
                repository.upsertItemMappingByLocalKey(
                    provider: provider,
                    localEntityType: "task",
                    localEntityID: localEntityID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: nil,
                            lastSeenExternalModAt: nil,
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            } else {
                repository.upsertItemMappingByExternalKey(
                    provider: provider,
                    externalItemID: externalItemID,
                    mutate: { existing in
                        ExternalItemMapDefinition(
                            id: existing?.id ?? UUID(),
                            provider: provider,
                            localEntityType: "task",
                            localEntityID: localEntityID,
                            externalItemID: externalItemID,
                            externalPersistentID: "persist-\(index)",
                            lastSeenExternalModAt: Date(),
                            externalPayloadData: nil,
                            createdAt: existing?.createdAt ?? Date()
                        )
                    },
                    completion: { result in
                        if case .failure(let error) = result {
                            lock.lock()
                            if firstError == nil {
                                firstError = error
                            }
                            lock.unlock()
                        }
                        group.leave()
                    }
                )
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let byLocal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                localEntityType: "task",
                localEntityID: localEntityID,
                completion: completion
            )
        }
        let byExternal = try awaitResult { completion in
            repository.fetchItemMapping(
                provider: provider,
                externalItemID: externalItemID,
                completion: completion
            )
        }

        XCTAssertEqual(byLocal?.id, byExternal?.id)
    }

    func testConcurrentXPEventSavesRespectIdempotencyUnderRace() throws {
        let container = try makeInMemoryV2Container()
        let repository = CoreDataGamificationRepository(container: container)
        let idempotencyKey = "xp-race-\(UUID().uuidString)"
        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?

        for index in 0..<20 {
            group.enter()
            let event = XPEventDefinition(
                id: UUID(),
                occurrenceID: nil,
                taskID: nil,
                delta: 10 + index,
                reason: "race-test",
                idempotencyKey: idempotencyKey,
                createdAt: Date()
            )
            repository.saveXPEvent(event) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        if let firstError {
            throw firstError
        }

        let storedEvents = try awaitResult { completion in
            repository.fetchXPEvents(completion: completion)
        }
        let matches = storedEvents.filter { $0.idempotencyKey == idempotencyKey }
        XCTAssertEqual(matches.count, 1, "Race save should keep one canonical XP event per idempotency key")
    }

    private func makeInMemoryV2Container() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil
        else {
            throw NSError(domain: "ConcurrencyRaceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV2 from test bundles"])
        }

        let container = NSPersistentContainer(name: "TaskModelV2", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container
    }
}

final class TaskDefinitionCreationMetadataTests: XCTestCase {
    func testCreateTaskDefinitionPersistsMetadataAndLinks() throws {
        let taskRepository = MetadataCapturingTaskDefinitionRepository()
        let tagRepository = MetadataCapturingTaskTagLinkRepository()
        let dependencyRepository = MetadataCapturingTaskDependencyRepository()
        let useCase = CreateTaskDefinitionUseCase(
            repository: taskRepository,
            taskTagLinkRepository: tagRepository,
            taskDependencyRepository: dependencyRepository
        )

        let dependencyA = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .blocks)
        let dependencyB = TaskDependencyLinkDefinition(taskID: UUID(), dependsOnTaskID: UUID(), kind: .related)
        let request = CreateTaskDefinitionRequest(
            id: UUID(),
            title: "Plan release #work",
            details: "Finalize and ship",
            projectID: UUID(),
            projectName: "Work",
            lifeAreaID: UUID(),
            sectionID: UUID(),
            dueDate: Date(),
            parentTaskID: UUID(),
            tagIDs: [UUID(), UUID()],
            dependencies: [dependencyA, dependencyB],
            priority: .high,
            type: .morning,
            energy: .high,
            category: .general,
            context: .anywhere,
            isEveningTask: false,
            alertReminderTime: Date(),
            createdAt: Date()
        )

        let createdTask = try awaitResult { completion in
            useCase.execute(request: request, completion: completion)
        }

        XCTAssertEqual(taskRepository.lastCreateRequest?.id, request.id)
        XCTAssertEqual(taskRepository.lastCreateRequest?.lifeAreaID, request.lifeAreaID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.sectionID, request.sectionID)
        XCTAssertEqual(taskRepository.lastCreateRequest?.parentTaskID, request.parentTaskID)
        XCTAssertEqual(createdTask.projectID, request.projectID)
        XCTAssertEqual(createdTask.project, request.projectName)

        XCTAssertEqual(tagRepository.lastTaskID, request.id)
        XCTAssertEqual(Set(tagRepository.lastTagIDs ?? []), Set(request.tagIDs))

        XCTAssertEqual(dependencyRepository.lastTaskID, request.id)
        XCTAssertEqual(dependencyRepository.lastDependencies?.count, 2)
        XCTAssertEqual(Set(dependencyRepository.lastDependencies?.map(\.kind) ?? []), Set([.blocks, .related]))
    }
}

private final class InMemoryScheduleRepository: ScheduleRepositoryProtocol {
    var templates: [ScheduleTemplateDefinition] = []
    var rulesByTemplateID: [UUID: [ScheduleRuleDefinition]] = [:]
    var exceptionsByTemplateID: [UUID: [ScheduleExceptionDefinition]] = [:]

    func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        completion(.success(templates))
    }

    func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success(rulesByTemplateID[templateID] ?? []))
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        templates.removeAll { $0.id == template.id }
        templates.append(template)
        completion(.success(template))
    }

    func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        completion(.success(exceptionsByTemplateID[templateID] ?? []))
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        var current = exceptionsByTemplateID[exception.scheduleTemplateID] ?? []
        current.append(exception)
        exceptionsByTemplateID[exception.scheduleTemplateID] = current
        completion(.success(exception))
    }
}

private final class MetadataCapturingTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    var lastCreateRequest: CreateTaskDefinitionRequest?
    var byID: [UUID: TaskDefinition] = [:]

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        lastCreateRequest = request
        let task = request.toTaskDefinition(projectName: request.projectName)
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "MetadataCapturingTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.name = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if let dueDate = request.dueDate { current.dueDate = dueDate }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    var lastTaskID: UUID?
    var lastTagIDs: [UUID]?

    func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastTagIDs ?? []) : []))
    }

    func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        lastTaskID = taskID
        lastTagIDs = tagIDs
        completion(.success(()))
    }
}

private final class MetadataCapturingTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    var lastTaskID: UUID?
    var lastDependencies: [TaskDependencyLinkDefinition]?

    func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        completion(.success(lastTaskID == taskID ? (lastDependencies ?? []) : []))
    }

    func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        lastTaskID = taskID
        lastDependencies = dependencies
        completion(.success(()))
    }
}

private final class InMemoryOccurrenceRepository: OccurrenceRepositoryProtocol {
    var occurrences: [OccurrenceDefinition] = []
    var resolutions: [OccurrenceResolutionDefinition] = []
    var deletedOccurrenceIDs: [UUID] = []

    func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success(occurrences.filter { $0.scheduledAt >= start && $0.scheduledAt <= end }))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        for occurrence in occurrences {
            if let index = self.occurrences.firstIndex(where: { $0.id == occurrence.id }) {
                self.occurrences[index] = occurrence
            } else {
                self.occurrences.append(occurrence)
            }
        }
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        resolutions.append(resolution)
        if let index = occurrences.firstIndex(where: { $0.id == resolution.occurrenceID }) {
            switch resolution.resolutionType {
            case .completed:
                occurrences[index].state = .completed
            case .skipped, .deferred:
                occurrences[index].state = .skipped
            case .missed:
                occurrences[index].state = .missed
            }
            occurrences[index].updatedAt = resolution.resolvedAt
        }
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedOccurrenceIDs.append(contentsOf: ids)
        occurrences.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

private final class InMemoryTombstoneRepository: TombstoneRepositoryProtocol {
    var tombstones: [TombstoneDefinition] = []
    var deletedIDs: [UUID] = []

    func create(_ tombstone: TombstoneDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        tombstones.append(tombstone)
        completion(.success(()))
    }

    func fetchExpired(before date: Date, completion: @escaping (Result<[TombstoneDefinition], Error>) -> Void) {
        completion(.success(tombstones.filter { $0.purgeAfter <= date }))
    }

    func delete(ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        deletedIDs.append(contentsOf: ids)
        tombstones.removeAll { ids.contains($0.id) }
        completion(.success(()))
    }
}

private extension XCTestCase {
    func awaitResult<T>(
        timeout: TimeInterval = 2.0,
        _ execute: (@escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let expectation = expectation(description: "awaitResult")
        var captured: Result<T, Error>?
        execute { result in
            captured = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: timeout)
        return try XCTUnwrap(captured).get()
    }
}
