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
    private static let legacySingletonRegex = try! NSRegularExpression(
        pattern: "(^|[^A-Za-z0-9_])DependencyContainer\\.shared\\b"
    )

    private static let legacyScreenRegex = try! NSRegularExpression(
        pattern: "\\bNAddTaskScreen\\b"
    )

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

    func testMainStoryboardDoesNotContainLegacyAddTaskScene() throws {
        let storyboard = try loadWorkspaceFile("To Do List/Storyboards/Base.lproj/Main.storyboard")
        XCTAssertFalse(storyboard.contains("storyboardIdentifier=\"addTask\""))
        XCTAssertFalse(storyboard.contains("addTaskLegacy_unreachable"))
        XCTAssertFalse(storyboard.contains("customClass=\"NAddTaskScreen\""))
    }

    func testProjectBuildGraphExcludesLegacyAddTaskRuntimeSources() throws {
        let projectFile = try loadWorkspaceFile("Tasker.xcodeproj/project.pbxproj")
        XCTAssertFalse(projectFile.contains("/* NAddTaskScreen.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* DependencyContainer.swift in Sources */"))
        XCTAssertFalse(projectFile.contains("/* AddTaskLegacyStubs.swift in Sources */"))
    }

    func testPrimaryRuntimeFilesDoNotReferenceLegacyDependencyContainerSingleton() throws {
        let runtimeFiles = [
            "To Do List/AppDelegate.swift",
            "To Do List/SceneDelegate.swift",
            "To Do List/Presentation/DI/PresentationDependencyContainer.swift",
            "To Do List/State/DI/EnhancedDependencyContainer.swift",
            "To Do List/UseCases/Coordinator/UseCaseCoordinator.swift"
        ]

        for relativePath in runtimeFiles {
            let content = try loadWorkspaceFile(relativePath)
            XCTAssertFalse(
                Self.matches(Self.legacySingletonRegex, in: content),
                "Primary runtime file must not reference legacy DependencyContainer singleton: \(relativePath)"
            )
            XCTAssertFalse(
                Self.matches(Self.legacyScreenRegex, in: content),
                "Primary runtime file must not reference legacy NAddTaskScreen route: \(relativePath)"
            )
        }
    }

    func testLegacySingletonRegexDoesNotFalseMatchV2Singletons() {
        XCTAssertTrue(Self.matches(Self.legacySingletonRegex, in: "DependencyContainer.shared.inject(into: vc)"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "PresentationDependencyContainer.shared.configureFromStateLayer()"))
        XCTAssertFalse(Self.matches(Self.legacySingletonRegex, in: "EnhancedDependencyContainer.shared.configure(with: container)"))
        XCTAssertTrue(Self.matches(Self.legacyScreenRegex, in: "NAddTaskScreen()"))
    }

    func testLegacyGuardrailValidationScriptExistsAndIsExecutable() {
        let scriptURL = workspaceRootURL().appendingPathComponent("scripts/validate_legacy_runtime_guardrails.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: scriptURL.path))
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

    private static func matches(_ regex: NSRegularExpression, in content: String) -> Bool {
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.firstMatch(in: content, range: range) != nil
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

final class OccurrenceKeyCodecTests: XCTestCase {
    func testCanonicalRoundTrip() {
        let templateID = UUID()
        let sourceID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_705_000_000)
        let encoded = OccurrenceKeyCodec.encode(
            scheduleTemplateID: templateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
        let parsed = OccurrenceKeyCodec.parse(encoded)
        XCTAssertEqual(parsed?.scheduleTemplateID, templateID)
        XCTAssertEqual(parsed?.sourceID, sourceID)
        XCTAssertEqual(parsed?.scheduledAt.timeIntervalSince1970, scheduledAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(parsed?.isCanonical, true)
    }

    func testLegacyKeyParsesAndCanonicalizesWithFallbackSource() {
        let templateID = UUID()
        let sourceID = UUID()
        let legacy = "\(templateID.uuidString)_2026-01-02T09:30"
        let canonical = OccurrenceKeyCodec.canonicalize(
            legacy,
            fallbackTemplateID: templateID,
            fallbackSourceID: sourceID
        )
        XCTAssertNotNil(canonical)
        XCTAssertTrue(canonical?.contains(sourceID.uuidString) ?? false)
    }

    func testMalformedKeyRejected() {
        XCTAssertNil(OccurrenceKeyCodec.parse("not-a-valid-key"))
        XCTAssertNil(
            OccurrenceKeyCodec.canonicalize(
                "bad-key",
                fallbackTemplateID: UUID(),
                fallbackSourceID: UUID()
            )
        )
    }
}

final class FeatureFlagKillSwitchTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true
    private var originalRemindersBackgroundRefreshEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = V2FeatureFlags.v2Enabled
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        originalRemindersBackgroundRefreshEnabled = V2FeatureFlags.remindersBackgroundRefreshEnabled
    }

    override func tearDown() {
        V2FeatureFlags.v2Enabled = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        V2FeatureFlags.remindersBackgroundRefreshEnabled = originalRemindersBackgroundRefreshEnabled
        super.tearDown()
    }

    func testReconcileExternalRemindersFailsClosedWhenSyncFlagDisabled() {
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.remindersSyncEnabled = false

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: NoopExternalSyncRepository()
        )

        let expectation = expectation(description: "reconcile-disabled")
        useCase.execute { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantApplyFailsClosedWhenApplyFlagDisabled() {
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.assistantApplyEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-apply-disabled")
        useCase.applyConfirmedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testAssistantUndoFailsClosedWhenUndoFlagDisabled() {
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.assistantUndoEnabled = false

        let useCase = AssistantActionPipelineUseCase(
            repository: NoopAssistantActionRepository(),
            taskRepository: NoopTaskDefinitionRepository()
        )
        let expectation = expectation(description: "assistant-undo-disabled")
        useCase.undoAppliedRun(id: UUID()) { result in
            if case .failure = result {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }

    func testBackgroundRefreshFlagCanFailClosed() throws {
        V2FeatureFlags.remindersBackgroundRefreshEnabled = false
        XCTAssertFalse(V2FeatureFlags.remindersBackgroundRefreshEnabled)

        let appDelegateSource = try loadWorkspaceFile("To Do List/AppDelegate.swift")
        XCTAssertTrue(
            appDelegateSource.contains("V2FeatureFlags.remindersBackgroundRefreshEnabled"),
            "AppDelegate must gate reminders refresh with remindersBackgroundRefreshEnabled"
        )
    }

    private func loadWorkspaceFile(_ relativePath: String) throws -> String {
        let testsFilePath = URL(fileURLWithPath: #filePath)
        let workspaceRoot = testsFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let targetURL = workspaceRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: targetURL, encoding: .utf8)
    }
}

private final class NoopAssistantActionRepository: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(nil))
    }
}

private final class NoopTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.success(TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            title: request.title,
            details: request.details,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )))
    }
    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) { completion(.success(task)) }
    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        completion(.failure(NSError(domain: "NoopTaskDefinitionRepository", code: 1)))
    }
    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoopExternalSyncRepository: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class MockTaskRepository: TaskRepositoryProtocol, TaskReadModelRepositoryProtocol {
    private var storedTask: Task
    private let lock = NSLock()

    var currentTask: Task { readStoredTask() }
    private(set) var fetchAllTasksCallCount = 0
    private(set) var readModelFetchCallCount = 0
    private(set) var readModelSearchCallCount = 0

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
        fetchAllTasksCallCount += 1
        completion(.success([readStoredTask()]))
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskSliceResult, Error>) -> Void) {
        readModelFetchCallCount += 1
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let start = query.dueDateStart, let dueDate = task.dueDate, dueDate < start { return false }
            if let end = query.dueDateEnd, let dueDate = task.dueDate, dueDate > end { return false }
            return true
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskSliceResult, Error>) -> Void) {
        readModelSearchCallCount += 1
        let normalized = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = [readStoredTask()].filter { task in
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if normalized.isEmpty { return true }
            let nameMatch = task.name.lowercased().contains(normalized)
            let detailMatch = task.details?.lowercased().contains(normalized) ?? false
            return nameMatch || detailMatch
        }
        let start = min(query.offset, base.count)
        let end = min(start + query.limit, base.count)
        let slice = Array(base[start..<end])
        completion(.success(TaskSliceResult(
            tasks: slice,
            totalCount: base.count,
            limit: query.limit,
            offset: query.offset
        )))
    }

    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        if includeCompleted || task.isComplete == false {
            completion(.success([task.projectID: 1]))
        } else {
            completion(.success([:]))
        }
    }

    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[UUID : Int], Error>) -> Void
    ) {
        let task = readStoredTask()
        guard
            task.isComplete,
            let completedAt = task.dateCompleted,
            completedAt >= startDate,
            completedAt <= endDate
        else {
            completion(.success([:]))
            return
        }
        completion(.success([task.projectID: task.priority.scorePoints]))
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

final class ReconcileExternalRemindersConflictTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = V2FeatureFlags.v2Enabled
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        V2FeatureFlags.v2Enabled = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testEqualTimestampConflictDeterministicallyPullsWhenRemoteClockWinsNodeTie() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_705_000_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-a"
        let externalID = "ext-a"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Title",
                dueDate: fixedDate,
                isComplete: false,
                dateAdded: fixedDate,
                createdAt: fixedDate,
                updatedAt: fixedDate
            )
        ])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: fixedDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: fixedDate,
                externalPayloadData: nil,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: fixedDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Title",
                notes: "remote",
                dueDate: fixedDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: fixedDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "aaa-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 1)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)

        let updatedTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(updatedTask?.name, "Remote Title")
        XCTAssertEqual(updatedTask?.details, "remote")
    }

    func testNewerTombstoneSuppressesBothPullAndPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_100_000)
        let tombstone = SyncClock(
            physicalMillis: Int64(baseDate.timeIntervalSince1970 * 1_000) + 10_000,
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-b"
        let externalID = "ext-b"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local Tombstoned",
                dueDate: nil,
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Remote Tombstoned",
                notes: nil,
                dueDate: nil,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pulledFromExternal, 0)
        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(provider.upsertedSnapshots.count, 0)
    }

    func testNewerLocalUpdateResurrectsAfterOlderTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_200_000)
        let newDate = oldDate.addingTimeInterval(3_600)
        let tombstone = SyncClock(
            physicalMillis: Int64(oldDate.timeIntervalSince1970 * 1_000),
            logicalCounter: 0,
            nodeID: "remote.apple_reminders"
        )

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-c"
        let externalID = "ext-c"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Locally Resurrected",
                dueDate: newDate,
                isComplete: false,
                dateAdded: oldDate,
                createdAt: oldDate,
                updatedAt: newDate
            )
        ])

        var state = ReminderMergeState()
        state.tombstoneClock = tombstone
        state.lastWriteClock = tombstone

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: nil,
                syncStateData: state.encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Old Remote Value",
                notes: nil,
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 0,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: oldDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 1)
        XCTAssertEqual(provider.upsertedSnapshots.count, 1)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let updatedState = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNil(updatedState.tombstoneClock, "Successful resurrection must clear obsolete tombstone clock")
    }

    func testMappedMissingRemoteWithDeletedLocalCreatesTombstone() throws {
        let oldDate = Date(timeIntervalSince1970: 1_705_260_000)
        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-missing-remote"
        let externalID = "ext-missing-remote"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: oldDate
            )
        ]

        let envelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Previously Synced",
                notes: "legacy",
                dueDate: oldDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: []
            ),
            passthroughData: Data("legacy-passthrough".utf8)
        )

        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: oldDate,
                externalPayloadData: try JSONEncoder().encode(envelope),
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: oldDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = []

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }

        XCTAssertEqual(summary.pushedToExternal, 0)
        XCTAssertEqual(summary.pulledFromExternal, 0)

        let updatedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let state = ReminderMergeState.decode(from: updatedMap?.syncStateData)
        XCTAssertNotNil(state.tombstoneClock, "Missing remote + missing local must persist a tombstone decision")
    }
}

final class ReminderPayloadRoundTripTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalRemindersSyncEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = V2FeatureFlags.v2Enabled
        originalRemindersSyncEnabled = V2FeatureFlags.remindersSyncEnabled
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.remindersSyncEnabled = true
    }

    override func tearDown() {
        V2FeatureFlags.v2Enabled = originalV2Enabled
        V2FeatureFlags.remindersSyncEnabled = originalRemindersSyncEnabled
        super.tearDown()
    }

    func testLegacyPayloadDecodePreservesRawBytesAsPassthrough() {
        let legacyPayload = Data(#"{"title":"Legacy Reminder","notes":"n","unsupported":{"alpha":1}}"#.utf8)
        let mergeEngine = ReminderMergeEngine()
        let decoded = mergeEngine.decodeEnvelope(data: legacyPayload)

        XCTAssertEqual(decoded?.known.title, "Legacy Reminder")
        XCTAssertEqual(decoded?.passthroughData, legacyPayload)
    }

    func testUnsupportedPayloadBytesArePreservedAcrossPush() throws {
        let baseDate = Date(timeIntervalSince1970: 1_705_300_000)
        let passthrough = Data("opaque-payload".utf8)
        let originalEnvelope = ReminderMergeEnvelope(
            known: ReminderMergeEnvelope.KnownFields(
                title: "Old",
                notes: "old-note",
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: "https://example.com",
                alarmDates: []
            ),
            passthroughData: passthrough
        )
        let originalPayload = try JSONEncoder().encode(originalEnvelope)

        let projectID = UUID()
        let taskID = UUID()
        let listID = "list-roundtrip"
        let externalID = "ext-roundtrip"

        let taskRepository = InMemoryTaskDefinitionRepository(seed: [
            TaskDefinition(
                id: taskID,
                projectID: projectID,
                projectName: "Inbox",
                title: "Local New Title",
                details: "Local New Notes",
                dueDate: baseDate.addingTimeInterval(86_400),
                isComplete: false,
                dateAdded: baseDate,
                createdAt: baseDate,
                updatedAt: baseDate.addingTimeInterval(120)
            )
        ])

        let externalRepository = InMemoryExternalSyncRepository()
        externalRepository.containerMappings = [
            ExternalContainerMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                projectID: projectID,
                externalContainerID: listID,
                syncEnabled: true,
                lastSyncAt: nil,
                createdAt: baseDate
            )
        ]
        externalRepository.itemMappings = [
            ExternalItemMapDefinition(
                id: UUID(),
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                externalItemID: externalID,
                externalPersistentID: nil,
                lastSeenExternalModAt: baseDate,
                externalPayloadData: originalPayload,
                syncStateData: ReminderMergeState().encodedData(),
                createdAt: baseDate
            )
        ]

        let provider = InMemoryAppleRemindersProvider()
        provider.remindersByListID[listID] = [
            AppleReminderItemSnapshot(
                itemID: externalID,
                calendarID: listID,
                title: "Older Remote Title",
                notes: nil,
                dueDate: baseDate,
                completionDate: nil,
                isCompleted: false,
                priority: 5,
                urlString: nil,
                alarmDates: [],
                lastModifiedAt: baseDate
            )
        ]

        let useCase = ReconcileExternalRemindersUseCase(
            externalRepository: externalRepository,
            remindersProvider: provider,
            taskRepository: taskRepository,
            nodeID: "zzz-local-node"
        )

        let summary = try awaitResult { completion in
            useCase.reconcileProject(projectID: projectID, completion: completion)
        }
        XCTAssertEqual(summary.pushedToExternal, 1)

        let pushedPayload = try XCTUnwrap(provider.upsertedSnapshots.first?.payloadData)
        let pushedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: pushedPayload)
        XCTAssertEqual(pushedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(pushedEnvelope.known.title, "Local New Title")

        let savedMap = try awaitResult { completion in
            externalRepository.fetchItemMapping(
                provider: "apple_reminders",
                localEntityType: "task",
                localEntityID: taskID,
                completion: completion
            )
        }
        let savedPayload = try XCTUnwrap(savedMap?.externalPayloadData)
        let savedEnvelope = try JSONDecoder().decode(ReminderMergeEnvelope.self, from: savedPayload)
        XCTAssertEqual(savedEnvelope.passthroughData, passthrough)
        XCTAssertEqual(savedEnvelope.known.title, "Local New Title")
    }
}

