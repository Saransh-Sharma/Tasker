import XCTest
import CoreData
@testable import To_Do_List

final class ManageLifeAreasUseCaseTests: XCTestCase {
    func testUpdateLifeAreaNameAndIconSucceeds() {
        let area = LifeArea(id: UUID(), name: "Health", color: "#22C55E", icon: "heart.fill")
        let repository = LifeAreaRepositoryStub(areas: [area])
        let useCase = ManageLifeAreasUseCase(repository: repository)

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
                XCTAssertEqual(updated.color, "#16A34A")
                XCTAssertEqual(updated.icon, "leaf.fill")
                XCTAssertEqual(repository.areas.first?.name, "Wellness")
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
}

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

final class LifeManagementProjectionTests: XCTestCase {
    func testProjectionBuildsOverviewAndGroupsActiveEntitiesByArea() {
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

        let snapshot = LifeManagementProjection.build(
            lifeAreas: [general, career],
            projectStats: [inbox, roadmap],
            habitRows: [activeHabit, pausedHabit],
            selectedScope: .overview,
            selectedHabitFilter: .all,
            searchQuery: "",
            generalLifeAreaID: general.id
        )

        XCTAssertEqual(snapshot.overview.stats.map(\.value), ["2", "2", "2"])
        XCTAssertEqual(snapshot.areaRows.count, 2)
        XCTAssertEqual(snapshot.projectGroups.count, 2)
        XCTAssertEqual(snapshot.habitGroups.count, 2)
        XCTAssertTrue(snapshot.overview.attentionItems.contains(where: { $0.title.contains("empty project") }))
        XCTAssertTrue(snapshot.overview.attentionItems.contains(where: { $0.title.contains("paused habit") }))
        XCTAssertEqual(snapshot.projectGroups.first(where: { $0.title == "Career" })?.rows.first?.linkedHabitCount, 1)
        XCTAssertEqual(snapshot.habitGroups.first(where: { $0.title == "Career" })?.rows.first?.row.colorHex, "#3B82F6")
    }

    func testProjectionSearchesArchivedEntitiesSeparately() {
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

        let snapshot = LifeManagementProjection.build(
            lifeAreas: [general, archivedArea],
            projectStats: [archivedProject],
            habitRows: [archivedHabit],
            selectedScope: .archive,
            selectedHabitFilter: .all,
            searchQuery: "japan",
            generalLifeAreaID: general.id
        )

        XCTAssertEqual(snapshot.searchResults.areas.count, 0)
        XCTAssertEqual(snapshot.searchResults.projects.map(\.project.name), ["Japan trip"])
        XCTAssertEqual(snapshot.searchResults.habits.count, 0)
        XCTAssertEqual(snapshot.archiveSections.areas.count, 1)
        XCTAssertEqual(snapshot.archiveSections.projects.first?.rows.count, 1)
        XCTAssertEqual(snapshot.archiveSections.habits.first?.rows.count, 1)
    }

    func testProjectionAppliesPausedHabitFilter() {
        let general = LifeArea(id: UUID(), name: "General", color: "#9E5F0A", icon: "square.grid.2x2")

        let activeHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "Read",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: general.id,
            lifeAreaName: general.name,
            isPaused: false,
            isArchived: false,
            currentStreak: 3,
            bestStreak: 5
        )
        let pausedHabit = HabitLibraryRow(
            habitID: UUID(),
            title: "No sugar",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: general.id,
            lifeAreaName: general.name,
            isPaused: true,
            isArchived: false,
            currentStreak: 0,
            bestStreak: 7
        )

        let snapshot = LifeManagementProjection.build(
            lifeAreas: [general],
            projectStats: [],
            habitRows: [activeHabit, pausedHabit],
            selectedScope: .habits,
            selectedHabitFilter: .paused,
            searchQuery: "",
            generalLifeAreaID: general.id
        )

        XCTAssertEqual(snapshot.habitGroups.count, 1)
        XCTAssertEqual(snapshot.habitGroups.first?.rows.map(\.row.title), ["No sugar"])
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

final class LifeAreaProjectDropValidationTests: XCTestCase {
    func testValidateDropRequiresAllowedTargetAndTextPayload() {
        XCTAssertTrue(
            lifeAreaProjectDropIsValid(
                acceptsDrop: true,
                canDropProject: true,
                hasTextItem: true
            )
        )
        XCTAssertFalse(
            lifeAreaProjectDropIsValid(
                acceptsDrop: true,
                canDropProject: false,
                hasTextItem: true
            )
        )
        XCTAssertFalse(
            lifeAreaProjectDropIsValid(
                acceptsDrop: true,
                canDropProject: true,
                hasTextItem: false
            )
        )
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
