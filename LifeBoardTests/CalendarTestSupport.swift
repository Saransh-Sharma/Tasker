import Foundation
import Combine
import XCTest
@testable import LifeBoard

final class CalendarEventsProviderStub: CalendarEventsProviderProtocol {
    var authorizationStatusValue: LifeBoardCalendarAuthorizationStatus = .authorized
    var authorizationStatusAfterAccess: LifeBoardCalendarAuthorizationStatus?
    var requestAccessResult: Result<Bool, Error> = .success(true)

    var calendarsResult: Result<[LifeBoardCalendarSourceSnapshot], Error> = .success([])
    var eventsResult: Result<[LifeBoardCalendarEventSnapshot], Error> = .success([])

    private let storeChangedSubject = PassthroughSubject<Void, Never>()

    private(set) var fetchCalendarsCallCount = 0
    private(set) var fetchEventsCallCount = 0
    private(set) var resetStoreCallCount = 0
    private(set) var requestAccessCallCount = 0
    private(set) var lastRequestedStartDate: Date?
    private(set) var lastRequestedEndDate: Date?
    private(set) var lastRequestedCalendarIDs: Set<String> = []

    init() {}

    func authorizationStatus() -> LifeBoardCalendarAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAccess(completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        requestAccessCallCount += 1
        if let nextStatus = authorizationStatusAfterAccess {
            authorizationStatusValue = nextStatus
        }
        completion(requestAccessResult)
    }

    func resetStoreStateAfterPermissionChange() {
        resetStoreCallCount += 1
    }

    func fetchCalendars(completion: @escaping @Sendable (Result<[LifeBoardCalendarSourceSnapshot], Error>) -> Void) {
        fetchCalendarsCallCount += 1
        completion(calendarsResult)
    }

    func fetchEvents(
        startDate: Date,
        endDate: Date,
        calendarIDs: Set<String>,
        completion: @escaping @Sendable (Result<[LifeBoardCalendarEventSnapshot], Error>) -> Void
    ) {
        fetchEventsCallCount += 1
        lastRequestedStartDate = startDate
        lastRequestedEndDate = endDate
        lastRequestedCalendarIDs = calendarIDs
        completion(eventsResult)
    }

    func storeChangedPublisher() -> AnyPublisher<Void, Never> {
        storeChangedSubject.eraseToAnyPublisher()
    }

    func emitStoreChanged() {
        storeChangedSubject.send(())
    }
}

final class CalendarProjectRepositoryStub: ProjectRepositoryProtocol {
    private var projects: [Project]

    init(projects: [Project]) {
        self.projects = projects
    }

    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projects))
    }

    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first { $0.id == id }))
    }

    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        completion(.success(projects.first { $0.name == name }))
    }

    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        if let inbox = projects.first(where: \.isInbox) {
            completion(.success(inbox))
            return
        }

        let inbox = Project.createInbox()
        projects.append(inbox)
        completion(.success(inbox))
    }

    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        completion(.success(projects.filter { !$0.isInbox }))
    }

    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        projects.append(project)
        completion(.success(project))
    }

    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        if let inbox = projects.first(where: \.isInbox) {
            completion(.success(inbox))
            return
        }
        let inbox = Project.createInbox()
        projects.append(inbox)
        completion(.success(inbox))
    }

    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: projects.count, merged: 0, deleted: 0, inboxCandidates: projects.filter(\.isInbox).count, warnings: [])))
    }

    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
        completion(.success(project))
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            completion(.failure(NSError(domain: "CalendarProjectRepositoryStub", code: 404)))
            return
        }
        projects[index].name = newName
        completion(.success(projects[index]))
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        _ = deleteTasks
        projects.removeAll { $0.id == id }
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
