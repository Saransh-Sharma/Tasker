import XCTest
@testable import To_Do_List

final class HomeTaskSectionBuilderTests: XCTestCase {

    func testPrioritizeOverdueBuildsInboxThenGroupedOverdueThenCustomWithoutDuplication() {
        let inbox = Project.createInbox()
        let work = Project(id: UUID(), name: "Work", icon: .work)
        let side = Project(id: UUID(), name: "Side", icon: .creative)

        let nonOverdue = [
            makeTask(name: "Inbox Due", project: inbox, dueDate: Date()),
            makeTask(name: "Work Due", project: work, dueDate: Date()),
            makeTask(name: "Side Due", project: side, dueDate: Date())
        ]

        let overdue = [
            makeTask(name: "Inbox Overdue", project: inbox, dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            makeTask(name: "Work Overdue", project: work, dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        ]

        let layout = HomeTaskSectionBuilder.buildTodayLayout(
            mode: .prioritizeOverdue,
            nonOverdueTasks: nonOverdue,
            overdueTasks: overdue,
            projects: [inbox, work, side],
            customProjectOrderIDs: [side.id, work.id]
        )

        XCTAssertEqual(layout.inboxSection?.project.id, inbox.id)
        XCTAssertEqual(layout.inboxSection?.tasks.map(\.name), ["Inbox Due"])

        XCTAssertEqual(layout.overdueGroups.map(\.project.name), ["Inbox", "Work"])
        XCTAssertEqual(layout.customSections.map(\.project.name), ["Side", "Work"])
        XCTAssertTrue(layout.customSections.flatMap(\.tasks).allSatisfy { !$0.isOverdue })
    }

    func testGroupByProjectsIncludesDueAndOverdueWithNonOverdueFirst() {
        let inbox = Project.createInbox()
        let work = Project(id: UUID(), name: "Work", icon: .work)

        let workDue = makeTask(name: "Work Due", project: work, dueDate: Date())
        let workOverdue = makeTask(
            name: "Work Overdue",
            project: work,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )

        let layout = HomeTaskSectionBuilder.buildTodayLayout(
            mode: .groupByProjects,
            nonOverdueTasks: [makeTask(name: "Inbox Due", project: inbox, dueDate: Date()), workDue],
            overdueTasks: [makeTask(name: "Inbox Overdue", project: inbox, dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!), workOverdue],
            projects: [inbox, work],
            customProjectOrderIDs: [work.id]
        )

        XCTAssertTrue(layout.overdueGroups.isEmpty)
        XCTAssertEqual(layout.inboxSection?.tasks.count, 2)

        guard let workSection = layout.customSections.first(where: { $0.project.id == work.id }) else {
            return XCTFail("Expected Work section")
        }
        XCTAssertEqual(workSection.tasks.count, 2)
        XCTAssertEqual(workSection.tasks.first?.name, "Work Due")
        XCTAssertEqual(workSection.tasks.last?.name, "Work Overdue")
        XCTAssertFalse(workSection.tasks.first?.isOverdue ?? true)
        XCTAssertTrue(workSection.tasks.last?.isOverdue ?? false)
    }

    func testCustomProjectOrderUsesSavedOrderAndAppendsAlphabeticalForUnknown() {
        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)
        let gamma = Project(id: UUID(), name: "Gamma", icon: .folder)

        let nonOverdue = [
            makeTask(name: "A", project: alpha, dueDate: Date()),
            makeTask(name: "B", project: beta, dueDate: Date()),
            makeTask(name: "G", project: gamma, dueDate: Date())
        ]

        let layout = HomeTaskSectionBuilder.buildTodayLayout(
            mode: .prioritizeOverdue,
            nonOverdueTasks: nonOverdue,
            overdueTasks: [],
            projects: [inbox, alpha, beta, gamma],
            customProjectOrderIDs: [gamma.id]
        )

        XCTAssertEqual(layout.customSections.map(\.project.name), ["Gamma", "Alpha", "Beta"])
    }

    func testGroupedSectionsDoNotForceCompletionBasedReordering() {
        let inbox = Project.createInbox()
        let work = Project(id: UUID(), name: "Work", icon: .work)

        let openTask = makeTask(
            name: "Open Task",
            project: work,
            dueDate: Date(),
            isComplete: false,
            priority: .low
        )
        let completedTask = makeTask(
            name: "Completed Task",
            project: work,
            dueDate: Date(),
            isComplete: true,
            priority: .max
        )

        let layout = HomeTaskSectionBuilder.buildTodayLayout(
            mode: .groupByProjects,
            nonOverdueTasks: [completedTask, openTask],
            overdueTasks: [],
            projects: [inbox, work],
            customProjectOrderIDs: [work.id]
        )

        guard let workSection = layout.customSections.first(where: { $0.project.id == work.id }) else {
            return XCTFail("Expected Work section")
        }

        XCTAssertEqual(workSection.tasks.map(\.name), ["Completed Task", "Open Task"])
        XCTAssertEqual(workSection.tasks.map(\.isComplete), [true, false])
    }

    private func makeTask(
        name: String,
        project: Project,
        dueDate: Date,
        isComplete: Bool = false,
        priority: TaskPriority = .low
    ) -> DomainTask {
        DomainTask(
            projectID: project.id,
            name: name,
            dueDate: dueDate,
            isComplete: isComplete,
            priority: priority,
            project: project.name
        )
    }
}
