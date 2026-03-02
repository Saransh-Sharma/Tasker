import XCTest
import CoreData
@testable import To_Do_List

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
}

final class CoreDataProjectRepositoryLifeAreaMutationTests: XCTestCase {
    func testMoveProjectToLifeAreaRemapsProjectAndAllTasks() throws {
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let generalID = UUID()
        let targetAreaID = UUID()
        let projectID = UUID()

        context.performAndWait {
            makeLifeArea(in: context, id: generalID, name: "General")
            makeLifeArea(in: context, id: targetAreaID, name: "Career")
            makeProject(in: context, id: projectID, name: "Portfolio", lifeAreaID: generalID, isDefault: false)
            makeTask(in: context, id: UUID(), title: "Task A", projectID: projectID, lifeAreaID: generalID)
            makeTask(in: context, id: UUID(), title: "Task B", projectID: projectID, lifeAreaID: generalID)
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
        let container = try makeInMemoryContainer()
        let context = container.viewContext

        let generalID = UUID()
        let customProjectID = UUID()
        let assignedAreaID = UUID()
        let assignedProjectID = UUID()

        context.performAndWait {
            makeLifeArea(in: context, id: generalID, name: "General")
            makeLifeArea(in: context, id: assignedAreaID, name: "Learning")

            makeProject(
                in: context,
                id: ProjectConstants.inboxProjectID,
                name: ProjectConstants.inboxProjectName,
                lifeAreaID: nil,
                isDefault: true
            )
            makeProject(in: context, id: customProjectID, name: "Health Sprint", lifeAreaID: nil, isDefault: false)
            makeProject(in: context, id: assignedProjectID, name: "Study", lifeAreaID: assignedAreaID, isDefault: false)

            makeTask(in: context, id: UUID(), title: "Inbox Task", projectID: ProjectConstants.inboxProjectID, lifeAreaID: nil)
            makeTask(in: context, id: UUID(), title: "Custom Task", projectID: customProjectID, lifeAreaID: nil)
            makeTask(in: context, id: UUID(), title: "Assigned Task", projectID: assignedProjectID, lifeAreaID: assignedAreaID)

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

final class LifeManagementViewModelTests: XCTestCase {
    func testLoadGroupsProjectsByLifeAreaAndBackfillsUnassignedToGeneral() {
        let general = LifeArea(id: UUID(), name: "General", color: "#4A6FA5", icon: "square.grid.2x2")
        let career = LifeArea(id: UUID(), name: "Career", color: "#3B82F6", icon: "briefcase.fill")

        let inbox = Project(
            id: ProjectConstants.inboxProjectID,
            lifeAreaID: nil,
            name: ProjectConstants.inboxProjectName,
            projectDescription: nil,
            isDefault: true
        )
        let customUnassigned = Project(
            id: UUID(),
            lifeAreaID: nil,
            name: "Sleep Reset",
            projectDescription: "Night routine"
        )
        let customCareer = Project(
            id: UUID(),
            lifeAreaID: career.id,
            name: "Promotion Prep",
            projectDescription: "Quarter goals"
        )

        let projectRepository = ProjectRepositoryStub(
            projects: [inbox, customUnassigned, customCareer],
            taskCounts: [
                inbox.id: 1,
                customUnassigned.id: 2,
                customCareer.id: 3
            ]
        )
        let lifeAreaRepository = LifeAreaRepositoryStub(areas: [general, career])

        let viewModel = LifeManagementViewModel(
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: lifeAreaRepository),
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: projectRepository),
            projectRepository: projectRepository
        )

        viewModel.loadIfNeeded()
        waitUntil(timeout: 1.5) {
            viewModel.isLoading == false && viewModel.sections.count == 2
        }

        let generalSection = viewModel.sections.first(where: { $0.lifeArea.id == general.id })
        let careerSection = viewModel.sections.first(where: { $0.lifeArea.id == career.id })

        XCTAssertNotNil(generalSection)
        XCTAssertNotNil(careerSection)

        XCTAssertEqual(generalSection?.projects.count, 2)
        XCTAssertEqual(careerSection?.projects.count, 1)
        XCTAssertTrue(generalSection?.projects.contains(where: { $0.project.id == ProjectConstants.inboxProjectID }) ?? false)
        XCTAssertTrue(generalSection?.projects.contains(where: { $0.project.id == customUnassigned.id }) ?? false)
        XCTAssertEqual(projectRepository.backfillCalls, [general.id])
    }

    func testVisibleSuggestionsExcludesExistingSuggestedLifeAreas() {
        let general = LifeArea(id: UUID(), name: "General", color: nil, icon: nil)
        let health = LifeArea(id: UUID(), name: "Health", color: nil, icon: "heart.fill")
        let projectRepository = ProjectRepositoryStub(projects: [], taskCounts: [:])
        let lifeAreaRepository = LifeAreaRepositoryStub(areas: [general, health])

        let viewModel = LifeManagementViewModel(
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: lifeAreaRepository),
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: projectRepository),
            projectRepository: projectRepository
        )

        viewModel.loadIfNeeded()
        waitUntil(timeout: 1.0) {
            viewModel.isLoading == false && !viewModel.sections.isEmpty
        }

        XCTAssertFalse(viewModel.visibleSuggestions.contains(where: { $0.name == "Health" }))
        XCTAssertTrue(viewModel.visibleSuggestions.contains(where: { $0.name == "Career" }))
    }

