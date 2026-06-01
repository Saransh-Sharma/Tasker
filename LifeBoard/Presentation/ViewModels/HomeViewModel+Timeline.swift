//
//  HomeViewModel+Timeline.swift
//  LifeBoard
//
//  Move-only HomeViewModel decomposition.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    func buildTimelineSnapshot(
        calendarSnapshot: HomeCalendarSnapshot,
        sunriseAnchor: SunriseAnchor,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeTimelineSnapshot {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineSnapshotBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        let workspacePreferences = workspacePreferencesProvider()
        let showCalendarEventsInTimeline = workspacePreferences.showCalendarEventsInTimeline
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let currentMinuteStamp = Int(now.timeIntervalSinceReferenceDate / 60)
        let taskCandidates = timelineTaskCandidates()
        let weekAgenda = showCalendarEventsInTimeline
            ? calendarIntegrationService.weekAgenda(anchorDate: selectedDate, weekStartsOn: workspacePreferences.weekStartsOn)
            : []
        let projectionInput = HomeTimelineProjectionInput(
            dataRevision: dataRevision,
            selectedDay: selectedDay,
            now: now,
            calendar: calendar,
            currentMinuteStamp: currentMinuteStamp,
            sunriseAnchor: sunriseAnchor,
            calendarSnapshot: calendarSnapshot,
            workspacePreferences: workspacePreferences,
            hiddenCalendarEvents: hiddenHomeTimelineCalendarEvents.sorted(),
            pinnedFocusTaskIDs: pinnedFocusTaskIDs,
            needsReplanCandidates: needsReplanCandidates,
            replanState: homeReplanState,
            taskCandidates: taskCandidates,
            taskIndexByID: timelineTaskUniverseByID(),
            projects: projects,
            lifeAreas: lifeAreas,
            calendarWeekAgenda: weekAgenda
        )
        let builtProjection = timelineProjectionBuilder.build(
            input: projectionInput,
            cached: timelineSnapshotCache
        )
        timelineSnapshotCache = builtProjection
        return builtProjection.snapshot
    }

    func timelineWeekStartsOn() -> Weekday {
        calendarIntegrationService.weekStartsOn
    }

    func showCalendarEventsInTimelineFromHome() {
        LifeBoardWorkspacePreferencesStore.shared.update { preferences in
            preferences.showCalendarEventsInTimeline = true
        }
        calendarIntegrationService.refreshContext(referenceDate: selectedDate, reason: "home_timeline_show_calendar")
    }

    func hideCalendarEventFromTimeline(eventID: String, on day: Date) {
        hiddenHomeTimelineCalendarEvents = hiddenCalendarEventStore.hide(eventID: eventID, on: day)
    }

    func isCalendarEventHiddenFromHomeTimeline(eventID: String, on day: Date) -> Bool {
        hiddenHomeTimelineCalendarEvents.contains(HomeTimelineHiddenCalendarEventKey(eventID: eventID, day: day))
    }
}

struct TimelineWindowBuckets {
    let allItems: [TimelinePlanItem]
    let beforeWakeItems: [TimelinePlanItem]
    let bridgeIntoWakeItems: [TimelinePlanItem]
    let operationalItems: [TimelinePlanItem]
    let bridgePastSleepItems: [TimelinePlanItem]
    let afterSleepItems: [TimelinePlanItem]

    var bridgeItems: [TimelinePlanItem] {
        bridgeIntoWakeItems + bridgePastSleepItems
    }
}

func timelinePlanItemSort(lhs: TimelinePlanItem, rhs: TimelinePlanItem) -> Bool {
    guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.title < rhs.title }
    if lhsStart != rhsStart { return lhsStart < rhsStart }
    return (lhs.endDate ?? lhsStart) < (rhs.endDate ?? rhsStart)
}

