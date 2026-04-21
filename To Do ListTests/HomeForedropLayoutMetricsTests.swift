import XCTest
@testable import To_Do_List

final class HomeForedropLayoutMetricsTests: XCTestCase {

    func testCollapsedOffsetIsZero() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 18,
            timelineHeaderHeight: 64,
            weeklyBackdropHeight: 300,
            geometryHeight: 844
        )

        XCTAssertEqual(metrics.offset(for: .collapsed), 0)
    }

    func testMidRevealOffsetRespondsToMeasuredBackdropHeight() {
        let compact = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 96,
            timelineHeaderHeight: 56,
            weeklyBackdropHeight: 120,
            geometryHeight: 1000
        )
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 96,
            timelineHeaderHeight: 56,
            weeklyBackdropHeight: 180,
            geometryHeight: 1000
        )

        XCTAssertGreaterThan(metrics.offset(for: .midReveal), compact.offset(for: .midReveal))
    }

    func testFullRevealOffsetRespondsToMeasuredCalendarHeight() {
        let compact = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 88,
            timelineHeaderHeight: 64,
            weeklyBackdropHeight: 180,
            geometryHeight: 1000
        )
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 132,
            timelineHeaderHeight: 64,
            weeklyBackdropHeight: 180,
            geometryHeight: 1000
        )

        XCTAssertGreaterThan(metrics.offset(for: .fullReveal), compact.offset(for: .fullReveal))
    }

    func testOffsetsRemainMonotonicAcrossSnapStates() {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: 108,
            timelineHeaderHeight: 70,
            weeklyBackdropHeight: 156,
            geometryHeight: 844
        )

        XCTAssertLessThan(metrics.offset(for: .collapsed), metrics.offset(for: .midReveal))
        XCTAssertLessThan(metrics.offset(for: .midReveal), metrics.offset(for: .fullReveal))
    }

    func testScheduleNormalizerCreatesTimedScheduleFromDeadline() {
        let calendar = Self.fixedCalendar
        let pickedDate = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 30)
        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: pickedDate,
            existingScheduledStartAt: nil,
            existingScheduledEndAt: nil,
            estimatedDuration: 15 * 60,
            preserveExistingDuration: false,
            calendar: calendar
        )

        XCTAssertEqual(schedule.dueDate, pickedDate)
        XCTAssertEqual(schedule.scheduledStartAt, pickedDate)
        XCTAssertEqual(schedule.scheduledEndAt, pickedDate.addingTimeInterval(15 * 60))
        XCTAssertFalse(schedule.isAllDay)
        XCTAssertFalse(schedule.clearScheduledStartAt)
        XCTAssertFalse(schedule.clearScheduledEndAt)
    }

    func testScheduleNormalizerTreatsDateOnlyDeadlineAsAllDay() {
        let calendar = Self.fixedCalendar
        let pickedDate = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 0, minute: 0)
        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: pickedDate,
            existingScheduledStartAt: nil,
            existingScheduledEndAt: nil,
            estimatedDuration: 45 * 60,
            preserveExistingDuration: false,
            calendar: calendar
        )

        XCTAssertEqual(schedule.dueDate, pickedDate)
        XCTAssertNil(schedule.scheduledStartAt)
        XCTAssertNil(schedule.scheduledEndAt)
        XCTAssertTrue(schedule.isAllDay)
        XCTAssertTrue(schedule.clearScheduledStartAt)
        XCTAssertTrue(schedule.clearScheduledEndAt)
    }

    func testScheduleNormalizerPreservesExistingDurationDuringReschedule() {
        let calendar = Self.fixedCalendar
        let existingStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let existingEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30)
        let newDate = Self.date(calendar: calendar, year: 2026, month: 4, day: 22, hour: 13, minute: 15)
        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: newDate,
            existingScheduledStartAt: existingStart,
            existingScheduledEndAt: existingEnd,
            estimatedDuration: 15 * 60,
            preserveExistingDuration: true,
            calendar: calendar
        )

        XCTAssertEqual(schedule.scheduledStartAt, newDate)
        XCTAssertEqual(schedule.scheduledEndAt, newDate.addingTimeInterval(90 * 60))
        XCTAssertFalse(schedule.isAllDay)
    }

    func testScheduleNormalizerClearsScheduleWhenDeadlineRemoved() {
        let schedule = TaskScheduleNormalizer.normalize(
            deadlineDate: nil,
            existingScheduledStartAt: Date(),
            existingScheduledEndAt: Date().addingTimeInterval(1800),
            estimatedDuration: 1800,
            preserveExistingDuration: true
        )

        XCTAssertNil(schedule.dueDate)
        XCTAssertNil(schedule.scheduledStartAt)
        XCTAssertNil(schedule.scheduledEndAt)
        XCTAssertFalse(schedule.isAllDay)
        XCTAssertTrue(schedule.clearScheduledStartAt)
        XCTAssertTrue(schedule.clearScheduledEndAt)
    }

    func testTimelineLayoutPlanPlacesNonOverlappingItemsProportionally() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let firstStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 30)
        let firstEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let secondStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let secondEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "first", title: "First", start: firstStart, end: firstEnd),
                Self.makeTimedItem(id: "second", title: "Second", start: secondStart, end: secondEnd)
            ],
            gaps: [
                TimelineGap(startDate: firstEnd, endDate: secondStart, suggestedTaskCount: 2)
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.items.count, 2)
        XCTAssertEqual(plan.items[0].y, plan.topInset + 30, accuracy: 0.001)
        XCTAssertEqual(plan.items[1].y, plan.topInset + 120, accuracy: 0.001)
        XCTAssertEqual(plan.gaps.first?.startY ?? 0, plan.topInset + 60, accuracy: 0.001)
        XCTAssertEqual(plan.gaps.first?.height ?? 0, 60, accuracy: 0.001)
    }

    func testTimelineLayoutPlanAssignsOverlapColumnsSideBySide() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(
                    id: "first",
                    title: "First",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
                ),
                Self.makeTimedItem(
                    id: "second",
                    title: "Second",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 15),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 45)
                ),
                Self.makeTimedItem(
                    id: "third",
                    title: "Third",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 30),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 15)
                )
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.items.map(\.columnCount), [3, 3, 3])
        XCTAssertEqual(plan.items.map(\.columnIndex), [0, 1, 2])
    }

    func testTimelineLayoutPlanKeepsShortItemAnchoredWhileApplyingMinimumHeight() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 10)
        let end = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 20)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "short", title: "Short", start: start, end: end)
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.items.first?.y ?? 0, plan.topInset + 10, accuracy: 0.001)
        XCTAssertEqual(plan.items.first?.height ?? 0, 44, accuracy: 0.001)
    }

    func testExpandedTimelineLayoutPlanRendersLongerItemsTallerThanShorterItems() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let thirtyMinuteStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let ninetyMinuteStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(
                    id: "thirty",
                    title: "Thirty",
                    start: thirtyMinuteStart,
                    end: thirtyMinuteStart.addingTimeInterval(30 * 60)
                ),
                Self.makeTimedItem(
                    id: "ninety",
                    title: "Ninety",
                    start: ninetyMinuteStart,
                    end: ninetyMinuteStart.addingTimeInterval(90 * 60)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.items.count, 2)
        XCTAssertGreaterThan(plan.items[1].height, plan.items[0].height)
    }

    func testCompactTimelineLayoutPlanPreservesChronologicalOrdering() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let itemStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 13, minute: 0)
        let itemEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 14, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "midday", title: "Midday", start: itemStart, end: itemEnd)
            ],
            gaps: [
                TimelineGap(startDate: wake, endDate: itemStart, suggestedTaskCount: 0),
                TimelineGap(startDate: itemEnd, endDate: sleep, suggestedTaskCount: 0)
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection)

        XCTAssertEqual(Self.compactEntryIDs(plan.entries), [
            "anchor:wake",
            "gap:\(wake.timeIntervalSince1970)-\(itemStart.timeIntervalSince1970)",
            "item:task:midday",
            "gap:\(itemEnd.timeIntervalSince1970)-\(sleep.timeIntervalSince1970)",
            "anchor:sleep"
        ])
    }

    func testCompactTimelineRailUsesSubtleContinuousConnector() {
        let spec = TimelineRailPresentationSpec.compactConnector

        XCTAssertFalse(spec.isDashed)
        XCTAssertLessThanOrEqual(spec.lineWidth, 2)
        XCTAssertGreaterThanOrEqual(spec.opacity, 0.35)
        XCTAssertLessThanOrEqual(spec.opacity, 0.55)
    }

    func testCompactTimelineLayoutPlanHeightStaysCappedForSparseDay() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let itemStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 12, minute: 0)
        let itemEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 13, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "focus", title: "Focus", start: itemStart, end: itemEnd)
            ],
            gaps: [
                TimelineGap(startDate: wake, endDate: itemStart, suggestedTaskCount: 1),
                TimelineGap(startDate: itemEnd, endDate: sleep, suggestedTaskCount: 1)
            ],
            layoutMode: .compact
        )

        let compactPlan = TimelineCompactLayoutPlan(projection: projection)
        let expandedPlan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertLessThan(compactPlan.contentHeight, 520)
        XCTAssertLessThan(compactPlan.contentHeight, expandedPlan.contentHeight * 0.55)
    }

    func testCompactTimelineLayoutPlanScalesItemRowsByDuration() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let thirtyMinuteStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let ninetyMinuteStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(
                    id: "thirty",
                    title: "Thirty",
                    start: thirtyMinuteStart,
                    end: thirtyMinuteStart.addingTimeInterval(30 * 60)
                ),
                Self.makeTimedItem(
                    id: "ninety",
                    title: "Ninety",
                    start: ninetyMinuteStart,
                    end: ninetyMinuteStart.addingTimeInterval(90 * 60)
                )
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection)
        let items = Self.compactItemEntries(plan.entries)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].capsuleHeight, 64, accuracy: 0.001)
        XCTAssertEqual(items[0].rowHeight, 84, accuracy: 0.001)
        XCTAssertEqual(items[1].capsuleHeight, 112, accuracy: 0.001)
        XCTAssertEqual(items[1].rowHeight, 132, accuracy: 0.001)
        XCTAssertGreaterThan(items[1].capsuleHeight, items[0].capsuleHeight)
        XCTAssertGreaterThan(items[1].rowHeight, items[0].rowHeight)
    }

    func testCompactTimelineLayoutPlanCapsVeryLongDurationRows() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 0),
            timedItems: [
                Self.makeTimedItem(
                    id: "long",
                    title: "Long",
                    start: start,
                    end: start.addingTimeInterval(4 * 60 * 60)
                )
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection)
        let item = Self.compactItemEntries(plan.entries).first

        XCTAssertEqual(item?.capsuleHeight ?? 0, 132, accuracy: 0.001)
        XCTAssertEqual(item?.rowHeight ?? 0, 152, accuracy: 0.001)
    }

    func testCompactTimelineLayoutPlanKeepsWakeAndSleepAnchorsAroundEmptyDayGap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [],
            gaps: [
                TimelineGap(startDate: wake, endDate: sleep, suggestedTaskCount: 0)
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection)

        XCTAssertEqual(Self.compactEntryIDs(plan.entries), [
            "anchor:wake",
            "gap:\(wake.timeIntervalSince1970)-\(sleep.timeIntervalSince1970)",
            "anchor:sleep"
        ])
    }

    func testFaceMappingSelectsBottomBarHomeForTasksFace() {
        XCTAssertEqual(HomeForedropFace.tasks.selectedBottomBarItem, .home)
    }

    func testFaceMappingSelectsBottomBarChartsForAnalyticsFace() {
        XCTAssertEqual(HomeForedropFace.analytics.selectedBottomBarItem, .charts)
    }

    func testFaceMappingSelectsBottomBarSearchForSearchFace() {
        XCTAssertEqual(HomeForedropFace.search.selectedBottomBarItem, .search)
    }

    func testSurfaceAccessibilityValueContractRemainsStableForAllFaces() {
        XCTAssertEqual(HomeForedropFace.tasks.surfaceAccessibilityValue, "collapsed")
        XCTAssertEqual(HomeForedropFace.analytics.surfaceAccessibilityValue, "fullReveal")
        XCTAssertEqual(HomeForedropFace.search.surfaceAccessibilityValue, "fullReveal")
    }

    func testSearchStateDebouncesQueryUpdates() async throws {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0.05)
        }

        await MainActor.run {
            state.configureIfNeeded(
                makeEngine: { engine },
                dataRevisionProvider: { .zero }
            )
            state.updateQuery("meet")
            state.updateQuery("meeting")
        }

        try await _Concurrency.Task.sleep(nanoseconds: 10_000_000)
        let queriesBeforeDebounce = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queriesBeforeDebounce, [], "Debounced query should not fire immediately")

        try await _Concurrency.Task.sleep(nanoseconds: 80_000_000)
        let queriesAfterDebounce = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queriesAfterDebounce, ["meeting"], "Debounce should emit only latest query")
    }

    func testSearchStateAppliesStatusPriorityAndProjectFiltersTogether() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded(
                makeEngine: { engine },
                dataRevisionProvider: { .zero }
            )
            state.setStatus(.today)
            state.togglePriority(.high)
            state.toggleProject("Inbox")
        }

        let appliedStatus = await MainActor.run { engine.currentStatus }
        let appliedPriorities = await MainActor.run { engine.currentPriorities }
        let appliedProjects = await MainActor.run { engine.currentProjects }
        XCTAssertEqual(appliedStatus, .today)
        XCTAssertEqual(appliedPriorities, Set([TaskPriorityConfig.Priority.high.rawValue]))
        XCTAssertEqual(appliedProjects, Set(["Inbox"]))
    }

    func testSearchStateEmptyStateTransitionsBetweenDefaultAndNoResultQuery() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            engine.stubbedResultsByQuery[""] = []
            engine.stubbedResultsByQuery["xyz"] = []
            state.configureIfNeeded(
                makeEngine: { engine },
                dataRevisionProvider: { .zero }
            )
            state.activate()
        }

        let defaultTitle = await MainActor.run { state.emptyStateTitle }
        let defaultVisible = await MainActor.run { state.shouldShowNoResultsMessage }
        XCTAssertTrue(defaultVisible)
        XCTAssertEqual(defaultTitle, "Start searching")

        await MainActor.run {
            state.updateQuery("xyz")
        }

        let queryTitle = await MainActor.run { state.emptyStateTitle }
        let queryVisible = await MainActor.run { state.shouldShowNoResultsMessage }
        XCTAssertTrue(queryVisible)
        XCTAssertEqual(queryTitle, "No tasks found")
    }

    func testSearchFocusPolicyAutofocusesPhoneOnly() {
        let originalValue = V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled
        defer { V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled = originalValue }
        V2FeatureFlags.iPadPerfSearchFocusStabilizationV3Enabled = true

        XCTAssertFalse(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .phone))
        XCTAssertFalse(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .padRegular))
        XCTAssertFalse(HomeSearchFocusPolicyResolver.shouldAutoFocusOnSearchEntry(layoutClass: .padExpanded))
    }

    func testSearchStateActivationSkipsRedundantRefreshWhenSignatureIsUnchanged() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded(
                makeEngine: { engine },
                dataRevisionProvider: { .zero }
            )
            state.activate()
        }

        let initialCount = await MainActor.run { engine.searchQueries.count }

        await MainActor.run {
            state.activate()
        }

        let finalCount = await MainActor.run { engine.searchQueries.count }
        XCTAssertEqual(initialCount, 1)
        XCTAssertEqual(finalCount, initialCount, "Unchanged search activation should not issue a duplicate search")
    }

    func testSearchStateDataMutationForcesRefreshOnNextActivation() async {
        let engine = await MainActor.run { MockHomeSearchEngine() }
        let state = await MainActor.run {
            HomeSearchState(debounceDelay: 0)
        }

        await MainActor.run {
            state.configureIfNeeded(
                makeEngine: { engine },
                dataRevisionProvider: { .zero }
            )
            state.activate()
            state.markDataMutated()
            state.activate()
        }

        let queries = await MainActor.run { engine.searchQueries }
        XCTAssertEqual(queries.count, 2, "A data mutation should force one additional refresh")
    }

}

