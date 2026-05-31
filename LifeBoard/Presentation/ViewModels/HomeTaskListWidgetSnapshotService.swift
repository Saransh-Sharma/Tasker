//
//  HomeTaskListWidgetSnapshotService.swift
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

enum TaskListWidgetCalendarProjection {
    static func make(
        from snapshot: LifeBoardCalendarSnapshot,
        weekStartsOn: Weekday,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskListWidgetCalendarSnapshot {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let todayEvents = events(
            from: snapshot.eventsInRange,
            start: startOfToday,
            end: endOfToday
        )
        let timedEvents = todayEvents
            .filter { $0.isAllDay == false && $0.isBusy }
            .map(calendarEvent(from:))
        let allDayEvents = todayEvents
            .filter(\.isAllDay)
            .map(calendarEvent(from:))

        return TaskListWidgetCalendarSnapshot(
            status: status(from: snapshot, todayEvents: todayEvents, timedEvents: timedEvents),
            date: startOfToday,
            updatedAt: now,
            selectedCalendarCount: snapshot.selectedCalendarIDs.count,
            availableCalendarCount: snapshot.availableCalendars.count,
            eventsTodayCount: todayEvents.count,
            nextMeeting: snapshot.nextMeeting.map(nextMeeting(from:)),
            freeUntil: snapshot.freeUntil,
            timedEvents: timedEvents,
            allDayEvents: allDayEvents,
            weekDays: weekDays(
                from: snapshot.eventsInRange,
                anchorDate: startOfToday,
                weekStartsOn: weekStartsOn,
                calendar: calendar
            ),
            isLoading: snapshot.isLoading,
            errorMessage: snapshot.errorMessage
        )
    }

    static func status(
        from snapshot: LifeBoardCalendarSnapshot,
        todayEvents: [LifeBoardCalendarEventSnapshot],
        timedEvents: [TaskListWidgetCalendarEvent]
    ) -> TaskListWidgetCalendarStatus {
        if snapshot.authorizationStatus.isAuthorizedForRead == false {
            return .permissionRequired
        }
        if let error = snapshot.errorMessage, error.isEmpty == false {
            return .error
        }
        if snapshot.selectedCalendarIDs.isEmpty {
            return .noCalendarsSelected
        }
        if todayEvents.isEmpty == false && timedEvents.isEmpty {
            return .allDayOnly
        }
        if timedEvents.isEmpty {
            return .empty
        }
        return .active
    }

    static func weekDays(
        from sourceEvents: [LifeBoardCalendarEventSnapshot],
        anchorDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar
    ) -> [TaskListWidgetCalendarDay] {
        let weekStart = XPCalculationEngine.startOfWeek(
            for: anchorDate,
            startingOn: weekStartsOn,
            calendar: calendar
        )

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayEvents = events(from: sourceEvents, start: dayStart, end: dayEnd)
            return TaskListWidgetCalendarDay(
                date: dayStart,
                eventCount: dayEvents.count,
                timedEvents: dayEvents
                    .filter { $0.isAllDay == false && $0.isBusy }
                    .prefix(3)
                    .map(calendarEvent(from:)),
                allDayEvents: dayEvents
                    .filter(\.isAllDay)
                    .prefix(2)
                    .map(calendarEvent(from:))
            )
        }
    }

    static func events(
        from sourceEvents: [LifeBoardCalendarEventSnapshot],
        start: Date,
        end: Date
    ) -> [LifeBoardCalendarEventSnapshot] {
        sourceEvents
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }

    static func nextMeeting(
        from summary: LifeBoardNextMeetingSummary
    ) -> TaskListWidgetCalendarNextMeeting {
        TaskListWidgetCalendarNextMeeting(
            event: calendarEvent(from: summary.event),
            isInProgress: summary.isInProgress,
            minutesUntilStart: summary.minutesUntilStart
        )
    }

    static func calendarEvent(
        from event: LifeBoardCalendarEventSnapshot
    ) -> TaskListWidgetCalendarEvent {
        TaskListWidgetCalendarEvent(
            id: event.id,
            title: event.title,
            calendarTitle: event.calendarTitle,
            calendarColorHex: event.calendarColorHex,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isBusy: event.isBusy,
            isCanceled: event.isCanceled,
            isTentative: event.participationStatus == .tentative
        )
    }
}