final class SyncClockDeterminismTests: XCTestCase {
    func testLogicalCounterBreaksPhysicalTimestampTie() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 1, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 2, nodeID: "node-a")
        XCTAssertTrue(rhs > lhs)
    }

    func testNodeIDBreaksFullClockTieDeterministically() {
        let lhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-a")
        let rhs = SyncClock(physicalMillis: 1_000, logicalCounter: 0, nodeID: "node-b")
        XCTAssertTrue(lhs < rhs)
        XCTAssertTrue(rhs > lhs)
    }
}

final class AssistantPipelineTransactionalTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantApplyEnabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = V2FeatureFlags.v2Enabled
        originalAssistantApplyEnabled = V2FeatureFlags.assistantApplyEnabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.assistantApplyEnabled = true
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        V2FeatureFlags.v2Enabled = originalV2Enabled
        V2FeatureFlags.assistantApplyEnabled = originalAssistantApplyEnabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testPartialApplyFailureRollsBackAndPersistsVerifiedRollbackOutcome() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Apply",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        taskRepository.failUpdateOnCall = 2
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "Step 1", dueDate: nil),
                .updateTask(taskID: taskID, title: "Step 2", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        let applyExpectation = expectation(description: "apply-fails")
        useCase.applyConfirmedRun(id: runID) { result in
            if case .failure = result {
                applyExpectation.fulfill()
            } else {
                XCTFail("Expected apply to fail")
            }
        }
        waitForExpectations(timeout: 2.0)

        let persistedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(persistedRun?.status, .failed)
        XCTAssertEqual(persistedRun?.rollbackStatus, .verified)
        XCTAssertNotNil(persistedRun?.rollbackVerifiedAt)
        XCTAssertNotNil(persistedRun?.executionTraceData)
        XCTAssertEqual(persistedRun?.lastErrorCode, "assistant_apply_failed")

        let finalTask = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(finalTask?.name, "Before Apply", "Rollback must restore pre-apply state")
    }

    func testSuccessfulApplyGeneratesDeterministicUndoPlan() throws {
        let taskID = UUID()
        let projectID = UUID()
        let initialTask = TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: "Inbox",
            title: "Before Undo",
            dueDate: nil,
            isComplete: false,
            dateAdded: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [initialTask])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [
                .updateTask(taskID: taskID, title: "After Undo", dueDate: nil)
            ]
        )
        let run = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .confirmed,
            confirmedAt: Date(),
            createdAt: Date()
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(run, completion: completion)
        }

        _ = try awaitResult { completion in
            useCase.applyConfirmedRun(id: runID, completion: completion)
        }

        let appliedRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(appliedRun?.status, .applied)
        let appliedData = try XCTUnwrap(appliedRun?.proposalData)
        let appliedEnvelope = try JSONDecoder().decode(AssistantCommandEnvelope.self, from: appliedData)
        XCTAssertEqual(appliedEnvelope.undoCommands?.count, 1)

        _ = try awaitResult { completion in
            useCase.undoAppliedRun(id: runID, completion: completion)
        }

        let undoneRun = try awaitResult { completion in
            actionRepository.fetchRun(id: runID, completion: completion)
        }
        XCTAssertEqual(undoneRun?.status, .confirmed)

        let taskAfterUndo = try awaitResult { completion in
            taskRepository.fetchTaskDefinition(id: taskID, completion: completion)
        }
        XCTAssertEqual(taskAfterUndo?.name, "Before Undo")
    }
}

