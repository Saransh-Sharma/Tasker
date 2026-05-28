import XCTest
import SwiftUI
@testable import LifeBoard
#if canImport(UIKit)
import UIKit
#endif

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

    func testAssetNamesMatchFourVariantsPerPeriod() {
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .morning), ["M1", "M2", "M3", "M4"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .afternoon), ["A1", "A2", "A3", "A4"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .evening), ["E1", "E2", "E3", "E4"])
        XCTAssertEqual(TimeOfDayHeaderAsset.assetNames(for: .night), ["N1", "N2", "N3", "N4"])
    }

    func testResolveIsStableForSameActivationAndPeriod() {
        let activationID = "launch-1"

        let first = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), activationID: activationID, calendar: calendar)
        let second = TimeOfDayHeaderAsset.resolve(for: date(hour: 11, minute: 30), activationID: activationID, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertTrue(TimeOfDayHeaderAsset.assetNames(for: .morning).contains(first.name))
    }

    func testResolveChangesSelectionKeyWhenPeriodChanges() {
        let activationID = "launch-1"

        let morning = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), activationID: activationID, calendar: calendar)
        let afternoon = TimeOfDayHeaderAsset.resolve(for: date(hour: 14), activationID: activationID, calendar: calendar)

        XCTAssertNotEqual(morning.selectionKey, afternoon.selectionKey)
        XCTAssertEqual(morning.period, .morning)
        XCTAssertEqual(afternoon.period, .afternoon)
    }

    func testStableIndexIsDeterministicAndBounded() {
        let key = TimeOfDayHeaderAsset.selectionKey(for: .morning, activationID: "launch-1")

        let first = TimeOfDayHeaderAsset.stableIndex(selectionKey: key, count: 4)
        let second = TimeOfDayHeaderAsset.stableIndex(selectionKey: key, count: 4)

        XCTAssertEqual(first, second)
        XCTAssertTrue((0..<4).contains(first))
        XCTAssertEqual(TimeOfDayHeaderAsset.stableIndex(selectionKey: key, count: 0), 0)
    }

    func testResolveChangesSelectionKeyWhenActivationChanges() {
        let first = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), activationID: "launch-1", calendar: calendar)
        let second = TimeOfDayHeaderAsset.resolve(for: date(hour: 8), activationID: "launch-2", calendar: calendar)

        XCTAssertNotEqual(first.selectionKey, second.selectionKey)
        XCTAssertTrue(TimeOfDayHeaderAsset.assetNames(for: .morning).contains(first.name))
        XCTAssertTrue(TimeOfDayHeaderAsset.assetNames(for: .morning).contains(second.name))
    }

    func testHeaderContextUsesCurrentClockForSelectedToday() {
        let selectedDateAtMidnight = date(hour: 0)
        let now = date(hour: 16, minute: 24)

        let context = LBHeaderTimeContext.resolve(
            selectedDate: selectedDateAtMidnight,
            now: now,
            activationID: "launch-1",
            calendar: calendar
        )

        XCTAssertEqual(context.period, .afternoon)
        XCTAssertEqual(context.asset.period, .afternoon)
        XCTAssertEqual(context.greeting, TimeOfDayHeaderAsset.Period.afternoon.greeting)
    }

    func testHeaderContextUsesNoonForNonTodayDates() {
        let selectedDateAtMidnight = date(hour: 0, day: 9)
        let now = date(hour: 22, day: 8)

        let context = LBHeaderTimeContext.resolve(
            selectedDate: selectedDateAtMidnight,
            now: now,
            activationID: "launch-1",
            calendar: calendar
        )

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
        let homeSource = try String(contentsOf: projectRoot.appendingPathComponent("LifeBoard/View/SunriseAppShellView.swift"))

        XCTAssertTrue(headerSource.contains("\"home.sunrise.date.selector\""))
        XCTAssertFalse(headerSource.contains("\"home.sunrise.date.previous\""))
        XCTAssertFalse(headerSource.contains("\"home.sunrise.date.next\""))
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
        let models = SunriseHomeScreen.filterChipModels(selectedContentScope: .tasks)
        let selectedIDs = models.filter(\.isSelected).map(\.id)

        XCTAssertEqual(selectedIDs, ["tasks"])
        XCTAssertFalse(models.first(where: { $0.id == "all" })?.isSelected ?? true)
    }

    @MainActor
    func testFilterChipOrderIncludesFiltersAfterHabits() {
        let models = SunriseHomeScreen.filterChipModels(selectedContentScope: .all, hasActiveFilters: true)

        XCTAssertEqual(models.map(\.title), ["All", "Meetings", "Tasks", "Habits", "Filters"])
        XCTAssertEqual(models.map(\.id), ["all", "meetings", "tasks", "habits", "filters"])
        XCTAssertFalse(models.first(where: { $0.id == "filters" })?.isSelected ?? true)
        XCTAssertTrue(models.first(where: { $0.id == "filters" })?.showsIndicator ?? false)
    }

    @MainActor
    func testFilterChipIndicatorDoesNotSelectFiltersChip() {
        let models = SunriseHomeScreen.filterChipModels(selectedContentScope: .meetings, hasActiveFilters: true)
        let selectedIDs = models.filter(\.isSelected).map(\.id)
        let filters = models.first(where: { $0.id == "filters" })

        XCTAssertEqual(selectedIDs, ["meetings"])
        XCTAssertFalse(filters?.isSelected ?? true)
        XCTAssertTrue(filters?.showsIndicator ?? false)
    }

    func testTasksContentScopeShowsOnlyTaskTimelineItems() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 8), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let task = timelineItem(id: "task", startHour: 18, endHour: 19)
        let meetingTask = timelineItem(id: "meeting-task", startHour: 19, endHour: 20, isMeetingLike: true)
        let calendarEvent = timelineItem(id: "event", source: .calendarEvent, startHour: 20, endHour: 21)
        let gap = TimelineGap(startDate: date(hour: 21), endDate: date(hour: 22), suggestedTaskCount: 0)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [task, meetingTask, calendarEvent],
            gaps: [gap],
            now: now,
            isToday: true,
            contentScope: .tasks,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertEqual(rows.map(\.id), ["item-task"])
    }

    func testMeetingsContentScopeShowsCalendarAndMeetingRowsOnly() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 8), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let task = timelineItem(id: "task", startHour: 17, endHour: 18)
        let meetingOne = timelineItem(id: "meeting-1", source: .calendarEvent, startHour: 18, endHour: 19)
        let meetingTwo = timelineItem(id: "meeting-2", source: .calendarEvent, startHour: 18, startMinute: 15, endHour: 19)
        let meetingThree = timelineItem(id: "meeting-3", source: .calendarEvent, startHour: 18, startMinute: 30, endHour: 19)
        let meetingTask = timelineItem(id: "meeting-task", startHour: 20, endHour: 21, isMeetingLike: true)
        let gap = TimelineGap(startDate: date(hour: 21), endDate: date(hour: 22), suggestedTaskCount: 0)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [task, meetingOne, meetingTwo, meetingThree, meetingTask],
            gaps: [gap],
            now: now,
            isToday: true,
            contentScope: .meetings,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertEqual(rows.map(\.id), ["item-meeting-1", "item-meeting-2", "item-meeting-3", "item-meeting-task"])
        XCTAssertFalse(rows.contains { $0.id == "item-task" })
        XCTAssertFalse(rows.contains { if case .gap = $0 { return true }; return false })
        XCTAssertFalse(rows.contains { if case .now = $0 { return true }; return false })
        XCTAssertFalse(rows.contains { $0.id.hasPrefix("anchor-") })
    }

    func testHabitsContentScopeSuppressesTimelineRows() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 8), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let task = timelineItem(id: "task", startHour: 18, endHour: 19)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [task],
            gaps: [TimelineGap(startDate: date(hour: 21), endDate: date(hour: 22), suggestedTaskCount: 0)],
            now: now,
            isToday: true,
            contentScope: .habits,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertTrue(rows.isEmpty)
    }

    func testAllContentScopeRestoresMixedTimelineRows() {
        let now = date(hour: 21, minute: 15)
        let wake = TimelineAnchorItem(id: "wake", title: "Rise", time: date(hour: 8), systemImageName: "sunrise")
        let sleep = TimelineAnchorItem(id: "sleep", title: "Wind Down", time: date(hour: 23), systemImageName: "moon.stars.fill")
        let task = timelineItem(id: "task", startHour: 18, endHour: 19)
        let calendarEvent = timelineItem(id: "event", source: .calendarEvent, startHour: 20, endHour: 21)
        let gap = TimelineGap(startDate: date(hour: 21), endDate: date(hour: 22), suggestedTaskCount: 0)

        let rows = SunriseHomeScreen.buildTimelineRows(
            wakeAnchor: wake,
            sleepAnchor: sleep,
            plottedItems: [task, calendarEvent],
            gaps: [gap],
            now: now,
            isToday: true,
            contentScope: .all,
            meetingFlockModel: stubMeetingFlock
        )

        XCTAssertTrue(rows.contains { $0.id == "anchor-wake" })
        XCTAssertTrue(rows.contains { $0.id == "item-task" })
        XCTAssertTrue(rows.contains { $0.id == "item-event" })
        XCTAssertTrue(rows.contains { if case .gap = $0 { return true }; return false })
        XCTAssertTrue(rows.contains { if case .now = $0 { return true }; return false })
        XCTAssertTrue(rows.contains { $0.id == "anchor-sleep" })
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
            tintHex: "#123456",
            accessoryText: nil,
            temporalState: .future,
            isCompleted: false,
            isToggleable: true,
            isCurrent: false
        )
        let calendarModel = LBTimelineCard.Model(
            id: "calendar",
            title: "Calendar",
            subtitle: "",
            timeText: "9:00 PM",
            role: .meeting,
            kind: .calendar,
            systemImage: "calendar",
            tintHex: nil,
            accessoryText: nil,
            temporalState: .future,
            isCompleted: false,
            isToggleable: false,
            isCurrent: false
        )

        XCTAssertEqual(taskModel.kind, .task)
        XCTAssertEqual(taskModel.tintHex, "#123456")
        XCTAssertNil(taskModel.accessoryText)
        XCTAssertTrue(taskModel.isToggleable)
        XCTAssertEqual(calendarModel.kind, .calendar)
        XCTAssertNil(calendarModel.tintHex)
        XCTAssertFalse(calendarModel.isToggleable)
    }

    func testCalendarCardSubtitleIsEmptyWhenEventIsNotNextUpcoming() {
        let now = date(hour: 21, minute: 15)
        let calendarItem = timelineItem(
            id: "calendar",
            source: .calendarEvent,
            startHour: 22,
            endHour: 23
        )

        XCTAssertEqual(
            SunriseHomeScreen.timelineCardSubtitle(
                for: calendarItem,
                now: now,
                nextUpcomingCalendarItemID: nil
            ),
            ""
        )
    }

    func testNextUpcomingCalendarCardSubtitleUsesMinuteCountdown() {
        let now = date(hour: 21, minute: 15)
        let current = timelineItem(
            id: "current",
            source: .calendarEvent,
            startHour: 21,
            startMinute: 0,
            endHour: 21,
            endMinute: 30
        )
        let next = timelineItem(
            id: "next",
            source: .calendarEvent,
            startHour: 21,
            startMinute: 42,
            endHour: 22
        )
        let later = timelineItem(
            id: "later",
            source: .calendarEvent,
            startHour: 22,
            startMinute: 30,
            endHour: 23
        )
        let rows = [
            SunriseTimelineRow.item(current),
            SunriseTimelineRow.item(next),
            SunriseTimelineRow.item(later)
        ]
        let nextID = SunriseHomeScreen.nextUpcomingCalendarItemID(in: rows, now: now)

        XCTAssertEqual(nextID, "next")
        XCTAssertEqual(
            SunriseHomeScreen.timelineCardSubtitle(
                for: next,
                now: now,
                nextUpcomingCalendarItemID: nextID
            ),
            "in 27m"
        )
        XCTAssertEqual(
            SunriseHomeScreen.timelineCardSubtitle(
                for: later,
                now: now,
                nextUpcomingCalendarItemID: nextID
            ),
            ""
        )
    }

    func testCalendarCountdownRoundsUpToHoursAtSixtyMinutesOrMore() {
        let now = date(hour: 21, minute: 15)

        XCTAssertEqual(
            SunriseHomeScreen.calendarCountdownSubtitle(
                until: date(hour: 22, minute: 15),
                now: now
            ),
            "in 1h"
        )
        XCTAssertEqual(
            SunriseHomeScreen.calendarCountdownSubtitle(
                until: date(hour: 22, minute: 16),
                now: now
            ),
            "in 2h"
        )
    }

    func testPastAndCurrentCalendarEventsDoNotReceiveCountdownText() {
        let now = date(hour: 21, minute: 15)
        let past = timelineItem(
            id: "past",
            source: .calendarEvent,
            startHour: 20,
            endHour: 21
        )
        let current = timelineItem(
            id: "current",
            source: .calendarEvent,
            startHour: 21,
            startMinute: 0,
            endHour: 21,
            endMinute: 30
        )

        XCTAssertNil(SunriseHomeScreen.nextUpcomingCalendarItemID(in: [.item(past), .item(current)], now: now))
        XCTAssertNil(SunriseHomeScreen.calendarCountdownSubtitle(until: past.startDate!, now: now))
        XCTAssertNil(SunriseHomeScreen.calendarCountdownSubtitle(until: current.startDate!, now: now))
    }

    func testTaskCardSubtitleKeepsExistingTaskSubtitle() {
        let now = date(hour: 21, minute: 15)
        let task = timelineItem(id: "task", startHour: 22, endHour: 23)

        XCTAssertEqual(
            SunriseHomeScreen.timelineCardSubtitle(
                for: task,
                now: now,
                nextUpcomingCalendarItemID: nil
            ),
            "Inbox"
        )
    }

    #if canImport(UIKit)
    func testSunriseTokensResolveDarkModeGlassAwayFromNearWhite() {
        let darkGlass = resolvedColor(LBColorTokens.glass, style: .dark)
        let darkStrongGlass = resolvedColor(LBColorTokens.glassStrong, style: .dark)
        let darkCanvas = resolvedColor(LBColorTokens.canvas, style: .dark)

        XCTAssertLessThan(relativeLuminance(darkGlass), 0.04)
        XCTAssertLessThan(relativeLuminance(darkStrongGlass), 0.06)
        XCTAssertLessThan(relativeLuminance(darkCanvas), 0.01)
        XCTAssertLessThan(redComponent(darkGlass), 0.20)
        XCTAssertLessThan(greenComponent(darkGlass), 0.24)
        XCTAssertLessThan(blueComponent(darkGlass), 0.32)
    }

    func testSunriseDarkModeTextAndDockContrast() {
        let darkCanvas = resolvedColor(LBColorTokens.canvas, style: .dark)
        let darkGlassStrong = resolvedColor(LBColorTokens.glassStrong, style: .dark)
        let primaryText = resolvedColor(LBColorTokens.navy, style: .dark)
        let secondaryText = resolvedColor(LBColorTokens.navyMuted, style: .dark)
        let selectedDockText = resolvedColor(LBColorTokens.violetDeep, style: .dark)
        let selectedDockFill = resolvedColor(LBColorTokens.violetSoft, style: .dark)

        XCTAssertGreaterThan(contrastRatio(primaryText, darkCanvas), 12.0)
        XCTAssertGreaterThan(contrastRatio(secondaryText, darkGlassStrong), 7.0)
        XCTAssertGreaterThan(contrastRatio(selectedDockText, selectedDockFill), 6.0)

        for role in [LBRole.task, .meeting, .warning, .error, .neutral] {
            let style = LBColorTokens.role(role)
            XCTAssertGreaterThan(
                contrastRatio(
                    resolvedColor(LBColorTokens.navy, style: .dark),
                    resolvedColor(style.softSurface, style: .dark)
                ),
                7.0,
                "Expected readable primary text on \(role.rawValue) dark Sunrise surface."
            )
        }
    }

    func testSunriseIncreasedContrastStrengthensDarkSeparators() {
        let normalHairline = resolvedColor(LBColorTokens.hairline, style: .dark)
        let highContrastHairline = resolvedColor(LBColorTokens.hairline, style: .dark, contrast: .high)
        let normalGlass = resolvedColor(LBColorTokens.glassStrong, style: .dark)
        let highContrastGlass = resolvedColor(LBColorTokens.glassStrong, style: .dark, contrast: .high)

        XCTAssertGreaterThan(relativeLuminance(highContrastHairline), relativeLuminance(normalHairline))
        XCTAssertGreaterThan(alphaComponent(highContrastGlass), alphaComponent(normalGlass))
    }
    #endif

    func testSunriseScrollOffsetNormalizesForChromeTracker() {
        XCTAssertEqual(SunriseHomeScreen.chromeOffset(forScrollMinY: 16), 0)
        XCTAssertEqual(SunriseHomeScreen.chromeOffset(forScrollMinY: 0), 0)
        XCTAssertEqual(SunriseHomeScreen.chromeOffset(forScrollMinY: -64), 64)
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
        isComplete: Bool = false,
        isMeetingLike: Bool = false
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
            accessoryText: nil,
            isMeetingLike: isMeetingLike
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

    #if canImport(UIKit)
    private func resolvedColor(
        _ color: Color,
        style: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast = .normal
    ) -> UIColor {
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: style),
            UITraitCollection(accessibilityContrast: contrast)
        ])
        return UIColor(color).resolvedColor(with: traits)
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor) -> CGFloat {
        let lighter = max(relativeLuminance(foreground), relativeLuminance(background))
        let darker = min(relativeLuminance(foreground), relativeLuminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        let components = rgbaComponents(color)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(components.red)
            + 0.7152 * channel(components.green)
            + 0.0722 * channel(components.blue)
    }

    private func redComponent(_ color: UIColor) -> CGFloat {
        rgbaComponents(color).red
    }

    private func greenComponent(_ color: UIColor) -> CGFloat {
        rgbaComponents(color).green
    }

    private func blueComponent(_ color: UIColor) -> CGFloat {
        rgbaComponents(color).blue
    }

    private func alphaComponent(_ color: UIColor) -> CGFloat {
        rgbaComponents(color).alpha
    }

    private func rgbaComponents(_ color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
    #endif
}
