import XCTest
@testable import To_Do_List

final class LLMProjectionTimeoutTests: XCTestCase {
    func testTimeoutReturnsFallbackPayload() async {
        let startedAt = Date()
        let result = await LLMProjectionTimeout.execute(timeoutMs: 25) {
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 250_000_000)
                return #"{"late":true}"#
            } catch {
                return #"{"cancelled":true}"#
            }
        }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        XCTAssertEqual(result.payload, "{}")
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(elapsedMs, 200)
    }

    func testFastProjectionReturnsPayloadWithoutTimeout() async {
        let result = await LLMProjectionTimeout.execute(timeoutMs: 250) {
            #"{"ok":true}"#
        }

        XCTAssertEqual(result.payload, #"{"ok":true}"#)
        XCTAssertFalse(result.timedOut)
    }
}

final class LLMContextProjectionServiceTests: XCTestCase {
    func testBuildOverdueJSONIncludesOnlyOpenOverdueTasks() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = makeTask(
            title: "Overdue",
            dueDate: calendar.date(byAdding: .hour, value: -1, to: startOfToday),
            isComplete: false
        )
        let todayTask = makeTask(
            title: "Today",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )
        let completedOverdueTask = makeTask(
            title: "Completed Overdue",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: true
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(
                tasks: [overdueTask, todayTask, completedOverdueTask]
            ),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Overdue"])
    }

    func testBuildOverdueJSONExcludesStartOfDayBoundary() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let boundaryTask = makeTask(
            title: "Boundary",
            dueDate: startOfToday,
            isComplete: false
        )
        let overdueTask = makeTask(
            title: "Past Boundary",
            dueDate: startOfToday.addingTimeInterval(-1),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [boundaryTask, overdueTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Past Boundary"])
        XCTAssertFalse(titles.contains("Boundary"))
    }

    func testBuildTodayJSONKeepsOpenAndCompletedTodayOnly() async throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let dueToday = calendar.date(byAdding: .hour, value: 3, to: startOfToday)
        let completedTodayAt = calendar.date(byAdding: .hour, value: 4, to: startOfToday)
        let completedYesterdayAt = calendar.date(byAdding: .day, value: -1, to: completedTodayAt ?? now)

        var completedToday = makeTask(title: "Completed Today", dueDate: dueToday, isComplete: true)
        completedToday.dateCompleted = completedTodayAt
        var completedYesterday = makeTask(title: "Completed Yesterday", dueDate: dueToday, isComplete: true)
        completedYesterday.dateCompleted = completedYesterdayAt
        let openToday = makeTask(title: "Open Today", dueDate: dueToday, isComplete: false)

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(
                tasks: [completedToday, completedYesterday, openToday]
            ),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let json = await service.buildTodayJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let titles = Set(tasks.compactMap { $0["title"] as? String })
        XCTAssertEqual(titles, ["Completed Today", "Open Today"])
        XCTAssertFalse(titles.contains("Completed Yesterday"))
    }

    func testContextEnvelopeBuilderMarksMissingServiceAsPartial() async throws {
        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 25, service: nil)
        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        let partialFlags = try XCTUnwrap(payload["partial_flags"] as? [String: Any])

        XCTAssertEqual(metadata["context_partial"] as? Bool, true)
        XCTAssertEqual(partialFlags["missing_service"] as? Bool, true)
        XCTAssertEqual(partialFlags["context_partial"] as? Bool, true)
        XCTAssertTrue(result.usedTimeoutFallback)
    }

    func testContextEnvelopeBuilderIncludesOverdueSlice() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = makeTask(
            title: "Urgent overdue",
            dueDate: calendar.date(byAdding: .hour, value: -4, to: startOfToday),
            isComplete: false
        )
        let todayTask = makeTask(
            title: "Today",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask, todayTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )
        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 250, service: service)

        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let overdue = try XCTUnwrap(payload["overdue"] as? [String: Any])
        XCTAssertEqual(overdue["context_type"] as? String, "overdue")
        XCTAssertEqual(overdue["count"] as? Int, 1)
    }

    func testBuildOverdueJSONIncludesTagNamesFromRepository() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let urgentTag = TagDefinition(name: "Urgent")
        var task = makeTask(
            title: "Overdue tagged",
            dueDate: startOfToday.addingTimeInterval(-3_600),
            isComplete: false
        )
        task.tagIDs = [urgentTag.id]

        let service = LLMContextProjectionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [task]),
            projectRepository: MockProjectRepository(),
            tagRepository: MockTagRepository(tags: [urgentTag])
        )

        let json = await service.buildOverdueJSON()
        let payload = try XCTUnwrap(parseJSONDictionary(json))
        let tasks = try XCTUnwrap(payload["tasks"] as? [[String: Any]])
        let firstTask = try XCTUnwrap(tasks.first)
        let tagNames = try XCTUnwrap(firstTask["tag_names"] as? [String])
        XCTAssertEqual(tagNames, ["Urgent"])
    }

    func testContextEnvelopeBuilderMarksTimedOutSlicesAsPartial() async throws {
        let slowRepository = MockTaskReadModelRepository(
            tasks: [makeTask(title: "Slow", dueDate: Date(), isComplete: false)],
            fetchDelayMs: 150
        )
        let service = LLMContextProjectionService(
            taskReadModelRepository: slowRepository,
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let result = await LLMChatContextEnvelopeBuilder.build(timeoutMs: 10, service: service)
        let payload = try XCTUnwrap(parseJSONDictionary(result.envelope.toJSONString()))
        let metadata = try XCTUnwrap(payload["metadata"] as? [String: Any])
        let partialFlags = try XCTUnwrap(payload["partial_flags"] as? [String: Any])

        XCTAssertEqual(metadata["context_partial"] as? Bool, true)
        XCTAssertEqual(partialFlags["today_timed_out"] as? Bool, true)
        XCTAssertEqual(partialFlags["overdue_timed_out"] as? Bool, true)
        XCTAssertEqual(partialFlags["upcoming_timed_out"] as? Bool, true)
    }

    private func makeTask(
        title: String,
        dueDate: Date?,
        isComplete: Bool
    ) -> TaskDefinition {
        TaskDefinition(
            title: title,
            dueDate: dueDate,
            isComplete: isComplete
        )
    }

    private func parseJSONDictionary(_ raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }
}