extension HomeViewModel {
    func timelineTaskCandidates() -> [TaskDefinition] {
        var tasksByID: [UUID: TaskDefinition] = [:]

        func insert(_ task: TaskDefinition) {
            guard task.parentTaskID == nil else { return }
            let relevantDate = timelinePlacementDate(for: task)
            let isScheduled = relevantDate != nil
            let isAllDayTask = task.isAllDay || timelineIsDateOnlyDueDate(task.dueDate)
            let isUnscheduledInbox = task.scheduledStartAt == nil && task.dueDate == nil && task.isComplete == false
            guard isScheduled || isAllDayTask || isUnscheduledInbox else { return }
            tasksByID[task.id] = task
        }

        (morningTasks + eveningTasks + overdueTasks + dailyCompletedTasks + completedTasks + focusTasks)
            .forEach(insert)

        todaySections.forEach { section in
            section.rows.forEach { row in
                guard case .task(let task) = row else { return }
                insert(task)
            }
        }

        dueTodayRows.forEach { row in
            guard case .task(let task) = row else { return }
            insert(task)
        }

        return timelineSortedTasks(Array(tasksByID.values))
    }

    func timelineTasksForSelectedDay() -> [TaskDefinition] {
        timelineTasksForSelectedDay(candidates: timelineTaskCandidates())
    }

    func timelineTasksForSelectedDay(candidates: [TaskDefinition]) -> [TaskDefinition] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        let workspacePreferences = workspacePreferencesProvider()
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        let previousWindow = resolvedTimelineAnchorWindow(on: previousDay, preferences: workspacePreferences, calendar: calendar)

        let filtered = candidates.filter { task in
            let relevantDate = timelinePlacementDate(for: task)
            let isScheduledForDay = relevantDate.map { $0 < selectedDayEnd && $0 >= selectedDay } ?? false
            let isPreviousNightContext = relevantDate.map { date in
                date >= previousWindow.sleep && date < selectedDay
            } ?? false
            let isAllDayForDay = timelineAllDayDate(for: task).map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false
            let isUnscheduledInbox = task.scheduledStartAt == nil && task.dueDate == nil && task.isComplete == false
            return isScheduledForDay || isPreviousNightContext || isAllDayForDay || isUnscheduledInbox
        }

