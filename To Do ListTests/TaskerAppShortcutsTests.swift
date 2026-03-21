import XCTest
@testable import To_Do_List

final class TaskerShortcutDeepLinkTests: XCTestCase {
    func testChatDeepLinkRoundTripsPrompt() {
        let prompt = "What should I focus on first today?"
        let url = TaskerShortcutDeepLink.chatURL(prompt: prompt)

        XCTAssertEqual(url.absoluteString, "tasker://chat?prompt=What%20should%20I%20focus%20on%20first%20today%3F")
        XCTAssertEqual(TaskerShortcutDeepLink.chatPrompt(from: url), prompt)
    }

    func testChatDeepLinkOmitsBlankPrompt() {
        let url = TaskerShortcutDeepLink.chatURL(prompt: "   ")

        XCTAssertEqual(url.absoluteString, "tasker://chat")
        XCTAssertNil(TaskerShortcutDeepLink.chatPrompt(from: url))
    }

    func testChatLaunchRequestStoreConsumesPendingRequest() async {
        let request = EvaChatLaunchRequest(prompt: "Plan my day")

        await MainActor.run {
            EvaChatLaunchRequestStore.shared.submit(request)
            XCTAssertEqual(EvaChatLaunchRequestStore.shared.consumePendingRequest(), request)
            XCTAssertNil(EvaChatLaunchRequestStore.shared.consumePendingRequest())
        }
    }
}

final class InboxTaskCaptureServiceTests: XCTestCase {
    func testCreateTaskUsesExistingInboxProject() async throws {
        let inbox = Project.createInbox()
        let projectRepository = ShortcutProjectRepositoryStub(projects: [inbox])
        let taskRepository = InMemoryTaskDefinitionRepositoryStub()
        let service = InboxTaskCaptureService(
            projectRepository: projectRepository,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(repository: taskRepository)
        )

        let task = try await service.createTask(
            title: "  Ship app shortcuts  ",
            details: "  Wire Siri surfaces cleanly  "
        )

        XCTAssertEqual(task.title, "Ship app shortcuts")
        XCTAssertEqual(task.details, "Wire Siri surfaces cleanly")
        XCTAssertEqual(task.projectID, inbox.id)
        XCTAssertEqual(projectRepository.createProjectCallCount, 0)
    }

    func testCreateTaskEnsuresInboxWhenMissing() async throws {
        let projectRepository = ShortcutProjectRepositoryStub(projects: [])
        let taskRepository = InMemoryTaskDefinitionRepositoryStub()
        let service = InboxTaskCaptureService(
            projectRepository: projectRepository,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(repository: taskRepository)
        )

        let task = try await service.createTask(title: "Capture inbox task", details: nil)

        XCTAssertEqual(projectRepository.createProjectCallCount, 1)
        XCTAssertEqual(task.projectID, ProjectConstants.inboxProjectID)
    }