    func testPerformDropMovesProjectAcrossSectionsAndClearsDragState() {
        let general = LifeArea(id: UUID(), name: "General", color: "#4A6FA5", icon: "square.grid.2x2")
        let career = LifeArea(id: UUID(), name: "Career", color: "#3B82F6", icon: "briefcase.fill")

        let project = Project(
            id: UUID(),
            lifeAreaID: career.id,
            name: "Promotion Prep",
            projectDescription: "Quarter goals"
        )

        let projectRepository = ProjectRepositoryStub(
            projects: [project],
            taskCounts: [project.id: 3]
        )
        let lifeAreaRepository = LifeAreaRepositoryStub(areas: [general, career])

        let viewModel = LifeManagementViewModel(
            manageLifeAreasUseCase: ManageLifeAreasUseCase(repository: lifeAreaRepository),
            manageProjectsUseCase: ManageProjectsUseCase(projectRepository: projectRepository),
            projectRepository: projectRepository
        )

        viewModel.loadIfNeeded()
        waitUntil(timeout: 1.0) {
            viewModel.isLoading == false && viewModel.sections.count == 2
        }

        viewModel.beginDrag(projectID: project.id)
        viewModel.dropEntered(targetLifeAreaID: general.id)
        XCTAssertEqual(viewModel.activeDropLifeAreaID, general.id)

        let handled = viewModel.performDrop(providers: [], targetLifeAreaID: general.id)
        XCTAssertTrue(handled)

        waitUntil(timeout: 1.0) {
            let generalContainsProject = viewModel.sections.first(where: { $0.lifeArea.id == general.id })?
                .projects
                .contains(where: { $0.project.id == project.id }) ?? false
            return generalContainsProject
                && viewModel.draggingProjectID == nil
                && viewModel.activeDropLifeAreaID == nil
                && viewModel.isMutating == false
        }

        XCTAssertEqual(projectRepository.moveProjectCalls.count, 1)
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = expectation(description: "wait-until")
        let deadline = Date().addingTimeInterval(timeout)

        func poll() {
            if condition() {
                expectation.fulfill()
                return
            }
            if Date() >= deadline {
                XCTFail("Timed out waiting for condition.")
                expectation.fulfill()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                poll()
            }
        }

        poll()
        waitForExpectations(timeout: timeout + 0.3)
    }
}

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
}

private final class ProjectRepositoryStub: ProjectRepositoryProtocol {
    var projects: [Project]
    var taskCounts: [UUID: Int]

    var moveProjectCalls: [(projectID: UUID, lifeAreaID: UUID)] = []
    var backfillCalls: [UUID] = []

    /// Initializes a new instance.
    init(projects: [Project] = [], taskCounts: [UUID: Int] = [:]) {
        self.projects = projects
        self.taskCounts = taskCounts
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.id == id })))
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })))
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        if let existing = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
            completion(.success(existing))
            return
        }
        completion(.success(Project.createInbox()))
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isDefault && !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        if let existing = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
            completion(.success(existing))
            return
        }
        let inbox = Project.createInbox()
        projects.append(inbox)
        completion(.success(inbox))
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "ProjectRepositoryStub", code: 404)))
            return
        }
        var project = projects[index]
        project.name = newName
        projects[index] = project
        completion(.success(project))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        projects.removeAll { $0.id == id }
        taskCounts[id] = nil
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(taskCounts[projectId] ?? 0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let moved = taskCounts[sourceProjectId] ?? 0
        taskCounts[sourceProjectId] = 0
        taskCounts[targetProjectId, default: 0] += moved
        completion(.success(()))
    }

    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        moveProjectCalls.append((projectID: projectID, lifeAreaID: lifeAreaID))
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
        completion: @escaping (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
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

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        let conflict = projects.contains {
            $0.name.caseInsensitiveCompare(name) == .orderedSame &&
            $0.id != excludingId
        }
        completion(.success(!conflict))
    }
}

private final class LifeAreaRepositoryStub: LifeAreaRepositoryProtocol {
    var areas: [LifeArea]

    /// Initializes a new instance.
    init(areas: [LifeArea]) {
        self.areas = areas
    }

    func fetchAll(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        completion(.success(areas))
    }

    func create(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        areas.append(area)
        completion(.success(area))
    }

    func update(_ area: LifeArea, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        if let index = areas.firstIndex(where: { $0.id == area.id }) {
            areas[index] = area
        }
        completion(.success(area))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        areas.removeAll { $0.id == id }
        completion(.success(()))
    }
}

private extension CoreDataProjectRepositoryLifeAreaMutationTests {
    func makeInMemoryContainer() throws -> NSPersistentContainer {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
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
    func makeLifeArea(in context: NSManagedObjectContext, id: UUID, name: String) -> NSManagedObject {
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
    func makeProject(
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
    func makeTask(
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
