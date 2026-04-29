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

    func testPhoneTimelineRendererUsesUnifiedCanvasForNormalTextSizes() {
        XCTAssertEqual(
            TimelineForedropRendererPolicy.mode(layoutClass: .phone, dayLayoutMode: .compact, isAccessibilitySize: false),
            .expanded
        )
        XCTAssertEqual(
            TimelineForedropRendererPolicy.mode(layoutClass: .phone, dayLayoutMode: .expanded, isAccessibilitySize: false),
            .expanded
        )
    }

    func testTimelineRendererKeepsAccessibilityAndPadCompactFallbacks() {
        XCTAssertEqual(
            TimelineForedropRendererPolicy.mode(layoutClass: .phone, dayLayoutMode: .expanded, isAccessibilitySize: true),
            .agenda
        )
        XCTAssertEqual(
            TimelineForedropRendererPolicy.mode(layoutClass: .padCompact, dayLayoutMode: .expanded, isAccessibilitySize: false),
            .compact
        )
        XCTAssertEqual(
            TimelineForedropRendererPolicy.mode(layoutClass: .padRegular, dayLayoutMode: .compact, isAccessibilitySize: false),
            .expanded
        )
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

    func testTimelineLayoutPlanKeepsNonOverlappingTaskAndMeetingAsSeparateBlocks() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeTimedItem(
                    id: "task",
                    title: "Task",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 45)
                ),
                Self.makeMeetingItem(
                    id: "meeting",
                    title: "Meeting",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 2)
        XCTAssertTrue(plan.blocks.allSatisfy { $0.block.isConflict == false })
        XCTAssertEqual(plan.blocks.map(\.block.items.count), [1, 1])
    }

    func testTimelineLayoutPlanGroupsOverlappingTaskAndMeetingIntoConflictBlock() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(
                    id: "meeting",
                    title: "Design Sync",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0)
                ),
                Self.makeTimedItem(
                    id: "task",
                    title: "Draft Report",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 30)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 1)
        XCTAssertTrue(plan.blocks[0].block.isConflict)
        XCTAssertTrue(plan.blocks[0].block.containsTask)
        XCTAssertTrue(plan.blocks[0].block.containsCalendarEvent)
        XCTAssertEqual(plan.blocks[0].block.items.map(\.id), ["event:meeting", "task:task"])
        XCTAssertEqual(plan.blocks[0].block.startDate, Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0))
        XCTAssertEqual(plan.blocks[0].block.endDate, Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 30))
        XCTAssertEqual(plan.blocks[0].block.overlapDepth, 2)
        XCTAssertEqual(plan.blocks[0].block.visualLaneCount, 2)
        XCTAssertEqual(plan.blocks[0].block.densityMode, .dualLane)
        XCTAssertEqual(plan.blocks[0].block.lanePlacements.map(\.laneIndex), [0, 1])
    }

    func testPhoneTimelineMetricsMoveSpineLeftWhileKeepingReadableTimeGutter() {
        let metrics = TimelineSurfaceMetrics.make(for: .phone)
        let rail = TimelineRailMetrics.make(for: .phone, surfaceMetrics: metrics)

        XCTAssertEqual(rail.labelLeadingX, 4, accuracy: 0.001)
        XCTAssertEqual(rail.labelWidth, 68, accuracy: 0.001)
        XCTAssertEqual(rail.timeToSpineGap, 3, accuracy: 0.001)
        XCTAssertEqual(rail.labelLayerWidth, 72, accuracy: 0.001)
        XCTAssertEqual(rail.spineX, 75, accuracy: 0.001)
        XCTAssertEqual(rail.contentLeadingGap, 8, accuracy: 0.001)
        XCTAssertEqual(rail.contentX, 83, accuracy: 0.001)
    }

    func testTimelineRailTypographyUsesCompactMetadataSizes() {
        XCTAssertEqual(TimelineRailTypography.compactHourSize, 14, accuracy: 0.001)
        XCTAssertEqual(TimelineRailTypography.exactSize, 14, accuracy: 0.001)
        XCTAssertEqual(TimelineRailTypography.currentSize, 13, accuracy: 0.001)
    }

    func testVisualGapFormulaKeepsSmallGapsMeaningfulAndClampsLongGaps() {
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 0), 12, accuracy: 0.001)
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 30), 36, accuracy: 0.001)
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 60), 72, accuracy: 0.001)
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 120), 93, accuracy: 0.001)
        XCTAssertLessThanOrEqual(TimelineCanvasLayoutPlan.visualGap(for: 179), 112.001)
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 180), 112, accuracy: 0.001)
        XCTAssertEqual(TimelineCanvasLayoutPlan.visualGap(for: 181), 112, accuracy: 0.001)
    }

    func testExpandedRailTimeFormatterUsesCompactHoursOnlyForRailLabels() {
        let calendar = Self.fixedCalendar

        XCTAssertEqual(
            TimelineRailTimeFormatter.railText(forItemStart: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0), calendar: calendar),
            "11 AM"
        )
        XCTAssertEqual(
            TimelineRailTimeFormatter.railText(for: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0), kind: .exact, calendar: calendar),
            "11:00 AM"
        )
        XCTAssertEqual(
            TimelineRailTimeFormatter.railText(for: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0), kind: .exact, calendar: calendar),
            "10:00 PM"
        )
        XCTAssertEqual(
            TimelineRailTimeFormatter.railText(forItemStart: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 17, minute: 12), calendar: calendar),
            "5:12 PM"
        )
        XCTAssertEqual(
            TimelineRailTimeFormatter.railText(for: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 52), kind: .current, calendar: calendar),
            "6:52 PM"
        )
    }

    func testRoutineMarkerHeightUsesIconGuardrail() {
        XCTAssertEqual(TimelineCanvasLayoutPlan.routineMarkerHeight, max(96, TimelineCanvasLayoutPlan.routineIconLayoutSize + 20), accuracy: 0.001)
    }

    func testRoutineSubtitleIncludesExactTimeAndExistingCopy() {
        let calendar = Self.fixedCalendar
        let wake = TimelineAnchorItem(
            id: "wake",
            title: "Rise and shine",
            time: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0),
            systemImageName: "alarm.fill",
            subtitle: "Start the day"
        )
        let sleep = TimelineAnchorItem(
            id: "sleep",
            title: "Wind down",
            time: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0),
            systemImageName: "moon.fill",
            subtitle: "Close the day"
        )

        XCTAssertEqual(TimelineRoutineTextFormatter.subtitle(for: wake, subtitle: wake.subtitle, calendar: calendar), "8:00 AM · Start the day")
        XCTAssertEqual(TimelineRoutineTextFormatter.subtitle(for: sleep, subtitle: sleep.subtitle, calendar: calendar), "10:00 PM · Close the day")
    }

    func testRoutineTextZoneStaysSeparatedFromIconBubble() {
        let metrics = TimelineSurfaceMetrics.make(for: .phone)
        let rail = TimelineRailMetrics.make(for: .phone, surfaceMetrics: metrics)
        let iconRightEdge = rail.spineX + (metrics.expandedAnchorCircleSize / 2)

        XCTAssertEqual(rail.routineTextLeadingX(iconSize: metrics.expandedAnchorCircleSize), iconRightEdge + 14, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(rail.routineTextLeadingX(iconSize: metrics.expandedAnchorCircleSize), iconRightEdge + 12)
    }

    func testTimelineBottomProtectionIsConditionalOnNextHomeWidget() {
        let metrics = TimelineSurfaceMetrics.make(for: .phone)

        XCTAssertEqual(metrics.resolvedTimelineBottomPadding(hasNextHomeWidget: true), 0, accuracy: 0.001)
        XCTAssertGreaterThan(metrics.resolvedTimelineBottomPadding(hasNextHomeWidget: false), 0)
    }

    func testPhoneRenderModelUsesNormalCardForSingleTaskAndCalendarEvent() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let taskStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let eventStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "task", title: "Draft", start: taskStart, end: taskStart.addingTimeInterval(30 * 60)),
                Self.makeMeetingItem(id: "event", title: "Review", start: eventStart, end: eventStart.addingTimeInterval(30 * 60))
            ]
        )

        let blocks = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks
        let renderModels = blocks.map { TimelinePhoneRenderModel.make(from: $0.block, now: wake) }

        guard case .normal(let firstItem) = renderModels[0],
              case .normal(let secondItem) = renderModels[1] else {
            return XCTFail("Single timeline blocks should render as normal phone cards")
        }
        XCTAssertEqual(firstItem.id, "task:task")
        XCTAssertEqual(secondItem.id, "event:event")
    }

    func testPhoneRenderModelUsesFlockForOverlapsInsteadOfPhoneLanes() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "a", title: "Alpha", start: start, end: start.addingTimeInterval(60 * 60)),
                Self.makeTimedItem(id: "b", title: "Beta", start: start.addingTimeInterval(15 * 60), end: start.addingTimeInterval(75 * 60))
            ]
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block
        let renderModel = TimelinePhoneRenderModel.make(from: block, now: start)

        guard case .flock(let flock) = renderModel else {
            return XCTFail("Phone overlaps should render as a flock")
        }
        XCTAssertEqual(flock.rows.count, 2)
        XCTAssertEqual(flock.densityMode, .smallFlock)
        XCTAssertEqual(flock.displayHeight, 104, accuracy: 0.001)
    }

    func testFlockHeightAndTapTargetRulesMatchDensityModes() {
        XCTAssertEqual(TimelineFlockModel.effectiveTapTargetHeight, 44, accuracy: 0.001)
        XCTAssertEqual(TimelineFlockModel.displayHeight(itemCount: 2), 104, accuracy: 0.001)
        XCTAssertEqual(TimelineFlockModel.displayHeight(itemCount: 3), 132, accuracy: 0.001)
        XCTAssertEqual(TimelineFlockModel.displayHeight(itemCount: 4), 156, accuracy: 0.001)
        XCTAssertLessThanOrEqual(TimelineFlockModel.displayHeight(itemCount: 10, densityMode: .extremeFlock), 280)
    }

    func testCurrentTimeInsideFlockMarksActiveRow() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 15, minute: 0)
        let now = start.addingTimeInterval(20 * 60)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "current", title: "Current", start: start, end: start.addingTimeInterval(60 * 60)),
                Self.makeTimedItem(id: "other", title: "Other", start: start.addingTimeInterval(10 * 60), end: start.addingTimeInterval(40 * 60))
            ]
        )
        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block

        let flock = TimelineFlockModel(block: block, now: now)

        XCTAssertEqual(flock.activeItemID, "event:current")
        XCTAssertTrue(flock.rows.contains { $0.id == "event:current" && $0.isActiveNow })
    }

    func testExtremeFlockPrioritizesCurrentNextTaskAndChronologicalRows() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let base = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 13, minute: 0)
        let items = (0..<10).map { index in
            index == 4
                ? Self.makeTimedItem(id: "task-\(index)", title: "Task \(index)", start: base.addingTimeInterval(Double(index * 5) * 60), end: base.addingTimeInterval(Double(index * 5 + 45) * 60))
                : Self.makeMeetingItem(id: "event-\(index)", title: "Event \(index)", start: base.addingTimeInterval(Double(index * 5) * 60), end: base.addingTimeInterval(Double(index * 5 + 45) * 60))
        }
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: items
        )
        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block

        let flock = TimelineFlockModel(block: block, now: base.addingTimeInterval(22 * 60))

        XCTAssertEqual(flock.densityMode, .extremeFlock)
        XCTAssertTrue(flock.isCollapsedExtreme)
        XCTAssertTrue(flock.visibleItemIDs.contains("event:event-0"))
        XCTAssertTrue(flock.visibleItemIDs.contains("event:event-5"))
        XCTAssertTrue(flock.visibleItemIDs.contains("task:task-4"))
        XCTAssertEqual(flock.rows.last?.isSummary, true)
    }

    func testReadableVisualPositionTracksTemporalPositionAndCapsShift() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let firstStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let firstEnd = firstStart.addingTimeInterval(20 * 60)
        let secondStart = firstEnd
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "a", title: "A", start: firstStart, end: firstEnd),
                Self.makeMeetingItem(id: "b", title: "B", start: firstStart.addingTimeInterval(5 * 60), end: firstEnd),
                Self.makeTimedItem(id: "c", title: "C", start: secondStart, end: secondStart.addingTimeInterval(10 * 60))
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 2)
        guard plan.blocks.count == 2 else { return }
        XCTAssertEqual(plan.blocks[0].temporalY, plan.blocks[0].visualY, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(plan.blocks[1].visualY, plan.blocks[1].temporalY)
        XCTAssertLessThanOrEqual(plan.blocks[1].visualY - plan.blocks[1].temporalY, 120)
        XCTAssertEqual(plan.blocks[1].wasVisuallyShifted, plan.blocks[1].visualY > plan.blocks[1].temporalY)
    }

    func testTimelineLayoutPlanGroupsOverlappingMeetingsIntoEventConflictBlock() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(
                    id: "alpha",
                    title: "Alpha",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 12, minute: 0)
                ),
                Self.makeMeetingItem(
                    id: "beta",
                    title: "Beta",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 15),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 45)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 1)
        XCTAssertTrue(plan.blocks[0].block.isConflict)
        XCTAssertFalse(plan.blocks[0].block.containsTask)
        XCTAssertTrue(plan.blocks[0].block.containsCalendarEvent)
        XCTAssertEqual(plan.blocks[0].block.countLabel, "2 Events")
    }

    func testTimelineLayoutPlanUsesCompactLaneModeForThreeSimultaneousItems() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 14, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "a", title: "Alpha", start: start, end: start.addingTimeInterval(45 * 60)),
                Self.makeTimedItem(id: "b", title: "Beta", start: start.addingTimeInterval(5 * 60), end: start.addingTimeInterval(35 * 60)),
                Self.makeMeetingItem(id: "c", title: "Gamma", start: start.addingTimeInterval(10 * 60), end: start.addingTimeInterval(40 * 60))
            ]
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block

        XCTAssertEqual(block.overlapDepth, 3)
        XCTAssertEqual(block.visualLaneCount, 3)
        XCTAssertEqual(block.densityMode, .compactLane)
        XCTAssertEqual(block.lanePlacements.map(\.laneIndex), [0, 1, 2])
        XCTAssertFalse(block.compressed)
    }

    func testTimelineLayoutPlanCapsPhoneOverlapAtThreeVisualColumnsAndPacksMicroRows() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 14, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "a", title: "Alpha", start: start, end: start.addingTimeInterval(45 * 60)),
                Self.makeTimedItem(id: "b", title: "Beta", start: start, end: start.addingTimeInterval(45 * 60)),
                Self.makeMeetingItem(id: "c", title: "Gamma", start: start, end: start.addingTimeInterval(45 * 60)),
                Self.makeTimedItem(id: "d", title: "Delta", start: start, end: start.addingTimeInterval(45 * 60))
            ]
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, maxVisualColumns: 3, calendar: calendar).blocks[0].block

        XCTAssertEqual(block.overlapDepth, 4)
        XCTAssertEqual(block.visualLaneCount, 3)
        XCTAssertEqual(block.densityMode, .microLane)
        XCTAssertTrue(block.compressed)
        XCTAssertEqual(block.lanePlacements.map(\.laneIndex), [0, 1, 2, 0])
        XCTAssertEqual(block.lanePlacements.map(\.rowIndex), [0, 0, 0, 1])
    }

    func testTimelineLayoutPlanShowsSixDenseItemsWithoutVisualCollision() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 14, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: (0..<6).map { index in
                Self.makeMeetingItem(
                    id: "event-\(index)",
                    title: "Event \(index)",
                    start: start,
                    end: start.addingTimeInterval(30 * 60)
                )
            }
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, maxVisualColumns: 3, calendar: calendar).blocks[0].block

        XCTAssertEqual(block.lanePlacements.count, 6)
        XCTAssertEqual(block.visualLaneCount, 3)
        XCTAssertTrue(block.compressed)
        Self.assertNoVisualCollisions(block.lanePlacements)
    }

    func testTimelineLayoutPlanScalesSameLaneMinimumHeightUntilCap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let base = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "long", title: "Long", start: base, end: base.addingTimeInterval(60 * 60)),
                Self.makeTimedItem(id: "short-a", title: "Short A", start: base.addingTimeInterval(5 * 60), end: base.addingTimeInterval(10 * 60)),
                Self.makeTimedItem(id: "short-b", title: "Short B", start: base.addingTimeInterval(30 * 60), end: base.addingTimeInterval(35 * 60))
            ]
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block
        let secondLanePlacements = block.lanePlacements.filter { $0.laneIndex == 1 }.sorted { $0.relativeY < $1.relativeY }

        XCTAssertEqual(block.densityMode, .dualLane)
        XCTAssertFalse(block.isDensePacked)
        XCTAssertGreaterThan(secondLanePlacements[1].relativeY - secondLanePlacements[0].relativeY, 52)
    }

    func testTimelineLayoutPlanSwitchesToDensePackedWhenScaleWouldExceedCap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let base = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "long", title: "Long", start: base, end: base.addingTimeInterval(60 * 60)),
                Self.makeTimedItem(id: "short-a", title: "Short A", start: base.addingTimeInterval(5 * 60), end: base.addingTimeInterval(10 * 60)),
                Self.makeTimedItem(id: "short-b", title: "Short B", start: base.addingTimeInterval(11 * 60), end: base.addingTimeInterval(16 * 60))
            ]
        )

        let block = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar).blocks[0].block

        XCTAssertEqual(block.densityMode, .densePacked)
        XCTAssertTrue(block.isDensePacked)
        XCTAssertTrue(block.compressed)
        Self.assertNoVisualCollisions(block.lanePlacements)
    }

    func testTimelineLayoutPlanMergesChainedOverlapsIntoOneConflictBlock() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(
                    id: "a",
                    title: "A",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
                ),
                Self.makeTimedItem(
                    id: "b",
                    title: "B",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 45),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30)
                ),
                Self.makeMeetingItem(
                    id: "c",
                    title: "C",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 15),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 1)
        XCTAssertEqual(plan.blocks[0].block.items.map(\.id), ["event:a", "task:b", "event:c"])
        XCTAssertEqual(plan.blocks[0].block.endDate, Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0))
    }

    func testTimelineLayoutPlanDoesNotGroupAdjacentItemsAsConflict() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(
                    id: "meeting",
                    title: "Meeting",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
                ),
                Self.makeTimedItem(
                    id: "task",
                    title: "Task",
                    start: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0),
                    end: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 30)
                )
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(plan.blocks.count, 2)
        XCTAssertTrue(plan.blocks.allSatisfy { $0.block.isConflict == false })
    }

    func testVisualTimelineKeepsAdjacentMeetingsSeparateWithUniversalGap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let firstStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let firstEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 30)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "a", title: "A", start: firstStart, end: firstEnd),
                Self.makeMeetingItem(id: "b", title: "B", start: firstEnd, end: firstEnd.addingTimeInterval(30 * 60))
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let meetings = plan.visualElements.filter { positioned in
            if case .meetingCard = positioned.element { return true }
            return false
        }

        XCTAssertEqual(meetings.count, 2)
        XCTAssertEqual(plan.blocks.count, 2)
        let expectedSecondMeetingY = meetings[0].y + meetings[0].height + TimelineCanvasLayoutPlan.minimumBlockGap
        XCTAssertGreaterThanOrEqual(meetings[1].y + 0.001, expectedSecondMeetingY)
    }

    func testVisualTimelineKeepsFlockAndFollowingTaskSeparatedByUniversalGap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let overlapStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let nextStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0),
            timedItems: [
                Self.makeMeetingItem(id: "meeting", title: "Meeting", start: overlapStart, end: overlapStart.addingTimeInterval(45 * 60)),
                Self.makeTimedItem(id: "task", title: "Task", start: overlapStart.addingTimeInterval(15 * 60), end: nextStart),
                Self.makeTimedItem(id: "next", title: "Next", start: nextStart, end: nextStart.addingTimeInterval(30 * 60))
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let flock = plan.visualElements.first { positioned in
            if case .flock = positioned.element { return true }
            return false
        }
        let next = plan.visualElements.first { $0.element.id.contains("task:next") }

        XCTAssertNotNil(flock)
        XCTAssertNotNil(next)
        let expectedNextY = (flock?.y ?? 0) + (flock?.height ?? 0) + TimelineCanvasLayoutPlan.minimumBlockGap
        XCTAssertGreaterThanOrEqual((next?.y ?? 0) + 0.001, expectedNextY)
    }

    func testVisualTimelineReservesSpaceForRoutineAndTaskMarkerAtSameTime() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0)
        let preSleepStart = sleep.addingTimeInterval(-30 * 60)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "wake-task", title: "Wake task", start: wake, end: wake.addingTimeInterval(30 * 60)),
                Self.makeTimedItem(id: "pre-sleep-task", title: "Pre-sleep task", start: preSleepStart, end: sleep)
            ]
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let wakeRoutine = plan.visualElements.first { $0.element.id == "routine:wake" }
        let wakeTask = plan.visualElements.first { $0.element.id.contains("task-marker:task:wake-task") }
        let sleepRoutine = plan.visualElements.first { $0.element.id == "routine:sleep" }
        let preSleepTask = plan.visualElements.first { $0.element.id.contains("task-marker:task:pre-sleep-task") }

        XCTAssertNotNil(wakeRoutine)
        XCTAssertNotNil(wakeTask)
        XCTAssertNotNil(sleepRoutine)
        XCTAssertNotNil(preSleepTask)

        let expectedWakeTaskY = (wakeRoutine?.y ?? 0) + (wakeRoutine?.height ?? 0) + TimelineCanvasLayoutPlan.minimumBlockGap
        XCTAssertGreaterThanOrEqual((wakeTask?.y ?? 0) + 0.001, expectedWakeTaskY)

        let expectedSleepRoutineY = (preSleepTask?.y ?? 0) + (preSleepTask?.height ?? 0) + TimelineCanvasLayoutPlan.minimumBlockGap
        XCTAssertGreaterThanOrEqual((sleepRoutine?.y ?? 0) + 0.001, expectedSleepRoutineY)
    }

    func testVisualTimelineClassifiesTaskMarkerAndCardHierarchy() {
        let calendar = Self.fixedCalendar
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let normal = Self.makeTimedItem(id: "normal", title: "Normal", start: start, end: start.addingTimeInterval(30 * 60), priority: .low)
        let highShort = Self.makeTimedItem(id: "high-short", title: "High short", start: start, end: start.addingTimeInterval(30 * 60), priority: .high)
        let highLong = Self.makeTimedItem(id: "high-long", title: "High long", start: start, end: start.addingTimeInterval(45 * 60), priority: .high)
        let maxTask = Self.makeTimedItem(id: "max", title: "Max", start: start, end: start.addingTimeInterval(15 * 60), priority: .max)
        let pinned = Self.makeTimedItem(id: "pinned", title: "Pinned", start: start, end: start.addingTimeInterval(15 * 60), priority: .low, isPinnedFocusTask: true)

        XCTAssertFalse(TimelineCanvasLayoutPlan.shouldRenderTaskAsCard(normal))
        XCTAssertFalse(TimelineCanvasLayoutPlan.shouldRenderTaskAsCard(highShort))
        XCTAssertTrue(TimelineCanvasLayoutPlan.shouldRenderTaskAsCard(highLong))
        XCTAssertTrue(TimelineCanvasLayoutPlan.shouldRenderTaskAsCard(maxTask))
        XCTAssertTrue(TimelineCanvasLayoutPlan.shouldRenderTaskAsCard(pinned))
    }

    func testSparseTimelineUsesEmptyStateAndCompactSpineEnd() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(calendar: calendar, wake: wake, sleep: sleep, timedItems: [])
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, bottomInset: 120, calendar: calendar)

        XCTAssertEqual(projection.timelineDensityMode, .sparse)
        XCTAssertTrue(plan.visualElements.contains { positioned in
            if case .emptyState(let model) = positioned.element {
                return model.title == "No meetings today" && model.showsCalendarAction == false
            }
            return false
        })
        XCTAssertGreaterThan(plan.endMarker.centerY, plan.spineExtent.fadeEndY)
        XCTAssertGreaterThanOrEqual(plan.contentHeight, plan.endMarker.centerY + 22 + 120)
    }

    func testSparseTimelineEndMarkerUsesHitAreaForCompactContentHeight() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(calendar: calendar, wake: wake, sleep: sleep, timedItems: [])
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, bottomInset: 0, calendar: calendar)

        XCTAssertEqual(
            plan.endMarker.centerY,
            plan.spineExtent.fadeEndY + TimelineCanvasLayoutPlan.endMarkerTopGapAfterFade + (TimelineCanvasLayoutPlan.endMarkerHitArea / 2),
            accuracy: 0.001
        )
        XCTAssertEqual(
            plan.contentHeight,
            plan.endMarker.centerY + (TimelineCanvasLayoutPlan.endMarkerHitArea / 2),
            accuracy: 0.001
        )
    }

    func testCalendarHiddenSparseTimelineUsesCalendarCopyAndAction() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0),
            timedItems: [],
            calendarPlottingEnabled: false
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let empty = plan.visualElements.compactMap { positioned -> VisualTimelineElement.EmptyStateModel? in
            guard case .emptyState(let model) = positioned.element else { return nil }
            return model
        }.first

        XCTAssertEqual(empty?.title, "Calendar is hidden")
        XCTAssertEqual(empty?.secondaryTitle, "Show calendar")
        XCTAssertEqual(empty?.showsCalendarAction, true)
    }

    func testLightTimelineAddsOpenDayPromptForOneShortItem() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 16, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "small", title: "Small", start: start, end: start.addingTimeInterval(30 * 60))
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)

        XCTAssertEqual(projection.timelineDensityMode, .lightTimeline)
        XCTAssertTrue(plan.visualElements.contains { positioned in
            if case .emptyState(let model) = positioned.element {
                return model.id == "empty:light" && model.title == "Plenty of open time"
            }
            return false
        })
    }

    func testLongSingleItemStaysNormalTimelineMode() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let start = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "long", title: "Long", start: start, end: start.addingTimeInterval(120 * 60))
            ]
        )

        XCTAssertEqual(projection.timelineDensityMode, .normal)
    }

    func testLongGapIndicatorIsCenteredInsideCompressedGap() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let firstStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let firstEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 10, minute: 0)
        let secondStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 14, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0),
            timedItems: [
                Self.makeTimedItem(id: "first", title: "First", start: firstStart, end: firstEnd),
                Self.makeTimedItem(id: "second", title: "Second", start: secondStart, end: secondStart.addingTimeInterval(30 * 60))
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let taskElements = plan.visualElements.filter { positioned in
            if case .taskMarker = positioned.element { return true }
            return false
        }

        XCTAssertEqual(plan.longGapIndicators.count, 1)
        XCTAssertEqual(plan.longGapIndicators.first?.text, "· · · 4h free · · ·")
        if taskElements.count == 2, let indicator = plan.longGapIndicators.first {
            let gapTop = taskElements[0].bottomY
            let gapBottom = taskElements[1].y
            XCTAssertEqual(indicator.y + (indicator.height / 2), gapTop + ((gapBottom - gapTop) / 2), accuracy: 0.001)
        } else {
            XCTFail("Expected two task elements around the long gap")
        }
    }

    func testSpineEndUsesAfterSleepItemAndEndMarkerSuggestedDate() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let lateStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 30)
        let lateEnd = lateStart.addingTimeInterval(30 * 60)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [],
            afterSleepItems: [
                Self.makeTimedItem(id: "late", title: "Late", start: lateStart, end: lateEnd)
            ]
        )
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let late = plan.visualElements.first { $0.element.id.contains("task:late") }

        XCTAssertNotNil(late)
        XCTAssertEqual(plan.spineExtent.solidEndY, late?.centerY ?? 0, accuracy: 0.001)
        XCTAssertEqual(plan.endMarker.suggestedDate, lateEnd)
    }

    func testTimelineLayoutPlanOnlyReturnsCurrentTimeYForSelectedTodayWithinVisibleWindow() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 0)
        let projection = Self.makeProjection(calendar: calendar, wake: wake, sleep: sleep, timedItems: [])
        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let now = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 30)

        let currentY = plan.currentTimeY(now: now, selectedDate: wake, calendar: calendar)
        XCTAssertNotNil(currentY)
        XCTAssertEqual(currentY ?? 0, plan.wakeAnchor.y + 210, accuracy: 0.001)
        XCTAssertNil(plan.currentTimeY(now: now, selectedDate: Self.date(calendar: calendar, year: 2026, month: 4, day: 22, hour: 0, minute: 0), calendar: calendar))
        XCTAssertNil(plan.currentTimeY(now: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 7, minute: 59), selectedDate: wake, calendar: calendar))
        XCTAssertNil(plan.currentTimeY(now: Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 18, minute: 1), selectedDate: wake, calendar: calendar))
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

    func testCompactTimelineLayoutPlanRendersOffWindowItemsAsRowsAroundAnchors() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let beforeStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 1, minute: 51)
        let focusStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 30)
        let afterStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 15)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "focus", title: "Focus", start: focusStart, end: focusStart.addingTimeInterval(30 * 60))
            ],
            beforeWakeItems: [
                Self.makeTimedItem(id: "late-night", title: "Late night", start: beforeStart, end: beforeStart.addingTimeInterval(15 * 60))
            ],
            afterSleepItems: [
                Self.makeTimedItem(id: "after-sleep", title: "After sleep", start: afterStart, end: afterStart.addingTimeInterval(15 * 60))
            ],
            gaps: [
                TimelineGap(startDate: focusStart.addingTimeInterval(30 * 60), endDate: sleep, suggestedTaskCount: 0)
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection)

        XCTAssertEqual(Self.compactEntryIDs(plan.entries), [
            "item:task:late-night",
            "anchor:wake",
            "item:task:focus",
            "gap:\(focusStart.addingTimeInterval(30 * 60).timeIntervalSince1970)-\(sleep.timeIntervalSince1970)",
            "anchor:sleep",
            "item:task:after-sleep"
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
        XCTAssertLessThan(compactPlan.contentHeight, expandedPlan.contentHeight * 0.57)
    }

    func testExpandedTimelineCompressesOffWindowRowsAroundOperationalWindow() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let beforeStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 1, minute: 51)
        let operationalStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 11, minute: 30)
        let afterStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 23, minute: 15)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "focus", title: "Focus", start: operationalStart, end: operationalStart.addingTimeInterval(30 * 60))
            ],
            beforeWakeItems: [
                Self.makeTimedItem(id: "late-night", title: "Late night", start: beforeStart, end: beforeStart.addingTimeInterval(15 * 60))
            ],
            afterSleepItems: [
                Self.makeTimedItem(id: "after-sleep", title: "After sleep", start: afterStart, end: afterStart.addingTimeInterval(15 * 60))
            ],
            layoutMode: .expanded
        )

        let plan = TimelineCanvasLayoutPlan(projection: projection, pointsPerMinute: 1, minimumItemHeight: 44, calendar: calendar)
        let positionedItems = Dictionary(uniqueKeysWithValues: plan.items.map { ($0.item.id, $0) })

        XCTAssertLessThan(positionedItems["task:late-night"]?.y ?? .greatestFiniteMagnitude, plan.wakeAnchor.y)
        XCTAssertEqual(plan.wakeAnchor.y, 128, accuracy: 0.001)
        XCTAssertGreaterThan(positionedItems["task:after-sleep"]?.y ?? 0, plan.sleepAnchor.y)
        XCTAssertEqual(positionedItems["task:focus"]?.y ?? 0, plan.wakeAnchor.y + 210, accuracy: 0.001)
        XCTAssertLessThan(plan.contentHeight, 1_150)
    }

    func testTimelineSurfaceMetricsUsePadCompactSpecificCompactValues() {
        let metrics = TimelineSurfaceMetrics.make(for: .padCompact)

        XCTAssertEqual(metrics.compactTimeGutter, 72, accuracy: 0.001)
        XCTAssertEqual(metrics.compactLaneWidth, 60, accuracy: 0.001)
        XCTAssertEqual(metrics.compactTrailingLaneWidth, 48, accuracy: 0.001)
        XCTAssertEqual(metrics.compactConnectorHeight, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.compactAnchorRowHeight, 60, accuracy: 0.001)
        XCTAssertEqual(metrics.compactGapRowHeight, 62, accuracy: 0.001)
        XCTAssertEqual(metrics.compactItemMinRowHeight, 78, accuracy: 0.001)
        XCTAssertEqual(metrics.compactReadableWidth ?? 0, 680, accuracy: 0.001)
    }

    func testTimelineSurfaceMetricsUsePadExpandedReadableWidthAndExpandedValues() {
        let metrics = TimelineSurfaceMetrics.make(for: .padExpanded)

        XCTAssertEqual(metrics.expandedTimeGutter, 76, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedSpineLaneWidth, 84, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedTrailingLaneWidth, 52, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedContentInset, 16, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedTimeToSpineGap, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedCapsuleMinWidth, 64, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedSingleColumnTextMaxWidth, 420, accuracy: 0.001)
        XCTAssertEqual(metrics.expandedOverlappingTextMaxWidth, 320, accuracy: 0.001)
        XCTAssertEqual(metrics.timelineBottomPadding, 132, accuracy: 0.001)
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
        XCTAssertEqual(items[0].capsuleHeight, 90, accuracy: 0.001)
        XCTAssertEqual(items[0].rowHeight, 110, accuracy: 0.001)
        XCTAssertEqual(items[1].capsuleHeight, 168, accuracy: 0.001)
        XCTAssertEqual(items[1].rowHeight, 188, accuracy: 0.001)
        XCTAssertGreaterThan(items[1].capsuleHeight, items[0].capsuleHeight)
        XCTAssertGreaterThan(items[1].rowHeight, items[0].rowHeight)
    }

    func testPadCompactTimelineLayoutPlanUsesAdaptedAnchorGapAndItemHeights() {
        let calendar = Self.fixedCalendar
        let wake = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 8, minute: 0)
        let itemStart = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 0)
        let itemEnd = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 9, minute: 30)
        let sleep = Self.date(calendar: calendar, year: 2026, month: 4, day: 21, hour: 22, minute: 0)
        let projection = Self.makeProjection(
            calendar: calendar,
            wake: wake,
            sleep: sleep,
            timedItems: [
                Self.makeTimedItem(id: "focus", title: "Focus", start: itemStart, end: itemEnd)
            ],
            gaps: [
                TimelineGap(startDate: wake, endDate: itemStart, suggestedTaskCount: 0),
                TimelineGap(startDate: itemEnd, endDate: sleep, suggestedTaskCount: 0)
            ],
            layoutMode: .compact
        )

        let plan = TimelineCompactLayoutPlan(projection: projection, layoutClass: .padCompact)

        XCTAssertEqual(plan.entries.map(\.rowHeight), [60, 62, 110, 62, 60])
        XCTAssertEqual(Self.compactItemEntries(plan.entries).first?.capsuleHeight ?? 0, 90, accuracy: 0.001)
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

        XCTAssertEqual(item?.capsuleHeight ?? 0, 176, accuracy: 0.001)
        XCTAssertEqual(item?.rowHeight ?? 0, 196, accuracy: 0.001)
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

    static func makeTimedItem(
        id: String,
        title: String,
        start: Date,
        end: Date,
        priority: TaskPriority = .low,
        isPinnedFocusTask: Bool = false
    ) -> TimelinePlanItem {
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
            accessoryText: nil,
            taskPriority: priority,
            isPinnedFocusTask: isPinnedFocusTask
        )
    }

    static func makeMeetingItem(id: String, title: String, start: Date, end: Date) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "event:\(id)",
            source: .calendarEvent,
            taskID: nil,
            eventID: id,
            title: title,
            subtitle: "Work",
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: false,
            tintHex: ProjectColor.purple.hexString,
            systemImageName: "calendar",
            accessoryText: nil,
            isMeetingLike: true
        )
    }

    static func makeProjection(
        calendar: Calendar,
        wake: Date,
        sleep: Date,
        timedItems: [TimelinePlanItem],
        beforeWakeItems: [TimelinePlanItem] = [],
        afterSleepItems: [TimelinePlanItem] = [],
        gaps: [TimelineGap] = [],
        layoutMode: TimelineDayLayoutMode = .expanded,
        calendarPlottingEnabled: Bool = true
    ) -> TimelineDayProjection {
        TimelineDayProjection(
            date: calendar.startOfDay(for: wake),
            allDayItems: [],
            inboxItems: [],
            timedItems: timedItems,
            gaps: gaps,
            beforeWakeSummaryItems: beforeWakeItems,
            afterSleepSummaryItems: afterSleepItems,
            layoutMode: layoutMode,
            calendarPlottingEnabled: calendarPlottingEnabled,
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

    static func assertNoVisualCollisions(
        _ placements: [TimelineTimeBlock.LanePlacement],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let grouped = Dictionary(grouping: placements, by: \.laneIndex)
        for lanePlacements in grouped.values {
            let sorted = lanePlacements.sorted { $0.relativeY < $1.relativeY }
            guard sorted.count > 1 else { continue }
            for index in 0..<(sorted.count - 1) {
                XCTAssertLessThanOrEqual(
                    sorted[index].relativeY + sorted[index].height,
                    sorted[index + 1].relativeY + 0.001,
                    file: file,
                    line: line
                )
            }
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
