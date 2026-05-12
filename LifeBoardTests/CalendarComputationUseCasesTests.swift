import XCTest
@testable import LifeBoard

final class CalendarComputationUseCasesTests: XCTestCase {
    func testBusyBlockMergingHandlesOverlapAndNearAdjacency() {
        let useCase = BuildCalendarBusyBlocksUseCase(mergeGapThreshold: 5 * 60)
        let referenceStart = CalendarTestClock.date(hour: 8)
        let referenceEnd = CalendarTestClock.date(hour: 13)

        let events = [
            makeEvent(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0),
            makeEvent(startHour: 9, startMinute: 50, endHour: 11, endMinute: 0),
            makeEvent(startHour: 11, startMinute: 3, endHour: 11, endMinute: 30),
            makeEvent(startHour: 11, startMinute: 40, endHour: 12, endMinute: 0)
        ]

        let blocks = useCase.execute(
            events: events,
            includeAllDayEvents: false,
            referenceStart: referenceStart,
            referenceEnd: referenceEnd
        )

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].startDate, CalendarTestClock.date(hour: 9))
        XCTAssertEqual(blocks[0].endDate, CalendarTestClock.date(hour: 11, minute: 30))
        XCTAssertEqual(blocks[1].startDate, CalendarTestClock.date(hour: 11, minute: 40))
        XCTAssertEqual(blocks[1].endDate, CalendarTestClock.date(hour: 12))
    }

    func testBusyBlockMergingRespectsAllDayToggle() {
        let useCase = BuildCalendarBusyBlocksUseCase(mergeGapThreshold: 5 * 60)
        let referenceStart = CalendarTestClock.date(hour: 0)
        let referenceEnd = CalendarTestClock.date(hour: 23, minute: 59)

        let events = [
            makeEvent(
                startHour: 0,
                startMinute: 0,
                endHour: 23,
                endMinute: 59,
                isAllDay: true
            ),
            makeEvent(startHour: 10, startMinute: 0, endHour: 11, endMinute: 0)
        ]

        let excluded = useCase.execute(
            events: events,
            includeAllDayEvents: false,
            referenceStart: referenceStart,
            referenceEnd: referenceEnd
        )
        XCTAssertEqual(excluded.count, 1)
        XCTAssertEqual(excluded[0].startDate, CalendarTestClock.date(hour: 10))
        XCTAssertEqual(excluded[0].endDate, CalendarTestClock.date(hour: 11))

        let included = useCase.execute(
            events: events,
            includeAllDayEvents: true,
            referenceStart: referenceStart,
            referenceEnd: referenceEnd
        )
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startDate, CalendarTestClock.date(hour: 0))
        XCTAssertEqual(included[0].endDate, CalendarTestClock.date(hour: 23, minute: 59))
    }

    func testResolveNextMeetingPrefersOngoingEvent() {
        let useCase = ResolveNextMeetingUseCase()
        let now = CalendarTestClock.date(hour: 9, minute: 30)
        let events = [
            makeEvent(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0, title: "Ongoing"),
            makeEvent(startHour: 9, startMinute: 45, endHour: 10, endMinute: 30, title: "Upcoming")
        ]

        let summary = useCase.execute(events: events, now: now)

        XCTAssertEqual(summary?.event.title, "Ongoing")
        XCTAssertEqual(summary?.isInProgress, true)
        XCTAssertEqual(summary?.minutesUntilStart, 0)
    }

    func testResolveNextMeetingReturnsNilForEmptyOrPastEvents() {
        let useCase = ResolveNextMeetingUseCase()
        let now = CalendarTestClock.date(hour: 12)
        let pastEvent = makeEvent(startHour: 9, startMinute: 0, endHour: 10, endMinute: 0)

        XCTAssertNil(useCase.execute(events: [], now: now))
        XCTAssertNil(useCase.execute(events: [pastEvent], now: now))
    }

    func testTaskFitClassificationFit() {
        let useCase = ComputeTaskFitHintUseCase(bufferMinutes: 15, calendar: CalendarTestClock.calendar)
        let now = CalendarTestClock.date(hour: 9)
        let dueDate = CalendarTestClock.date(hour: 12)
        let busy = [LifeBoardCalendarBusyBlock(
            startDate: CalendarTestClock.date(hour: 10),
            endDate: CalendarTestClock.date(hour: 10, minute: 30)
        )]

        let result = useCase.execute(
            now: now,
            taskDueDate: dueDate,
            estimatedDuration: 60 * 60,
            busyBlocks: busy
        )

        XCTAssertEqual(result.classification, .fit)
    }

    func testTaskFitClassificationTight() {
        let useCase = ComputeTaskFitHintUseCase(bufferMinutes: 15, calendar: CalendarTestClock.calendar)
        let now = CalendarTestClock.date(hour: 9)
        let dueDate = CalendarTestClock.date(hour: 10)

        let result = useCase.execute(
            now: now,
            taskDueDate: dueDate,
            estimatedDuration: 60 * 60,
            busyBlocks: []
        )

        XCTAssertEqual(result.classification, .tight)
    }

    func testTaskFitClassificationConflict() {
        let useCase = ComputeTaskFitHintUseCase(bufferMinutes: 15, calendar: CalendarTestClock.calendar)
        let now = CalendarTestClock.date(hour: 9)
        let dueDate = CalendarTestClock.date(hour: 10)
        let busy = [
            LifeBoardCalendarBusyBlock(
                startDate: CalendarTestClock.date(hour: 9),
                endDate: CalendarTestClock.date(hour: 9, minute: 50)
            )
        ]

        let result = useCase.execute(
            now: now,
            taskDueDate: dueDate,
            estimatedDuration: 20 * 60,
            busyBlocks: busy
        )

        XCTAssertEqual(result.classification, .conflict)
    }

    func testTaskFitClassificationUnknownWhenMissingInputs() {
        let useCase = ComputeTaskFitHintUseCase(bufferMinutes: 15, calendar: CalendarTestClock.calendar)
        let now = CalendarTestClock.date(hour: 9)

        let missingDue = useCase.execute(
            now: now,
            taskDueDate: nil,
            estimatedDuration: 20 * 60,
            busyBlocks: []
        )
        XCTAssertEqual(missingDue.classification, .unknown)

        let missingDuration = useCase.execute(
            now: now,
            taskDueDate: CalendarTestClock.date(hour: 11),
            estimatedDuration: nil,
            busyBlocks: []
        )
        XCTAssertEqual(missingDuration.classification, .unknown)
    }

    private func makeEvent(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        title: String = "Event",
        calendarID: String = "work",
        isAllDay: Bool = false,
        availability: LifeBoardCalendarEventAvailability = .busy,
        participationStatus: LifeBoardCalendarEventParticipationStatus = .accepted
    ) -> LifeBoardCalendarEventSnapshot {
        LifeBoardCalendarEventSnapshot(
            id: UUID().uuidString,
            calendarID: calendarID,
            calendarTitle: "Work",
            title: title,
            startDate: CalendarTestClock.date(hour: startHour, minute: startMinute),
            endDate: CalendarTestClock.date(hour: endHour, minute: endMinute),
            isAllDay: isAllDay,
            availability: availability,
            participationStatus: participationStatus
        )
    }
}
