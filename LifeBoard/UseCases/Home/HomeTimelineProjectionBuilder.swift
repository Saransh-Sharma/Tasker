import Foundation

struct HomeTimelineSnapshotProjectionInput {
    let dataRevision: HomeDataRevision
    let selectedDay: Date
    let now: Date
    let calendar: Calendar
    let currentMinuteStamp: Int
    let sunriseAnchor: SunriseAnchor
    let calendarSnapshot: HomeCalendarSnapshot
    let workspacePreferences: LifeBoardWorkspacePreferences
    let hiddenCalendarEvents: [HomeTimelineHiddenCalendarEventKey]
    let pinnedFocusTaskIDs: [UUID]
    let needsReplanCandidates: [HomeReplanCandidate]
    let replanState: HomeReplanSessionState
    let taskCandidates: [TaskDefinition]
    let taskIndexByID: [UUID: TaskDefinition]
    let projects: [Project]
    let lifeAreas: [LifeArea]
    let calendarWeekAgenda: [LifeBoardCalendarDayAgenda]
}

// Compatibility alias retained while older Home call sites migrate to the
// canonical HomeTimelineSnapshotProjectionInput name.
typealias HomeTimelineProjectionInput = HomeTimelineSnapshotProjectionInput

struct HomeTimelineProjectionBuilder {
    private static let defaultTaskDuration: TimeInterval = 30 * 60
    private static let minimumTaskDuration: TimeInterval = 15 * 60
    private static let minimumOperationalGapDuration: TimeInterval = 20 * 60
    private static let shortPrepGapThreshold: TimeInterval = 45 * 60
    private static let actionableHorizonDuration: TimeInterval = 4 * 60 * 60
    private static let minimumFutureGapDuration: TimeInterval = 45 * 60
    private static let minimumQuietGapDuration: TimeInterval = 90 * 60
    private static let minimumPromptSpacing: TimeInterval = 90 * 60
    private static let expandedLayoutGapThreshold: TimeInterval = 4 * 60 * 60
    private static let compactTimedCoverageRatio = 0.22

    private struct LookupContext {
        let projectsByID: [UUID: Project]
        let lifeAreasByID: [UUID: LifeArea]

