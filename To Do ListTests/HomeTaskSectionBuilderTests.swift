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

    func testRowStateDeduplicatePrefersOverrideAlignedState() {
        let sharedID = UUID()
        let openTask = makeTask(
            id: sharedID,
            name: "Task",
            project: Project.createInbox(),
            dueDate: Date(),
            isComplete: false
        )
        let doneTask = makeTask(
            id: sharedID,
            name: "Task",
            project: Project.createInbox(),
            dueDate: Date(),
            isComplete: true,
            dateCompleted: Date()
        )

        let deduplicated = HomeRowStateCanonicalizer.deduplicate(
            tasks: [openTask, doneTask],
            completionOverrideForID: { id in
                id == sharedID ? false : nil
            },
            logConflicts: false
        )

        XCTAssertEqual(deduplicated.count, 1)
        XCTAssertFalse(deduplicated[0].isComplete)
    }

    func testRowStateDeduplicateKeepsFirstSeenOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let inbox = Project.createInbox()

        let firstOpen = makeTask(id: firstID, name: "First", project: inbox, dueDate: Date(), isComplete: false)
        let secondOpen = makeTask(id: secondID, name: "Second", project: inbox, dueDate: Date(), isComplete: false)
        let firstDone = makeTask(id: firstID, name: "First", project: inbox, dueDate: Date(), isComplete: true, dateCompleted: Date())

        let deduplicated = HomeRowStateCanonicalizer.deduplicate(
            tasks: [firstOpen, secondOpen, firstDone],
            completionOverrideForID: { id in
                id == firstID ? true : nil
            },
            logConflicts: false
        )

        XCTAssertEqual(deduplicated.map(\.id), [firstID, secondID])
        XCTAssertTrue(deduplicated[0].isComplete)
        XCTAssertFalse(deduplicated[1].isComplete)
    }

    func testCompletedMergeEligibilitySkipsReopenedRows() {
        let inbox = Project.createInbox()
        let reopened = makeTask(
            name: "Reopened",
            project: inbox,
            dueDate: Date(),
            isComplete: false
        )
        let completed = makeTask(
            name: "Completed",
            project: inbox,
            dueDate: Date(),
            isComplete: true,
            dateCompleted: Date()
        )

        let eligible = HomeRowStateCanonicalizer.tasksEligibleForCompletedMerge(
            from: [reopened, completed],
            completionOverrideForID: nil
        )

        XCTAssertEqual(eligible.map(\.name), ["Completed"])
        XCTAssertTrue(eligible.allSatisfy(\.isComplete))
    }

    func testSectionSortPlacesOpenRowsBeforeCompletedRows() {
        let inbox = Project.createInbox()
        let completedHighPriority = makeTask(
            name: "Completed High",
            project: inbox,
            dueDate: Date(),
            isComplete: true,
            priority: .max,
            dateCompleted: Date()
        )
        let openLowPriority = makeTask(
            name: "Open Low",
            project: inbox,
            dueDate: Date(),
            isComplete: false,
            priority: .low
        )

        let sorted = HomeRowStateCanonicalizer.sortSectionTasksForDisplay([completedHighPriority, openLowPriority])

        XCTAssertEqual(sorted.map(\.name), ["Open Low", "Completed High"])
        XCTAssertEqual(sorted.map(\.isComplete), [false, true])
    }

    func testCanonicalizeMergedSectionsRemovesCrossSectionDuplicateIDs() {
        let inbox = Project.createInbox()
        let sharedID = UUID()
        let completedDate = Date()

        let openMorning = makeTask(
            id: sharedID,
            name: "Shared Task",
            project: inbox,
            dueDate: Date(),
            isComplete: false
        )
        let doneEvening = makeTask(
            id: sharedID,
            name: "Shared Task",
            project: inbox,
            dueDate: Date(),
            isComplete: true,
            dateCompleted: completedDate
        )
        let anotherOpen = makeTask(
            name: "Another Open",
            project: inbox,
            dueDate: Date(),
            isComplete: false
        )

        let canonical = HomeRowStateCanonicalizer.canonicalizeMergedSections(
            morning: [openMorning, anotherOpen],
            evening: [doneEvening],
            overdue: [],
            completionOverrideForID: nil
        ) { _ in .morning }

        let ids = canonical.morning.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.count, 2)
    }

    func testCanonicalizeMergedSectionsPrefersOpenStateWhenOverrideReopensTask() {
        let inbox = Project.createInbox()
        let sharedID = UUID()

        let reopened = makeTask(
            id: sharedID,
            name: "Reopened",
            project: inbox,
            dueDate: Date(),
            isComplete: false
        )
        let staleCompleted = makeTask(
            id: sharedID,
            name: "Reopened",
            project: inbox,
            dueDate: Date(),
            isComplete: true,
            dateCompleted: Date()
        )

        let canonical = HomeRowStateCanonicalizer.canonicalizeMergedSections(
            morning: [reopened],
            evening: [staleCompleted],
            overdue: [],
            completionOverrideForID: { id in
                id == sharedID ? false : nil
            }
        ) { _ in .morning }

        XCTAssertEqual(canonical.morning.count, 1)
        XCTAssertEqual(canonical.morning.first?.id, sharedID)
        XCTAssertEqual(canonical.morning.first?.isComplete, false)
    }

    func testCanonicalizeMergedSectionsKeepsOpenRowsBeforeCompletedRows() {
        let inbox = Project.createInbox()
        let openTask = makeTask(
            name: "Open Task",
            project: inbox,
            dueDate: Date(),
            isComplete: false,
            priority: .low
        )
        let completedTask = makeTask(
            name: "Completed Task",
            project: inbox,
            dueDate: Date(),
            isComplete: true,
            priority: .max,
            dateCompleted: Date()
        )

        let canonical = HomeRowStateCanonicalizer.canonicalizeMergedSections(
            morning: [completedTask, openTask],
            evening: [],
            overdue: [],
            completionOverrideForID: nil
        ) { _ in .morning }

        XCTAssertEqual(canonical.morning.map(\.name), ["Open Task", "Completed Task"])
        XCTAssertEqual(canonical.morning.map(\.isComplete), [false, true])
    }

    func testTaskRowDisplayModelBuildsCompactMetadataAndTrailingDue() {
        let due = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        let task = DomainTask(
            projectID: ProjectConstants.inboxProjectID,
            name: "Metadata task",
            details: "  Add note  ",
            type: .morning,
            priority: .high,
            dueDate: due,
            project: ProjectConstants.inboxProjectName
        )

        let model = TaskRowDisplayModel.from(task: task, showTypeBadge: false, now: Date())

        XCTAssertTrue(model.rowMetaText.contains("Inbox"))
        XCTAssertTrue(model.rowMetaText.contains("+\(task.priority.scorePoints) XP"))
        XCTAssertFalse(model.trailingMetaText.isEmpty)
        XCTAssertEqual(model.noteText, "Add note")
    }

    func testTaskRowDisplayModelFallsBackToXPWhenNoDueDate() {
        let task = DomainTask(
            projectID: ProjectConstants.inboxProjectID,
            name: "No due date",
            type: .morning,
            priority: .low,
            dueDate: nil,
            project: nil
        )

        let model = TaskRowDisplayModel.from(task: task, showTypeBadge: true, now: Date())
        XCTAssertEqual(model.trailingMetaText, "+\(task.priority.scorePoints) XP")
        XCTAssertTrue(model.rowMetaText.contains("Inbox"))
        XCTAssertTrue(model.rowMetaText.contains("Morning"))
    }

    private func makeTask(
        id: UUID = UUID(),
        name: String,
        project: Project,
        dueDate: Date,
        isComplete: Bool = false,
        priority: TaskPriority = .low,
        dateCompleted: Date? = nil
    ) -> DomainTask {
        DomainTask(
            id: id,
            projectID: project.id,
            name: name,
            dueDate: dueDate,
            isComplete: isComplete,
            priority: priority,
            dateCompleted: dateCompleted,
            project: project.name
        )
    }
}