final class AssistantUndoWindowTests: XCTestCase {
    private var originalV2Enabled = true
    private var originalAssistantUndoEnabled = true

    override func setUp() {
        super.setUp()
        originalV2Enabled = V2FeatureFlags.v2Enabled
        originalAssistantUndoEnabled = V2FeatureFlags.assistantUndoEnabled
        V2FeatureFlags.v2Enabled = true
        V2FeatureFlags.assistantUndoEnabled = true
    }

    override func tearDown() {
        V2FeatureFlags.v2Enabled = originalV2Enabled
        V2FeatureFlags.assistantUndoEnabled = originalAssistantUndoEnabled
        super.tearDown()
    }

    func testUndoWindowExpirationIsDeterministic() throws {
        let taskRepository = InMemoryTaskDefinitionRepository(seed: [])
        let actionRepository = InMemoryAssistantActionRepository()
        let useCase = AssistantActionPipelineUseCase(
            repository: actionRepository,
            taskRepository: taskRepository
        )

        let runID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 1,
            commands: [.createTask(projectID: UUID(), title: "Expired")],
            undoCommands: [.deleteTask(taskID: UUID())]
        )
        let staleRun = AssistantActionRunDefinition(
            id: runID,
            threadID: "thread",
            proposalData: try JSONEncoder().encode(envelope),
            status: .applied,
            confirmedAt: Date().addingTimeInterval(-4_000),
            appliedAt: Date().addingTimeInterval(-4_000),
            createdAt: Date().addingTimeInterval(-4_000)
        )
        _ = try awaitResult { completion in
            actionRepository.createRun(staleRun, completion: completion)
        }