enum TaskListWidgetTimelineProjection {
    static func make(
        tasks: [TaskDefinition],
        calendarSnapshot: TaskListWidgetCalendarSnapshot,
        preferences: LifeBoardWorkspacePreferences,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskListWidgetTimelineSnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let wakeAnchor = timelineAnchorTime(
            on: dayStart,
            hour: preferences.timelineRiseAndShineHour,
            minute: preferences.timelineRiseAndShineMinute,
            calendar: calendar
        )
        let sleepAnchor = resolvedSleepAnchor(
            on: dayStart,
            wakeAnchor: wakeAnchor,
            preferences: preferences,
            calendar: calendar
        )
        let calendarItems = preferences.showCalendarEventsInTimeline
            ? calendarSnapshot.timedEvents.map(timelineItem(from:))
            : []
        let allDayCalendarItems = preferences.showCalendarEventsInTimeline
            ? calendarSnapshot.allDayEvents.map(timelineItem(from:))
            : []

        let taskItems = tasks
            .filter { $0.parentTaskID == nil }
            .compactMap { timelineItem(from: $0, dayStart: dayStart, dayEnd: dayEnd, now: now, calendar: calendar) }
        let timedTaskItems = taskItems.filter { $0.isAllDay == false && $0.startDate != nil }
        let allDayTaskItems = taskItems.filter(\.isAllDay)
        let inboxItems = tasks
            .filter { isInboxCaptureTask($0) }
            .sorted(by: sortTasksForTimeline)
            .prefix(4)
            .map { inboxItem(from: $0) }

        let rawTimedItems = (timedTaskItems + calendarItems).sorted(by: sortItemsForTimeline)
        let currentItemID = currentTimelineItemID(in: rawTimedItems, now: now)
        let timedItems = rawTimedItems.map { item in
            var value = item
            value.isCurrent = value.id == currentItemID
            return value
        }
        let allDayItems = (allDayTaskItems + allDayCalendarItems).sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        let gaps = timelineGaps(
            timedItems: timedItems,
            wakeAnchor: wakeAnchor,
            sleepAnchor: sleepAnchor,
            inboxCount: inboxItems.count,
            now: now
        )
        let weekDays = weekDays(
            tasks: tasks,
            calendarSnapshot: calendarSnapshot,
            preferences: preferences,
            anchorDate: dayStart,
            calendar: calendar
        )

        return TaskListWidgetTimelineSnapshot(
            date: dayStart,
            updatedAt: now,
            day: TaskListWidgetTimelineDay(
                date: dayStart,
                wakeAnchor: wakeAnchor,
                sleepAnchor: sleepAnchor,
                currentTime: now,
                allDayItems: Array(allDayItems.prefix(6)),
                inboxItems: Array(inboxItems),
                timedItems: Array(timedItems.prefix(12)),
                gaps: Array(gaps.prefix(4)),
                currentItemID: currentItemID
            ),
            weekDays: weekDays,
            calendarPlottingEnabled: preferences.showCalendarEventsInTimeline
        )
    }

    static func timelineItem(
        from task: TaskDefinition,
        dayStart: Date,
        dayEnd: Date,
        now: Date,
        calendar: Calendar
    ) -> TaskListWidgetTimelineItem? {
        if let allDayDate = allDayDate(for: task, calendar: calendar),
           calendar.isDate(allDayDate, inSameDayAs: dayStart) {
            return TaskListWidgetTimelineItem(
                id: "task:\(task.id.uuidString)",
                source: .task,
                taskID: task.id,
                title: task.title,
                subtitle: task.projectLabelForWidget,
                startDate: allDayDate,
                endDate: nil,
                isAllDay: true,
                isComplete: task.isComplete,
                tintHex: task.priority.colorHex,
                systemImageName: systemImageName(for: task),
                accessoryText: task.isComplete ? "Done" : nil
            )
        }

        guard let start = placementDate(for: task, calendar: calendar) else { return nil }
        let duration = max(task.scheduledEndAt?.timeIntervalSince(start) ?? task.estimatedDuration ?? 30 * 60, 15 * 60)
        let end = task.scheduledEndAt ?? start.addingTimeInterval(duration)
        guard end > dayStart, start < dayEnd else { return nil }

        return TaskListWidgetTimelineItem(
            id: "task:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            title: task.title,
            subtitle: task.projectLabelForWidget,
            startDate: start,
            endDate: end,
            isAllDay: false,
            isComplete: task.isComplete,
            tintHex: task.priority.colorHex,
            systemImageName: systemImageName(for: task),
            accessoryText: accessoryText(for: task, start: start, end: end, now: now)
        )
    }

    static func timelineItem(from event: TaskListWidgetCalendarEvent) -> TaskListWidgetTimelineItem {
        TaskListWidgetTimelineItem(
            id: "event:\(event.id)",
            source: .calendarEvent,
            eventID: event.id,
            title: event.title,
            subtitle: event.calendarTitle,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isComplete: false,
            tintHex: event.calendarColorHex,
            systemImageName: event.isAllDay ? "sun.max" : "calendar.badge.clock",
            accessoryText: event.isTentative ? "Tentative" : nil
        )
    }

