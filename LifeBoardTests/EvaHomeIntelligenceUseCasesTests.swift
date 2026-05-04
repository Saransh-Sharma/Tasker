import XCTest
@testable import LifeBoard

final class EvaHomeIntelligenceUseCasesTests: XCTestCase {

    func testComputeEvaHomeInsightsBuildsDeterministicSignals() {
        let useCase = ComputeEvaHomeInsightsUseCase()
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0, second: 0))!
        let overdueDate = calendar.date(byAdding: .day, value: -3, to: now)!

        let focusA = makeTask(
            title: "Prepare escalation deck",
            dueDate: overdueDate,
            priority: .high,
            estimatedDuration: 15 * 60,
            updatedAt: calendar.date(byAdding: .day, value: -2, to: now)!
        )
        let focusB = makeTask(
            title: "Review launch checklist",
            dueDate: now,
            priority: .low,
            estimatedDuration: 30 * 60,
            updatedAt: calendar.date(byAdding: .hour, value: -4, to: now)!
        )

        let inboxUntriagedA = makeTask(
            title: "Follow up with vendor",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: nil,
            priority: .low,
            estimatedDuration: nil,
            createdAt: calendar.date(byAdding: .hour, value: -30, to: now)!,
            updatedAt: calendar.date(byAdding: .hour, value: -30, to: now)!
        )
        let inboxUntriagedB = makeTask(
            title: "Draft roadmap note",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: nil,
            priority: .low,
            estimatedDuration: nil,
            createdAt: calendar.date(byAdding: .hour, value: -28, to: now)!,
            updatedAt: calendar.date(byAdding: .hour, value: -28, to: now)!
        )

        let rescueA = makeTask(
            title: "Old overdue item",
            dueDate: calendar.date(byAdding: .day, value: -12, to: now)!,
            priority: .max,
            estimatedDuration: 2 * 60 * 60,
            updatedAt: calendar.date(byAdding: .day, value: -16, to: now)!
        )
        let rescueB = makeTask(
            title: "Another overdue",
            dueDate: calendar.date(byAdding: .day, value: -7, to: now)!,
            priority: .high,
            estimatedDuration: 60 * 60,
            updatedAt: calendar.date(byAdding: .day, value: -9, to: now)!
        )

        let open = [focusA, focusB, inboxUntriagedA, inboxUntriagedB, rescueA, rescueB]
        let insights = useCase.execute(
            openTasks: open,
            focusTasks: [focusA, focusB],
            anchorDate: now,
            now: now
        )

        XCTAssertEqual(insights.focus.taskInsights.count, 2)
        XCTAssertTrue(insights.focus.summaryLine?.contains("Eva picked for:") ?? false)
        XCTAssertEqual(insights.triage.untriagedCount, 2)
        XCTAssertEqual(insights.triage.promptLevel, .microcopy)
        XCTAssertEqual(insights.rescue.promptLevel, .microcopy)
        XCTAssertNotEqual(insights.rescue.debtLevel, .none)
    }

    func testInboxTriageQueueMapsDurationsToSupportedPresets() {
        let useCase = GetInboxTriageQueueUseCase()
        let project = Project(id: UUID(), name: "Work", icon: .work)

        let estimatedOffPreset = makeTask(
            title: "Refine architecture document",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: nil,
            priority: .low,
            estimatedDuration: 40 * 60
        )
        let keywordSuggested = makeTask(
            title: "Design project kickoff",
            projectID: ProjectConstants.inboxProjectID,
            dueDate: nil,
            priority: .low,
            estimatedDuration: nil
        )

        let queue = useCase.execute(
            inboxTasks: [estimatedOffPreset, keywordSuggested],
            allTasks: [estimatedOffPreset, keywordSuggested],
            projects: [Project.createInbox(), project],
            maxItems: 20,
            now: Date()
        )

        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue[0].suggestions.durationSeconds, 30 * 60)
        XCTAssertEqual(queue[1].suggestions.durationSeconds, 2 * 60 * 60)
    }

    func testOverdueRescuePlanCapsDoTodayAndSurfacesDropCandidates() {
        let useCase = GetOverdueRescuePlanUseCase()
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 10, minute: 0, second: 0))!

        let quickA = makeTask(title: "Quick A", dueDate: calendar.date(byAdding: .day, value: -1, to: now)!, priority: .high, estimatedDuration: 15 * 60)
        let quickB = makeTask(title: "Quick B", dueDate: calendar.date(byAdding: .day, value: -1, to: now)!, priority: .high, estimatedDuration: 15 * 60)
        let quickC = makeTask(title: "Quick C", dueDate: calendar.date(byAdding: .day, value: -1, to: now)!, priority: .high, estimatedDuration: 15 * 60)
        let quickD = makeTask(title: "Quick D", dueDate: calendar.date(byAdding: .day, value: -1, to: now)!, priority: .high, estimatedDuration: 15 * 60)
        let stale = makeTask(
            title: "Stale task",
            dueDate: calendar.date(byAdding: .day, value: -20, to: now)!,
            priority: .low,
            estimatedDuration: 30 * 60,
            updatedAt: calendar.date(byAdding: .day, value: -25, to: now)!
        )

        let plan = useCase.execute(overdueTasks: [quickA, quickB, quickC, quickD, stale], now: now, doTodayCap: 3)

        XCTAssertEqual(plan.doTodayCap, 3)
        XCTAssertEqual(plan.doToday.count, 3)
        XCTAssertTrue(plan.move.count >= 1)
        XCTAssertTrue(plan.dropCandidate.contains(where: { $0.taskID == stale.id }))
    }

    func testBuildEvaBatchProposalProducesSnapshotMutations() {
        let useCase = BuildEvaBatchProposalUseCase()
        let now = Date()

        let task = makeTask(
            title: "Move to someday",
            dueDate: Calendar.current.date(byAdding: .day, value: -2, to: now),
            priority: .high,
            estimatedDuration: 60 * 60
        )
        let mutation = EvaBatchMutationInstruction(
            taskID: task.id,
            projectID: ProjectConstants.inboxProjectID,
            dueDate: nil,
            clearDueDate: true,
            estimatedDuration: 30 * 60,
            clearEstimatedDuration: false,
            isComplete: false
        )

        let proposal = useCase.execute(
            source: .rescue,
            tasksByID: [task.id: task],
            mutations: [mutation],
            now: now
        )

        XCTAssertEqual(proposal.envelope.schemaVersion, 2)
        XCTAssertEqual(proposal.envelope.commands.count, 1)
        XCTAssertTrue(proposal.threadID.contains("eva_rescue_"))

        guard case .restoreTaskSnapshot(let snapshot) = proposal.envelope.commands[0] else {
            return XCTFail("Expected restoreTaskSnapshot command")
        }

        XCTAssertEqual(snapshot.id, task.id)
        XCTAssertEqual(snapshot.projectID, ProjectConstants.inboxProjectID)
        XCTAssertNil(snapshot.dueDate)
        XCTAssertEqual(snapshot.estimatedDuration, 30 * 60)
        XCTAssertEqual(snapshot.isComplete, false)
    }

    private func makeTask(
        title: String,
        projectID: UUID = UUID(),
        dueDate: Date?,
        priority: TaskPriority,
        estimatedDuration: TimeInterval? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> TaskDefinition {
        TaskDefinition(
            projectID: projectID,
            projectName: projectID == ProjectConstants.inboxProjectID ? ProjectConstants.inboxProjectName : "Project",
            title: title,
            priority: priority,
            dueDate: dueDate,
            estimatedDuration: estimatedDuration,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