        let expectation = expectation(description: "undo-expired")
        useCase.undoAppliedRun(id: runID) { result in
            switch result {
            case .failure(let error as NSError):
                XCTAssertEqual(error.code, 410)
                expectation.fulfill()
            default:
                XCTFail("Expected undo window expiration failure")
            }
        }
        waitForExpectations(timeout: 2.0)
    }
}

final class ReadModelQueryPathTests: XCTestCase {
    func testHomeAndSearchUseCasesPreferReadModelQueriesOverFetchAll() {
        let inbox = Project.createInbox()
        let task = Task(
            id: UUID(),
            projectID: inbox.id,
            name: "ReadModel Task",
            details: "searchable",
            type: .morning,
            priority: .low,
            dueDate: Date(),
            project: inbox.name
        )
        let repository = MockTaskRepository(seed: task)

        let homeUseCase = GetHomeFilteredTasksUseCase(
            taskRepository: repository,
            readModelRepository: repository
        )
        let homeExpectation = expectation(description: "home-read-model")
        homeUseCase.execute(state: .default, scope: .today) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected home failure: \(error)")
            }
            homeExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelFetchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)

        let getTasksUseCase = GetTasksUseCase(
            taskRepository: repository,
            readModelRepository: repository
        )
        let searchExpectation = expectation(description: "search-read-model")
        getTasksUseCase.searchTasks(query: "ReadModel", scope: .all) { result in
            if case .failure(let error) = result {
                XCTFail("Unexpected search failure: \(error)")
            }
            searchExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.readModelSearchCallCount, 1)
        XCTAssertEqual(repository.fetchAllTasksCallCount, 0)
    }
}