private extension HomeForedropLayoutMetricsTests {
    static var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func date(calendar: Calendar, year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 0)
    }

    static func makeTimedItem(id: String, title: String, start: Date, end: Date) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "task:\(id)",
            source: .task,
            taskID: UUID(),
            eventID: nil,
            title: title,
            subtitle: nil,
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: false,
            tintHex: ProjectColor.blue.hexString,
            systemImageName: "checklist",
            accessoryText: nil
        )
    }

    static func makeProjection(
        calendar: Calendar,
        wake: Date,
        sleep: Date,
        timedItems: [TimelinePlanItem],
        gaps: [TimelineGap] = [],
        layoutMode: TimelineDayLayoutMode = .expanded
    ) -> TimelineDayProjection {
        TimelineDayProjection(
            date: calendar.startOfDay(for: wake),
            allDayItems: [],
            inboxItems: [],
            timedItems: timedItems,
            gaps: gaps,
            layoutMode: layoutMode,
            wakeAnchor: TimelineAnchorItem(id: "wake", title: "Wake", time: wake, systemImageName: "sun.max.fill"),
            sleepAnchor: TimelineAnchorItem(id: "sleep", title: "Sleep", time: sleep, systemImageName: "moon.fill"),
            activeItemID: nil,
            currentTime: wake
        )
    }

    static func compactEntryIDs(_ entries: [TimelineCompactLayoutPlan.Entry]) -> [String] {
        entries.map { entry in
            switch entry {
            case .anchor(let anchor):
                return "anchor:\(anchor.anchor.id)"
            case .item(let item):
                return "item:\(item.item.id)"
            case .gap(let gap):
                return "gap:\(gap.gap.id)"
            }
        }
    }

    static func compactItemEntries(_ entries: [TimelineCompactLayoutPlan.Entry]) -> [TimelineCompactLayoutPlan.PositionedItem] {
        entries.compactMap { entry in
            guard case .item(let item) = entry else { return nil }
            return item
        }
    }
}

