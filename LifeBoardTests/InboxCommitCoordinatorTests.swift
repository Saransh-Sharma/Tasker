import XCTest
@testable import LifeBoard

/// In-memory stand-in for the task repository.
///
/// An actor rather than a locked class: the protocol's methods are `async`, and
/// `NSLock.lock()` is unavailable from an async context.
private actor SpyTaskWriter: InboxTaskWriting {
    private(set) var created: [InboxCaptureCommitRequest] = []
    private(set) var deleted: [UUID] = []
    private(set) var moves: [(id: UUID, project: UUID?)] = []
    private var createResult: Result<UUID, Error> = .success(UUID())
    private var deleteError: Error?

    struct Boom: Error {}

    func setCreateResult(_ value: Result<UUID, Error>) { createResult = value }
    func setDeleteError(_ value: Error?) { deleteError = value }

    var movedProjects: [UUID?] { moves.map(\.project) }

    func createTask(_ request: InboxCaptureCommitRequest) async throws -> UUID {
        created.append(request)
        return try createResult.get()
    }

    func deleteTask(id: UUID) async throws {
        if let deleteError { throw deleteError }
        deleted.append(id)
    }

    func moveTask(id: UUID, toProject projectID: UUID?) async throws {
        moves.append((id, projectID))
    }
}

final class InboxCommitCoordinatorTests: XCTestCase {

    private final class QueueBox: @unchecked Sendable {
        let lock = NSLock()
        var captures: [PendingCapture] = []
    }

    private func makeCoordinator(
        writer: SpyTaskWriter,
        seeded: [PendingCapture]
    ) -> (InboxCommitCoordinator, QueueBox) {
        let box = QueueBox()
        box.captures = seeded
        let access = InboxCaptureQueueAccess(
            read: { box.lock.lock(); defer { box.lock.unlock() }; return box.captures },
            remove: { ids in
                box.lock.lock(); defer { box.lock.unlock() }
                box.captures.removeAll { ids.contains($0.id) }
            },
            restore: { capture in
                box.lock.lock(); defer { box.lock.unlock() }
                box.captures.append(capture)
            }
        )
        return (InboxCommitCoordinator(writer: writer, queue: access), box)
    }

    private func capture(_ text: String = "call mom") -> PendingCapture {
        PendingCapture(rawText: text, createdAt: Date(timeIntervalSince1970: 1_700_000_000), source: "widget")
    }

    // MARK: - Commit ordering

    func testCommitCreatesTaskThenClearsTheCapture() async throws {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        let mutation = try await coordinator.commit(
            InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
        )

        XCTAssertEqual(mutation, .commitCapture(captureID: pending.id, createdTaskID: taskID))
        let createdCount = await writer.created.count
        XCTAssertEqual(createdCount, 1)
        XCTAssertTrue(box.captures.isEmpty)
    }

    /// The property that matters most here: a capture is often the only copy of
    /// something the user typed once, so a failed task write must not consume it.
    func testFailedTaskWriteLeavesTheCaptureInTheQueue() async {
        let writer = SpyTaskWriter()
        await writer.setCreateResult(.failure(SpyTaskWriter.Boom()))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        do {
            _ = try await coordinator.commit(
                InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
            )
            XCTFail("expected the commit to throw")
        } catch {
            guard case InboxCommitFailure.taskWriteFailed = error else {
                return XCTFail("expected taskWriteFailed, got \(error)")
            }
        }

        XCTAssertEqual(box.captures.map(\.id), [pending.id])
    }

    /// Already committed elsewhere, or discarded on another device. Committing
    /// again would silently create a duplicate task.
    func testCommittingAnAbsentCaptureFailsRatherThanCreatingADuplicate() async {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let missing = UUID()

        do {
            _ = try await coordinator.commit(
                InboxCaptureCommitRequest(captureID: missing, title: "call mom")
            )
            XCTFail("expected the commit to throw")
        } catch {
            XCTAssertEqual(error as? InboxCommitFailure, .captureNotFound(missing))
        }
        let createdEmpty = await writer.created.isEmpty
        XCTAssertTrue(createdEmpty)
    }

    // MARK: - Undo

    func testUndoDeletesTheTaskAndRestoresTheCaptureUnchanged() async throws {
        let writer = SpyTaskWriter()
        let taskID = UUID()
        await writer.setCreateResult(.success(taskID))
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [pending])

        let mutation = try await coordinator.commit(
            InboxCaptureCommitRequest(captureID: pending.id, title: "call mom")
        )
        try await coordinator.undoCommit(mutation, restoring: pending)

