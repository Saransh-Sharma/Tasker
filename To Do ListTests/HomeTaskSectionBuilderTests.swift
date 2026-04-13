import XCTest
@testable import To_Do_List

private enum HomeRowDestinationSection {
    case morning
    case evening
    case overdue
}

private enum HomeRowStateCanonicalizer {
    struct CanonicalizedSections {
        let morning: [TaskDefinition]
        let evening: [TaskDefinition]
        let overdue: [TaskDefinition]
    }

    private static let noOverride: (UUID) -> Bool? = { _ in nil }

    static func deduplicate(
        tasks: [TaskDefinition],
        completionOverrideForID: @escaping (UUID) -> Bool?,
        logConflicts: Bool
    ) -> [TaskDefinition] {
        var orderedIDs: [UUID] = []
        var byID: [UUID: TaskDefinition] = [:]

        for task in tasks {
            if byID[task.id] == nil {
                orderedIDs.append(task.id)
                byID[task.id] = task
                continue
            }

            guard var existing = byID[task.id] else { continue }
            let override = completionOverrideForID(task.id)
            let existingEffective = override ?? existing.isComplete
            let incomingEffective = override ?? task.isComplete

            if incomingEffective != existingEffective {
                if incomingEffective == (override ?? incomingEffective) {
                    existing = task
                } else if logConflicts {
                    print("HomeRowStateCanonicalizer conflict for task \(task.id)")
                }
            } else if override != nil, task.isComplete == override {
                existing = task
            }

            if let override {
                existing.isComplete = override
                if override == false {
                    existing.dateCompleted = nil
                } else if existing.dateCompleted == nil {
                    existing.dateCompleted = Date()
                }
            }

            byID[task.id] = existing
        }

        return orderedIDs.compactMap { byID[$0] }
    }

    static func tasksEligibleForCompletedMerge(
        from tasks: [TaskDefinition],
        completionOverrideForID: ((UUID) -> Bool?)?
    ) -> [TaskDefinition] {
        let override = completionOverrideForID ?? noOverride
        return tasks.filter { task in
            let effective = override(task.id) ?? task.isComplete
            return effective
        }
    }

    static func sortSectionTasksForDisplay(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        tasks
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.isComplete != rhs.element.isComplete {
                    return lhs.element.isComplete == false
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    static func canonicalizeMergedSections(
        morning: [TaskDefinition],
        evening: [TaskDefinition],
        overdue: [TaskDefinition],
        completionOverrideForID: ((UUID) -> Bool?)?,
        destinationForTaskID: (UUID) -> HomeRowDestinationSection
    ) -> CanonicalizedSections {
        let override = completionOverrideForID ?? noOverride
        let deduped = deduplicate(
            tasks: morning + evening + overdue,
            completionOverrideForID: override,
            logConflicts: false
        )
        let ordered = sortSectionTasksForDisplay(deduped)

        var morningRows: [TaskDefinition] = []
        var eveningRows: [TaskDefinition] = []
        var overdueRows: [TaskDefinition] = []

        for task in ordered {
            switch destinationForTaskID(task.id) {
            case .morning:
                morningRows.append(task)
            case .evening:
                eveningRows.append(task)
            case .overdue:
                overdueRows.append(task)
            }
        }

        return CanonicalizedSections(
            morning: morningRows,
            evening: eveningRows,
            overdue: overdueRows
        )
    }
}

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
        XCTAssertEqual(layout.inboxSection?.tasks.map(\.title), ["Inbox Due"])

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
        XCTAssertEqual(workSection.tasks.first?.title, "Work Due")
        XCTAssertEqual(workSection.tasks.last?.title, "Work Overdue")
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

        XCTAssertEqual(workSection.tasks.map(\.title), ["Completed Task", "Open Task"])
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

        XCTAssertEqual(eligible.map(\.title), ["Completed"])
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

        XCTAssertEqual(sorted.map(\.title), ["Open Low", "Completed High"])
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

        XCTAssertEqual(canonical.morning.map(\.title), ["Open Task", "Completed Task"])
        XCTAssertEqual(canonical.morning.map(\.isComplete), [false, true])
    }

    func testTaskRowDisplayModelShowsOverdueProjectRecurrenceAndFirstTagInOverdueSection() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        var task = TaskDefinition(
            projectID: ProjectConstants.inboxProjectID,
            title: "Escalation follow-up",
            details: "Coordinate blockers and owner handoffs",
            priority: .high,
            type: .morning,
            dueDate: Calendar.current.date(byAdding: .day, value: -10, to: now)
        )
        let tagID = UUID()
        task.tagIDs = [tagID]
        task.repeatPattern = .daily

        let model = TaskRowDisplayModel.from(
            task: task,
            showTypeBadge: false,
            now: now,
            isInOverdueSection: true,
            tagNameByID: [tagID: "Client"]
        )