final class PromptMiddlewareTests: XCTestCase {
    override func tearDown() {
        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: nil,
            projectRepository: nil,
            tagRepository: nil
        )
        super.tearDown()
    }

    func testTodaySummaryIncludesOverdueSection() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = TaskDefinition(
            title: "Overdue Task",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: false
        )
        let todayTask = TaskDefinition(
            title: "Today Task",
            dueDate: calendar.date(byAdding: .hour, value: 1, to: startOfToday),
            isComplete: false
        )

        LLMContextRepositoryProvider.configure(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [todayTask, overdueTask]),
            projectRepository: MockProjectRepository(),
            tagRepository: nil
        )

        let summary = PromptMiddleware.buildTasksSummary(range: .today)
        XCTAssertTrue(summary.contains("Overdue:"))
        XCTAssertTrue(summary.contains("• [overdue] Overdue Task"))
        XCTAssertTrue(summary.contains("Due today:"))
        XCTAssertTrue(summary.contains("• [today] Today Task"))
    }
}

final class SlashCommandCatalogTests: XCTestCase {
    func testParseTodoAliasResolvesToTodayInvocation() {
        let result = SlashCommandCatalog.parse("/todo")
        switch result {
        case .invocation(let invocation):
            XCTAssertEqual(invocation.id, .today)
        default:
            XCTFail("Expected /todo to parse as a today invocation")
        }
    }

    func testParseUnknownSlashCommandReturnsUnknownResult() {
        let result = SlashCommandCatalog.parse("/notreal")
        switch result {
        case .unknown(let command):
            XCTAssertEqual(command, "/notreal")
        default:
            XCTFail("Expected unknown command parse result")
        }
    }

    func testParseProjectWithoutNameReturnsMissingArgument() {
        let result = SlashCommandCatalog.parse("/project")
        switch result {
        case .missingRequiredArgument(let commandID, let partial):
            XCTAssertEqual(commandID, .project)
            XCTAssertNil(partial)
        default:
            XCTFail("Expected missing argument parse result for /project")
        }
    }

    func testFilteredDescriptorsPrioritizesRecentsBeforePopularity() {
        let filtered = SlashCommandCatalog.filteredDescriptors(
            query: "",
            recents: [.month, .project],
            limit: 3
        )

        XCTAssertEqual(filtered.map(\.id), [.month, .project, .today])
    }
}