final class V2PerformanceGateTests: XCTestCase {
    private struct PerfSnapshot: Decodable {
        struct Percentiles: Decodable {
            let p95_ms: Double
            let p99_ms: Double
        }
        struct Metrics: Decodable {
            let home: Percentiles
            let project: Percentiles
            let search: Percentiles
        }
        let metrics: Metrics
    }

    func testPerfSeedHarnessProducesBalancedProfileSnapshot() throws {
        let root = workspaceRootURLForTests()
        let outputURL = root.appendingPathComponent("build/benchmarks/v2_readmodel.test.json")
        let command = [
            "swift",
            "scripts/perf_seed_v2.swift",
            "--tasks", "2000",
            "--occurrences", "20000",
            "--iterations", "60",
            "--output", outputURL.path
        ].joined(separator: " ")

        let status = try runShellCommand(command, in: root)
        XCTAssertEqual(status, 0, "Benchmark harness command failed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        let data = try Data(contentsOf: outputURL)
        let snapshot = try JSONDecoder().decode(PerfSnapshot.self, from: data)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p95_ms, 250)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p95_ms, 300)
        XCTAssertLessThanOrEqual(snapshot.metrics.home.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.project.p99_ms, 600)
        XCTAssertLessThanOrEqual(snapshot.metrics.search.p99_ms, 600)
    }
}