        XCTAssertEqual(model.metadataText, "1w late • Inbox • Daily • Client")
        XCTAssertEqual(model.statusChip, nil)
    }

    func testTaskRowDisplayModelShowsInlineDueTimeAndProjectMetadataOnMainRows() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueToday = Calendar.current.date(byAdding: .hour, value: 6, to: now)!
        let overdue = Calendar.current.date(byAdding: .day, value: -2, to: now)!

        let dueTodayTask = TaskDefinition(projectName: "Ops", title: "Due later", priority: .low, dueDate: dueToday)
        let overdueTask = TaskDefinition(projectName: "Ops", title: "Late task", priority: .low, dueDate: overdue)

        let todayModel = TaskRowDisplayModel.from(task: dueTodayTask, showTypeBadge: false, now: now)
        let overdueModel = TaskRowDisplayModel.from(task: overdueTask, showTypeBadge: false, now: now)

        XCTAssertNil(todayModel.statusChip)
        XCTAssertEqual(todayModel.metadataText, "\(dueToday.formatted(date: .omitted, time: .shortened)) • Ops")
        XCTAssertNil(overdueModel.statusChip)
        XCTAssertEqual(overdueModel.metadataText, "2d late • Ops")
    }

    func testTaskRowDisplayModelShowsDueSoonChipOnlyInsideWindow() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let dueSoonTask = TaskDefinition(
            title: "Call legal",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .minute, value: 45, to: now)
        )
        let laterTask = TaskDefinition(
            title: "Design review",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .hour, value: 4, to: now)
        )

        let dueSoonModel = TaskRowDisplayModel.from(task: dueSoonTask, showTypeBadge: false, now: now)
        let laterModel = TaskRowDisplayModel.from(task: laterTask, showTypeBadge: false, now: now)

        XCTAssertEqual(dueSoonModel.statusChip, .dueSoon)
        XCTAssertNil(laterModel.statusChip)
    }

    func testTaskRowDisplayModelAppliesSmartDescriptionRules() {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 24, hour: 9, minute: 0))!
        let duplicateTask = TaskDefinition(
            title: "Call Manivel",
            details: "call manivel",
            priority: .low,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)
        )
        let highPriorityTask = TaskDefinition(
            title: "Escalation prep",
            details: "Send docs",
            priority: .high,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)
        )
        let contextRichTask = TaskDefinition(
            title: "Status update",
            details: "Summarize blockers, owner updates, and rollout notes",
            priority: .low,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)
        )
        let plainTask = TaskDefinition(
            title: "Follow up",
            details: "Ping team",
            priority: .low,
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)
        )

        let duplicateModel = TaskRowDisplayModel.from(task: duplicateTask, showTypeBadge: false, now: now)
        let highPriorityModel = TaskRowDisplayModel.from(task: highPriorityTask, showTypeBadge: false, now: now)
        let contextRichModel = TaskRowDisplayModel.from(task: contextRichTask, showTypeBadge: false, now: now)
        let plainModel = TaskRowDisplayModel.from(task: plainTask, showTypeBadge: false, now: now)

        XCTAssertNil(duplicateModel.descriptionText)
        XCTAssertEqual(highPriorityModel.descriptionText, "Send docs")
        XCTAssertEqual(contextRichModel.descriptionText, "Summarize blockers, owner updates, and rollout notes")
        XCTAssertNil(plainModel.descriptionText)
    }

    func testMixedTodaySectionsGroupTaskAndHabitInsideLifeAreaSection() {
        let inbox = Project.createInbox()
        let career = LifeArea(id: UUID(), name: "Career", color: nil, sortOrder: 0)
        let work = Project(id: UUID(), lifeAreaID: career.id, name: "Work", icon: .work)
        let task = makeTask(name: "Send recap", project: work, dueDate: Date())
        let habit = HomeHabitRow(
            habitID: UUID(),
            title: "Daily planning",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: career.id,
            lifeAreaName: "Career",
            projectID: work.id,
            projectName: work.name,
            iconSymbolName: "list.bullet.clipboard",
            dueAt: Calendar.current.date(byAdding: .hour, value: 1, to: Date()),
            state: .due
        )

        let sections = HomeMixedSectionBuilder.buildTodaySections(
            taskRows: [task],
            habitRows: [habit],
            projects: [inbox, work],
            lifeAreas: [career]
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.anchor.title, "Career")
        XCTAssertEqual(sections.first?.rows.count, 2)
        XCTAssertTrue(sections.first?.rows.contains(HomeTodayRow.task(task)) ?? false)
        XCTAssertTrue(sections.first?.rows.contains(HomeTodayRow.habit(habit)) ?? false)
    }

    func testMixedTodaySectionsPlaceProjectlessLapseOnlyHabitInLifeAreaSection() {
        let inbox = Project.createInbox()
        let lapseOnly = HomeHabitRow(
            habitID: UUID(),
            title: "No smoking",
            kind: .negative,
            trackingMode: .lapseOnly,
            lifeAreaID: UUID(),
            lifeAreaName: "Health",
            projectID: nil,
            projectName: nil,
            iconSymbolName: "nosign",
            dueAt: nil,
            state: .tracking,
            currentStreak: 9,
            bestStreak: 15
        )

        let sections = HomeMixedSectionBuilder.buildTodaySections(
            taskRows: [],
            habitRows: [lapseOnly],
            projects: [inbox],
            lifeAreas: []
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.anchor.title, "Health")
        XCTAssertEqual(sections.first?.rows, [.habit(lapseOnly)])
    }

    func testMixedTodaySectionsKeepResolvedRowsAtBottomOfSection() {
        let mind = LifeArea(name: "Mind")
        let work = Project(id: UUID(), lifeAreaID: mind.id, name: "Work", icon: .work)
        let openTask = makeTask(name: "Ship note", project: work, dueDate: Date(), isComplete: false)
        let completedTask = makeTask(
            name: "Closed loop",
            project: work,
            dueDate: Date(),
            isComplete: true,
            dateCompleted: Date()
        )
        let completedHabit = HomeHabitRow(
            habitID: UUID(),
            title: "Journal",
            kind: .positive,
            trackingMode: .dailyCheckIn,
            lifeAreaID: mind.id,
            lifeAreaName: mind.name,
            projectID: work.id,
            projectName: work.name,
            iconSymbolName: "book.closed",
            dueAt: Date(),
            state: .completedToday
        )

        let sections = HomeMixedSectionBuilder.buildTodaySections(
            taskRows: [completedTask, openTask],
            habitRows: [completedHabit],
            projects: [work],
            lifeAreas: [mind]
        )

        XCTAssertEqual(sections.first?.rows.first?.title, "Ship note")
        XCTAssertEqual(sections.first?.rows.map(\.isResolved), [false, true, true])
        XCTAssertEqual(
            Set(sections.first?.rows.dropFirst().map(\.title) ?? []),
            Set(["Journal", "Closed loop"])
        )
    }

    func testAdaptiveDayGroupingKeepsUnifiedPlainListWhenNoProjectCrossesThreshold() {
        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)

        let sections = HomeMixedSectionBuilder.buildTodaySections(
            taskRows: [
                makeTask(name: "Alpha 1", project: alpha, dueDate: Date()),
                makeTask(name: "Inbox 1", project: inbox, dueDate: Date()),
                makeTask(name: "Beta 1", project: beta, dueDate: Date())
            ],
            habitRows: [],
            projects: [inbox, alpha, beta],
            lifeAreas: [],
            useAdaptiveDayGrouping: true
        )

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.displayStyle, .plain)
        XCTAssertEqual(sections.first?.rows.map(\.title), ["Alpha 1", "Inbox 1", "Beta 1"])
    }

    func testAdaptiveDayGroupingEmitsQualifiedProjectSectionsInFirstOccurrenceOrder() {
        let inbox = Project.createInbox()
        let alpha = Project(id: UUID(), name: "Alpha", icon: .folder)
        let beta = Project(id: UUID(), name: "Beta", icon: .folder)

        let sections = HomeMixedSectionBuilder.buildTodaySections(
            taskRows: [
                makeTask(name: "Beta 1", project: beta, dueDate: Date()),
                makeTask(name: "Alpha 1", project: alpha, dueDate: Date()),
                makeTask(name: "Beta 2", project: beta, dueDate: Date()),
                makeTask(name: "Inbox 1", project: inbox, dueDate: Date()),
                makeTask(name: "Alpha 2", project: alpha, dueDate: Date()),
                makeTask(name: "Inbox 2", project: inbox, dueDate: Date()),
                makeTask(name: "Alpha 3", project: alpha, dueDate: Date()),
                makeTask(name: "Inbox 3", project: inbox, dueDate: Date()),
                makeTask(name: "Alpha 4", project: alpha, dueDate: Date()),
                makeTask(name: "Inbox 4", project: inbox, dueDate: Date())
            ],
            habitRows: [],
            projects: [inbox, alpha, beta],
            lifeAreas: [],
            useAdaptiveDayGrouping: true
        )

        XCTAssertEqual(sections.count, 4)
        XCTAssertEqual(sections[0].displayStyle, .plain)
        XCTAssertEqual(sections[0].rows.map(\.title), ["Beta 1"])
        XCTAssertEqual(sections[1].anchor.title, "Alpha")
        XCTAssertEqual(sections[1].rows.map(\.title), ["Alpha 1", "Alpha 2", "Alpha 3", "Alpha 4"])
        XCTAssertEqual(sections[2].displayStyle, .plain)
        XCTAssertEqual(sections[2].rows.map(\.title), ["Beta 2"])
        XCTAssertTrue(sections[3].anchor.isInboxProject)
        XCTAssertEqual(sections[3].rows.map(\.title), ["Inbox 1", "Inbox 2", "Inbox 3", "Inbox 4"])
    }

    private func makeTask(
        id: UUID = UUID(),
        name: String,
        project: Project,
        dueDate: Date,
        isComplete: Bool = false,
        priority: TaskPriority = .low,
        dateCompleted: Date? = nil
    ) -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: project.id,
            projectName: project.name,
            title: name,
            priority: priority,
            dueDate: dueDate,
            isComplete: isComplete,
            dateCompleted: dateCompleted
        )
    }
}