    static func inboxItem(from task: TaskDefinition) -> TaskListWidgetTimelineItem {
        TaskListWidgetTimelineItem(
            id: "inbox:\(task.id.uuidString)",
            source: .task,
            taskID: task.id,
            title: task.title,
            subtitle: task.projectLabelForWidget,
            isAllDay: false,
            isComplete: false,
            tintHex: task.priority.colorHex,
            systemImageName: systemImageName(for: task),
            accessoryText: task.priority.code
        )
    }

    static func weekDays(
        tasks: [TaskDefinition],
        calendarSnapshot: TaskListWidgetCalendarSnapshot,
        preferences: LifeBoardWorkspacePreferences,
        anchorDate: Date,
        calendar: Calendar
    ) -> [TaskListWidgetTimelineWeekDay] {
        let weekStart = XPCalculationEngine.startOfWeek(
            for: anchorDate,
            startingOn: preferences.weekStartsOn,
            calendar: calendar
        )
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayTasks = tasks.filter { task in
                if let allDayDate = allDayDate(for: task, calendar: calendar) {
                    return calendar.isDate(allDayDate, inSameDayAs: dayStart)
                }
                guard let start = placementDate(for: task, calendar: calendar) else { return false }
                let end = task.scheduledEndAt ?? start.addingTimeInterval(max(task.estimatedDuration ?? 30 * 60, 15 * 60))
                return end > dayStart && start < dayEnd
            }
            let taskAllDayCount = dayTasks.filter { allDayDate(for: $0, calendar: calendar) != nil }.count
            let taskTimedCount = dayTasks.count - taskAllDayCount
            let calendarDay = preferences.showCalendarEventsInTimeline
                ? calendarSnapshot.weekDays.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
                : nil
            let calendarAllDayCount = calendarDay?.allDayEvents.count ?? 0
            let calendarTimedCount = calendarDay.map { max(0, $0.eventCount - $0.allDayEvents.count) } ?? 0
            let allDayCount = taskAllDayCount + calendarAllDayCount
            let timedCount = taskTimedCount + calendarTimedCount
            let tints = dayTasks.map { $0.priority.colorHex } + (calendarDay?.timedEvents.compactMap(\.calendarColorHex) ?? [])

            return TaskListWidgetTimelineWeekDay(
                date: dayStart,
                dayKey: dayKey(for: dayStart, calendar: calendar),
                allDayCount: allDayCount,
                timedCount: timedCount,
                tintHexes: Array(tints.prefix(4)),
                loadLevel: loadLevel(for: allDayCount + timedCount)
            )
        }
    }

    static func timelineGaps(
        timedItems: [TaskListWidgetTimelineItem],
        wakeAnchor: Date,
        sleepAnchor: Date,
        inboxCount: Int,
        now: Date
    ) -> [TaskListWidgetTimelineGap] {
        guard sleepAnchor > wakeAnchor else { return [] }
        let intervals = timedItems.compactMap { item -> (start: Date, end: Date)? in
            guard let start = item.startDate, let end = item.endDate else { return nil }
            let clippedStart = max(start, wakeAnchor)
            let clippedEnd = min(end, sleepAnchor)
            guard clippedEnd > clippedStart else { return nil }
            return (clippedStart, clippedEnd)
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end < rhs.end
        }

        var merged: [(start: Date, end: Date)] = []
        for interval in intervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged[merged.count - 1] = (last.start, max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        var cursor = wakeAnchor
        var gaps: [TaskListWidgetTimelineGap] = []
        for interval in merged {
            appendGapIfNeeded(start: cursor, end: interval.start, inboxCount: inboxCount, now: now, into: &gaps)
            cursor = max(cursor, interval.end)
        }
        appendGapIfNeeded(start: cursor, end: sleepAnchor, inboxCount: inboxCount, now: now, into: &gaps)
        return gaps
    }

    static func appendGapIfNeeded(
        start: Date,
        end: Date,
        inboxCount: Int,
        now: Date,
        into gaps: inout [TaskListWidgetTimelineGap]
    ) {
        guard end.timeIntervalSince(start) >= 30 * 60 else { return }
        let headline = start <= now && end > now ? "Open now" : "Open time"
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let supporting = inboxCount > 0
            ? "\(minutes)m available. Place an Inbox task here."
            : "\(minutes)m available. Add a task for this window."
        gaps.append(TaskListWidgetTimelineGap(
            startDate: start,
            endDate: end,
            suggestedTaskCount: inboxCount,
            headline: headline,
            supportingText: supporting
        ))
    }

    static func currentTimelineItemID(in items: [TaskListWidgetTimelineItem], now: Date) -> String? {
        if let current = items.first(where: { item in
            guard item.isComplete == false, let start = item.startDate, let end = item.endDate else { return false }
            return start <= now && end > now
        }) {
            return current.id
        }
        return items.first { item in
            guard let start = item.startDate else { return false }
            return start >= now
        }?.id
    }

    static func sortItemsForTimeline(_ lhs: TaskListWidgetTimelineItem, _ rhs: TaskListWidgetTimelineItem) -> Bool {
        let lhsStart = lhs.startDate ?? Date.distantFuture
        let rhsStart = rhs.startDate ?? Date.distantFuture
        if lhsStart != rhsStart { return lhsStart < rhsStart }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    static func sortTasksForTimeline(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    static func isInboxCaptureTask(_ task: TaskDefinition) -> Bool {
        guard task.isComplete == false, task.parentTaskID == nil else { return false }
        guard task.scheduledStartAt == nil, task.dueDate == nil else { return false }
        let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return task.projectID == ProjectConstants.inboxProjectID
            || projectName.isEmpty
            || projectName.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    static func placementDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        task.scheduledStartAt ?? (isDateOnly(task.dueDate, calendar: calendar) ? nil : task.dueDate)
    }

    static func allDayDate(for task: TaskDefinition, calendar: Calendar) -> Date? {
        if task.isAllDay {
            return task.dueDate ?? task.scheduledStartAt
        }
        if isDateOnly(task.dueDate, calendar: calendar) {
            return task.dueDate
        }
        return nil
    }

    static func isDateOnly(_ date: Date?, calendar: Calendar) -> Bool {
        guard let date else { return false }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0 && (components.second ?? 0) == 0
    }

    static func timelineAnchorTime(on day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }

    static func resolvedSleepAnchor(
        on day: Date,
        wakeAnchor: Date,
        preferences: LifeBoardWorkspacePreferences,
        calendar: Calendar
    ) -> Date {
        var sleep = timelineAnchorTime(
            on: day,
            hour: preferences.timelineWindDownHour,
            minute: preferences.timelineWindDownMinute,
            calendar: calendar
        )
        if sleep <= wakeAnchor {
            sleep = calendar.date(byAdding: .day, value: 1, to: sleep) ?? sleep
        }
        return sleep
    }

    static func accessoryText(for task: TaskDefinition, start: Date, end: Date, now: Date) -> String? {
        if task.isComplete {
            return "Done"
        }
        if start <= now, end > now {
            let roundedMinutes = max(1, Int(ceil(end.timeIntervalSince(now) / 60)))
            return "\(roundedMinutes)m left"
        }
        if let duration = task.estimatedDuration {
            return durationText(duration)
        }
        return task.priority.code
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    static func systemImageName(for task: TaskDefinition) -> String {
        if let iconSymbolName = task.iconSymbolName, iconSymbolName.isEmpty == false {
            return iconSymbolName
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

    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func loadLevel(for count: Int) -> TaskListWidgetTimelineLoadLevel {
        if count >= 5 { return .busy }
        if count >= 2 { return .balanced }
        return .light
    }
}

extension TaskDefinition {
    var projectLabelForWidget: String {
        let projectName = projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return projectName?.isEmpty == false ? projectName! : ProjectConstants.inboxProjectName
    }
}

final class TaskListWidgetSnapshotService: @unchecked Sendable {
    static let shared = TaskListWidgetSnapshotService()

    let queue = DispatchQueue(label: "lifeboard.tasklist.widget.snapshot", qos: .utility)
    let debounceDelay: TimeInterval = 0.75
    var pendingWorkItem: DispatchWorkItem?
    var refreshInFlight = false
    var queuedReasonAfterRefresh: String?

    init() {}

    func scheduleRefresh(reason: String) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.refreshInFlight {
                self.queuedReasonAfterRefresh = reason
                return
            }
            self.pendingWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.refreshNow(reason: reason)
            }
            self.pendingWorkItem = workItem
            self.queue.asyncAfter(deadline: .now() + self.debounceDelay, execute: workItem)
        }
    }

    func refreshNow(reason: String) {
        guard V2FeatureFlags.taskListWidgetsEnabled else { return }
        guard let coordinator = currentCoordinator() else { return }
        if refreshInFlight {
            queuedReasonAfterRefresh = reason
            return
        }
        refreshInFlight = true
        pendingWorkItem = nil
        LifeBoardMemoryDiagnostics.checkpoint(
            event: "widget_snapshot_refresh_started",
            message: "Refreshing task list widget snapshot",
            fields: ["reason": reason]
        )

        coordinator.getTasks.searchTasks(query: "", in: .all) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                logWarning(
                    event: "task_list_widget_snapshot_refresh_failed",
                    message: "Failed to refresh task list widget snapshot",
                    fields: [
                        "reason": reason,
                        "error": error.localizedDescription
                    ]
                )
                self.finishRefresh()
            case .success(let tasks):
                LifeBoardMemoryDiagnostics.checkpoint(
                    event: "widget_snapshot_refresh_loaded",
                    message: "Loaded task list widget source data",
                    fields: ["reason": reason],
                    counts: ["task_count": tasks.count]
                )
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let calendarSnapshot = TaskListWidgetCalendarProjection.make(
                        from: coordinator.calendarIntegrationService.snapshot,
                        weekStartsOn: coordinator.calendarIntegrationService.weekStartsOn
                    )
                    let workspacePreferences = LifeBoardWorkspacePreferencesStore.shared.load()
                    let now = Date()
                    self.loadHabitRows(coordinator: coordinator, on: now) { [weak self] habitRows in
                        guard let self else { return }
                        let snapshot = self.buildSnapshot(
                            tasks: tasks,
                            now: now,
                            habitRows: habitRows,
                            calendarSnapshot: calendarSnapshot,
                            workspacePreferences: workspacePreferences
                        )
                        self.persistIfChanged(snapshot: snapshot, reason: reason)
                        self.finishRefresh()
                    }
                }
            }
        }
    }

    func finishRefresh() {
        queue.async { [weak self] in
            guard let self else { return }
            self.refreshInFlight = false
            guard let queuedReason = self.queuedReasonAfterRefresh else { return }
            self.queuedReasonAfterRefresh = nil
            self.scheduleRefresh(reason: queuedReason)
        }
    }

    func currentCoordinator() -> UseCaseCoordinator? {
        let container = EnhancedDependencyContainer.shared
        guard let coordinator = container.useCaseCoordinator else { return nil }
        return coordinator
    }

    func buildSnapshot(
        tasks: [TaskDefinition],
        now: Date = Date(),
        habitRows: [HomeHabitRow] = [],
        calendarSnapshot: TaskListWidgetCalendarSnapshot = .empty,
        workspacePreferences: LifeBoardWorkspacePreferences = LifeBoardWorkspacePreferences()
    ) -> TaskListWidgetSnapshot {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let fortyEightHours = now.addingTimeInterval(48 * 60 * 60)

        let openTasks = tasks.filter { !$0.isComplete }
        let sortedOpen = openTasks.sorted(by: sortByPriorityThenDue)
        let overdueOpen = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday
            }
            .sorted(by: sortByPriorityThenDue)
        let todayOpen = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startOfToday && dueDate < endOfToday
            }
            .sorted(by: sortByPriorityThenDue)
        let dueSoon = openTasks
            .filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= now && dueDate <= fortyEightHours
            }
            .sorted(by: sortByPriorityThenDue)
        let quickWins = openTasks
            .filter { task in
                guard let duration = task.estimatedDuration else { return false }
                let minutes = Int(duration / 60)
                return minutes > 0 && minutes <= 15
            }
            .sorted(by: sortByPriorityThenDue)
        let waitingOn = openTasks
            .filter { !$0.dependencies.isEmpty }
            .sorted(by: sortByPriorityThenDue)

        let completedToday = tasks
            .filter(\.isComplete)
            .filter { task in
                guard let completedAt = task.dateCompleted else { return false }
                return calendar.isDateInToday(completedAt)
            }
            .sorted(by: sortCompletedDescending)

        let focusNow = Array((todayOpen.isEmpty ? sortedOpen : todayOpen).prefix(3))
        let topTasks = Array((todayOpen + overdueOpen).isEmpty ? sortedOpen.prefix(3) : (todayOpen + overdueOpen).prefix(3))

        let projectSlices: [TaskListWidgetProjectSlice] = Dictionary(
            grouping: openTasks,
            by: { $0.projectID }
        )
        .map { projectID, projectTasks in
            let projectName = projectTasks.first?.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TaskListWidgetProjectSlice(
                projectID: projectID,
                projectName: (projectName?.isEmpty == false ? projectName : nil) ?? "Inbox",
                openCount: projectTasks.count,
                overdueCount: projectTasks.filter(\.isOverdue).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.openCount != rhs.openCount {
                return lhs.openCount > rhs.openCount
            }
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        let energyBuckets: [TaskListWidgetEnergyBucket] = TaskEnergy.allCases.map { energy in
            TaskListWidgetEnergyBucket(
                energy: energy.rawValue,
                count: openTasks.filter { $0.energy == energy }.count
            )
        }
        let timelineSnapshot = TaskListWidgetTimelineProjection.make(
            tasks: tasks,
            calendarSnapshot: calendarSnapshot,
            preferences: workspacePreferences,
            now: now,
            calendar: calendar
        )
        let habitSnapshot = taskListWidgetHabitSnapshot(
            from: habitRows,
            now: now,
            calendar: calendar
        )

        return TaskListWidgetSnapshot(
            schemaVersion: TaskListWidgetSnapshot.currentSchemaVersion,
            updatedAt: now,
            todayTopTasks: topTasks.map(widgetTask(from:)),
            upcomingTasks: Array(dueSoon.prefix(3)).map(widgetTask(from:)),
            overdueTasks: Array(overdueOpen.prefix(3)).map(widgetTask(from:)),
            quickWins: Array(quickWins.prefix(3)).map(widgetTask(from:)),
            projectSlices: Array(projectSlices.prefix(6)),
            doneTodayCount: completedToday.count,
            focusNow: focusNow.map(widgetTask(from:)),
            waitingOn: Array(waitingOn.prefix(3)).map(widgetTask(from:)),
            energyBuckets: energyBuckets,
            openTodayCount: todayOpen.count + overdueOpen.count,
            openTaskPool: Array(sortedOpen.prefix(25)).map(widgetTask(from:)),
            completedTodayTasks: Array(completedToday.prefix(8)).map(widgetTask(from:)),
            snapshotHealth: TaskListWidgetSnapshotHealth(
                source: "full_query",
                generatedAt: now,
                isStale: false,
                hasCorruptionFallback: false
            ),
            calendar: calendarSnapshot,
            timeline: timelineSnapshot,
            habit: habitSnapshot
        )
    }

    func loadHabitRows(
        coordinator: UseCaseCoordinator,
        on date: Date,
        completion: @escaping ([HomeHabitRow]) -> Void
    ) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let group = DispatchGroup()
        let state = LockedResultAccumulator(HomeHabitWidgetRowsState())

        group.enter()
        coordinator.buildHabitHomeProjection.execute(date: day) { result in
            if case .success(let rows) = result {
                state.update { $0.agendaRows = rows }
            }
            group.leave()
        }

        group.enter()
        coordinator.getHabitLibrary.execute(includeArchived: false) { [weak self] result in
            guard let self else {
                group.leave()
                return
            }
            guard case .success(let libraryRows) = result else {
                group.leave()
                return
            }
            guard libraryRows.isEmpty == false else {
                group.leave()
                return
            }

            group.enter()
            coordinator.getHabitHistory.execute(
                habitIDs: libraryRows.map(\.habitID),
                endingOn: day,
                dayCount: 30
            ) { historyResult in
                var historyByHabitID: [UUID: [HabitDayMark]] = [:]
                if case .success(let windows) = historyResult {
                    historyByHabitID = windows.reduce(into: [:]) { result, window in
                        result[window.habitID] = window.marks
                    }
                }
                let rows = self.trackingWidgetHabitRows(
                    from: libraryRows,
                    historyByHabitID: historyByHabitID,
                    on: day,
                    calendar: calendar
                )
                state.update { $0.trackingRows = rows }
                group.leave()
            }
            group.leave()
        }

        group.notify(queue: queue) { [weak self] in
            guard let self else { return }
            let resolvedState = (try? state.result().get()) ?? HomeHabitWidgetRowsState()
            let mergedRows = self.mergeWidgetHabitRows(
                agenda: resolvedState.agendaRows,
                tracking: resolvedState.trackingRows
            )
            completion(mergedRows)
        }
    }

    func trackingWidgetHabitRows(
        from rows: [HabitLibraryRow],
        historyByHabitID: [UUID: [HabitDayMark]],
        on date: Date,
        calendar: Calendar
    ) -> [HomeHabitRow] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        return rows.compactMap { row in
            guard !row.isArchived, !row.isPaused, row.trackingMode == .lapseOnly else {
                return nil
            }

            let marks = historyByHabitID[row.habitID] ?? row.last14Days
            let todayMark = marks.first { mark in
                let markDate = calendar.startOfDay(for: mark.date)
                return markDate >= startOfDay && markDate < endOfDay
            }
            let state: HomeHabitRowState
            switch todayMark?.state {
            case .failure:
                state = .lapsedToday
            default:
                state = .tracking
            }

            let compactCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 7,
                calendar: calendar
            )
            let expandedCells = HabitBoardPresentationBuilder.buildCells(
                marks: marks,
                cadence: row.cadence,
                referenceDate: date,
                dayCount: 30,
                calendar: calendar
            )

            return HomeHabitRow(
                habitID: row.habitID,
                title: row.title,
                kind: row.kind,
                trackingMode: row.trackingMode,
                lifeAreaID: row.lifeAreaID,
                lifeAreaName: row.lifeAreaName,
                projectID: row.projectID,
                projectName: row.projectName,
                iconSymbolName: row.icon?.symbolName ?? "circle.dashed",
                accentHex: row.colorHex,
                cadence: row.cadence,
                cadenceLabel: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar),
                dueAt: row.nextDueAt,
                state: state,
                currentStreak: row.currentStreak,
                bestStreak: row.bestStreak,
                last14Days: marks,
                boardCellsCompact: compactCells,
                boardCellsExpanded: expandedCells,
                riskState: todayMark?.state == .failure ? .broken : .stable,
                helperText: HabitBoardPresentationBuilder.cadenceLabel(for: row.cadence, calendar: calendar)
            )
        }
    }

    func mergeWidgetHabitRows(
        agenda: [HomeHabitRow],
        tracking: [HomeHabitRow]
    ) -> [HomeHabitRow] {
        var merged: [String: HomeHabitRow] = [:]
        for row in agenda {
            merged[row.id] = row
        }
        for row in tracking where merged[row.id] == nil {
            merged[row.id] = row
        }
        return merged.values.sorted { lhs, rhs in
            if lhs.projectName != rhs.projectName {
                return (lhs.projectName ?? lhs.lifeAreaName)
                    .localizedCaseInsensitiveCompare(rhs.projectName ?? rhs.lifeAreaName) == .orderedAscending
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    func taskListWidgetHabitSnapshot(
        from rows: [HomeHabitRow],
        now: Date,
        calendar: Calendar
    ) -> TaskListWidgetHabitSnapshot {
        let day = calendar.startOfDay(for: now)
        let activeRows = rows.filter { row in
            switch row.state {
            case .due, .overdue, .completedToday, .lapsedToday, .skippedToday, .tracking:
                return true
            }
        }
        let dueCount = activeRows.filter { $0.state == .due || $0.state == .overdue }.count
        let completedCount = activeRows.filter { $0.state == .completedToday }.count
        let atRiskCount = activeRows.filter { $0.riskState == .atRisk || $0.riskState == .broken }.count
        let primary = activeRows
            .sorted { lhs, rhs in
                let lhsRank = taskListWidgetHabitPriority(lhs)
                let rhsRank = taskListWidgetHabitPriority(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if lhs.currentStreak != rhs.currentStreak { return lhs.currentStreak > rhs.currentStreak }
                let lhsDue = lhs.dueAt ?? Date.distantFuture
                let rhsDue = rhs.dueAt ?? Date.distantFuture
                if lhsDue != rhsDue { return lhsDue < rhsDue }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .first
            .map { row in
                TaskListWidgetHabitPrimary(
                    habitID: row.habitID,
                    title: row.title,
                    iconSymbolName: row.iconSymbolName,
                    accentHex: row.accentHex,
                    currentStreak: row.currentStreak,
                    bestStreak: row.bestStreak,
                    todayState: taskListWidgetHabitTodayState(row.state),
                    dueAt: row.dueAt,
                    week: taskListWidgetHabitWeek(from: row.last14Days, endingOn: day, calendar: calendar)
                )
            }

        return TaskListWidgetHabitSnapshot(
            date: day,
            updatedAt: now,
            primaryHabit: primary,
            dueCount: dueCount,
            completedTodayCount: completedCount,
            atRiskCount: atRiskCount
        )
    }

    func taskListWidgetHabitPriority(_ row: HomeHabitRow) -> Int {
        switch row.state {
        case .overdue:
            return 0
        case .due:
            return row.riskState == .atRisk || row.riskState == .broken ? 1 : 2
        case .lapsedToday:
            return 3
        case .tracking:
            return row.currentStreak > 0 ? 4 : 6
        case .completedToday:
            return 5
        case .skippedToday:
            return 7
        }
    }

    func taskListWidgetHabitTodayState(_ state: HomeHabitRowState) -> TaskListWidgetHabitTodayState {
        switch state {
        case .due:
            return .due
        case .overdue:
            return .overdue
        case .completedToday:
            return .completedToday
        case .lapsedToday:
            return .lapsedToday
        case .skippedToday:
            return .skippedToday
        case .tracking:
            return .tracking
        }
    }

    func taskListWidgetHabitWeek(
        from marks: [HabitDayMark],
        endingOn date: Date,
        calendar: Calendar
    ) -> [TaskListWidgetHabitDay] {
        let days = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: date)
        }
        return days.map { day in
            let mark = marks.first { calendar.isDate($0.date, inSameDayAs: day) }
            return TaskListWidgetHabitDay(
                date: day,
                dayKey: taskListWidgetHabitDayKey(day, calendar: calendar),
                state: taskListWidgetHabitDayState(mark?.state, day: day, now: date, calendar: calendar)
            )
        }
    }

    func taskListWidgetHabitDayState(
        _ state: HabitDayState?,
        day: Date,
        now: Date,
        calendar: Calendar
    ) -> TaskListWidgetHabitDayState {
        if day > now, calendar.isDate(day, inSameDayAs: now) == false {
            return .future
        }
        switch state ?? .none {
        case .success:
            return .success
        case .failure:
            return .failure
        case .skipped:
            return .skipped
        case .none:
            return .none
        case .future:
            return .future
        }
    }

    func taskListWidgetHabitDayKey(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func widgetTask(from task: TaskDefinition) -> TaskListWidgetTask {
        TaskListWidgetTask(
            id: task.id,
            title: task.title,
            projectID: task.projectID,
            projectName: task.projectName,
            priorityCode: task.priority.code,
            dueDate: task.dueDate,
            isOverdue: task.isOverdue,
            estimatedDurationMinutes: task.estimatedDuration.map { max(1, Int($0 / 60)) },
            energy: task.energy.rawValue,
            context: task.context.rawValue,
            isComplete: task.isComplete,
            hasDependencies: !task.dependencies.isEmpty
        )
    }

    func sortByPriorityThenDue(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        if lhs.priority.scorePoints != rhs.priority.scorePoints {
            return lhs.priority.scorePoints > rhs.priority.scorePoints
        }
        let lhsDate = lhs.dueDate ?? Date.distantFuture
        let rhsDate = rhs.dueDate ?? Date.distantFuture
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func sortCompletedDescending(lhs: TaskDefinition, rhs: TaskDefinition) -> Bool {
        let lhsDate = lhs.dateCompleted ?? Date.distantPast
        let rhsDate = rhs.dateCompleted ?? Date.distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    func persistIfChanged(snapshot: TaskListWidgetSnapshot, reason: String) {
        let current = TaskListWidgetSnapshot.load()
        if Self.normalizedForReloadComparison(snapshot) == Self.normalizedForReloadComparison(current) {
            return
        }
        snapshot.save()
        WatchWidgetSnapshotSync.shared.sendTaskListSnapshot(snapshot)
        reloadTaskListTimelines()
        logDebug("TASK_WIDGET_SNAPSHOT refreshed reason=\(reason)")
    }

    static func normalizedForReloadComparison(_ snapshot: TaskListWidgetSnapshot) -> TaskListWidgetSnapshot {
        var value = snapshot
        value.updatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.generatedAt = Date(timeIntervalSince1970: 0)
        value.snapshotHealth.hasCorruptionFallback = false
        value.calendar.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.updatedAt = Date(timeIntervalSince1970: 0)
        value.timeline.day.currentTime = Date(timeIntervalSince1970: 0)
        value.habit.updatedAt = Date(timeIntervalSince1970: 0)
        return value
    }

    func reloadTaskListTimelines() {
        #if canImport(WidgetKit)
        let kinds = [
            "TopTaskNowWidget", "TodayCounterNextWidget", "OverdueRescueWidget", "QuickWin15mWidget",
            "MorningKickoffWidget", "EveningWrapWidget", "WaitingOnWidget", "InboxTriageWidget",
            "DueSoonRadarWidget", "EnergyMatchWidget", "ProjectSpotlightWidget", "CalendarTaskBridgeWidget",
            "TodayTop3Widget", "NowLaneWidget", "OverdueBoardWidget", "Upcoming48hWidget",
            "MorningEveningPlanWidget", "QuickViewSwitcherWidget", "ProjectSprintWidget",
            "PriorityMatrixLiteWidget", "ContextWidget", "FocusSessionQueueWidget",
            "RecoveryWidget", "DoneReflectionWidget",
            "TodayPlannerBoardWidget", "WeekTaskPlannerWidget", "ProjectCockpitWidget",
            "BacklogHealthWidget", "KanbanLiteWidget", "DeadlineHeatmapWidget",
            "ExecutionDashboardWidget", "DeepWorkAgendaWidget", "AssistantPlanPreviewWidget",
            "LifeAreasBoardWidget",
            "HomeCalendarWidget", "HomeTimelineWidget",
            "WatchTimelineComplication", "WatchMeetingScheduleComplication", "WatchHabitStreakComplication",
            "InlineNextTaskWidget", "InlineDueSoonWidget",
            "CircularTodayProgressWidget", "CircularQuickAddWidget",
            "RectangularTop2TasksWidget", "RectangularOverdueAlertWidget",
            "RectangularFocusNowWidget", "RectangularWaitingOnWidget",
            "DeskTodayBoardWidget", "CountdownPanelWidget", "NightlyResetWidget",
            "MorningBriefPanelWidget", "ProjectPulseWidget", "FocusDockWidget"
        ]
        Task { @MainActor in
            let center = WidgetCenter.shared
            for kind in kinds {
                center.reloadTimelines(ofKind: kind)
            }
        }
        #endif
    }
}