@MainActor
private final class MockHomeSearchEngine: HomeSearchEngine {
    var onResultsUpdated: ((Int, [TaskDefinition]) -> Void)?
    var projects: [Project] = [Project.createInbox()]

    var searchQueries: [String] = []
    var searchRevisions: [Int] = []
    var currentStatus: HomeSearchStatusFilter = .all
    var currentPriorities: Set<Int32> = []
    var currentProjects: Set<String> = []
    var stubbedResultsByQuery: [String: [TaskDefinition]] = [:]

    func search(query: String, revision: Int) {
        searchQueries.append(query)
        searchRevisions.append(revision)
        let payload = stubbedResultsByQuery[query] ?? []
        onResultsUpdated?(revision, payload)
    }

    func loadProjects(completion: (() -> Void)?) {
        completion?()
    }

    func setFilters(status: HomeSearchStatusFilter, projects: [String], priorities: [Int32]) {
        currentStatus = status
        currentProjects = Set(projects)
        currentPriorities = Set(priorities)
    }

    func clearFilters() {
        currentStatus = .all
        currentPriorities.removeAll()
        currentProjects.removeAll()
    }

    func toggleProjectFilter(_ project: String) {
        if currentProjects.contains(project) {
            currentProjects.remove(project)
        } else {
            currentProjects.insert(project)
        }
    }

    func togglePriorityFilter(_ priority: Int32) {
        if currentPriorities.contains(priority) {
            currentPriorities.remove(priority)
        } else {
            currentPriorities.insert(priority)
        }
    }

    func setStatusFilter(_ filter: HomeSearchStatusFilter) {
        currentStatus = filter
    }

    func invalidateSearchCache(revision: Int) {
        _ = revision
    }

    func releaseResources() {}

    func groupTasksByProject(_ tasks: [TaskDefinition]) -> [(project: String, tasks: [TaskDefinition])] {
        let grouped = Dictionary(grouping: tasks) { $0.projectName ?? "Inbox" }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.project < $1.project }
    }
}