final class FlowctlToolingTests: XCTestCase {
    func testFlowctlInstallAndVerifyScriptsSucceed() throws {
        let root = workspaceRootURLForTests()
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/install_flowctl.sh", in: root), 0)
        XCTAssertEqual(try runShellCommand("FLOWCTL_ALLOW_SHIM=1 bash scripts/verify_flowctl.sh", in: root), 0)
        let flowctlPath = root.appendingPathComponent(".flow/bin/flowctl").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: flowctlPath))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: flowctlPath))
    }
}

final class AssistantPipelineImplementationTests: XCTestCase {
    func testPipelineImplementationContainsNoSemaphoreWaits() throws {
        let root = workspaceRootURLForTests()
        let sourceURL = root.appendingPathComponent("To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("DispatchSemaphore"))
        XCTAssertFalse(source.contains(".wait(timeout:"))
    }
}

private final class InMemoryAssistantActionRepository: AssistantActionRepositoryProtocol {
    private var byID: [UUID: AssistantActionRunDefinition] = [:]

    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping (Result<AssistantActionRunDefinition, Error>) -> Void) {
        byID[run.id] = run
        completion(.success(run))
    }

    func fetchRun(id: UUID, completion: @escaping (Result<AssistantActionRunDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }
}

private final class InMemoryTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private(set) var byID: [UUID: TaskDefinition]
    private(set) var updateCallCount = 0
    var failUpdateOnCall: Int?

    init(seed: [TaskDefinition]) {
        byID = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        let filtered = Array(byID.values).filter { task in
            guard let query else { return true }
            if let projectID = query.projectID, task.projectID != projectID { return false }
            if query.includeCompleted == false, task.isComplete { return false }
            if let parentTaskID = query.parentTaskID, task.parentTaskID != parentTaskID { return false }
            if let start = query.dueDateStart, let due = task.dueDate, due < start { return false }
            if let end = query.dueDateEnd, let due = task.dueDate, due > end { return false }
            if let searchText = query.searchText?.lowercased(), searchText.isEmpty == false {
                let nameMatch = task.name.lowercased().contains(searchText)
                let detailMatch = task.details?.lowercased().contains(searchText) ?? false
                if !nameMatch && !detailMatch { return false }
            }
            return true
        }
        completion(.success(filtered))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(byID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        byID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let task = TaskDefinition(
            id: request.id,
            projectID: request.projectID,
            projectName: request.projectName ?? ProjectConstants.inboxProjectName,
            lifeAreaID: request.lifeAreaID,
            sectionID: request.sectionID,
            parentTaskID: request.parentTaskID,
            title: request.title,
            details: request.details,
            priority: request.priority,
            type: request.type,
            energy: request.energy,
            category: request.category,
            context: request.context,
            dueDate: request.dueDate,
            isComplete: false,
            dateAdded: request.createdAt,
            isEveningTask: request.isEveningTask,
            alertReminderTime: request.alertReminderTime,
            tagIDs: request.tagIDs,
            dependencies: request.dependencies,
            createdAt: request.createdAt,
            updatedAt: request.createdAt
        )
        byID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        updateCallCount += 1
        if failUpdateOnCall == updateCallCount {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Injected update failure"])))
            return
        }
        byID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        guard var current = byID[request.id] else {
            completion(.failure(NSError(domain: "InMemoryTaskDefinitionRepository", code: 404)))
            return
        }
        if let title = request.title { current.name = title }
        if let details = request.details { current.details = details }
        if let projectID = request.projectID { current.projectID = projectID }
        if let dueDate = request.dueDate { current.dueDate = dueDate }
        if let isComplete = request.isComplete { current.isComplete = isComplete }
        if request.dateCompleted != nil || request.isComplete == false { current.dateCompleted = request.dateCompleted }
        current.updatedAt = Date()
        byID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(byID.values.filter { $0.parentTaskID == parentTaskID })))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        byID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class InMemoryExternalSyncRepository: ExternalSyncRepositoryProtocol {
    var containerMappings: [ExternalContainerMapDefinition] = []
    var itemMappings: [ExternalItemMapDefinition] = []

    func fetchContainerMappings(completion: @escaping (Result<[ExternalContainerMapDefinition], Error>) -> Void) {
        completion(.success(containerMappings))
    }

    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = containerMappings.firstIndex(where: { $0.id == mapping.id }) {
            containerMappings[index] = mapping
        } else if let index = containerMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.projectID == mapping.projectID
        }) {
            containerMappings[index] = mapping
        } else {
            containerMappings.append(mapping)
        }
        completion(.success(()))
    }

    func fetchContainerMapping(
        provider: String,
        projectID: UUID,
        completion: @escaping (Result<ExternalContainerMapDefinition?, Error>) -> Void
    ) {
        completion(.success(containerMappings.first { $0.provider == provider && $0.projectID == projectID }))
    }

    func upsertContainerMapping(
        provider: String,
        projectID: UUID,
        mutate: @escaping (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition,
        completion: @escaping (Result<ExternalContainerMapDefinition, Error>) -> Void
    ) {
        let existing = containerMappings.first { $0.provider == provider && $0.projectID == projectID }
        let mutated = mutate(existing)
        saveContainerMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMappings(completion: @escaping (Result<[ExternalItemMapDefinition], Error>) -> Void) {
        completion(.success(itemMappings))
    }

    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        if let index = itemMappings.firstIndex(where: { $0.id == mapping.id }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider &&
            $0.localEntityType == mapping.localEntityType &&
            $0.localEntityID == mapping.localEntityID
        }) {
            itemMappings[index] = mapping
        } else if let index = itemMappings.firstIndex(where: {
            $0.provider == mapping.provider && $0.externalItemID == mapping.externalItemID
        }) {
            itemMappings[index] = mapping
        } else {
            itemMappings.append(mapping)
        }
        completion(.success(()))
    }

    func upsertItemMappingByLocalKey(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func upsertItemMappingByExternalKey(
        provider: String,
        externalItemID: String,
        mutate: @escaping (ExternalItemMapDefinition?) -> ExternalItemMapDefinition,
        completion: @escaping (Result<ExternalItemMapDefinition, Error>) -> Void
    ) {
        let existing = itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }
        let mutated = mutate(existing)
        saveItemMapping(mutated) { _ in
            completion(.success(mutated))
        }
    }

    func fetchItemMapping(
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void
    ) {
        completion(.success(itemMappings.first {
            $0.provider == provider && $0.localEntityType == localEntityType && $0.localEntityID == localEntityID
        }))
    }

    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping (Result<ExternalItemMapDefinition?, Error>) -> Void) {
        completion(.success(itemMappings.first { $0.provider == provider && $0.externalItemID == externalItemID }))
    }
}