    func testCreateTaskRejectsBlankTitle() async {
        let projectRepository = ShortcutProjectRepositoryStub(projects: [Project.createInbox()])
        let taskRepository = InMemoryTaskDefinitionRepositoryStub()
        let service = InboxTaskCaptureService(
            projectRepository: projectRepository,
            createTaskDefinitionUseCase: CreateTaskDefinitionUseCase(repository: taskRepository)
        )

        do {
            _ = try await service.createTask(title: "   ", details: nil)
            XCTFail("Expected blank title to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("cannot be empty"))
        }
    }
}

final class FocusSessionShortcutRecoveryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPersistedFocusSessionKeys()
    }

    override func tearDown() {
        clearPersistedFocusSessionKeys()
        super.tearDown()
    }

    func testFetchActiveSessionReturnsNewestUnfinishedSession() throws {
        let olderSession = FocusSessionDefinition(
            id: UUID(),
            taskID: UUID(),
            startedAt: Date().addingTimeInterval(-1_200),
            endedAt: nil,
            durationSeconds: 0,
            targetDurationSeconds: 25 * 60,
            wasCompleted: false,
            xpAwarded: 0
        )
        let newestSession = FocusSessionDefinition(
            id: UUID(),
            taskID: UUID(),
            startedAt: Date().addingTimeInterval(-300),
            endedAt: nil,
            durationSeconds: 0,
            targetDurationSeconds: 25 * 60,
            wasCompleted: false,
            xpAwarded: 0
        )
        let repository = ShortcutFocusSessionRepositoryStub(
            sessions: [
                olderSession,
                FocusSessionDefinition(
                    id: UUID(),
                    taskID: UUID(),
                    startedAt: Date().addingTimeInterval(-2_400),
                    endedAt: Date().addingTimeInterval(-1_800),
                    durationSeconds: 600,
                    targetDurationSeconds: 25 * 60,
                    wasCompleted: false,
                    xpAwarded: 0
                ),
                newestSession
            ]
        )
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let session = try awaitResult { completion in
            useCase.fetchActiveSession(completion: completion)
        }

        XCTAssertEqual(session?.id, newestSession.id)
    }

    func testFetchActiveSessionClearsPersistedKeysWhenRepositoryHasNoActiveSession() throws {
        UserDefaults.standard.set(UUID().uuidString, forKey: "focusSessionActiveID")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "focusSessionStartedAt")
        UserDefaults.standard.set(UUID().uuidString, forKey: "focusSessionTaskID")
        UserDefaults.standard.set(25 * 60, forKey: "focusSessionTargetSeconds")

        let repository = ShortcutFocusSessionRepositoryStub(
            sessions: [
                FocusSessionDefinition(
                    id: UUID(),
                    taskID: UUID(),
                    startedAt: Date().addingTimeInterval(-1_200),
                    endedAt: Date().addingTimeInterval(-600),
                    durationSeconds: 600,
                    targetDurationSeconds: 25 * 60,
                    wasCompleted: false,
                    xpAwarded: 0
                )
            ]
        )
        let useCase = FocusSessionUseCase(repository: repository, engine: GamificationEngine(repository: repository))

        let session = try awaitResult { completion in
            useCase.fetchActiveSession(completion: completion)
        }

        XCTAssertNil(session)
        XCTAssertNil(UserDefaults.standard.string(forKey: "focusSessionActiveID"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "focusSessionStartedAt"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "focusSessionTaskID"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "focusSessionTargetSeconds"))
    }

    private func clearPersistedFocusSessionKeys() {
        UserDefaults.standard.removeObject(forKey: "focusSessionActiveID")
        UserDefaults.standard.removeObject(forKey: "focusSessionStartedAt")
        UserDefaults.standard.removeObject(forKey: "focusSessionTaskID")
        UserDefaults.standard.removeObject(forKey: "focusSessionTargetSeconds")
    }
}

private final class ShortcutProjectRepositoryStub: ProjectRepositoryProtocol {
    private(set) var projects: [Project]
    private(set) var createProjectCallCount = 0

    init(projects: [Project]) {
        self.projects = projects
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
        if let inbox = projects.first(where: { $0.id == ProjectConstants.inboxProjectID || $0.isInbox }) {
            completion(.success(inbox))
        } else {
            completion(.failure(NSError(domain: "ShortcutProjectRepositoryStub", code: 404)))
        }
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        createProjectCallCount += 1
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        if let inbox = projects.first(where: { $0.id == ProjectConstants.inboxProjectID || $0.isInbox }) {
            completion(.success(inbox))
            return
        }

        let inbox = Project.createInbox()
        createProject(inbox, completion: completion)
    }

    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return completion(.failure(NSError(domain: "ShortcutProjectRepositoryStub", code: 404)))
        }
        projects[index].name = newName
        completion(.success(projects[index]))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        projects.removeAll { $0.id == id }
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        completion(.success(0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
    }
}

private final class ShortcutFocusSessionRepositoryStub: GamificationRepositoryProtocol {
    var sessions: [FocusSessionDefinition]

    init(sessions: [FocusSessionDefinition]) {
        self.sessions = sessions
    }

    func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) { completion(.success(nil)) }
    func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) { completion(.success([])) }
    func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(false)) }
    func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) { completion(.success([])) }
    func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) { completion(.success(nil)) }
    func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) { completion(.success([])) }
    func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        completion(.success(sessions.filter { $0.startedAt >= startDate && $0.startedAt < endDate }))
    }
}

private func awaitResult<T>(
    timeout: TimeInterval = 1.0,
    _ operation: (@escaping (Result<T, Error>) -> Void) -> Void
) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    var capturedResult: Result<T, Error>?

    operation { result in
        capturedResult = result
        semaphore.signal()
    }

    let waitResult = semaphore.wait(timeout: .now() + timeout)
    if waitResult == .timedOut {
        throw NSError(domain: "TaskerAppShortcutsTests", code: 408, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for result"])
    }

    return try XCTUnwrap(capturedResult).get()
}
