import XCTest
@testable import LifeBoard

final class SunriseHeaderAssetTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        TimeOfDayHeaderAsset.resetCacheForTests()
    }

    override func tearDown() {
        TimeOfDayHeaderAsset.resetCacheForTests()
        calendar = nil
        super.tearDown()
    }

    func testPeriodBucketsUseProductionBoundaries() {
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 4, minute: 59), calendar: calendar), .night)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 5), calendar: calendar), .morning)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 11, minute: 59), calendar: calendar), .morning)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 12), calendar: calendar), .afternoon)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 16, minute: 59), calendar: calendar), .afternoon)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 17), calendar: calendar), .evening)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 20, minute: 59), calendar: calendar), .evening)
        XCTAssertEqual(TimeOfDayHeaderAsset.period(for: date(hour: 21), calendar: calendar), .night)
    }

    func testAssetNamesMatchSixVariantsPerPeriod() {
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .morning), ["M1", "M2", "M3", "M4", "M5", "M6"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .afternoon), ["A1", "A2", "A3", "A4", "A5", "A6"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .evening), ["E1", "E2", "E3", "E4", "E5", "E6"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .night), ["N1", "N2", "N3", "N4", "N5", "N6"])
    }

    func testResolveIsStableForSameDateAndPeriod() {
        let first = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), calendar: calendar)
        let second = TimeOfDayHeaderAsset.resolve(for: date(hour: 11, minute: 30), calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertTrue(TimeOfDayHeaderAsset.assetNames(for: .morning).contains(first.name))
    }

    func testResolveChangesCacheKeyWhenPeriodChanges() {
        let morning = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), calendar: calendar)
        let afternoon = TimeOfDayHeaderAsset.resolve(for: date(hour: 14), calendar: calendar)

        XCTAssertNotEqual(morning.dateKey, afternoon.dateKey)
        XCTAssertEqual(morning.period, .morning)
        XCTAssertEqual(afternoon.period, .afternoon)
    }

    func testStableIndexIsDeterministicAndBounded() {
        let key = TimeOfDayHeaderAsset.cacheKey(for: date(hour: 8), period: .morning, calendar: calendar)

        let first = TimeOfDayHeaderAsset.stableIndex(dateKey: key, count: 6)
        let second = TimeOfDayHeaderAsset.stableIndex(dateKey: key, count: 6)

        XCTAssertEqual(first, second)
        XCTAssertTrue((0..<6).contains(first))
        XCTAssertEqual(TimeOfDayHeaderAsset.stableIndex(dateKey: key, count: 0), 0)
    }

    func testHeaderContextUsesCurrentClockForSelectedToday() {
        let selectedDateAtMidnight = date(hour: 0)
        let now = date(hour: 16, minute: 24)

        let context = LBHeaderTimeContext.resolve(selectedDate: selectedDateAtMidnight, now: now, calendar: calendar)

        XCTAssertEqual(context.period, .afternoon)
        XCTAssertEqual(context.asset.period, .afternoon)
        XCTAssertEqual(context.greeting, TimeOfDayHeaderAsset.Period.afternoon.greeting)
    }

    func testHeaderContextUsesNoonForNonTodayDates() {
        let selectedDateAtMidnight = date(hour: 0, day: 9)
        let now = date(hour: 22, day: 8)

        let context = LBHeaderTimeContext.resolve(selectedDate: selectedDateAtMidnight, now: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: context.effectiveDate), 12)
        XCTAssertEqual(context.period, .afternoon)
        XCTAssertEqual(context.asset.period, .afternoon)
    }

    func testNavigatorTitleAvoidsDuplicatingHeroDateForRelativeDays() {
        let now = date(hour: 9, day: 8)

        XCTAssertEqual(LBHeaderTimeContext.navigatorTitle(selectedDate: date(hour: 0, day: 8), now: now, calendar: calendar), "Today")
        XCTAssertEqual(LBHeaderTimeContext.navigatorTitle(selectedDate: date(hour: 0, day: 9), now: now, calendar: calendar), "Tomorrow")
        XCTAssertEqual(LBHeaderTimeContext.navigatorTitle(selectedDate: date(hour: 0, day: 7), now: now, calendar: calendar), "Yesterday")
    }

    func testSunriseDateNavigatorAccessibilityIdentifiersAreStable() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let headerSource = try String(contentsOf: projectRoot.appendingPathComponent("LifeBoard/LifeBoardDesign/Components/LBDateHeroHeader.swift"))
        let homeSource = try String(contentsOf: projectRoot.appendingPathComponent("LifeBoard/View/HomeForedropView.swift"))

        XCTAssertTrue(headerSource.contains("\"home.sunrise.date.previous\""))
        XCTAssertTrue(headerSource.contains("\"home.sunrise.date.next\""))
        XCTAssertTrue(headerSource.contains("\"home.sunrise.date.selector\""))
        XCTAssertTrue(homeSource.contains("\"home.datePicker\""))
    }

    func testAssistantCopySwitchesByTimeBucket() {
        let start = date(hour: 14)
        let end = date(hour: 15, minute: 30)

        XCTAssertEqual(LBHeaderTimeContext.assistantCopy(for: .morning, gapStart: start, gapEnd: end, now: start).title, "Use this morning well")
        XCTAssertEqual(LBHeaderTimeContext.assistantCopy(for: .afternoon, gapStart: start, gapEnd: end, now: start).title, "Protect the next block")
        XCTAssertEqual(LBHeaderTimeContext.assistantCopy(for: .evening, gapStart: start, gapEnd: end, now: start).title, "Evening buffer")
        XCTAssertEqual(LBHeaderTimeContext.assistantCopy(for: .night, gapStart: start, gapEnd: end, now: start).title, "Wind down gently")
    }

    @MainActor
    func testOnlyOneFilterChipIsSelected() {
        let models = SunriseHomeScreen.filterChipModels(selectedFilterID: "tasks")
        let selectedIDs = models.filter(\.isSelected).map(\.id)

        XCTAssertEqual(selectedIDs, ["tasks"])
        XCTAssertFalse(models.first(where: { $0.id == "all" })?.isSelected ?? true)
    }

    @MainActor
    func testFilterChipOrderIncludesFiltersAfterHabits() {
        let models = SunriseHomeScreen.filterChipModels(selectedFilterID: "all", hasActiveFilters: true)

        XCTAssertEqual(models.map(\.title), ["All", "Meetings", "Tasks", "Habits", "Filters"])
        XCTAssertEqual(models.map(\.id), ["all", "meetings", "tasks", "habits", "filters"])
        XCTAssertFalse(models.first(where: { $0.id == "filters" })?.isSelected ?? true)
        XCTAssertTrue(models.first(where: { $0.id == "filters" })?.showsIndicator ?? false)
    }

    func testNowRowSortsChronologicallyBetweenTimelineItems() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 11, minute: 15), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let earlyTask = timelineItem(id: "early", startHour: 18, startMinute: 5, endHour: 18, endMinute: 20)
        let lateTask = timelineItem(id: "late", startHour: 22, startMinute: 0, endHour: 22, endMinute: 30)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [earlyTask, lateTask],
            gaps: [],
            now: now,
            isToday: true,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertEqual(rows.map { $0.id }, ["anchor-wake", "item-early", "now-\(Int(now.timeIntervalSince1970 / 60))", "item-late", "anchor-sleep"])
    }

    func testNowRowIsOmittedForNonTodayTimeline() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 11, minute: 15), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [],
            gaps: [],
            now: now,
            isToday: false,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertFalse(rows.contains { if case .now = $0 { return true }; return false })
    }

    func testWindDownAnchorStaysSeparateFromAssistantGap() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 8), systemImageName: "sunrise.fill")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let activeGap = TimelineGap(startDate: date(hour: 21), endDate: date(hour: 22), suggestedTaskCount: 0)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [],
            gaps: [activeGap],
            now: now,
            isToday: true,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertTrue(rows.contains { $0.id == "anchor-sleep" })
        XCTAssertTrue(rows.contains { if case .gap = $0 { return true }; return false })
        XCTAssertEqual(LBColorTokens.role(.windDown).symbolName, "moon.stars.fill")
    }

    func testTemporalStateMarksPastCurrentAndFutureRows() {
        let now = date(hour: 21, minute: 15)
        let past = timelineItem(id: "past", startHour: 18, startMinute: 5, endHour: 18, endMinute: 20)
        let current = timelineItem(id: "current", startHour: 21, startMinute: 0, endHour: 21, endMinute: 30)
        let future = timelineItem(id: "future", startHour: 22, startMinute: 0, endHour: 22, endMinute: 30)

        XCTAssertEqual(SunriseTimelineRow.item(past).temporalState(now: now), .past)
        XCTAssertEqual(SunriseTimelineRow.item(current).temporalState(now: now), .current)
        XCTAssertEqual(SunriseTimelineRow.item(future).temporalState(now: now), .future)
    }

    func testActiveAssistantGapDisplaysAtNowAndStaleGapsAreHidden() {
        let now = date(hour: 21, minute: 15)
        let activeGap = TimelineGap(startDate: date(hour: 20), endDate: date(hour: 22), suggestedTaskCount: 0)
        let staleGap = TimelineGap(startDate: date(hour: 18), endDate: date(hour: 18, minute: 30), suggestedTaskCount: 0)
        let shortGap = TimelineGap(startDate: date(hour: 21), endDate: date(hour: 21, minute: 25), suggestedTaskCount: 0)

        XCTAssertEqual(SunriseHomeScreen.assistantDisplayDate(for: activeGap, now: now), now)
        XCTAssertNil(SunriseHomeScreen.assistantDisplayDate(for: staleGap, now: now))
        XCTAssertNil(SunriseHomeScreen.assistantDisplayDate(for: shortGap, now: now))
    }

    func testTaskAndCalendarCardModelsExposeToggleSemantics() {
        let taskModel = LBTimelineCard.Model(
            id: "task",
            title: "Task",
            subtitle: "Inbox",
            timeText: "9:00 PM",
            role: .task,
            kind: .task,
            systemImage: "checkmark.square",
            accessoryText: "Task",
            temporalState: .future,
            isCompleted: false,
            isToggleable: true,
            isCurrent: false
        )
        let calendarModel = LBTimelineCard.Model(
            id: "calendar",
            title: "Calendar",
            subtitle: "Calendar",
            timeText: "9:00 PM",
            role: .meeting,
            kind: .calendar,
            systemImage: "calendar",
            accessoryText: nil,
            temporalState: .future,
            isCompleted: false,
            isToggleable: false,
            isCurrent: false
        )

        XCTAssertEqual(taskModel.kind, .task)
        XCTAssertTrue(taskModel.isToggleable)
        XCTAssertEqual(calendarModel.kind, .calendar)
        XCTAssertFalse(calendarModel.isToggleable)
    }

    private func date(hour: Int, minute: Int = 0, day: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: day, hour: hour, minute: minute))!
    }

    private func timelineItem(
        id: String,
        source: TimelinePlanItemSource = .task,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        isComplete: Bool = false
    ) -> TimelinePlanItem {
        TimelinePlanItem(
            id: id,
            source: source,
            taskID: source == .task ? UUID() : nil,
            eventID: source == .calendarEvent ? id : nil,
            title: id,
            subtitle: source == .calendarEvent ? "Calendar" : "Inbox",
            startDate: date(hour: startHour, minute: startMinute),
            endDate: date(hour: endHour, minute: endMinute),
            isAllDay: false,
            isComplete: isComplete,
            tintHex: nil,
            systemImageName: source == .calendarEvent ? "calendar" : "checkmark.square",
            accessoryText: nil
        )
    }

    private func stubMeetingFlock(_ items: [TimelinePlanItem]) -> LBMeetingFlockCard.Model {
        LBMeetingFlockCard.Model(
            id: "stub-flock",
            timeRange: "9:00 PM – 10:00 PM",
            meetings: items.map { item in
                LBMeetingFlockCard.Meeting(id: item.id, title: item.title, timeText: "9:00 PM", isNow: false)
            },
            eventCountText: "\(items.count) events"
        )
    }
}