        return timelineSortedTasks(filtered)
    }

    func timelineTasksForWeek(weekStart: Date, weekEnd: Date) -> [TaskDefinition] {
        timelineTasksForWeek(weekStart: weekStart, weekEnd: weekEnd, candidates: timelineTaskCandidates())
    }

    func timelineTasksForWeek(weekStart: Date, weekEnd: Date, candidates: [TaskDefinition]) -> [TaskDefinition] {
        let filtered = candidates.filter { task in
            guard task.scheduledStartAt != nil || task.dueDate != nil else { return false }
            if let placementDate = timelinePlacementDate(for: task) {
                return placementDate >= weekStart && placementDate < weekEnd
            }
            if let allDayDate = timelineAllDayDate(for: task) {
                return allDayDate >= weekStart && allDayDate < weekEnd
            }
            return false
        }

        return timelineSortedTasks(filtered)
    }

    func timelineSortedTasks(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
        return tasks.sorted { lhs, rhs in
            let lhsDate = timelinePlacementDate(for: lhs) ?? timelineAllDayDate(for: lhs) ?? lhs.createdAt
            let rhsDate = timelinePlacementDate(for: rhs) ?? timelineAllDayDate(for: rhs) ?? rhs.createdAt
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    func timelineWeekSummary(weekStartsOn: Weekday, includeCalendarEvents: Bool) -> TimelineWeekSummary {
        timelineWeekSummary(
            weekStartsOn: weekStartsOn,
            includeCalendarEvents: includeCalendarEvents,
            candidates: timelineTaskCandidates()
        )
    }

    func timelineWeekSummary(
        weekStartsOn: Weekday,
        includeCalendarEvents: Bool,
        candidates: [TaskDefinition]
    ) -> TimelineWeekSummary {
        let calendar = Calendar.current
        let weekStart = XPCalculationEngine.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let calendarAgenda = includeCalendarEvents
            ? calendarIntegrationService.weekAgenda(anchorDate: selectedDate, weekStartsOn: weekStartsOn)
            : []
        let agendaByDay = Dictionary(uniqueKeysWithValues: calendarAgenda.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
        let weekTasks = timelineTasksForWeek(weekStart: weekStart, weekEnd: weekEnd, candidates: candidates)
        let tasksByDay = Dictionary(grouping: weekTasks) { task -> Date in
            if let placementDate = timelinePlacementDate(for: task) {
                return calendar.startOfDay(for: placementDate)
            }
            if let allDayDate = timelineAllDayDate(for: task) {
                return calendar.startOfDay(for: allDayDate)
            }
            return weekStart
        }
        let replanCountsByDay = Dictionary(grouping: needsReplanCandidates.compactMap { candidate -> Date? in
            candidate.anchorDate.map { calendar.startOfDay(for: $0) }
        }) { $0 }
            .mapValues(\.count)

        let days = (0..<7).compactMap { offset -> TimelineWeekDaySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let normalizedDay = calendar.startOfDay(for: day)
            let agenda = agendaByDay[normalizedDay]
            let tasks = tasksByDay[normalizedDay] ?? []
            let taskMarkers = tasks.compactMap { timelinePlacementDate(for: $0) }
            let visibleEvents = includeCalendarEvents
                ? (agenda?.events.filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: normalizedDay) } ?? [])
                : []
            let eventMarkers = visibleEvents.filter { !$0.isAllDay }.map(\.startDate)
            let tints = tasks.compactMap { timelineTintHex(for: $0) } + visibleEvents.compactMap(\.calendarColorHex)
            let allDayCount = tasks.filter { timelineAllDayDate(for: $0) != nil }.count + visibleEvents.filter(\.isAllDay).count
            let timedCount = taskMarkers.count + eventMarkers.count
            let totalCount = allDayCount + timedCount
            let replanEligibleCount = replanCountsByDay[normalizedDay] ?? 0
            return TimelineWeekDaySummary(
                date: normalizedDay,
                dayKey: timelineDayKey(for: normalizedDay, calendar: calendar),
                allDayCount: allDayCount,
                replanEligibleCount: replanEligibleCount,
                timedMarkers: (taskMarkers + eventMarkers).sorted(),
                tintHexes: Array(tints.prefix(4)),
                summaryText: timelineWeekSummaryText(taskCount: taskMarkers.count, eventCount: eventMarkers.count, allDayCount: allDayCount),
                loadLevel: timelineLoadLevel(for: totalCount)
            )
        }

        return TimelineWeekSummary(
            weekStart: weekStart,
            weekStartsOn: weekStartsOn,
            days: days
        )
    }

    func timelineTaskUniverseByID() -> [UUID: TaskDefinition] {
        var universe = uniqueTasks(
            morningTasks
            + eveningTasks
            + overdueTasks
            + dailyCompletedTasks
            + upcomingTasks
            + completedTasks
            + doneTimelineTasks
            + focusTasks
        )
        universe.append(contentsOf: dueTodayRows.compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task
        })
        todaySections.forEach { section in
            universe.append(contentsOf: section.rows.compactMap { row in
                guard case .task(let task) = row else { return nil }
                return task
            })
        }
        return Dictionary(uniqueKeysWithValues: uniqueTasks(universe).map { ($0.id, $0) })
    }

    func timelinePlanItem(from task: TaskDefinition, taskIndexByID: [UUID: TaskDefinition]? = nil) -> TimelinePlanItem {
        // Prefer explicit schedule fields. The dueDate fallback is temporary legacy support.
        let startDate = timelinePlacementDate(for: task)
        let resolvedDuration = task.scheduledEndAt?.timeIntervalSince(startDate ?? task.createdAt)
            ?? task.estimatedDuration
            ?? (30 * 60)
        let endDate = startDate.map { start in
            task.scheduledEndAt ?? start.addingTimeInterval(max(resolvedDuration, 15 * 60))
        }
        let checklistSummary = timelineChecklistSummary(for: task, taskIndexByID: taskIndexByID)
        let hasProjectUtility = {
            guard let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return projectName.isEmpty == false && projectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) != .orderedSame
        }()
        return TimelinePlanItem(
            id: "task:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            eventID: nil,
            title: task.title,
            subtitle: task.projectName,
            startDate: startDate,
            endDate: endDate,
            isAllDay: timelineAllDayDate(for: task) != nil,
            isComplete: task.isComplete,
            tintHex: timelineTintHex(for: task),
            systemImageName: timelineSystemImageName(for: task),
            accessoryText: timelineAccessoryText(for: task),
            taskPriority: task.priority,
            isPinnedFocusTask: pinnedFocusTaskIDs.contains(task.id),
            hasNotes: task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isRecurring: task.repeatPattern != nil || task.recurrenceSeriesID != nil,
            checklistSummary: checklistSummary,
            showsProjectUtility: hasProjectUtility,
            isMeetingLike: task.context == .meeting
        )
    }

    func timelinePlanItem(from task: TaskDefinition, on selectedDay: Date, taskIndexByID: [UUID: TaskDefinition]? = nil) -> TimelinePlanItem? {
        let item = timelinePlanItem(from: task, taskIndexByID: taskIndexByID)
        if item.isAllDay {
            return nil
        }
        guard let startDate = item.startDate else { return nil }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDay)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let endDate = item.endDate ?? startDate
        guard startDate < dayEnd, endDate > dayStart else { return nil }
        return item
    }

    func timelinePlanItem(from event: LifeBoardCalendarEventSnapshot) -> TimelinePlanItem {
        TimelinePlanItem(
            id: "event:\(event.id)",
            source: .calendarEvent,
            taskID: nil,
            eventID: event.id,
            title: event.title,
            subtitle: event.calendarTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isComplete: false,
            tintHex: event.calendarColorHex,
            systemImageName: "calendar",
            accessoryText: nil,
            taskPriority: nil,
            isPinnedFocusTask: false,
            hasNotes: event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isRecurring: false,
            checklistSummary: nil,
            showsProjectUtility: false,
            isMeetingLike: timelineIsMeetingLikeEvent(event)
        )
    }

    func resolvedTimelineAnchorWindow(
        on day: Date,
        preferences: LifeBoardWorkspacePreferences,
        calendar: Calendar = .current
    ) -> (wake: Date, sleep: Date) {
        let fallbackWake = timelineAnchorTime(on: day, hour: 5, minute: 0)
        let fallbackSleepBase = timelineAnchorTime(on: day, hour: 2, minute: 0)
        let fallbackSleep = calendar.date(byAdding: .day, value: 1, to: fallbackSleepBase) ?? fallbackSleepBase

        let wake = timelineAnchorTime(
            on: day,
            hour: preferences.timelineRiseAndShineHour,
            minute: preferences.timelineRiseAndShineMinute
        )
        var sleep = timelineAnchorTime(
            on: day,
            hour: preferences.timelineWindDownHour,
            minute: preferences.timelineWindDownMinute
        )
        if sleep <= wake {
            sleep = calendar.date(byAdding: .day, value: 1, to: sleep) ?? sleep
        }

        let span = sleep.timeIntervalSince(wake)
        guard span >= 60 * 60, span <= 22 * 60 * 60 else {
            return (fallbackWake, fallbackSleep)
        }
        return (wake, sleep)
    }

    func partitionTimelineItems(
        _ items: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelineWindowBuckets {
        let decoratedItems = items.map { item in
            decorateTimelineItem(item, wakeAnchor: wakeAnchor, sleepAnchor: sleepAnchor)
        }
        let beforeWakeItems = decoratedItems.filter { $0.windowRelation == .beforeWake }
        let afterSleepItems = decoratedItems.filter { $0.windowRelation == .afterSleep }
        let bridgeIntoWakeItems = decoratedItems.filter { $0.windowRelation == .bridgeIntoWake }
        let bridgePastSleepItems = decoratedItems.filter { $0.windowRelation == .bridgePastSleep }
        let operationalItems = (bridgeIntoWakeItems
            + decoratedItems.filter { $0.windowRelation == .operational }
            + bridgePastSleepItems)
            .sorted(by: timelinePlanItemSort)

        return TimelineWindowBuckets(
            allItems: decoratedItems.sorted(by: timelinePlanItemSort),
            beforeWakeItems: beforeWakeItems.sorted(by: timelinePlanItemSort),
            bridgeIntoWakeItems: bridgeIntoWakeItems.sorted(by: timelinePlanItemSort),
            operationalItems: operationalItems,
            bridgePastSleepItems: bridgePastSleepItems.sorted(by: timelinePlanItemSort),
            afterSleepItems: afterSleepItems.sorted(by: timelinePlanItemSort)
        )
    }

    func decorateTimelineItem(
        _ item: TimelinePlanItem,
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelinePlanItem {
        guard let start = item.startDate, let end = item.endDate, end > start else {
            return item
        }

        let overlapsWake = start < wakeAnchor.time && end > wakeAnchor.time
        let overlapsSleep = start < sleepAnchor.time && end > sleepAnchor.time
        let windowRelation: TimelineWindowRelation
        if end <= wakeAnchor.time {
            windowRelation = .beforeWake
        } else if start >= sleepAnchor.time {
            windowRelation = .afterSleep
        } else if overlapsWake {
            windowRelation = .bridgeIntoWake
        } else if overlapsSleep {
            windowRelation = .bridgePastSleep
        } else {
            windowRelation = .operational
        }

        return TimelinePlanItem(
            id: item.id,
            source: item.source,
            taskID: item.taskID,
            eventID: item.eventID,
            title: item.title,
            subtitle: item.subtitle,
            startDate: item.startDate,
            endDate: item.endDate,
            isAllDay: item.isAllDay,
            isComplete: item.isComplete,
            tintHex: item.tintHex,
            systemImageName: item.systemImageName,
            accessoryText: item.accessoryText,
            taskPriority: item.taskPriority,
            isPinnedFocusTask: item.isPinnedFocusTask,
            hasNotes: item.hasNotes,
            isRecurring: item.isRecurring,
            checklistSummary: item.checklistSummary,
            showsProjectUtility: item.showsProjectUtility,
            isMeetingLike: item.isMeetingLike,
            windowRelation: windowRelation,
            overlapsWake: overlapsWake,
            overlapsSleep: overlapsSleep
        )
    }

    func timelineGaps(
        between timedItems: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        inboxCount: Int,
        selectedDate: Date,
        now: Date,
        actionableHorizon: TimeInterval = 4 * 60 * 60,
        calendar: Calendar = .current
    ) -> [TimelineGap] {
        let gaps = timelineOperationalGaps(
            between: timedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxCount
        )

        return timelineActionableGaps(
            from: gaps,
            selectedDate: selectedDate,
            now: now,
            actionableHorizon: actionableHorizon,
            calendar: calendar
        )
    }

    func timelineActionableGaps(
        from gaps: [TimelineGap],
        selectedDate: Date,
        now: Date,
        actionableHorizon: TimeInterval = 4 * 60 * 60,
        minimumFutureDuration: TimeInterval = 45 * 60,
        minimumQuietDuration: TimeInterval = 90 * 60,
        minimumPromptSpacing: TimeInterval = 90 * 60,
        calendar: Calendar = .current
    ) -> [TimelineGap] {
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            return []
        }

        func spaced(_ candidates: [TimelineGap], limit: Int) -> [TimelineGap] {
            var selected: [TimelineGap] = []
            for gap in candidates.sorted(by: { $0.startDate < $1.startDate }) {
                guard selected.count < limit else { break }
                guard selected.allSatisfy({ abs(gap.startDate.timeIntervalSince($0.startDate)) >= minimumPromptSpacing }) else {
                    continue
                }
                selected.append(gap)
            }
            return selected
        }

        func preferredFutureCandidates(from source: [TimelineGap]) -> [TimelineGap] {
            let nonQuiet = source.filter { $0.emphasis != .quietWindow && $0.duration >= minimumFutureDuration }
            if nonQuiet.isEmpty == false {
                return nonQuiet
            }
            return source.filter { $0.emphasis == .quietWindow && $0.duration >= minimumQuietDuration }
        }

        if selectedDay > today {
            return spaced(preferredFutureCandidates(from: gaps), limit: 2)
        }

        let horizonEnd = now.addingTimeInterval(actionableHorizon)
        let activeGap = gaps.first { gap in
            gap.startDate <= now
                && now < gap.endDate
                && gap.endDate.timeIntervalSince(now) >= 20 * 60
        }
        let upcoming = preferredFutureCandidates(
            from: gaps.filter { gap in
                gap.startDate > now && gap.startDate <= horizonEnd
            }
        )

        var selected = activeGap.map { [$0] } ?? []
        for gap in upcoming.sorted(by: { $0.startDate < $1.startDate }) {
            guard selected.count < (activeGap == nil ? 2 : 2) else { break }
            guard activeGap == nil || selected.count < 2 else { break }
            guard selected.allSatisfy({ abs(gap.startDate.timeIntervalSince($0.startDate)) >= minimumPromptSpacing }) else {
                continue
            }
            selected.append(gap)
            if selected.count >= 2 {
                break
            }
        }

        return selected
    }

    func timelineOperationalGaps(
        between timedItems: [TimelinePlanItem],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        inboxCount: Int
    ) -> [TimelineGap] {
        struct Boundary {
            let start: Date
            let end: Date
            let isSleepAnchor: Bool
        }

        let sortedIntervals: [(start: Date, end: Date)] = timedItems.compactMap { item in
            guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
            let clippedStart = max(start, wakeAnchor.time)
            let clippedEnd = min(end, sleepAnchor.time)
            guard clippedEnd > clippedStart else { return nil }
            return (start: clippedStart, end: clippedEnd)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end < rhs.end
        }

        var mergedIntervals: [(start: Date, end: Date)] = []
        for interval in sortedIntervals {
            if let last = mergedIntervals.last, interval.start <= last.end {
                mergedIntervals[mergedIntervals.count - 1] = (last.start, max(last.end, interval.end))
            } else {
                mergedIntervals.append(interval)
            }
        }

        var boundaries: [Boundary] = [.init(start: wakeAnchor.time, end: wakeAnchor.time, isSleepAnchor: false)]
        boundaries.append(contentsOf: mergedIntervals.map { interval in
            Boundary(start: interval.start, end: interval.end, isSleepAnchor: false)
        })
        boundaries.append(.init(start: sleepAnchor.time, end: sleepAnchor.time, isSleepAnchor: true))
        boundaries.sort { lhs, rhs in lhs.start < rhs.start }

        var gaps: [TimelineGap] = []
        for index in 0..<(boundaries.count - 1) {
            let currentEnd = boundaries[index].end
            let nextStart = boundaries[index + 1].start
            let gapDuration = nextStart.timeIntervalSince(currentEnd)
            guard gapDuration >= 20 * 60 else { continue }
            let isFinalGap = boundaries[index + 1].isSleepAnchor
            let emphasis: TimelineGapEmphasis
            if isFinalGap {
                emphasis = .quietWindow
            } else if gapDuration <= 45 * 60 {
                emphasis = .prepWindow
            } else {
                emphasis = .openTime
            }
            let primaryAction: TimelineGapAction = .addTask
            let secondaryAction: TimelineGapAction? = .planBlock
            let copy = timelineGapCopy(
                duration: gapDuration,
                inboxCount: inboxCount,
                isFinalGap: isFinalGap,
                emphasis: emphasis,
                primaryAction: primaryAction
            )
            gaps.append(TimelineGap(
                startDate: currentEnd,
                endDate: nextStart,
                suggestedTaskCount: inboxCount,
                headline: copy.headline,
                supportingText: copy.supportingText,
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                emphasis: emphasis
            ))
        }
        return gaps
    }

    func timelineDayLayoutMode(
        timedItems: [TimelinePlanItem],
        gaps: [TimelineGap],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelineDayLayoutMode {
        guard timedItems.isEmpty == false else { return .compact }

        let daySpan = max(sleepAnchor.time.timeIntervalSince(wakeAnchor.time), 1)
        let largestGap = gaps.map(\.duration).max() ?? 0
        guard largestGap >= 4 * 60 * 60 else { return .expanded }

        let timedCoverage = timelineCoveredDuration(for: timedItems)
        return (timedCoverage / daySpan) <= 0.22 ? .compact : .expanded
    }

    func timelineCoveredDuration(for timedItems: [TimelinePlanItem]) -> TimeInterval {
        let intervals = timedItems.compactMap { item -> (start: Date, end: Date)? in
            guard let start = item.startDate, let end = item.endDate, end > start else { return nil }
            return (start, end)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }
            return lhs.end < rhs.end
        }

        guard let first = intervals.first else { return 0 }

        var mergedStart = first.start
        var mergedEnd = first.end
        var total: TimeInterval = 0

        for interval in intervals.dropFirst() {
            if interval.start <= mergedEnd {
                mergedEnd = max(mergedEnd, interval.end)
            } else {
                total += mergedEnd.timeIntervalSince(mergedStart)
                mergedStart = interval.start
                mergedEnd = interval.end
            }
        }

        total += mergedEnd.timeIntervalSince(mergedStart)
        return total
    }

    func timelineTintHex(for task: TaskDefinition) -> String? {
        let projectsByID = Dictionary(projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let lifeAreasByID = Dictionary(lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let owningTint = HomeTaskTintResolver.owningSectionAccentHex(
            for: task,
            projectsByID: projectsByID,
            lifeAreasByID: lifeAreasByID
        ) {
            return owningTint
        }

        // Preserve historical timeline fallback when ownership tint cannot be resolved.
        return projectsByID[task.projectID]?.color.hexString ?? task.priority.colorHex
    }

    func timelineDayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func timelineLoadLevel(for totalCount: Int) -> TimelineDayLoadLevel {
        switch totalCount {
        case ..<2:
            return .light
        case 2...4:
            return .balanced
        default:
            return .busy
        }
    }

    func timelineWeekSummaryText(taskCount: Int, eventCount: Int, allDayCount: Int) -> String {
        let totalCount = taskCount + eventCount + allDayCount
        if totalCount == 0 {
            return "Open"
        }
        if totalCount >= 5 {
            return "Busy"
        }
        if eventCount > 0 && taskCount > 0 {
            let taskText = taskCount == 1 ? "1 task" : "\(taskCount) tasks"
            let eventText = eventCount == 1 ? "1 event" : "\(eventCount) events"
            return "\(taskText) · \(eventText)"
        }
        if taskCount > 0 {
            return taskCount == 1 ? "1 task" : "\(taskCount) tasks"
        }
        if eventCount > 0 {
            return eventCount == 1 ? "1 event" : "\(eventCount) events"
        }
        return allDayCount == 1 ? "1 all-day" : "\(allDayCount) all-day"
    }

    func timelineGapCopy(
        duration: TimeInterval,
        inboxCount: Int,
        isFinalGap: Bool,
        emphasis: TimelineGapEmphasis,
        primaryAction: TimelineGapAction
    ) -> (headline: String, supportingText: String) {
        let durationText = timelineDurationText(duration)
        switch emphasis {
        case .quietWindow:
            return (
                headline: "Evening buffer",
                supportingText: "Need a lighter close with \(durationText)?"
            )
        case .prepWindow:
            return (
                headline: "Short opening",
                supportingText: "Need a short block for \(durationText)?"
            )
        case .openTime:
            return (
                headline: "Open time",
                supportingText: isFinalGap ? "Keep \(durationText) open." : "Want to use \(durationText) well?"
            )
        }
    }

    func timelineChecklistSummary(
        for task: TaskDefinition,
        taskIndexByID: [UUID: TaskDefinition]?
    ) -> TimelineChecklistSummary? {
        guard task.subtasks.isEmpty == false, let taskIndexByID else { return nil }
        let childTasks = task.subtasks.compactMap { taskIndexByID[$0] }
        guard childTasks.count == task.subtasks.count else { return nil }
        return TimelineChecklistSummary(
            completedCount: childTasks.filter(\.isComplete).count,
            totalCount: childTasks.count
        )
    }

    func timelineIsMeetingLikeEvent(_ event: LifeBoardCalendarEventSnapshot) -> Bool {
        let normalized = "\(event.title) \(event.calendarTitle)".lowercased()
        return normalized.contains("meet")
            || normalized.contains("zoom")
            || normalized.contains("call")
            || normalized.contains("video")
    }

    func timelineDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }

    func timelineSystemImageName(for task: TaskDefinition) -> String {
        if let iconSymbolName = task.iconSymbolName, iconSymbolName.isEmpty == false {
            return iconSymbolName
        }
        if let project = projects.first(where: { $0.id == task.projectID }) {
            return project.icon.systemImageName
        }
        switch task.category {
        case .work:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .personal:
            return "person.fill"
        case .shopping:
            return "cart.fill"
        default:
            return "checklist"
        }
    }

    func timelineAccessoryText(for task: TaskDefinition) -> String? {
        if task.isComplete {
            return "Done"
        }
        let now = Date()
        guard let start = timelinePlacementDate(for: task) else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let end = task.scheduledEndAt ?? start.addingTimeInterval(max(task.estimatedDuration ?? 30 * 60, 15 * 60))
        guard start <= now, end > now else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let roundedMinutes = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
        return "\(roundedMinutes)m remaining"
    }

    func timelineAnchorTime(on day: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }

    func timelineIsDateOnlyDueDate(_ date: Date?) -> Bool {
        guard let date else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    func timelinePlacementDate(for task: TaskDefinition) -> Date? {
        task.scheduledStartAt ?? (timelineIsDateOnlyDueDate(task.dueDate) ? nil : task.dueDate)
    }

    func timelineAllDayDate(for task: TaskDefinition) -> Date? {
        if task.isAllDay {
            return task.dueDate ?? task.scheduledStartAt
        }
        if timelineIsDateOnlyDueDate(task.dueDate) {
            return task.dueDate
        }
        return nil
    }

    static func timelineDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(max(minutes, 1))m"
    }
}
