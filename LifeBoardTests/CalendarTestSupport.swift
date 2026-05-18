import Foundation
@preconcurrency import Combine
import XCTest
@testable import LifeBoard

final class CalendarEventsProviderStub: CalendarEventsProviderProtocol {
    private struct State {
        var authorizationStatusValue: LifeBoardCalendarAuthorizationStatus = .authorized
        var authorizationStatusAfterAccess: LifeBoardCalendarAuthorizationStatus?
        var requestAccessResult: Result<Bool, Error> = .success(true)
        var calendarsResult: Result<[LifeBoardCalendarSourceSnapshot], Error> = .success([])
        var eventsResult: Result<[LifeBoardCalendarEventSnapshot], Error> = .success([])
        var fetchCalendarsCallCount = 0
        var fetchEventsCallCount = 0
        var resetStoreCallCount = 0
        var requestAccessCallCount = 0
        var lastRequestedStartDate: Date?
        var lastRequestedEndDate: Date?
        var lastRequestedCalendarIDs: Set<String> = []
    }

    private let state = LockedTestState(State())

    var authorizationStatusValue: LifeBoardCalendarAuthorizationStatus {
        get { state.read().authorizationStatusValue }
        set { state.withValue { $0.authorizationStatusValue = newValue } }
    }

    var authorizationStatusAfterAccess: LifeBoardCalendarAuthorizationStatus? {
        get { state.read().authorizationStatusAfterAccess }
        set { state.withValue { $0.authorizationStatusAfterAccess = newValue } }
    }

    var requestAccessResult: Result<Bool, Error> {
        get { state.read().requestAccessResult }
        set { state.withValue { $0.requestAccessResult = newValue } }
    }

    var calendarsResult: Result<[LifeBoardCalendarSourceSnapshot], Error> {
        get { state.read().calendarsResult }
        set { state.withValue { $0.calendarsResult = newValue } }
    }

    var eventsResult: Result<[LifeBoardCalendarEventSnapshot], Error> {
        get { state.read().eventsResult }
        set { state.withValue { $0.eventsResult = newValue } }
    }

    private let storeChangedSubject = PassthroughSubject<Void, Never>()

    var fetchCalendarsCallCount: Int { state.read().fetchCalendarsCallCount }
    var fetchEventsCallCount: Int { state.read().fetchEventsCallCount }
    var resetStoreCallCount: Int { state.read().resetStoreCallCount }
    var requestAccessCallCount: Int { state.read().requestAccessCallCount }
    var lastRequestedStartDate: Date? { state.read().lastRequestedStartDate }
    var lastRequestedEndDate: Date? { state.read().lastRequestedEndDate }
    var lastRequestedCalendarIDs: Set<String> { state.read().lastRequestedCalendarIDs }

    init() {}

    func authorizationStatus() -> LifeBoardCalendarAuthorizationStatus {
        state.read().authorizationStatusValue
    }

    func requestAccess(completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        let result = state.withValue { state -> Result<Bool, Error> in
            state.requestAccessCallCount += 1
            if let nextStatus = state.authorizationStatusAfterAccess {
                state.authorizationStatusValue = nextStatus
            }
            return state.requestAccessResult
        }
        completion(result)
    }

    func resetStoreStateAfterPermissionChange() {
        state.withValue { $0.resetStoreCallCount += 1 }
    }

    func fetchCalendars(completion: @escaping @Sendable (Result<[LifeBoardCalendarSourceSnapshot], Error>) -> Void) {
        let result = state.withValue { state -> Result<[LifeBoardCalendarSourceSnapshot], Error> in
            state.fetchCalendarsCallCount += 1
            return state.calendarsResult
        }
        completion(result)
    }

    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping @Sendable (Result<[LifeBoardCalendarEventSnapshot], Error>) -> Void
    ) {
        let result = state.withValue { state -> Result<[LifeBoardCalendarEventSnapshot], Error> in
            state.fetchEventsCallCount += 1
            state.lastRequestedStartDate = startDate
            state.lastRequestedEndDate = endDate
            state.lastRequestedCalendarIDs = calendarIDs
            return state.eventsResult
        }
        completion(result)
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        storeChangedSubject.eraseToAnyPublisher()
    }

    func emitStoreChanged() {
        storeChangedSubject.send(())
    }
}

final class CalendarProjectRepositoryStub: ProjectRepositoryProtocol {
    private let projectsState: LockedTestState<[Project]>

    init(projects: [Project]) {
        self.projectsState = LockedTestState(projects)
    }

    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projectsState.read()))
    }

    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projectsState.read().first { $0.id == id }))
    }

    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projectsState.read().first { $0.name == name }))
    }

    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let inbox = projectsState.withValue { projects -> Project in
            if let inbox = projects.first(where: \.isInbox) {
                return inbox
            }

            let inbox = Project.createInbox()
            projects.append(inbox)
            return inbox
        }
        completion(.success(inbox))
    }

    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projectsState.read().filter { !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        projectsState.withValue { $0.append(project) }
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let inbox = projectsState.withValue { projects -> Project in
            if let inbox = projects.first(where: \.isInbox) {
                return inbox
            }
            let inbox = Project.createInbox()
            projects.append(inbox)
            return inbox
        }
        completion(.success(inbox))
    }

    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        let projects = projectsState.read()
        completion(.success(ProjectRepairReport(scanned: projects.count, merged: 0, deleted: 0, inboxCandidates: projects.filter(\.isInbox).count, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        projectsState.withValue { projects in
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = project
            }
        }
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        do {
            let renamed = try projectsState.withValue { projects -> Project in
                guard let index = projects.firstIndex(where: { $0.id == id }) else {
                    throw NSError(domain: "CalendarProjectRepositoryStub", code: 404)
                }
                projects[index].name = newName
                return projects[index]
            }
            completion(.success(renamed))
        } catch {
            completion(.failure(error))
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        _ = deleteTasks
        projectsState.withValue { $0.removeAll { $0.id == id } }
        completion(.success(()))
    }

    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        _ = projectId
        completion(.success(0))
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        _ = sourceProjectId
        _ = targetProjectId
        completion(.success(()))
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        let projects = projectsState.read()
        completion(.success(projects.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame && $0.id != excludingId } == false))
    }
}

enum CalendarTestClock {
    static func date(
        year: Int = 2026,
        month: Int = 4,
        day: Int = 15,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }

    static let timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension XCTestCase {
    func waitForMainQueue(seconds: TimeInterval) {
        let expectation = expectation(description: "MainQueueFlush")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: max(2, seconds + 1.5))
    }
}