        init(input: HomeTimelineProjectionInput) {
            self.projectsByID = Dictionary(input.projects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.lifeAreasByID = Dictionary(input.lifeAreas.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        }
    }

    func cacheKey(for input: HomeTimelineProjectionInput) -> HomeTimelineSnapshotCacheKey {
        HomeTimelineSnapshotCacheKey(
            dataRevision: input.dataRevision,
            selectedDay: input.selectedDay,
            currentMinuteStamp: input.currentMinuteStamp,
            sunriseAnchor: input.sunriseAnchor,
            calendarSignature: HomeTimelineCalendarSignature(input.calendarSnapshot),
            workspacePreferences: HomeTimelineWorkspacePreferencesSignature(input.workspacePreferences),
            hiddenCalendarEvents: input.hiddenCalendarEvents.sorted(),
            pinnedFocusTaskIDs: input.pinnedFocusTaskIDs,
            needsReplanCandidates: input.needsReplanCandidates.map(HomeTimelineReplanCandidateSignature.init),
            replanState: HomeTimelineReplanStateSignature(input.replanState),
            taskCandidates: input.taskCandidates,
            projects: input.projects,
            lifeAreas: input.lifeAreas
        )
    }

    func build(
        input: HomeTimelineProjectionInput,
        cached: (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot)?
    ) -> (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot) {
        build(input: input, cached: cached) {
            makeSnapshot(input)
        }
    }

    func build(
        input: HomeTimelineProjectionInput,
        cached: (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot)?,
        makeSnapshot: () -> HomeTimelineSnapshot
    ) -> (key: HomeTimelineSnapshotCacheKey, snapshot: HomeTimelineSnapshot) {
        let key = cacheKey(for: input)
        if let cached, cached.key == key {
            return cached
        }
        return (key, makeSnapshot())
    }

    private func makeSnapshot(_ input: HomeTimelineProjectionInput) -> HomeTimelineSnapshot {
        let lookupContext = LookupContext(input: input)
        let showCalendarEventsInTimeline = input.workspacePreferences.showCalendarEventsInTimeline
        let anchorWindow = resolvedTimelineAnchorWindow(
            on: input.selectedDay,
            preferences: input.workspacePreferences,
            calendar: input.calendar
        )
        let wakeAnchor = TimelineAnchorItem(
            id: "wake",
            title: "Rise and shine",
            time: anchorWindow.wake,
            systemImageName: "alarm.fill",
            subtitle: "Start the day"
        )
        let sleepAnchor = TimelineAnchorItem(
            id: "sleep",
            title: "Wind down",
            time: anchorWindow.sleep,
            systemImageName: "moon.fill",
            subtitle: "Close the day"
        )

        let dayTasks = timelineTasksForSelectedDay(input.taskCandidates, input: input)
        let allDayTasks = dayTasks.filter { task in
            timelineAllDayDate(for: task, calendar: input.calendar) != nil
        }
        let inboxTasks = dayTasks.filter { task in
            task.isComplete == false
                && task.projectID == ProjectConstants.inboxProjectID
                && task.scheduledStartAt == nil
                && task.scheduledEndAt == nil
                && task.isAllDay == false
                && task.dueDate == nil
        }
        let timedTaskItems = dayTasks.compactMap { task -> TimelinePlanItem? in
            let item = timelinePlanItem(from: task, input: input, lookupContext: lookupContext)
            guard item.isAllDay == false, item.startDate != nil else { return nil }
            return item
        }
        let calendarAllDayItems = showCalendarEventsInTimeline
            ? input.calendarSnapshot.selectedDayEvents
                .filter(\.isAllDay)
                .filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: input.selectedDay, hiddenEvents: input.hiddenCalendarEvents) }
                .map(timelinePlanItem(from:))
            : []
        let calendarTimedItems = showCalendarEventsInTimeline
            ? input.calendarSnapshot.selectedDayTimelineEvents
                .filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: input.selectedDay, hiddenEvents: input.hiddenCalendarEvents) }
                .map(timelinePlanItem(from:))
                .sorted(by: timelinePlanItemSort)
            : []

        let allDayItems = allDayTasks.map { timelinePlanItem(from: $0, input: input, lookupContext: lookupContext) } + calendarAllDayItems
        let inboxItems = inboxTasks.map { timelinePlanItem(from: $0, input: input, lookupContext: lookupContext) }
        let baseTimedItems = (timedTaskItems + calendarTimedItems).sorted(by: timelinePlanItemSort)
        logRescueTimelineClassification(
            input: input,
            dayTasks: dayTasks,
            allDayTasks: allDayTasks,
            timedItems: timedTaskItems,
            inboxTasks: inboxTasks
        )
        let timedBuckets = partitionTimelineItems(
            baseTimedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor
        )
        let gaps = timelineOperationalGaps(
            between: timedBuckets.operationalItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxItems.count
        )
        let actionableGaps = timelineActionableGaps(
            from: gaps,
            selectedDate: input.selectedDay,
            now: input.now,
            calendar: input.calendar
        )
        let layoutMode = timelineDayLayoutMode(
            timedItems: timedBuckets.operationalItems,
            gaps: gaps,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor
        )
        let currentItemID = timedBuckets.allItems.first(where: { $0.isActive(at: input.now) })?.id

        return HomeTimelineSnapshot(
            selectedDate: input.selectedDay,
            sunriseAnchor: input.sunriseAnchor,
            day: TimelineDayProjection(
                date: input.selectedDay,
                allDayItems: allDayItems,
                inboxItems: inboxItems,
                timedItems: timedBuckets.operationalItems,
                gaps: gaps,
                operationalItems: timedBuckets.operationalItems,
                beforeWakeSummaryItems: timedBuckets.beforeWakeItems,
                afterSleepSummaryItems: timedBuckets.afterSleepItems,
                bridgeItems: timedBuckets.bridgeItems,
                actionableGaps: actionableGaps,
                layoutMode: layoutMode,
                calendarPlottingEnabled: showCalendarEventsInTimeline,
                wakeAnchor: wakeAnchor,
                sleepAnchor: sleepAnchor,
                activeItemID: currentItemID,
                currentItemID: currentItemID,
                currentTime: input.now
            ),
            week: timelineWeekSummary(
                weekStartsOn: input.workspacePreferences.weekStartsOn,
                includeCalendarEvents: showCalendarEventsInTimeline,
                input: input,
                lookupContext: lookupContext
            ),
            placementCandidate: input.replanState.placementCandidate
        )
    }

    private func timelineTasksForSelectedDay(
        _ candidates: [TaskDefinition],
        input: HomeTimelineProjectionInput
    ) -> [TaskDefinition] {
        let selectedDayEnd = input.calendar.date(byAdding: .day, value: 1, to: input.selectedDay) ?? input.selectedDay
        let previousDay = input.calendar.date(byAdding: .day, value: -1, to: input.selectedDay) ?? input.selectedDay
        let previousWindow = resolvedTimelineAnchorWindow(
            on: previousDay,
            preferences: input.workspacePreferences,
            calendar: input.calendar
        )

        let filtered = candidates.filter { task in
            let relevantDate = timelinePlacementDate(for: task, calendar: input.calendar)
            let isScheduledForDay = relevantDate.map { $0 < selectedDayEnd && $0 >= input.selectedDay } ?? false
            let isPreviousNightContext = relevantDate.map { date in
                date >= previousWindow.sleep && date < input.selectedDay
            } ?? false
            let isAllDayForDay = timelineAllDayDate(for: task, calendar: input.calendar)
                .map { input.calendar.isDate($0, inSameDayAs: input.selectedDay) } ?? false
            let isUnscheduledInbox = input.calendar.isDate(input.selectedDay, inSameDayAs: input.now)
                && task.scheduledStartAt == nil
                && task.dueDate == nil
                && task.isComplete == false
            return isScheduledForDay || isPreviousNightContext || isAllDayForDay || isUnscheduledInbox
        }

        return timelineSortedTasks(filtered, calendar: input.calendar)
    }

    private func timelineTasksForWeek(
        weekStart: Date,
        weekEnd: Date,
        candidates: [TaskDefinition],
        calendar: Calendar
    ) -> [TaskDefinition] {
        let filtered = candidates.filter { task in
            guard task.scheduledStartAt != nil || task.dueDate != nil else { return false }
            if let placementDate = timelinePlacementDate(for: task, calendar: calendar) {
                return placementDate >= weekStart && placementDate < weekEnd
            }
            if let allDayDate = timelineAllDayDate(for: task, calendar: calendar) {
                return allDayDate >= weekStart && allDayDate < weekEnd
            }
            return false
        }

        return timelineSortedTasks(filtered, calendar: calendar)
    }

    private func timelineSortedTasks(_ tasks: [TaskDefinition], calendar: Calendar) -> [TaskDefinition] {
        tasks.sorted { lhs, rhs in
            let lhsDate = timelinePlacementDate(for: lhs, calendar: calendar) ?? timelineAllDayDate(for: lhs, calendar: calendar) ?? lhs.createdAt
            let rhsDate = timelinePlacementDate(for: rhs, calendar: calendar) ?? timelineAllDayDate(for: rhs, calendar: calendar) ?? rhs.createdAt
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func timelineWeekSummary(
        weekStartsOn: Weekday,
        includeCalendarEvents: Bool,
        input: HomeTimelineProjectionInput,
        lookupContext: LookupContext
    ) -> TimelineWeekSummary {
        let weekStart = timelineWeekStart(
            for: input.selectedDay,
            startingOn: weekStartsOn,
            calendar: input.calendar
        )
        let weekEnd = input.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let agendaByDay = Dictionary(uniqueKeysWithValues: input.calendarWeekAgenda.map {
            (input.calendar.startOfDay(for: $0.date), $0)
        })
        let weekTasks = timelineTasksForWeek(
            weekStart: weekStart,
            weekEnd: weekEnd,
            candidates: input.taskCandidates,
            calendar: input.calendar
        )
        let tasksByDay = Dictionary(grouping: weekTasks) { task -> Date in
            if let placementDate = timelinePlacementDate(for: task, calendar: input.calendar) {
                return input.calendar.startOfDay(for: placementDate)
            }
            if let allDayDate = timelineAllDayDate(for: task, calendar: input.calendar) {
                return input.calendar.startOfDay(for: allDayDate)
            }
            return weekStart
        }
        let replanCountsByDay = Dictionary(grouping: input.needsReplanCandidates.compactMap { candidate -> Date? in
            candidate.anchorDate.map { input.calendar.startOfDay(for: $0) }
        }) { $0 }
            .mapValues(\.count)

        let days = (0..<7).compactMap { offset -> TimelineWeekDaySummary? in
            guard let day = input.calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let normalizedDay = input.calendar.startOfDay(for: day)
            let agenda = agendaByDay[normalizedDay]
            let tasks = tasksByDay[normalizedDay] ?? []
            let taskMarkers = tasks.compactMap { timelinePlacementDate(for: $0, calendar: input.calendar) }
            let visibleEvents = includeCalendarEvents
                ? (agenda?.events.filter { !isCalendarEventHiddenFromHomeTimeline(eventID: $0.id, on: normalizedDay, hiddenEvents: input.hiddenCalendarEvents) } ?? [])
                : []
            let eventMarkers = visibleEvents.filter { !$0.isAllDay }.map(\.startDate)
            let tints = tasks.compactMap { timelineTintHex(for: $0, lookupContext: lookupContext) } + visibleEvents.compactMap(\.calendarColorHex)
            let allDayCount = tasks.filter { timelineAllDayDate(for: $0, calendar: input.calendar) != nil }.count + visibleEvents.filter(\.isAllDay).count
            let timedCount = taskMarkers.count + eventMarkers.count
            let totalCount = allDayCount + timedCount
            let replanEligibleCount = replanCountsByDay[normalizedDay] ?? 0
            return TimelineWeekDaySummary(
                date: normalizedDay,
                dayKey: timelineDayKey(for: normalizedDay, calendar: input.calendar),
                allDayCount: allDayCount,
                replanEligibleCount: replanEligibleCount,
                timedMarkers: (taskMarkers + eventMarkers).sorted(),
                tintHexes: Array(tints.prefix(4)),
                summaryText: timelineWeekSummaryText(
                    taskCount: taskMarkers.count,
                    eventCount: eventMarkers.count,
                    allDayCount: allDayCount
                ),
                loadLevel: timelineLoadLevel(for: totalCount)
            )
        }

        return TimelineWeekSummary(
            weekStart: weekStart,
            weekStartsOn: weekStartsOn,
            days: days
        )
    }

    private func timelinePlanItem(
        from task: TaskDefinition,
        input: HomeTimelineProjectionInput,
        lookupContext: LookupContext
    ) -> TimelinePlanItem {
        let startDate = timelinePlacementDate(for: task, calendar: input.calendar)
        let resolvedDuration = task.scheduledEndAt?.timeIntervalSince(startDate ?? task.createdAt)
            ?? task.estimatedDuration
            ?? Self.defaultTaskDuration
        let endDate = startDate.map { start in
            task.scheduledEndAt ?? start.addingTimeInterval(max(resolvedDuration, Self.minimumTaskDuration))
        }
        let checklistSummary = timelineChecklistSummary(for: task, taskIndexByID: input.taskIndexByID)
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
            isAllDay: timelineAllDayDate(for: task, calendar: input.calendar) != nil,
            isComplete: task.isComplete,
            tintHex: timelineTintHex(for: task, lookupContext: lookupContext),
            systemImageName: timelineSystemImageName(for: task, projects: input.projects),
            lifeAreaSystemImageName: timelineLifeAreaSystemImageName(for: task, lookupContext: lookupContext),
            accessoryText: timelineAccessoryText(for: task, now: input.now, calendar: input.calendar),
            taskPriority: task.priority,
            isPinnedFocusTask: input.pinnedFocusTaskIDs.contains(task.id),
            hasNotes: task.details?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            isRecurring: task.repeatPattern != nil || task.recurrenceSeriesID != nil,
            checklistSummary: checklistSummary,
            showsProjectUtility: hasProjectUtility,
            isMeetingLike: task.context == .meeting
        )
    }

    private func timelinePlanItem(from event: LifeBoardCalendarEventSnapshot) -> TimelinePlanItem {
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

    private func resolvedTimelineAnchorWindow(
        on day: Date,
        preferences: LifeBoardWorkspacePreferences,
        calendar: Calendar
    ) -> (wake: Date, sleep: Date) {
        let fallbackWake = timelineAnchorTime(on: day, hour: 5, minute: 0, calendar: calendar)
        let fallbackSleepBase = timelineAnchorTime(on: day, hour: 2, minute: 0, calendar: calendar)
        let fallbackSleep = calendar.date(byAdding: .day, value: 1, to: fallbackSleepBase) ?? fallbackSleepBase

        let wake = timelineAnchorTime(
            on: day,
            hour: preferences.timelineRiseAndShineHour,
            minute: preferences.timelineRiseAndShineMinute,
            calendar: calendar
        )
        var sleep = timelineAnchorTime(
            on: day,
            hour: preferences.timelineWindDownHour,
            minute: preferences.timelineWindDownMinute,
            calendar: calendar
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

    private func partitionTimelineItems(
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

    private func decorateTimelineItem(
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
            lifeAreaSystemImageName: item.lifeAreaSystemImageName,
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

    private func timelineActionableGaps(
        from gaps: [TimelineGap],
        selectedDate: Date,
        now: Date,
        actionableHorizon: TimeInterval = Self.actionableHorizonDuration,
        minimumFutureDuration: TimeInterval = Self.minimumFutureGapDuration,
        minimumQuietDuration: TimeInterval = Self.minimumQuietGapDuration,
        minimumPromptSpacing: TimeInterval = Self.minimumPromptSpacing,
        calendar: Calendar
    ) -> [TimelineGap] {
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: now)
        if selectedDay < today {
            return []
        }

        func spaced(_ candidates: [TimelineGap], limit: Int, existing: [TimelineGap] = []) -> [TimelineGap] {
            var selected: [TimelineGap] = []
            for gap in candidates.sorted(by: { $0.startDate < $1.startDate }) {
                guard selected.count < limit else { break }
                guard (existing + selected).allSatisfy({ abs(gap.startDate.timeIntervalSince($0.startDate)) >= minimumPromptSpacing }) else {
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
                && gap.endDate.timeIntervalSince(now) >= Self.minimumOperationalGapDuration
        }
        let upcoming = preferredFutureCandidates(
            from: gaps.filter { gap in
                gap.startDate > now && gap.startDate <= horizonEnd
            }
        )

        var selected = activeGap.map { [$0] } ?? []
        let upcomingLimit = activeGap == nil ? 2 : 1
        selected.append(contentsOf: spaced(upcoming, limit: upcomingLimit, existing: selected))

        return selected
    }

    private func timelineOperationalGaps(
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
            guard gapDuration >= Self.minimumOperationalGapDuration else { continue }
            let isFinalGap = boundaries[index + 1].isSleepAnchor
            let emphasis: TimelineGapEmphasis
            if isFinalGap {
                emphasis = .quietWindow
            } else if gapDuration <= Self.shortPrepGapThreshold {
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
                emphasis: emphasis
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

    private func timelineDayLayoutMode(
        timedItems: [TimelinePlanItem],
        gaps: [TimelineGap],
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem
    ) -> TimelineDayLayoutMode {
        guard timedItems.isEmpty == false else { return .compact }
        let daySpan = max(sleepAnchor.time.timeIntervalSince(wakeAnchor.time), 1)
        let largestGap = gaps.map(\.duration).max() ?? 0
        guard largestGap >= Self.expandedLayoutGapThreshold else { return .expanded }
        let timedCoverage = timelineCoveredDuration(for: timedItems)
        return (timedCoverage / daySpan) <= Self.compactTimedCoverageRatio ? .compact : .expanded
    }

    private func timelineCoveredDuration(for timedItems: [TimelinePlanItem]) -> TimeInterval {
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

    private func timelineTintHex(for task: TaskDefinition, lookupContext: LookupContext) -> String? {
        if let owningTint = HomeTaskTintResolver.owningSectionAccentHex(
            for: task,
            projectsByID: lookupContext.projectsByID,
            lifeAreasByID: lookupContext.lifeAreasByID
        ) {
            return owningTint
        }

        return lookupContext.projectsByID[task.projectID]?.color.hexString ?? task.priority.colorHex
    }

    private func timelineLifeAreaSystemImageName(for task: TaskDefinition, lookupContext: LookupContext) -> String? {
        HomeTaskTintResolver.lifeAreaIconSymbolName(
            for: task,
            projectsByID: lookupContext.projectsByID,
            lifeAreasByID: lookupContext.lifeAreasByID
        )
    }

    private func timelineChecklistSummary(
        for task: TaskDefinition,
        taskIndexByID: [UUID: TaskDefinition]
    ) -> TimelineChecklistSummary? {
        guard task.subtasks.isEmpty == false else { return nil }
        let childTasks = task.subtasks.compactMap { taskIndexByID[$0] }
        guard childTasks.count == task.subtasks.count else { return nil }
        return TimelineChecklistSummary(
            completedCount: childTasks.filter(\.isComplete).count,
            totalCount: childTasks.count
        )
    }

    private func timelineSystemImageName(for task: TaskDefinition, projects: [Project]) -> String {
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

    private func timelineAccessoryText(for task: TaskDefinition, now: Date, calendar: Calendar) -> String? {
        if task.isComplete {
            return "Done"
        }
        guard let start = timelinePlacementDate(for: task, calendar: calendar) else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let end = task.scheduledEndAt ?? start.addingTimeInterval(max(task.estimatedDuration ?? Self.defaultTaskDuration, Self.minimumTaskDuration))
        guard start <= now, end > now else {
            return task.estimatedDuration.map(Self.timelineDurationText)
        }
        let roundedMinutes = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
        return "\(roundedMinutes)m remaining"
    }

    private func timelineIsMeetingLikeEvent(_ event: LifeBoardCalendarEventSnapshot) -> Bool {
        let normalized = "\(event.title) \(event.calendarTitle)".lowercased()
        if normalized.contains("google meet") || normalized.contains("slack huddle") {
            return true
        }
        let tokens = Set(normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.isEmpty == false })
        let meetingTokens: Set<String> = [
            "meeting",
            "zoom",
            "call",
            "video",
            "teams",
            "webex",
            "skype",
            "facetime"
        ]
        return tokens.isDisjoint(with: meetingTokens) == false
    }

    private func timelineGapCopy(
        duration: TimeInterval,
        inboxCount: Int,
        isFinalGap: Bool,
        emphasis: TimelineGapEmphasis
    ) -> (headline: String, supportingText: String) {
        let durationText = Self.timelineDurationText(duration)
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

    private func isCalendarEventHiddenFromHomeTimeline(
        eventID: String,
        on day: Date,
        hiddenEvents: [HomeTimelineHiddenCalendarEventKey]
    ) -> Bool {
        let key = HomeTimelineHiddenCalendarEventKey(eventID: eventID, day: day)
        return hiddenEvents.contains(key)
    }

    private func timelinePlanItemSort(lhs: TimelinePlanItem, rhs: TimelinePlanItem) -> Bool {
        guard let lhsStart = lhs.startDate, let rhsStart = rhs.startDate else { return lhs.title < rhs.title }
        if lhsStart != rhsStart { return lhsStart < rhsStart }
        return (lhs.endDate ?? lhsStart) < (rhs.endDate ?? rhsStart)
    }

    private func logRescueTimelineClassification(
        input: HomeTimelineProjectionInput,
        dayTasks: [TaskDefinition],
        allDayTasks: [TaskDefinition],
        timedItems: [TimelinePlanItem],
        inboxTasks: [TaskDefinition]
    ) {
        let rescueCandidates = input.taskCandidates.filter {
            $0.title.localizedCaseInsensitiveContains("rescue")
        }
        guard rescueCandidates.isEmpty == false else { return }

        let dayTaskIDs = Set(dayTasks.map(\.id))
        let allDayTaskIDs = Set(allDayTasks.map(\.id))
        let timedTaskIDs = Set(timedItems.compactMap(\.taskID))
        let inboxTaskIDs = Set(inboxTasks.map(\.id))
        let dayRescueCount = rescueCandidates.filter { dayTaskIDs.contains($0.id) }.count
        let allDayRescueCount = rescueCandidates.filter { allDayTaskIDs.contains($0.id) }.count
        let timedRescueCount = rescueCandidates.filter { timedTaskIDs.contains($0.id) }.count
        let inboxRescueCount = rescueCandidates.filter { inboxTaskIDs.contains($0.id) }.count
        let candidateCount = input.taskCandidates.count
        let rescueCandidateCount = rescueCandidates.count
        let rescueClassificationMessage =
            "HOME_TIMELINE rescue_classification "
            + "candidate_count=\(candidateCount) "
            + "rescue_candidate_count=\(rescueCandidateCount) "
            + "day=\(dayRescueCount) "
            + "all_day=\(allDayRescueCount) "
            + "timed=\(timedRescueCount) "
            + "inbox=\(inboxRescueCount)"
        logDebug(rescueClassificationMessage)
    }

    private func timelineAnchorTime(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }

    private func timelinePlacementDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        TaskScheduleNormalizer.timelinePlacementDate(for: task, calendar: calendar)
    }

    private func timelineAllDayDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        TaskScheduleNormalizer.timelineAllDayDate(for: task, calendar: calendar)
    }

    private func timelineIsDateOnlyDueDate(_ date: Date?, calendar: Calendar) -> Bool {
        guard let date else { return false }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
    }

    private func timelineDayKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private func timelineWeekStart(
        for date: Date,
        startingOn weekStartsOn: Weekday,
        calendar: Calendar
    ) -> Date {
        var calendar = calendar
        calendar.firstWeekday = weekStartsOn.number
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    private func timelineLoadLevel(for totalCount: Int) -> TimelineDayLoadLevel {
        switch totalCount {
        case ..<2:
            return .light
        case 2...4:
            return .balanced
        default:
            return .busy
        }
    }

    private func timelineWeekSummaryText(taskCount: Int, eventCount: Int, allDayCount: Int) -> String {
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

    private static func timelineDurationText(_ duration: TimeInterval) -> String {
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

// Compatibility alias retained while older call sites migrate to the canonical
// HomeTimelineProjectionBuilder name.
typealias HomeTimelineSnapshotProjectionBuilder = HomeTimelineProjectionBuilder