        let deleted = await writer.deleted
        XCTAssertEqual(deleted, [taskID])
        // Identity, text, timestamp and source all survive: a restored capture
        // must not read as a brand new one in an age-ordered Inbox.
        XCTAssertEqual(box.captures.count, 1)
        XCTAssertEqual(box.captures.first, pending)
    }

    func testUndoDoesNotRestoreTheCaptureWhenTheTaskDeleteFails() async {
        let writer = SpyTaskWriter()
        await writer.setDeleteError(SpyTaskWriter.Boom())
        let pending = capture()
        let (coordinator, box) = makeCoordinator(writer: writer, seeded: [])
        let mutation = InboxTriageMutation.commitCapture(captureID: pending.id, createdTaskID: UUID())

        do {
            try await coordinator.undoCommit(mutation, restoring: pending)
            XCTFail("expected undo to throw")
        } catch {
            guard case InboxCommitFailure.taskWriteFailed = error else {
                return XCTFail("expected taskWriteFailed, got \(error)")
            }
        }
        // Otherwise the user would end up with both the task and the capture.
        XCTAssertTrue(box.captures.isEmpty)
    }

    // MARK: - Project moves

    func testMoveToProjectRecordsBeforeSoUndoIsExact() async throws {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let taskID = UUID()
        let origin = UUID()
        let destination = UUID()

        let mutation = try await coordinator.moveToProject(taskID: taskID, from: origin, to: destination)
        try await coordinator.undoMoveToProject(mutation)

        let moved = await writer.movedProjects
        XCTAssertEqual(moved, [destination, origin])
    }

    /// The regression this fixes: `after` used to be non-optional, so inverting
    /// a move for a task that had no project produced
    /// `.moveToProject(before: after, after: after)` — a no-op that left the
    /// task in the project the undo was meant to pull it out of.
    func testUndoingAMoveForATaskThatHadNoProjectRemovesItFromTheProject() async throws {
        let writer = SpyTaskWriter()
        let (coordinator, _) = makeCoordinator(writer: writer, seeded: [])
        let taskID = UUID()
        let destination = UUID()

        let mutation = try await coordinator.moveToProject(taskID: taskID, from: nil, to: destination)
        try await coordinator.undoMoveToProject(mutation)

        let moved = await writer.movedProjects
        XCTAssertEqual(moved.count, 2)
        XCTAssertEqual(moved[0], destination)
        XCTAssertNil(moved[1])
    }

    func testMoveToProjectInverseRoundTrips() {
        let taskID = UUID()
        let origin = UUID()
        let destination = UUID()
        let forward = InboxTriageMutation.moveToProject(taskID: taskID, before: origin, after: destination)
        XCTAssertEqual(
            forward.inverse,
            .moveToProject(taskID: taskID, before: destination, after: origin)
        )
        XCTAssertEqual(forward.inverse.inverse, forward)
    }

    func testMoveToProjectInverseRoundTripsWithNoOriginalProject() {
        let taskID = UUID()
        let destination = UUID()
        let forward = InboxTriageMutation.moveToProject(taskID: taskID, before: nil, after: destination)
        XCTAssertEqual(forward.inverse, .moveToProject(taskID: taskID, before: destination, after: nil))
        XCTAssertEqual(forward.inverse.inverse, forward)
    }

    // MARK: - Building the request from a review

    /// The commit must carry exactly what the chips showed. Re-parsing at commit
    /// time would let a relative date resolve against a moved reference.
    func testReviewedRequestCarriesTheParsedProposalVerbatim() {
        let captureID = UUID()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        let parsed = TaskCaptureParser.parse(
            "draft proposal for 90 min tomorrow 2pm +Work #writing @desk !high",
            now: reference
        )
        let request = InboxCaptureCommitRequest.reviewed(
            captureID: captureID,
            parsed: parsed,
            fallbackTitle: "raw"
        )

        XCTAssertEqual(request.title, "draft proposal")
        XCTAssertEqual(request.estimatedDuration, 90 * 60)
        XCTAssertEqual(request.projectName, "Work")
        XCTAssertEqual(request.tagNames, ["writing"])
        XCTAssertEqual(request.contextName, "desk")
        XCTAssertEqual(request.priority, .high)
        XCTAssertEqual(request.dueDate, parsed.dueDate)
    }

    func testReviewedRequestFallsBackWhenTheParsedTitleIsEmpty() {
        let parsed = ParsedCapture(cleanTitle: "   ", dueDate: nil, isAllDay: false, matchedText: nil)
        let request = InboxCaptureCommitRequest.reviewed(
            captureID: UUID(),
            parsed: parsed,
            fallbackTitle: "tomorrow"
        )
        XCTAssertEqual(request.title, "tomorrow")
    }
}