final class SlashCommandExecutionServiceTests: XCTestCase {
    func testTodayExecutionIncludesOverdueAndDueTodayOnly() async throws {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let overdueTask = TaskDefinition(
            title: "Overdue task",
            dueDate: calendar.date(byAdding: .hour, value: -2, to: startOfToday),
            isComplete: false
        )
        let dueTodayTask = TaskDefinition(
            title: "Due today task",
            dueDate: calendar.date(byAdding: .hour, value: 2, to: startOfToday),
            isComplete: false
        )
        let completedOverdueTask = TaskDefinition(
            title: "Completed overdue",
            dueDate: calendar.date(byAdding: .hour, value: -4, to: startOfToday),
            isComplete: true
        )

        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [overdueTask, dueTodayTask, completedOverdueTask]),
            projectRepository: MockProjectRepository()
        )
        let result = try await service.execute(
            invocation: SlashCommandInvocation(id: .today, projectQuery: nil, projectName: nil)
        )

        XCTAssertEqual(result.commandID, .today)
        XCTAssertEqual(result.totalTaskCount, 2)
        XCTAssertEqual(Set(result.sections.map(\.id)), Set(["overdue", "today"]))
        let titles = Set(result.sections.flatMap { $0.tasks.map(\.title) })
        XCTAssertEqual(titles, Set(["Overdue task", "Due today task"]))
        XCTAssertFalse(titles.contains("Completed overdue"))
    }

    func testProjectExecutionDoesNotFallbackToAllTasksWhenProjectMissing() async throws {
        var inboxTask = TaskDefinition(title: "Inbox task", dueDate: Date(), isComplete: false)
        inboxTask.projectName = "Inbox"
        var workTask = TaskDefinition(title: "Work task", dueDate: Date(), isComplete: false)
        workTask.projectName = "Work"

        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: [inboxTask, workTask]),
            projectRepository: MockProjectRepository(projects: [
                Project.createInbox(),
                Project(name: "Work")
            ])
        )

        do {
            _ = try await service.execute(
                invocation: SlashCommandInvocation(id: .project, projectQuery: "Unknown Project", projectName: nil)
            )
            XCTFail("Expected missing project query to fail")
        } catch let error as SlashCommandExecutionError {
            switch error {
            case .projectNotFound(let query):
                XCTAssertEqual(query, "Unknown Project")
            default:
                XCTFail("Expected projectNotFound error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProjectExecutionReturnsAmbiguousErrorForNonUniqueMatch() async throws {
        let service = SlashCommandExecutionService(
            taskReadModelRepository: MockTaskReadModelRepository(tasks: []),
            projectRepository: MockProjectRepository(projects: [
                Project.createInbox(),
                Project(name: "Work Alpha"),
                Project(name: "Work Beta")
            ])
        )

        do {
            _ = try await service.execute(
                invocation: SlashCommandInvocation(id: .project, projectQuery: "Work", projectName: nil)
            )
            XCTFail("Expected ambiguous project match to fail")
        } catch let error as SlashCommandExecutionError {
            switch error {
            case .ambiguousProjectName(let query, let matches):
                XCTAssertEqual(query, "Work")
                XCTAssertEqual(Set(matches), Set(["Work Alpha", "Work Beta"]))
            default:
                XCTFail("Expected ambiguousProjectName error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockTaskReadModelRepository: TaskReadModelRepositoryProtocol {
    private let tasks: [TaskDefinition]
    private let fetchDelayMs: Int

    init(tasks: [TaskDefinition], fetchDelayMs: Int = 0) {
        self.tasks = tasks
        self.fetchDelayMs = fetchDelayMs
    }

    func fetchTasks(query: TaskReadQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        var filtered = tasks
        if let projectID = query.projectID {
            filtered = filtered.filter { $0.projectID == projectID }
        }
        if query.includeCompleted == false {
            filtered = filtered.filter { !$0.isComplete }
        }
        if let dueDateStart = query.dueDateStart {
            filtered = filtered.filter { ($0.dueDate ?? .distantPast) >= dueDateStart }
        }
        if let dueDateEnd = query.dueDateEnd {
            filtered = filtered.filter { ($0.dueDate ?? .distantFuture) <= dueDateEnd }
        }
        filtered = filtered.sorted {
            ($0.dueDate ?? .distantFuture, $0.updatedAt) < ($1.dueDate ?? .distantFuture, $1.updatedAt)
        }
        let result = TaskDefinitionSliceResult(
            tasks: filtered,
            totalCount: filtered.count,
            limit: query.limit,
            offset: query.offset
        )
        if fetchDelayMs > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(fetchDelayMs)) {
                completion(.success(result))
            }
            return
        }
        completion(.success(result))
    }

    func searchTasks(query: TaskSearchQuery, completion: @escaping (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    func fetchProjectTaskCounts(includeCompleted: Bool, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }

    func fetchProjectCompletionScoreTotals(from startDate: Date, to endDate: Date, completion: @escaping (Result<[UUID: Int], Error>) -> Void) {
        completion(.success([:]))
    }
}

private final class MockTagRepository: TagRepositoryProtocol {
    private let tags: [TagDefinition]

    init(tags: [TagDefinition]) {
        self.tags = tags
    }

    func fetchAll(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        completion(.success(tags))
    }

    func create(_ tag: TagDefinition, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        completion(.success(tag))
    }

    func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
}

private final class MockProjectRepository: ProjectRepositoryProtocol {
    private var projects: [Project]

    init(projects: [Project] = [Project.createInbox()]) {
        self.projects = projects
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success(projects)) }
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(projects.first { $0.id == id })) }
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(projects.first { $0.name == name })) }
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(projects.first { $0.isInbox } ?? Project.createInbox())) }
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success(projects.filter { !$0.isInbox })) }
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { projects.append(project); completion(.success(project)) }
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(projects.first { $0.isInbox } ?? Project.createInbox())) }
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: projects.count, merged: 0, deleted: 0, inboxCandidates: projects.filter { $0.isInbox }.count, warnings: [])))
    }
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == id }) {
            var updated = projects[index]
            updated.name = newName
            projects[index] = updated
            completion(.success(updated))
            return
        }
        completion(.failure(NSError(domain: "mock", code: 404)))
    }
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) { completion(.success(0)) }
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