private final class InMemoryAppleRemindersProvider: AppleRemindersProviderProtocol {
    var requestAccessGranted = true
    var lists: [AppleReminderListSnapshot] = []
    var remindersByListID: [String: [AppleReminderItemSnapshot]] = [:]
    var upsertedSnapshots: [AppleReminderItemSnapshot] = []

    func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(requestAccessGranted))
    }

    func fetchLists(completion: @escaping (Result<[AppleReminderListSnapshot], Error>) -> Void) {
        completion(.success(lists))
    }

    func fetchReminders(listID: String, completion: @escaping (Result<[AppleReminderItemSnapshot], Error>) -> Void) {
        completion(.success(remindersByListID[listID] ?? []))
    }

    func upsertReminder(
        listID: String,
        snapshot: AppleReminderItemSnapshot,
        completion: @escaping (Result<AppleReminderItemSnapshot, Error>) -> Void
    ) {
        upsertedSnapshots.append(snapshot)
        var persisted = snapshot
        persisted.lastModifiedAt = snapshot.lastModifiedAt ?? Date()
        var existing = remindersByListID[listID] ?? []
        if let index = existing.firstIndex(where: { $0.itemID == snapshot.itemID }) {
            existing[index] = persisted
        } else {
            existing.append(persisted)
        }
        remindersByListID[listID] = existing
        completion(.success(persisted))
    }

    func deleteReminder(itemID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        for key in remindersByListID.keys {
            remindersByListID[key]?.removeAll(where: { $0.itemID == itemID })
        }
        completion(.success(()))
    }
}

private func workspaceRootURLForTests() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
}

@discardableResult
private func runShellCommand(_ command: String, in directory: URL) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", command]
    process.currentDirectoryURL = directory
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
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
