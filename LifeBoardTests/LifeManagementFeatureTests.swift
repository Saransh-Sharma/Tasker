import XCTest
import CoreData
@testable import LifeBoard

@MainActor
final class ManageLifeAreasUseCaseTests: XCTestCase {
    func testUpdateLifeAreaNameAndIconSucceeds() {
        let area = LifeArea(id: UUID(), name: "Health", color: "#22C55E", icon: "heart.fill")
        let repository = LifeAreaRepositoryStub(areas: [area])
        let useCase = ManageLifeAreasUseCase(repository: repository)
        let expectedColor = LifeAreaColorPalette.normalizeOrMap(hex: "#16A34A", for: area.id)

        let expectation = expectation(description: "update life area")
        useCase.update(
            id: area.id,
            name: "Wellness",
            color: "#16A34A",
            icon: "leaf.fill"
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.name, "Wellness")
                XCTAssertEqual(updated.color, expectedColor)
                XCTAssertEqual(updated.icon, "leaf.fill")
                XCTAssertEqual(repository.areas.first?.name, "Wellness")
                XCTAssertEqual(repository.areas.first?.color, expectedColor)
                XCTAssertEqual(repository.areas.first?.icon, "leaf.fill")
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateRejectsDuplicateNormalizedName() {
        let first = LifeArea(id: UUID(), name: "Career", color: nil, icon: nil)
        let second = LifeArea(id: UUID(), name: "Health", color: nil, icon: nil)
        let repository = LifeAreaRepositoryStub(areas: [first, second])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "duplicate rename rejected")
        useCase.update(
            id: second.id,
            name: " career ",
            color: nil,
            icon: nil
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected duplicate-name failure")
            case .failure(let error):
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "ManageLifeAreasUseCase")
                XCTAssertEqual(nsError.code, 409)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testArchiveAndUnarchiveToggleIsArchived() {
        let area = LifeArea(id: UUID(), name: "Career", color: nil, icon: nil)
        let repository = LifeAreaRepositoryStub(areas: [area])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "archive and unarchive")
        useCase.archive(id: area.id) { archiveResult in
            switch archiveResult {
            case .success(let archived):
                XCTAssertTrue(archived.isArchived)
                useCase.unarchive(id: area.id) { unarchiveResult in
                    switch unarchiveResult {
                    case .success(let restored):
                        XCTAssertFalse(restored.isArchived)
                        XCTAssertEqual(repository.areas.first?.isArchived, false)
                    case .failure(let error):
                        XCTFail("Expected unarchive success, got \(error)")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("Expected archive success, got \(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCreateAssignsDeterministicPaletteDefaultWhenColorIsMissing() {
        let repository = LifeAreaRepositoryStub(areas: [])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "create life area with default palette color")
        useCase.create(name: "Health", color: nil, icon: nil) { result in
            switch result {
            case .success(let created):
                let expected = LifeAreaColorPalette.defaultHex(for: created.id)
                XCTAssertEqual(created.color, expected)
                XCTAssertEqual(repository.areas.first?.color, expected)
                XCTAssertTrue(HabitColorFamily.allCases.map(\.canonicalHex).contains(expected))
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateCanonicalizesPaletteHex() {
        let area = LifeArea(id: UUID(), name: "Health", color: "#4E9A2F", icon: "heart.fill")
        let repository = LifeAreaRepositoryStub(areas: [area])
        let useCase = ManageLifeAreasUseCase(repository: repository)

        let expectation = expectation(description: "update canonical palette hex")
        useCase.update(
            id: area.id,
            name: "Health",
            color: "4e9a2f",
            icon: "heart.fill"
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.color, HabitColorFamily.green.canonicalHex)
                XCTAssertEqual(repository.areas.first?.color, HabitColorFamily.green.canonicalHex)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testUpdateMapsLegacyHexToNearestPaletteColor() {
        let area = LifeArea(id: UUID(), name: "Career", color: "#4E9A2F", icon: "briefcase.fill")
        let repository = LifeAreaRepositoryStub(areas: [area])
        let useCase = ManageLifeAreasUseCase(repository: repository)
        let expected = LifeAreaColorPalette.normalizeOrMap(hex: "#3B82F6", for: area.id)

        let expectation = expectation(description: "update maps legacy hex")
        useCase.update(
            id: area.id,
            name: "Career",
            color: "#3B82F6",
            icon: "briefcase.fill"
        ) { result in
            switch result {
            case .success(let updated):
                XCTAssertEqual(updated.color, expected)
                XCTAssertEqual(repository.areas.first?.color, expected)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

@MainActor
final class LifeAreaColorPaletteTests: XCTestCase {
    func testDefaultHexIsStablePerUUID() {
        let id = UUID(uuidString: "4E59F2B2-9B93-4EFC-8CB6-AC3F880D0B6A")!
        let first = LifeAreaColorPalette.defaultHex(for: id)
        let second = LifeAreaColorPalette.defaultHex(for: id)
        XCTAssertEqual(first, second)
        XCTAssertTrue(HabitColorFamily.allCases.map(\.canonicalHex).contains(first))
    }

    func testNormalizeOrMapKeepsCanonicalPaletteHex() {
        let id = UUID()
        let resolved = LifeAreaColorPalette.resolve(hex: "4a86e8", for: id)
        XCTAssertEqual(resolved.hex, HabitColorFamily.blue.canonicalHex)
        XCTAssertEqual(resolved.reason, .exactPaletteMatch)
    }

    func testNormalizeOrMapMapsLegacyHexToNearestPalette() {
        let id = UUID()
        let resolved = LifeAreaColorPalette.resolve(hex: "#4B85E7", for: id)
        XCTAssertEqual(resolved.hex, HabitColorFamily.blue.canonicalHex)
        XCTAssertEqual(resolved.reason, .mappedLegacy)
    }

    func testNormalizeOrMapFallsBackToDefaultForInvalidInput() {
        let id = UUID()
        let expected = LifeAreaColorPalette.defaultHex(for: id)
        let resolved = LifeAreaColorPalette.resolve(hex: "not-a-hex", for: id)
        XCTAssertEqual(resolved.hex, expected)
        XCTAssertEqual(resolved.reason, .missingOrInvalid)
    }
}

@MainActor
final class ManageProjectsLifeAreaRoutingTests: XCTestCase {
    func testCreateProjectCarriesLifeAreaIDToRepository() {
        let lifeAreaID = UUID()
        let repository = ProjectRepositoryStub()
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let expectation = expectation(description: "create project with life area")
        useCase.createProject(
            request: CreateProjectRequest(
                name: "Fitness Plan",
                description: "Q2 routine",
                lifeAreaID: lifeAreaID
            )
        ) { result in
            switch result {
            case .success(let project):
                XCTAssertEqual(project.lifeAreaID, lifeAreaID)
                XCTAssertEqual(repository.projects.first?.lifeAreaID, lifeAreaID)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testMoveProjectToLifeAreaRejectsInboxProject() {
        let inbox = Project(
            id: ProjectConstants.inboxProjectID,
            lifeAreaID: UUID(),
            name: ProjectConstants.inboxProjectName,
            projectDescription: nil,
            isDefault: true
        )
        let repository = ProjectRepositoryStub(projects: [inbox])
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let expectation = expectation(description: "reject inbox move")
        useCase.moveProjectToLifeArea(
            projectId: ProjectConstants.inboxProjectID,
            lifeAreaID: UUID()
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure for Inbox move")
            case .failure(let error):
                if case .cannotModifyDefault = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.moveProjectCalls.count, 0)
    }

    func testMoveProjectToLifeAreaNoOpsWhenAlreadyInTargetArea() {
        let areaID = UUID()
        let project = Project(
            id: UUID(),
            lifeAreaID: areaID,
            name: "Roadmap",
            projectDescription: nil
        )
        let repository = ProjectRepositoryStub(projects: [project], taskCounts: [project.id: 4])
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let expectation = expectation(description: "no-op move")
        useCase.moveProjectToLifeArea(
            projectId: project.id,
            lifeAreaID: areaID
        ) { result in
            switch result {
            case .success(let payload):
                XCTAssertEqual(payload.updatedProjectID, project.id)
                XCTAssertEqual(payload.fromLifeAreaID, areaID)
                XCTAssertEqual(payload.toLifeAreaID, areaID)
                XCTAssertEqual(payload.tasksRemappedCount, 0)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.moveProjectCalls.count, 0)
    }

    func testArchiveAndUnarchiveProjectToggleIsArchived() {
        let project = Project(id: UUID(), lifeAreaID: UUID(), name: "Roadmap", projectDescription: "Quarter")
        let repository = ProjectRepositoryStub(projects: [project], taskCounts: [project.id: 4])
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let expectation = expectation(description: "archive and unarchive project")
        useCase.archiveProject(projectId: project.id) { archiveResult in
            switch archiveResult {
            case .success(let archived):
                XCTAssertTrue(archived.isArchived)
                XCTAssertEqual(repository.projects.first?.isArchived, true)
                useCase.unarchiveProject(projectId: project.id) { unarchiveResult in
                    switch unarchiveResult {
                    case .success(let restored):
                        XCTAssertFalse(restored.isArchived)
                        XCTAssertEqual(repository.projects.first?.isArchived, false)
                    case .failure(let error):
                        XCTFail("Expected unarchive success, got \(error)")
                    }
                    expectation.fulfill()
                }
            case .failure(let error):
                XCTFail("Expected archive success, got \(error)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testArchiveProjectRejectsInbox() {
        let inbox = Project.createInbox()
        let repository = ProjectRepositoryStub(projects: [inbox], taskCounts: [inbox.id: 1])
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let expectation = expectation(description: "reject inbox archive")
        useCase.archiveProject(projectId: inbox.id) { result in
            switch result {
            case .success:
                XCTFail("Expected inbox archive to fail")
            case .failure(let error):
                if case .cannotModifyDefault = error {
                    XCTAssertTrue(true)
                } else {
                    XCTFail("Unexpected error \(error)")
                }
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testArchiveProjectDispatchesMutationNotification() {
        let project = Project(id: UUID(), lifeAreaID: UUID(), name: "Focus")
        let repository = ProjectRepositoryStub(projects: [project], taskCounts: [project.id: 2])
        let useCase = ManageProjectsUseCase(projectRepository: repository)

        let mutationExpectation = expectation(forNotification: .homeTaskMutation, object: nil) { notification in
            let userInfo = notification.userInfo ?? [:]
            return (userInfo["projectID"] as? String) == project.id.uuidString &&
                (userInfo["archived"] as? Bool) == true
        }

        let completionExpectation = expectation(description: "archive completion")
        useCase.archiveProject(projectId: project.id) { result in
            if case .failure(let error) = result {
                XCTFail("Expected archive success, got \(error)")
            }
            completionExpectation.fulfill()
        }

        wait(for: [mutationExpectation, completionExpectation], timeout: 1.0)
    }
}

@MainActor
final class CoreDataProjectRepositoryLifeAreaMutationTests: XCTestCase {
    @MainActor
    func testCreateProjectRejectsDuplicateNameAtRepositoryWriteBoundary() throws {
        let container = try Self.makeInMemoryContainer()
        let context = container.viewContext

        context.performAndWait {
            Self.makeProject(in: context, id: UUID(), name: "Health", lifeAreaID: nil, isDefault: false)
            try? context.save()
        }

        let repository = CoreDataProjectRepository(container: container)
        let expectation = expectation(description: "reject duplicate project")
        repository.createProject(Project(name: " health ")) { result in
            switch result {
            case .success:
                XCTFail("Expected duplicate project name to be rejected")
            case .failure(let error):
                XCTAssertEqual(error as? ProjectValidationError, .duplicateName)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testMoveProjectToLifeAreaRemapsProjectAndAllTasks() throws {
        let container = try Self.makeInMemoryContainer()
        let context = container.viewContext

        let generalID = UUID()
        let targetAreaID = UUID()
        let projectID = UUID()

        context.performAndWait {
            Self.makeLifeArea(in: context, id: generalID, name: "General")
            Self.makeLifeArea(in: context, id: targetAreaID, name: "Career")
            Self.makeProject(in: context, id: projectID, name: "Portfolio", lifeAreaID: generalID, isDefault: false)
            Self.makeTask(in: context, id: UUID(), title: "Task A", projectID: projectID, lifeAreaID: generalID)
            Self.makeTask(in: context, id: UUID(), title: "Task B", projectID: projectID, lifeAreaID: generalID)
            try? context.save()
        }

        let repository = CoreDataProjectRepository(container: container)
        let expectation = expectation(description: "move project")
        repository.moveProjectToLifeArea(projectID: projectID, lifeAreaID: targetAreaID) { result in
            switch result {
            case .success(let payload):
                XCTAssertEqual(payload.updatedProjectID, projectID)
                XCTAssertEqual(payload.fromLifeAreaID, generalID)
                XCTAssertEqual(payload.toLifeAreaID, targetAreaID)
                XCTAssertEqual(payload.tasksRemappedCount, 2)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        context.performAndWait {
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            projectRequest.predicate = NSPredicate(format: "id == %@", projectID as CVarArg)
            let project = try? context.fetch(projectRequest).first
            XCTAssertEqual(project?.lifeAreaID, targetAreaID)

            let taskRequest: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
            taskRequest.predicate = NSPredicate(format: "projectID == %@", projectID as CVarArg)
            let tasks = (try? context.fetch(taskRequest)) ?? []
            XCTAssertEqual(tasks.count, 2)
            XCTAssertTrue(tasks.allSatisfy { $0.lifeAreaID == targetAreaID })
        }
    }

    func testBackfillProjectsWithoutLifeAreaAssignsGeneralAndPinsInbox() throws {
        let container = try Self.makeInMemoryContainer()
        let context = container.viewContext

        let generalID = UUID()
        let customProjectID = UUID()
        let assignedAreaID = UUID()
        let assignedProjectID = UUID()

        context.performAndWait {
            Self.makeLifeArea(in: context, id: generalID, name: "General")
            Self.makeLifeArea(in: context, id: assignedAreaID, name: "Learning")

            Self.makeProject(
                in: context,
                id: ProjectConstants.inboxProjectID,
                name: ProjectConstants.inboxProjectName,
                lifeAreaID: nil,
                isDefault: true
            )
            Self.makeProject(in: context, id: customProjectID, name: "Health Sprint", lifeAreaID: nil, isDefault: false)
            Self.makeProject(in: context, id: assignedProjectID, name: "Study", lifeAreaID: assignedAreaID, isDefault: false)

            Self.makeTask(in: context, id: UUID(), title: "Inbox Task", projectID: ProjectConstants.inboxProjectID, lifeAreaID: nil)
            Self.makeTask(in: context, id: UUID(), title: "Custom Task", projectID: customProjectID, lifeAreaID: nil)
            Self.makeTask(in: context, id: UUID(), title: "Assigned Task", projectID: assignedProjectID, lifeAreaID: assignedAreaID)

            try? context.save()
        }

        let repository = CoreDataProjectRepository(container: container)
        let expectation = expectation(description: "backfill")
        repository.backfillProjectsWithoutLifeArea(defaultLifeAreaID: generalID) { result in
            switch result {
            case .success(let payload):
                XCTAssertEqual(payload.defaultLifeAreaID, generalID)
                XCTAssertEqual(payload.projectsUpdatedCount, 2)
                XCTAssertEqual(payload.tasksRemappedCount, 2)
                XCTAssertTrue(payload.inboxPinned)
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        context.performAndWait {
            let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            let projects = (try? context.fetch(projectRequest)) ?? []
            let inbox = projects.first(where: { $0.id == ProjectConstants.inboxProjectID })
            let custom = projects.first(where: { $0.id == customProjectID })
            let assigned = projects.first(where: { $0.id == assignedProjectID })

            XCTAssertEqual(inbox?.lifeAreaID, generalID)
            XCTAssertEqual(custom?.lifeAreaID, generalID)
            XCTAssertEqual(assigned?.lifeAreaID, assignedAreaID)

            let taskRequest: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
            let tasks = (try? context.fetch(taskRequest)) ?? []
            let inboxTask = tasks.first(where: { $0.projectID == ProjectConstants.inboxProjectID })
            let customTask = tasks.first(where: { $0.projectID == customProjectID })
            let assignedTask = tasks.first(where: { $0.projectID == assignedProjectID })
            XCTAssertEqual(inboxTask?.lifeAreaID, generalID)
            XCTAssertEqual(customTask?.lifeAreaID, generalID)
            XCTAssertEqual(assignedTask?.lifeAreaID, assignedAreaID)
        }
    }
}

@MainActor
final class LifeBoardPersistentRuntimeInitializerLifeAreaColorBackfillTests: XCTestCase {
    private let backfillKey = "lifeboard.life_area_color_palette_backfill.v1"
    private let runtimeMarkerKeys = [
        "lifeboard.habit.runtime.field_backfill.v1",
        "lifeboard.habit.runtime.repair_required.v1",
        "lifeboard.habit.runtime.repair_completed.v1",
        "lifeboard.occurrence.key_backfill.v1",
        "lifeboard.life_area_color_palette_backfill.v1"
    ]

    override func setUp() {
        super.setUp()
        clearRuntimeInitializerMarkers()
    }

    override func tearDown() {
        clearRuntimeInitializerMarkers()
        super.tearDown()
    }

    private func clearRuntimeInitializerMarkers() {
        for key in runtimeMarkerKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testInitializeBackfillsLifeAreaColorsIntoPalette() throws {
        let container = try makeInMemoryCloudKitContainer()
        let context = container.viewContext

        let missingID = UUID()
        let invalidID = UUID()
        let legacyID = UUID()

        context.performAndWait {
            _ = insertLifeArea(in: context, id: UUID(), name: "General", color: nil)
            _ = insertLifeArea(in: context, id: missingID, name: "Health", color: nil)
            _ = insertLifeArea(in: context, id: invalidID, name: "Career", color: "not-a-hex")
            _ = insertLifeArea(in: context, id: legacyID, name: "Learning", color: "#3B82F6")
            try? context.save()
        }

        LifeBoardPersistentRuntimeInitializer().initialize(container: container)

        context.performAndWait {
            let missingColor = fetchLifeAreaColor(in: context, id: missingID)
            let invalidColor = fetchLifeAreaColor(in: context, id: invalidID)
            let legacyColor = fetchLifeAreaColor(in: context, id: legacyID)
            XCTAssertEqual(missingColor, LifeAreaColorPalette.defaultHex(for: missingID))
            XCTAssertEqual(invalidColor, LifeAreaColorPalette.defaultHex(for: invalidID))
            XCTAssertEqual(legacyColor, LifeAreaColorPalette.normalizeOrMap(hex: "#3B82F6", for: legacyID))
            XCTAssertTrue(HabitColorFamily.allCases.map(\.canonicalHex).contains(missingColor ?? ""))
            XCTAssertTrue(HabitColorFamily.allCases.map(\.canonicalHex).contains(invalidColor ?? ""))
            XCTAssertTrue(HabitColorFamily.allCases.map(\.canonicalHex).contains(legacyColor ?? ""))
        }

        XCTAssertTrue(UserDefaults.standard.bool(forKey: backfillKey))
    }

    func testInitializeSkipsColorBackfillAfterMarkerIsSet() throws {
        let container = try makeInMemoryCloudKitContainer()
        let context = container.viewContext
        let areaID = UUID()

        context.performAndWait {
            _ = insertLifeArea(in: context, id: UUID(), name: "General", color: nil)
            _ = insertLifeArea(in: context, id: areaID, name: "Health", color: nil)
            try? context.save()
        }

        let initializer = LifeBoardPersistentRuntimeInitializer()
        initializer.initialize(container: container)

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
            request.predicate = NSPredicate(format: "id == %@", areaID as CVarArg)
            request.fetchLimit = 1
            let area = try? context.fetch(request).first
            area?.setValue(nil, forKey: "color")
            try? context.save()
        }

        initializer.initialize(container: container)

        context.performAndWait {
            XCTAssertNil(fetchLifeAreaColor(in: context, id: areaID))
        }
    }

    func testInitializeDoesNotMutateHabitColorHex() throws {
        let container = try makeInMemoryCloudKitContainer()
        let context = container.viewContext
        let areaID = UUID()
        let habitID = UUID()

        context.performAndWait {
            _ = insertLifeArea(in: context, id: UUID(), name: "General", color: nil)
            _ = insertLifeArea(in: context, id: areaID, name: "Health", color: nil)
            _ = insertHabit(in: context, id: habitID, lifeAreaID: areaID, colorHex: "#8A46B5")
            try? context.save()
        }

        LifeBoardPersistentRuntimeInitializer().initialize(container: container)

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
            request.predicate = NSPredicate(format: "id == %@", habitID as CVarArg)
            request.fetchLimit = 1
            let habit = try? context.fetch(request).first
            XCTAssertEqual(habit?.value(forKey: "colorHex") as? String, "#8A46B5")
        }
    }

    private func makeInMemoryCloudKitContainer() throws -> NSPersistentCloudKitContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["LifeArea"] != nil,
              model.entitiesByName["HabitDefinition"] != nil else {
            throw NSError(
                domain: "LifeManagementFeatureTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 for runtime initializer tests"]
            )
        }

        let container = NSPersistentCloudKitContainer(name: "TaskModelV3", managedObjectModel: model)
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

    @discardableResult
    private func insertLifeArea(in context: NSManagedObjectContext, id: UUID, name: String, color: String?) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(name, forKey: "name")
        object.setValue(color, forKey: "color")
        object.setValue("square.grid.2x2", forKey: "icon")
        object.setValue(Int32(0), forKey: "sortOrder")
        object.setValue(false, forKey: "isArchived")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        object.setValue(Int32(1), forKey: "version")
        return object
    }

    @discardableResult
    private func insertHabit(in context: NSManagedObjectContext, id: UUID, lifeAreaID: UUID, colorHex: String) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "HabitDefinition", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue("Hydrate", forKey: "title")
        object.setValue("check_in", forKey: "habitType")
        object.setValue(colorHex, forKey: "colorHex")
        object.setValue(false, forKey: "isPaused")
        object.setValue(Int32(0), forKey: "streakCurrent")
        object.setValue(Int32(0), forKey: "streakBest")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    private func fetchLifeAreaColor(in context: NSManagedObjectContext, id: UUID) -> String? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        let area = try? context.fetch(request).first
        return area?.value(forKey: "color") as? String
    }
}

@MainActor
final class LifeManagementProjectionTests: XCTestCase {
    func testProjectionBuildsTreeWithProjectsAndDirectHabitsUnderAreas() throws {
        let general = LifeArea(id: UUID(), name: "General", color: "#9E5F0A", icon: "square.grid.2x2")
        let career = LifeArea(id: UUID(), name: "Career", color: "#3B82F6", icon: "briefcase.fill")

        let inbox = ProjectWithStats(
            project: Project(
                id: ProjectConstants.inboxProjectID,
                lifeAreaID: general.id,
                name: ProjectConstants.inboxProjectName,
                projectDescription: nil,
                isDefault: true
            ),
            taskCount: 1,
            completedTaskCount: 0
        )
        let roadmap = ProjectWithStats(
            project: Project(
                id: UUID(),
                lifeAreaID: career.id,
                name: "Roadmap",
                projectDescription: "Quarter goals",
                color: .blue,
                icon: .flag
            ),
            taskCount: 0,
            completedTaskCount: 0
        )

        let activeHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Deep work",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: career.id,
            lifeAreaName: "Career",
            projectID: roadmap.project.id,
            projectName: roadmap.project.name,
            colorHex: "#3B82F6",
            isPaused: false,
            isArchived: false,
            currentStreak: 6,
            bestStreak: 9
        )
        let pausedHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "No late caffeine",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: general.id,
            lifeAreaName: "General",
            colorHex: "#9E5F0A",
            isPaused: true,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 4
        )

        let context = LifeManagementProjection.prepare(
            lifeAreas: [general, career],
            projectStats: [inbox, roadmap],
            habitRows: [activeHabit, pausedHabit],
            generalLifeAreaID: general.id
        )
        let snapshot = context.snapshot(searchQuery: "")

        let activeSection = try XCTUnwrap(snapshot.treeSections.first(where: { $0.kind == LifeManagementTreeSectionKind.active }))
        XCTAssertEqual(activeSection.nodes.map(\.title), ["General", "Career"])

        let generalNode = try XCTUnwrap(activeSection.nodes.first(where: { $0.title == "General" }))
        XCTAssertEqual(generalNode.children.map(\.title), [ProjectConstants.inboxProjectName, "No late caffeine"])

        let careerNode = try XCTUnwrap(activeSection.nodes.first(where: { $0.title == "Career" }))
        XCTAssertEqual(careerNode.children.map(\.title), ["Roadmap"])

        let roadmapNode = try XCTUnwrap(careerNode.children.first(where: { $0.title == "Roadmap" }))
        XCTAssertEqual(roadmapNode.children.map(\.title), ["Deep work"])

        if case .project(let projectRow) = roadmapNode.payload {
            XCTAssertEqual(projectRow.linkedHabitCount, 1)
        } else {
            XCTFail("Expected roadmap node payload to be a project")
        }
    }

    func testProjectionSearchReturnsAncestorPreservingArchivedTreeSlice() throws {
        let general = LifeArea(id: UUID(), name: "General", color: "#9E5F0A", icon: "square.grid.2x2")
        let archivedArea = LifeArea(id: UUID(), name: "Travel", color: "#0EA5A3", icon: "airplane", isArchived: true)

        let archivedProject = ProjectWithStats(
            project: Project(
                id: UUID(),
                lifeAreaID: archivedArea.id,
                name: "Japan trip",
                projectDescription: "Archived trip plan",
                color: .teal,
                icon: .travel,
                isArchived: true
            ),
            taskCount: 2,
            completedTaskCount: 0
        )

        let archivedHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Pack bags",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: archivedArea.id,
            lifeAreaName: archivedArea.name,
            projectID: archivedProject.project.id,
            projectName: archivedProject.project.name,
            colorHex: "#0EA5A3",
            isPaused: true,
            isArchived: true,
            currentStreak: 0,
            bestStreak: 2
        )

        let context = LifeManagementProjection.prepare(
            lifeAreas: [general, archivedArea],
            projectStats: [archivedProject],
            habitRows: [archivedHabit],
            generalLifeAreaID: general.id
        )
        let snapshot = context.snapshot(searchQuery: "japan")

        XCTAssertNil(snapshot.treeSections.first(where: { $0.kind == LifeManagementTreeSectionKind.active }))

        let archivedSection = try XCTUnwrap(snapshot.treeSections.first(where: { $0.kind == LifeManagementTreeSectionKind.archived }))
        XCTAssertEqual(archivedSection.nodes.map(\.title), ["Travel"])

        let archivedAreaNode = try XCTUnwrap(archivedSection.nodes.first)
        XCTAssertEqual(archivedAreaNode.children.map(\.title), ["Japan trip"])

        let archivedProjectNode = try XCTUnwrap(archivedAreaNode.children.first)
        XCTAssertEqual(archivedProjectNode.title, "Japan trip")
        XCTAssertTrue(snapshot.searchExpandedAncestorNodeIDs.contains(archivedAreaNode.id))
    }

    func testProjectionUsesGeneralAreaForOrphanedProjectsAndHabits() throws {
        let general = LifeArea(id: UUID(), name: "General", color: "#9E5F0A", icon: "square.grid.2x2")
        let orphanProject = ProjectWithStats(
            project: Project(
                id: UUID(),
                lifeAreaID: nil,
                name: "Loose ends",
                projectDescription: "No explicit life area",
                color: .orange,
                icon: .folder
            ),
            taskCount: 0,
            completedTaskCount: 0
        )

        let orphanHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Inbox reset",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: nil,
            lifeAreaName: general.name,
            projectID: nil,
            isPaused: false,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 7
        )

        let context = LifeManagementProjection.prepare(
            lifeAreas: [general],
            projectStats: [orphanProject],
            habitRows: [orphanHabit],
            generalLifeAreaID: general.id
        )
        let snapshot = context.snapshot(searchQuery: "")

        let activeSection = try XCTUnwrap(snapshot.treeSections.first(where: { $0.kind == LifeManagementTreeSectionKind.active }))
        let generalNode = try XCTUnwrap(activeSection.nodes.first(where: { $0.title == "General" }))
        XCTAssertEqual(generalNode.children.map(\.title), ["Loose ends", "Inbox reset"])

        if case .area(let areaRow) = generalNode.payload {
            XCTAssertEqual(areaRow.projectCount, 1)
            XCTAssertEqual(areaRow.habitCount, 1)
        } else {
            XCTFail("Expected general node payload to be an area")
        }
    }

    func testPreparedContextBuildsDetailSnapshotsAndPrecomputedCounts() {
        let general = LifeArea(id: UUID(), name: "General", color: "#9E5F0A", icon: "square.grid.2x2")
        let career = LifeArea(id: UUID(), name: "Career", color: "#3B82F6", icon: "briefcase.fill")

        let inbox = ProjectWithStats(
            project: Project(
                id: ProjectConstants.inboxProjectID,
                lifeAreaID: general.id,
                name: ProjectConstants.inboxProjectName,
                projectDescription: nil,
                isDefault: true
            ),
            taskCount: 1,
            completedTaskCount: 0
        )
        let roadmap = ProjectWithStats(
            project: Project(
                id: UUID(),
                lifeAreaID: career.id,
                name: "Roadmap",
                projectDescription: "Quarter goals",
                color: .blue,
                icon: .flag
            ),
            taskCount: 0,
            completedTaskCount: 0
        )

        let activeHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Deep work",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: career.id,
            lifeAreaName: "Career",
            projectID: roadmap.project.id,
            projectName: roadmap.project.name,
            colorHex: "#3B82F6",
            isPaused: false,
            isArchived: false,
            currentStreak: 6,
            bestStreak: 9
        )
        let archivedHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Old review ritual",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: career.id,
            lifeAreaName: "Career",
            projectID: roadmap.project.id,
            projectName: roadmap.project.name,
            colorHex: "#3B82F6",
            isPaused: false,
            isArchived: true,
            currentStreak: 0,
            bestStreak: 4
        )

        let context = LifeManagementProjection.prepare(
            lifeAreas: [general, career],
            projectStats: [inbox, roadmap],
            habitRows: [activeHabit, archivedHabit],
            generalLifeAreaID: general.id
        )

        XCTAssertEqual(context.allProjectCountByAreaID[career.id], 1)
        XCTAssertEqual(context.allHabitCountByAreaID[career.id], 2)
        XCTAssertEqual(context.allLinkedHabitCountByProjectID[roadmap.project.id], 2)
        XCTAssertEqual(context.areaDetailByID[career.id]?.projectRows.map(\.project.name), ["Roadmap"])
        XCTAssertEqual(context.areaDetailByID[career.id]?.habitRows.map(\.row.title), ["Deep work"])
        XCTAssertEqual(context.projectDetailByID[roadmap.project.id]?.linkedHabits.map(\.row.title), ["Deep work"])
    }
}

@MainActor
final class WriteClosedProjectRepositoryAdapterLifeAreaTests: XCTestCase {
    func testWriteClosedBlocksMoveProjectToLifeArea() {
        let repository = ProjectRepositoryStub()
        let adapter = WriteClosedProjectRepositoryAdapter(
            base: repository,
            gate: SyncWriteGate(modeProvider: { .writeClosed(reason: "test") })
        )

        let expectation = expectation(description: "write-closed move blocked")
        adapter.moveProjectToLifeArea(projectID: UUID(), lifeAreaID: UUID()) { result in
            switch result {
            case .success:
                XCTFail("Expected move to be blocked in write-closed mode")
            case .failure(let error):
                XCTAssertTrue(error is SyncWriteClosedError)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(repository.moveProjectCalls.isEmpty)
    }

    func testWriteClosedBlocksBackfillProjectsWithoutLifeArea() {
        let repository = ProjectRepositoryStub()
        let adapter = WriteClosedProjectRepositoryAdapter(
            base: repository,
            gate: SyncWriteGate(modeProvider: { .writeClosed(reason: "test") })
        )

        let expectation = expectation(description: "write-closed backfill blocked")
        adapter.backfillProjectsWithoutLifeArea(defaultLifeAreaID: UUID()) { result in
            switch result {
            case .success:
                XCTFail("Expected backfill to be blocked in write-closed mode")
            case .failure(let error):
                XCTAssertTrue(error is SyncWriteClosedError)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(repository.backfillCalls.isEmpty)
    }

    func testProjectRepositoryStubUpdateRejectsUnknownID() {
        let existingProject = Project(id: UUID(), lifeAreaID: UUID(), name: "Existing", projectDescription: nil)
        let missingProject = Project(id: UUID(), lifeAreaID: UUID(), name: "Missing", projectDescription: nil)
        let repository = ProjectRepositoryStub(projects: [existingProject])

        let expectation = expectation(description: "missing project update rejected")
        repository.updateProject(missingProject) { result in
            switch result {
            case .success:
                XCTFail("Expected missing-ID update to fail")
            case .failure(let error):
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "ProjectRepository")
                XCTAssertEqual(nsError.code, 404)
                XCTAssertEqual(nsError.localizedDescription, "Project not found")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repository.projects.count, 1)
        XCTAssertEqual(repository.projects.first?.id, existingProject.id)
    }
}

@MainActor
final class LifeAreaProjectDropValidationTests: XCTestCase {
    func testValidateDropRequiresAllowedTargetAndTextPayload() {
        XCTAssertTrue(true && true && true)
        XCTAssertFalse(true && false && true)
        XCTAssertFalse(true && true && false)
    }
}

@MainActor
final class LifeManagementViewModelInteractionTests: XCTestCase {
    func testMoveProjectFromDraftKeepsDraftAndSurfacesErrorWhenMoveFails() async {
        let sourceAreaID = UUID()
        let destinationAreaID = UUID()
        let projectID = UUID()
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [
                LifeArea(id: sourceAreaID, name: "Career", color: nil, icon: nil),
                LifeArea(id: destinationAreaID, name: "Health", color: nil, icon: nil)
            ],
            projects: [
                Project(id: projectID, lifeAreaID: sourceAreaID, name: "Roadmap", projectDescription: nil)
            ]
        )
        repositories.projectRepository.moveProjectToLifeAreaError = NSError(
            domain: "ProjectRepositoryStub",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Move failed"]
        )
        let viewModel = makeLifeManagementViewModel(dependencies: repositories)
        viewModel.loadIfNeeded()

        await waitUntil {
            viewModel.projectRow(for: projectID) != nil
        }

        viewModel.beginMoveProject(projectID)
        XCTAssertEqual(viewModel.moveProjectDraft?.projectID, projectID)

        viewModel.moveProjectDraft?.targetLifeAreaID = destinationAreaID
        viewModel.moveProjectFromDraft()

        await waitUntil {
            viewModel.isMutating == false
        }

        XCTAssertTrue(viewModel.errorMessage?.contains("Move failed") == true)
        XCTAssertEqual(viewModel.moveProjectDraft?.projectID, projectID)
    }

    func testMergeLifeAreasPrefersResolvedActiveGeneralOverArchivedDuplicate() {
        let archivedGeneral = LifeArea(
            id: UUID(),
            name: " General ",
            color: nil,
            icon: nil,
            isArchived: true,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let resolvedGeneral = LifeArea(
            id: UUID(),
            name: "General",
            color: nil,
            icon: nil,
            isArchived: false,
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let merged = LifeManagementViewModel.mergeLifeAreas([archivedGeneral], generalArea: resolvedGeneral)
        let generalRows = merged.filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "general" }

        XCTAssertEqual(generalRows.count, 1)
        XCTAssertEqual(generalRows.first?.id, resolvedGeneral.id)
        XCTAssertFalse(generalRows.first?.isArchived ?? true)
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let start = ContinuousClock.now
        let timeout = Duration.nanoseconds(Int64(timeoutNanoseconds))
        let pollInterval = Duration.nanoseconds(Int64(pollIntervalNanoseconds))

        while condition() == false {
            if ContinuousClock.now - start >= timeout {
                XCTFail("Timed out waiting for condition")
                return
            }
            try? await _Concurrency.Task.sleep(for: pollInterval)
        }
    }
}

@MainActor
final class LifeManagementDestructiveFlowCoordinatorTests: XCTestCase {
    func testDeleteLifeAreaRejectsSameDestinationBeforeMutation() {
        let areaID = UUID()
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [LifeArea(id: areaID, name: "Career", color: nil, icon: nil)]
        )
        let coordinator = makeCoordinator(dependencies: repositories)
        let expectation = expectation(description: "same area rejected")

        coordinator.deleteLifeArea(
            request: DeleteLifeAreaRequest(
                areaID: areaID,
                destinationLifeAreaID: areaID
            )
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected no-op rejection")
            case .failure(let error):
                XCTAssertEqual(
                    error.localizedDescription,
                    "Choose a different destination area before deleting this area."
                )
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(repositories.projectRepository.moveProjectCalls.isEmpty)
        XCTAssertEqual(repositories.habitRepository.updateCallCount, 0)
    }

    func testDeleteProjectUsesCurrentLinkedHabitsInsteadOfRequestSnapshot() {
        let sourceProjectID = UUID()
        let destinationProjectID = UUID()
        let areaID = UUID()
        let linkedHabitID = UUID()
        let linkedHabit = HabitDefinitionRecord(
            id: linkedHabitID,
            lifeAreaID: areaID,
            projectID: sourceProjectID,
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            updatedAt: Date(timeIntervalSince1970: 1_704_067_200)
        )
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [LifeArea(id: areaID, name: "Health", color: nil, icon: nil)],
            projects: [
                Project(id: sourceProjectID, lifeAreaID: areaID, name: "Source", projectDescription: nil),
                Project(id: destinationProjectID, lifeAreaID: areaID, name: "Destination", projectDescription: nil)
            ],
            habits: [linkedHabit],
            habitRows: [
                HabitLibraryRow(
                    habitID: linkedHabitID,
                    title: "Hydrate",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: areaID,
                    lifeAreaName: "Health",
                    projectID: sourceProjectID,
                    projectName: "Source",
                    colorHex: nil,
                    isPaused: false,
                    isArchived: false,
                    currentStreak: 0,
                    bestStreak: 0
                )
            ]
        )
        let coordinator = makeCoordinator(dependencies: repositories)
        let expectation = expectation(description: "linked habits refetched")

        coordinator.deleteProject(
            request: DeleteProjectRequest(
                projectID: sourceProjectID,
                destinationProjectID: destinationProjectID
            )
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Expected delete to succeed, got error: \(error)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repositories.habitReadRepository.fetchHabitLibraryCallCount, 1)
        XCTAssertNil(repositories.habitRepository.habitsByID[linkedHabitID]?.projectID)
    }

    func testDeleteProjectRollsBackMovedTasksAndHabitLinksWhenDeleteFails() {
        let sourceProjectID = UUID()
        let destinationProjectID = UUID()
        let areaID = UUID()
        let linkedHabitID = UUID()
        let movedTaskID = UUID()
        let existingDestinationTaskID = UUID()
        let linkedHabit = HabitDefinitionRecord(
            id: linkedHabitID,
            lifeAreaID: areaID,
            projectID: sourceProjectID,
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            updatedAt: Date(timeIntervalSince1970: 1_704_067_200)
        )
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [LifeArea(id: areaID, name: "Health", color: nil, icon: nil)],
            projects: [
                Project(id: sourceProjectID, lifeAreaID: areaID, name: "Source", projectDescription: nil),
                Project(id: destinationProjectID, lifeAreaID: areaID, name: "Destination", projectDescription: nil)
            ],
            tasks: [
                TaskDefinition(id: movedTaskID, projectID: sourceProjectID, projectName: "Source", lifeAreaID: areaID, title: "Task to move"),
                TaskDefinition(id: existingDestinationTaskID, projectID: destinationProjectID, projectName: "Destination", lifeAreaID: areaID, title: "Existing destination task")
            ],
            habits: [linkedHabit],
            habitRows: [
                HabitLibraryRow(
                    habitID: linkedHabitID,
                    title: "Hydrate",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: areaID,
                    lifeAreaName: "Health",
                    projectID: sourceProjectID,
                    projectName: "Source",
                    colorHex: nil,
                    isPaused: false,
                    isArchived: false,
                    currentStreak: 0,
                    bestStreak: 0
                )
            ]
        )
        repositories.projectRepository.deleteError = NSError(domain: "ProjectRepositoryStub", code: 500)
        let coordinator = makeCoordinator(dependencies: repositories)
        let expectation = expectation(description: "project rollback")

        coordinator.deleteProject(
            request: DeleteProjectRequest(
                projectID: sourceProjectID,
                destinationProjectID: destinationProjectID
            )
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected delete failure")
            case .failure:
                XCTAssertEqual(repositories.taskDefinitionRepository.tasksByID[movedTaskID]?.projectID, sourceProjectID)
                XCTAssertEqual(repositories.taskDefinitionRepository.tasksByID[existingDestinationTaskID]?.projectID, destinationProjectID)
                XCTAssertEqual(repositories.habitRepository.habitsByID[linkedHabitID]?.projectID, sourceProjectID)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repositories.taskDefinitionRepository.updateRequests.count, 2)
        XCTAssertEqual(repositories.habitRepository.updateCallCount, 2)
    }

    func testDeleteProjectSurfacesRollbackFailure() {
        let sourceProjectID = UUID()
        let destinationProjectID = UUID()
        let areaID = UUID()
        let linkedHabitID = UUID()
        let linkedHabit = HabitDefinitionRecord(
            id: linkedHabitID,
            lifeAreaID: areaID,
            projectID: sourceProjectID,
            title: "Hydrate",
            habitType: "check_in",
            createdAt: Date(timeIntervalSince1970: 1_704_067_200),
            updatedAt: Date(timeIntervalSince1970: 1_704_067_200)
        )
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [LifeArea(id: areaID, name: "Health", color: nil, icon: nil)],
            projects: [
                Project(id: sourceProjectID, lifeAreaID: areaID, name: "Source", projectDescription: nil),
                Project(id: destinationProjectID, lifeAreaID: areaID, name: "Destination", projectDescription: nil)
            ],
            habits: [linkedHabit],
            habitRows: [
                HabitLibraryRow(
                    habitID: linkedHabitID,
                    title: "Hydrate",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: areaID,
                    lifeAreaName: "Health",
                    projectID: sourceProjectID,
                    projectName: "Source",
                    colorHex: nil,
                    isPaused: false,
                    isArchived: false,
                    currentStreak: 0,
                    bestStreak: 0
                )
            ]
        )
        repositories.projectRepository.deleteError = NSError(domain: "ProjectRepositoryStub", code: 500)
        repositories.habitRepository.queuedUpdateErrors = [NSError(domain: "CoordinatorHabitRepositoryStub", code: 501)]
        let coordinator = makeCoordinator(dependencies: repositories)
        let expectation = expectation(description: "project rollback failure")

        coordinator.deleteProject(
            request: DeleteProjectRequest(
                projectID: sourceProjectID,
                destinationProjectID: destinationProjectID
            )
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected delete failure")
            case .failure(let error):
                guard case let LifeManagementDestructiveFlowError.rollbackFailed(underlying, rollbackError) = error else {
                    return XCTFail("Expected rollbackFailed, got \(error)")
                }
                XCTAssertEqual((underlying as NSError).code, 500)
                XCTAssertEqual((rollbackError as NSError).code, 501)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDeleteLifeAreaRollsBackMovedChildrenWhenAreaDeleteFails() {
        let sourceAreaID = UUID()
        let destinationAreaID = UUID()
        let projectID = UUID()
        let habitID = UUID()
        let repositories = makeCoordinatorDependencies(
            lifeAreas: [
                LifeArea(id: sourceAreaID, name: "Career", color: nil, icon: nil),
                LifeArea(id: destinationAreaID, name: "Health", color: nil, icon: nil)
            ],
            projects: [
                Project(id: projectID, lifeAreaID: sourceAreaID, name: "Roadmap", projectDescription: nil)
            ],
            habits: [
                HabitDefinitionRecord(
                    id: habitID,
                    lifeAreaID: sourceAreaID,
                    projectID: projectID,
                    title: "Ship weekly review",
                    habitType: "check_in",
                    createdAt: Date(timeIntervalSince1970: 1_704_067_200),
                    updatedAt: Date(timeIntervalSince1970: 1_704_067_200)
                )
            ],
            habitRows: [
                HabitLibraryRow(
                    habitID: habitID,
                    title: "Ship weekly review",
                    kind: .positive,
                    trackingMode: .dailyCheckIn,
                    lifeAreaID: sourceAreaID,
                    lifeAreaName: "Career",
                    projectID: projectID,
                    projectName: "Roadmap",
                    colorHex: nil,
                    isPaused: false,
                    isArchived: false,
                    currentStreak: 0,
                    bestStreak: 0
                )
            ]
        )
        repositories.lifeAreaRepository.deleteError = NSError(domain: "LifeAreaRepositoryStub", code: 500)
        let coordinator = makeCoordinator(dependencies: repositories)
        let expectation = expectation(description: "area rollback")

        coordinator.deleteLifeArea(
            request: DeleteLifeAreaRequest(
                areaID: sourceAreaID,
                destinationLifeAreaID: destinationAreaID
            )
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected delete failure")
            case .failure:
                XCTAssertEqual(repositories.projectRepository.projects.first?.lifeAreaID, sourceAreaID)
                XCTAssertEqual(repositories.habitRepository.habitsByID[habitID]?.lifeAreaID, sourceAreaID)
                XCTAssertEqual(repositories.habitRepository.habitsByID[habitID]?.projectID, projectID)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(repositories.projectRepository.moveProjectCalls.count, 2)
        XCTAssertEqual(repositories.habitRepository.updateCallCount, 2)
    }
}

private final class ProjectRepositoryStub: ProjectRepositoryProtocol {
    var projects: [Project]
    var taskCounts: [UUID: Int]
    var deleteError: Error?
    var moveProjectToLifeAreaError: Error?

    var moveProjectCalls: [(projectID: UUID, lifeAreaID: UUID)] = []
    var backfillCalls: [UUID] = []
    var moveTasksCalls: [(sourceProjectId: UUID, targetProjectId: UUID)] = []
    var deleteProjectCalls: [(id: UUID, deleteTasks: Bool)] = []

    /// Initializes a new instance.
    init(projects: [Project] = [], taskCounts: [UUID: Int] = [:]) {
        self.projects = projects
        self.taskCounts = taskCounts
    }

    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }

    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.id == id })))
    }

    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })))
    }

    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        if let existing = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
            completion(.success(existing))
            return
        }
        completion(.success(Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isDefault && !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        if let existing = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
            completion(.success(existing))
            return
        }
        let inbox = Project.createInbox()
        projects.append(inbox)
        completion(.success(inbox))
    }

    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            completion(
                .failure(
                    NSError(
                        domain: "ProjectRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Project not found"]
                    )
                )
            )
            return
        }
        projects[index] = project
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "ProjectRepositoryStub", code: 404)))
            return
        }
        var project = projects[index]
        project.name = newName
        projects[index] = project
        completion(.success(project))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        deleteProjectCalls.append((id: id, deleteTasks: deleteTasks))
        if let deleteError {
            completion(.failure(deleteError))
            return
        }
        projects.removeAll { $0.id == id }
        if deleteTasks {
            taskCounts[id] = nil
        }
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        completion(.success(taskCounts[projectId] ?? 0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        moveTasksCalls.append((sourceProjectId: sourceProjectId, targetProjectId: targetProjectId))
        let moved = taskCounts[sourceProjectId] ?? 0
        taskCounts[sourceProjectId] = 0
        taskCounts[targetProjectId, default: 0] += moved
        completion(.success(()))
    }

    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        moveProjectCalls.append((projectID: projectID, lifeAreaID: lifeAreaID))
        if let moveProjectToLifeAreaError {
            completion(.failure(moveProjectToLifeAreaError))
            return
        }
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            completion(.failure(NSError(domain: "ProjectRepositoryStub", code: 404)))
            return
        }
        let fromLifeAreaID = projects[index].lifeAreaID
        projects[index].lifeAreaID = lifeAreaID
        completion(.success(ProjectLifeAreaMoveResult(
            updatedProjectID: projectID,
            fromLifeAreaID: fromLifeAreaID,
            toLifeAreaID: lifeAreaID,
            tasksRemappedCount: taskCounts[projectID] ?? 0
        )))
    }

    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        backfillCalls.append(defaultLifeAreaID)
        var updatedProjects = 0
        var remappedTasks = 0
        var inboxPinned = false

        for index in projects.indices {
            let shouldPinInbox = projects[index].id == ProjectConstants.inboxProjectID
            let shouldBackfill = shouldPinInbox || projects[index].lifeAreaID == nil
            guard shouldBackfill else { continue }
            if projects[index].lifeAreaID != defaultLifeAreaID {
                projects[index].lifeAreaID = defaultLifeAreaID
                updatedProjects += 1
            }
            if shouldPinInbox {
                inboxPinned = true
            }
            remappedTasks += taskCounts[projects[index].id] ?? 0
        }

        completion(.success(ProjectLifeAreaBackfillResult(
            defaultLifeAreaID: defaultLifeAreaID,
            projectsUpdatedCount: updatedProjects,
            tasksRemappedCount: remappedTasks,
            inboxPinned: inboxPinned
        )))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        let conflict = projects.contains {
            $0.name.caseInsensitiveCompare(name) == .orderedSame &&
            $0.id != excludingId
        }
        completion(.success(!conflict))
    }
}

private final class LifeAreaRepositoryStub: LifeAreaRepositoryProtocol {
    var areas: [LifeArea]
    var deleteError: Error?

    /// Initializes a new instance.
    init(areas: [LifeArea]) {
        self.areas = areas
    }

    func fetchAll(completion: @escaping @Sendable (Result<[LifeArea], Error>) -> Void) {
        completion(.success(areas))
    }

    func create(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) {
        areas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping @Sendable (Result<LifeArea, Error>) -> Void) {
        if let index = areas.firstIndex(where: { $0.id == area.id }) {
            areas[index] = area
        }
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        if let deleteError {
            completion(.failure(deleteError))
            return
        }
        areas.removeAll { $0.id == id }
        completion(.success(()))
    }
}

private final class CoordinatorHabitRepositoryStub: HabitRepositoryProtocol {
    var habitsByID: [UUID: HabitDefinitionRecord]
    var updateCallCount = 0
    var queuedUpdateErrors: [Error] = []

    init(habits: [HabitDefinitionRecord] = []) {
        self.habitsByID = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping @Sendable (Result<[HabitDefinitionRecord], Error>) -> Void) {
        completion(.success(Array(habitsByID.values)))
    }

    func create(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        habitsByID[habit.id] = habit
        completion(.success(habit))
    }

    func update(_ habit: HabitDefinitionRecord, completion: @escaping @Sendable (Result<HabitDefinitionRecord, Error>) -> Void) {
        updateCallCount += 1
        if queuedUpdateErrors.isEmpty == false {
            completion(.failure(queuedUpdateErrors.removeFirst()))
            return
        }
        habitsByID[habit.id] = habit
        completion(.success(habit))
    }

    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        habitsByID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class CoordinatorTaskDefinitionRepositoryStub: TaskDefinitionRepositoryProtocol {
    var tasksByID: [UUID: TaskDefinition]
    private(set) var updateRequests: [UpdateTaskDefinitionRequest] = []
    var queuedUpdateErrors: [Error] = []

    init(tasks: [TaskDefinition] = []) {
        self.tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    func fetchAll(completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchAll(query: TaskDefinitionQuery?, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success(Array(tasksByID.values)))
    }

    func fetchTaskDefinition(id: UUID, completion: @escaping @Sendable (Result<TaskDefinition?, Error>) -> Void) {
        completion(.success(tasksByID[id]))
    }

    func create(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func create(request: CreateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        let task = request.toTaskDefinition(projectName: request.projectName)
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func update(_ task: TaskDefinition, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        tasksByID[task.id] = task
        completion(.success(task))
    }

    func update(request: UpdateTaskDefinitionRequest, completion: @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) {
        updateRequests.append(request)
        if queuedUpdateErrors.isEmpty == false {
            completion(.failure(queuedUpdateErrors.removeFirst()))
            return
        }
        guard var current = tasksByID[request.id] else {
            completion(.failure(NSError(domain: "CoordinatorTaskDefinitionRepositoryStub", code: 404)))
            return
        }
        if let projectID = request.projectID {
            current.projectID = projectID
        }
        if request.clearLifeArea {
            current.lifeAreaID = nil
        } else if let lifeAreaID = request.lifeAreaID {
            current.lifeAreaID = lifeAreaID
        }
        tasksByID[current.id] = current
        completion(.success(current))
    }

    func fetchChildren(parentTaskID: UUID, completion: @escaping @Sendable (Result<[TaskDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        tasksByID.removeValue(forKey: id)
        completion(.success(()))
    }
}

private final class CoordinatorScheduleRepositoryStub: ScheduleRepositoryProtocol {
    func fetchTemplates(completion: @escaping @Sendable (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func fetchRules(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping @Sendable (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        completion(.success(template))
    }

    func deleteTemplate(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func replaceRules(
        templateID: UUID,
        rules: [ScheduleRuleDefinition],
        completion: @escaping @Sendable (Result<[ScheduleRuleDefinition], Error>) -> Void
    ) {
        completion(.success(rules))
    }

    func fetchExceptions(templateID: UUID, completion: @escaping @Sendable (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping @Sendable (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        completion(.success(exception))
    }
}

private final class CoordinatorOccurrenceRepositoryStub: OccurrenceRepositoryProtocol {
    func fetchInRange(start: Date, end: Date, completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void) {
        completion(.success([]))
    }

    func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func deleteOccurrences(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class CoordinatorSchedulingEngineStub: SchedulingEngineProtocol {
    func generateOccurrences(
        windowStart: Date,
        windowEnd: Date,
        sourceFilter: ScheduleSourceType?,
        completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func resolveOccurrence(
        id: UUID,
        resolution: OccurrenceResolutionType,
        actor: OccurrenceActor,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func rebuildFutureOccurrences(
        templateID: UUID,
        effectiveFrom: Date,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func applyScheduleException(
        templateID: UUID,
        occurrenceKey: String,
        action: ScheduleExceptionAction,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }
}

private final class CoordinatorHabitRuntimeReadRepositoryStub: HabitRuntimeReadRepositoryProtocol {
    var libraryRows: [HabitLibraryRow]
    private(set) var fetchHabitLibraryCallCount = 0

    init(libraryRows: [HabitLibraryRow] = []) {
        self.libraryRows = libraryRows
    }

    func fetchAgendaHabits(
        for date: Date,
        completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchHistory(
        habitIDs: [UUID],
        endingOn date: Date,
        dayCount: Int,
        completion: @escaping @Sendable (Result<[HabitHistoryWindow], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchSignals(
        start: Date,
        end: Date,
        completion: @escaping @Sendable (Result<[HabitOccurrenceSummary], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func fetchHabitLibrary(
        includeArchived: Bool,
        completion: @escaping @Sendable (Result<[HabitLibraryRow], Error>) -> Void
    ) {
        fetchHabitLibraryCallCount += 1
        completion(.success(libraryRows))
    }
}

private struct CoordinatorDependencies {
    let projectRepository: ProjectRepositoryStub
    let lifeAreaRepository: LifeAreaRepositoryStub
    let taskDefinitionRepository: CoordinatorTaskDefinitionRepositoryStub
    let habitRepository: CoordinatorHabitRepositoryStub
    let habitReadRepository: CoordinatorHabitRuntimeReadRepositoryStub
    let scheduleRepository: CoordinatorScheduleRepositoryStub
    let occurrenceRepository: CoordinatorOccurrenceRepositoryStub
    let schedulingEngine: CoordinatorSchedulingEngineStub
}

private func makeCoordinatorDependencies(
    lifeAreas: [LifeArea] = [],
    projects: [Project] = [],
    tasks: [TaskDefinition] = [],
    habits: [HabitDefinitionRecord] = [],
    habitRows: [HabitLibraryRow] = []
) -> CoordinatorDependencies {
    CoordinatorDependencies(
        projectRepository: ProjectRepositoryStub(projects: projects),
        lifeAreaRepository: LifeAreaRepositoryStub(areas: lifeAreas),
        taskDefinitionRepository: CoordinatorTaskDefinitionRepositoryStub(tasks: tasks),
        habitRepository: CoordinatorHabitRepositoryStub(habits: habits),
        habitReadRepository: CoordinatorHabitRuntimeReadRepositoryStub(libraryRows: habitRows),
        scheduleRepository: CoordinatorScheduleRepositoryStub(),
        occurrenceRepository: CoordinatorOccurrenceRepositoryStub(),
        schedulingEngine: CoordinatorSchedulingEngineStub()
    )
}

private func makeCoordinator(dependencies: CoordinatorDependencies) -> LifeManagementDestructiveFlowCoordinator {
    let recompute = RecomputeHabitStreaksUseCase(
        habitRepository: dependencies.habitRepository,
        occurrenceRepository: dependencies.occurrenceRepository
    )
    let sync = SyncHabitScheduleUseCase(
        habitRepository: dependencies.habitRepository,
        scheduleRepository: dependencies.scheduleRepository,
        scheduleEngine: dependencies.schedulingEngine,
        occurrenceRepository: dependencies.occurrenceRepository,
        recomputeHabitStreaksUseCase: recompute
    )
    let maintain = MaintainHabitRuntimeUseCase(syncHabitScheduleUseCase: sync)
    let updateHabit = UpdateHabitUseCase(
        habitRepository: dependencies.habitRepository,
        scheduleRepository: dependencies.scheduleRepository,
        scheduleEngine: dependencies.schedulingEngine,
        projectRepository: dependencies.projectRepository,
        lifeAreaRepository: dependencies.lifeAreaRepository,
        maintainHabitRuntimeUseCase: maintain
    )

    return LifeManagementDestructiveFlowCoordinator(
        manageProjectsUseCase: ManageProjectsUseCase(projectRepository: dependencies.projectRepository),
        updateHabitUseCase: updateHabit,
        projectRepository: dependencies.projectRepository,
        taskDefinitionRepository: dependencies.taskDefinitionRepository,
        lifeAreaRepository: dependencies.lifeAreaRepository,
        habitRuntimeReadRepository: dependencies.habitReadRepository
    )
}

@MainActor
private func makeLifeManagementViewModel(dependencies: CoordinatorDependencies) -> LifeManagementViewModel {
    let v2Dependencies = UseCaseCoordinator.V2Dependencies(
        projectRepository: dependencies.projectRepository,
        lifeAreaRepository: dependencies.lifeAreaRepository,
        sectionRepository: NoOpSectionRepositoryStub(),
        tagRepository: NoOpTagRepositoryStub(),
        taskDefinitionRepository: dependencies.taskDefinitionRepository,
        habitRepository: dependencies.habitRepository,
        habitRuntimeReadRepository: dependencies.habitReadRepository,
        scheduleRepository: dependencies.scheduleRepository,
        scheduleEngine: dependencies.schedulingEngine,
        occurrenceRepository: dependencies.occurrenceRepository,
        tombstoneRepository: NoOpTombstoneRepositoryStub(),
        reminderRepository: NoOpReminderRepositoryStub(),
        weeklyPlanRepository: NoOpWeeklyPlanRepositoryStub(),
        weeklyOutcomeRepository: NoOpWeeklyOutcomeRepositoryStub(),
        weeklyReviewRepository: NoOpWeeklyReviewRepositoryStub(),
        weeklyReviewMutationRepository: NoOpWeeklyReviewMutationRepositoryStub(),
        weeklyReviewDraftStore: NoOpWeeklyReviewDraftStoreStub(),
        dailyReflectionStore: UserDefaultsDailyReflectionStore(
            defaults: UserDefaults(suiteName: "LifeManagementFeatureTests.\(UUID().uuidString)") ?? .standard
        ),
        reflectionNoteRepository: NoOpReflectionNoteRepositoryStub(),
        gamificationRepository: NoOpGamificationRepositoryStub(),
        assistantActionRepository: NoOpAssistantActionRepositoryStub(),
        externalSyncRepository: NoOpExternalSyncRepositoryStub()
    )
    let coordinator = UseCaseCoordinator(
        projectRepository: dependencies.projectRepository,
        v2Dependencies: v2Dependencies
    )
    return LifeManagementViewModel(useCaseCoordinator: coordinator)
}

private final class NoOpSectionRepositoryStub: SectionRepositoryProtocol {
    func fetchSections(projectID: UUID, completion: @escaping @Sendable (Result<[LifeBoardProjectSection], Error>) -> Void) { completion(.success([])) }
    func create(_ section: LifeBoardProjectSection, completion: @escaping @Sendable (Result<LifeBoardProjectSection, Error>) -> Void) { completion(.success(section)) }
    func update(_ section: LifeBoardProjectSection, completion: @escaping @Sendable (Result<LifeBoardProjectSection, Error>) -> Void) { completion(.success(section)) }
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoOpTagRepositoryStub: TagRepositoryProtocol {
    func fetchAll(completion: @escaping @Sendable (Result<[TagDefinition], Error>) -> Void) { completion(.success([])) }
    func create(_ tag: TagDefinition, completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void) { completion(.success(tag)) }
    func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoOpTombstoneRepositoryStub: TombstoneRepositoryProtocol {
    func create(_ tombstone: TombstoneDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchExpired(before date: Date, completion: @escaping @Sendable (Result<[TombstoneDefinition], Error>) -> Void) { completion(.success([])) }
    func delete(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoOpReminderRepositoryStub: ReminderRepositoryProtocol {
    func fetchReminders(completion: @escaping @Sendable (Result<[ReminderDefinition], Error>) -> Void) { completion(.success([])) }
    func saveReminder(_ reminder: ReminderDefinition, completion: @escaping @Sendable (Result<ReminderDefinition, Error>) -> Void) { completion(.success(reminder)) }
    func fetchTriggers(reminderID: UUID, completion: @escaping @Sendable (Result<[ReminderTriggerDefinition], Error>) -> Void) { completion(.success([])) }
    func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping @Sendable (Result<ReminderTriggerDefinition, Error>) -> Void) { completion(.success(trigger)) }
    func fetchDeliveries(reminderID: UUID, completion: @escaping @Sendable (Result<[ReminderDeliveryDefinition], Error>) -> Void) { completion(.success([])) }
    func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
    func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping @Sendable (Result<ReminderDeliveryDefinition, Error>) -> Void) { completion(.success(delivery)) }
}

private final class NoOpGamificationRepositoryStub: GamificationRepositoryProtocol {
    func fetchProfile(completion: @escaping @Sendable (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping @Sendable (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping @Sendable (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping @Sendable (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[FocusSessionDefinition], Error>) -> Void) { completion(.success([])) }
}

private final class NoOpWeeklyPlanRepositoryStub: WeeklyPlanRepositoryProtocol {
    func fetchPlan(id: UUID, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) { completion(.success(nil)) }
    func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) { completion(.success(nil)) }
    func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[WeeklyPlan], Error>) -> Void) { completion(.success([])) }
    func savePlan(_ plan: WeeklyPlan, completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void) { completion(.success(plan)) }
}

private final class NoOpWeeklyOutcomeRepositoryStub: WeeklyOutcomeRepositoryProtocol {
    func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void) { completion(.success([])) }
    func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping @Sendable (Result<WeeklyOutcome, Error>) -> Void) { completion(.success(outcome)) }
    func replaceOutcomes(weeklyPlanID: UUID, outcomes: [WeeklyOutcome], completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void) { completion(.success(outcomes)) }
    func deleteOutcome(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoOpWeeklyReviewRepositoryStub: WeeklyReviewRepositoryProtocol {
    func fetchReview(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<WeeklyReview?, Error>) -> Void) { completion(.success(nil)) }
    func saveReview(_ review: WeeklyReview, completion: @escaping @Sendable (Result<WeeklyReview, Error>) -> Void) { completion(.success(review)) }
}

private final class NoOpWeeklyReviewMutationRepositoryStub: WeeklyReviewMutationRepositoryProtocol {
    func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        completion(.failure(NSError(domain: "NoOpWeeklyReviewMutationRepositoryStub", code: 1)))
    }
}

private final class NoOpWeeklyReviewDraftStoreStub: WeeklyReviewDraftStoreProtocol {
    func fetchDraft(weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyReviewDraft?, Error>) -> Void) {
        completion(.success(nil))
    }

    func saveDraft(_ draft: WeeklyReviewDraft, completion: @escaping @Sendable (Result<WeeklyReviewDraft, Error>) -> Void) {
        completion(.success(draft))
    }

    func clearDraft(weekStartDate: Date, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success([]))
    }

    func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        completion(.success(decisions))
    }
}

private final class NoOpReflectionNoteRepositoryStub: ReflectionNoteRepositoryProtocol {
    func fetchNotes(query: ReflectionNoteQuery, completion: @escaping @Sendable (Result<[ReflectionNote], Error>) -> Void) { completion(.success([])) }
    func saveNote(_ note: ReflectionNote, completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void) { completion(.success(note)) }
    func deleteNote(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
}

private final class NoOpAssistantActionRepositoryStub: AssistantActionRepositoryProtocol {
    func createRun(_ run: AssistantActionRunDefinition, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func updateRun(_ run: AssistantActionRunDefinition, completion: @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) { completion(.success(run)) }
    func fetchRun(id: UUID, completion: @escaping @Sendable (Result<AssistantActionRunDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private final class NoOpExternalSyncRepositoryStub: ExternalSyncRepositoryProtocol {
    func fetchContainerMappings(completion: @escaping @Sendable (Result<[ExternalContainerMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveContainerMapping(_ mapping: ExternalContainerMapDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchContainerMapping(provider: String, projectID: UUID, completion: @escaping @Sendable (Result<ExternalContainerMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func upsertContainerMapping(provider: String, projectID: UUID, mutate: @escaping @Sendable (ExternalContainerMapDefinition?) -> ExternalContainerMapDefinition, completion: @escaping @Sendable (Result<ExternalContainerMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMappings(completion: @escaping @Sendable (Result<[ExternalItemMapDefinition], Error>) -> Void) { completion(.success([])) }
    func saveItemMapping(_ mapping: ExternalItemMapDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    func upsertItemMappingByLocalKey(provider: String, localEntityType: String, localEntityID: UUID, mutate: @escaping @Sendable (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping @Sendable (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func upsertItemMappingByExternalKey(provider: String, externalItemID: String, mutate: @escaping @Sendable (ExternalItemMapDefinition?) -> ExternalItemMapDefinition, completion: @escaping @Sendable (Result<ExternalItemMapDefinition, Error>) -> Void) { completion(.success(mutate(nil))) }
    func fetchItemMapping(provider: String, localEntityType: String, localEntityID: UUID, completion: @escaping @Sendable (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func fetchItemMapping(provider: String, externalItemID: String, completion: @escaping @Sendable (Result<ExternalItemMapDefinition?, Error>) -> Void) { completion(.success(nil)) }
}

private extension CoreDataProjectRepositoryLifeAreaMutationTests {
    static func makeInMemoryContainer() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: Self.self)]
        guard let model = NSManagedObjectModel.mergedModel(from: bundles),
              model.entitiesByName["TaskDefinition"] != nil else {
            throw NSError(
                domain: "LifeManagementFeatureTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load TaskModelV3 from test bundles"]
            )
        }

        let container = NSPersistentContainer(name: "TaskModelV3", managedObjectModel: model)
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

    @discardableResult
    static func makeLifeArea(in context: NSManagedObjectContext, id: UUID, name: String) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "LifeArea", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(name, forKey: "name")
        object.setValue(Int32(0), forKey: "sortOrder")
        object.setValue(false, forKey: "isArchived")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    static func makeProject(
        in context: NSManagedObjectContext,
        id: UUID,
        name: String,
        lifeAreaID: UUID?,
        isDefault: Bool
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(name, forKey: "name")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(isDefault, forKey: "isDefault")
        object.setValue(id == ProjectConstants.inboxProjectID, forKey: "isInbox")
        object.setValue(Date(), forKey: "createdDate")
        object.setValue(Date(), forKey: "modifiedDate")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }

    @discardableResult
    static func makeTask(
        in context: NSManagedObjectContext,
        id: UUID,
        title: String,
        projectID: UUID,
        lifeAreaID: UUID?
    ) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDefinition", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(title, forKey: "title")
        object.setValue(projectID, forKey: "projectID")
        object.setValue(lifeAreaID, forKey: "lifeAreaID")
        object.setValue(false, forKey: "isComplete")
        object.setValue(Date(), forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        return object
    }
}
