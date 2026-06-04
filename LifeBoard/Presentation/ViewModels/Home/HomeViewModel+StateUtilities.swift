//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
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
    func isCurrentReloadGeneration(_ generation: Int) -> Bool {
        generation == reloadGeneration
    }

    func isCurrentAnalyticsGeneration(_ generation: Int) -> Bool {
        generation == analyticsGeneration
    }

    func isCurrentWeeklySummaryGeneration(_ generation: Int) -> Bool {
        generation == weeklySummaryGeneration
    }

    func assignIfChanged<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<HomeViewModel, Value>,
        _ newValue: Value
    ) {
        guard self[keyPath: keyPath] != newValue else { return }
        self[keyPath: keyPath] = newValue
        let erasedKeyPath = keyPath as AnyKeyPath
        invalidateDerivedRowCaches(for: erasedKeyPath)
        if !keyPathTriggersHomeRenderRefreshViaDidSet(erasedKeyPath) {
            scheduleHomeRenderStateRefresh(homeRenderInvalidation(forAssignedKeyPath: erasedKeyPath))
        }
    }

    func assignForHabitMutation<Value>(
        _ keyPath: ReferenceWritableKeyPath<HomeViewModel, Value>,
        _ newValue: Value
    ) {
        self[keyPath: keyPath] = newValue
        let erasedKeyPath = keyPath as AnyKeyPath
        invalidateDerivedRowCaches(for: erasedKeyPath)
        if !keyPathTriggersHomeRenderRefreshViaDidSet(erasedKeyPath) {
            scheduleHomeRenderStateRefresh(homeRenderInvalidation(forAssignedKeyPath: erasedKeyPath))
        }
    }

    /// Executes applyCompletionOverrides.

    func applyCompletionOverrides(openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) -> (openTasks: [TaskDefinition], doneTasks: [TaskDefinition]) {
        let normalizedOpen = openTasks.map(applyingCompletionOverrideIfNeeded)
        let normalizedDone = doneTasks.map(applyingCompletionOverrideIfNeeded)

        var mergedOpen: [TaskDefinition] = []
        var openIDs = Set<UUID>()
        for task in normalizedOpen where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }
        for task in normalizedDone where !task.isComplete {
            if openIDs.insert(task.id).inserted {
                mergedOpen.append(task)
            }
        }

        var mergedDone: [TaskDefinition] = []
        var doneIDs = Set<UUID>()
        for task in normalizedDone where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }
        for task in normalizedOpen where task.isComplete {
            if doneIDs.insert(task.id).inserted {
                mergedDone.append(task)
            }
        }

        reconcileCompletionOverrides(persistedTasks: openTasks + doneTasks)
        return (openTasks: mergedOpen, doneTasks: mergedDone)
    }

    /// Executes applyingCompletionOverrideIfNeeded.

    func applyingCompletionOverrideIfNeeded(_ task: TaskDefinition) -> TaskDefinition {
        guard let expectedCompletion = completionOverrides[task.id],
              expectedCompletion != task.isComplete else {
            return task
        }

        var updated = task
        updated.isComplete = expectedCompletion
        updated.dateCompleted = expectedCompletion ? (updated.dateCompleted ?? Date()) : nil
        return updated
    }

    /// Executes reconcileCompletionOverrides.

    func reconcileCompletionOverrides(persistedTasks: [TaskDefinition]) {
        guard !completionOverrides.isEmpty else { return }

        var resolvedIDs: [UUID] = []
        for (id, expectedCompletion) in completionOverrides {
            guard let persistedTask = persistedTasks.first(where: { $0.id == id }) else { continue }
            if persistedTask.isComplete == expectedCompletion {
                resolvedIDs.append(id)
            }
        }

        guard !resolvedIDs.isEmpty else { return }
        for id in resolvedIDs {
            completionOverrides.removeValue(forKey: id)
        }

        let resolvedSummary = resolvedIDs.map { $0.uuidString.prefix(8) }.joined(separator: ",")
        logDebug("HOME_ROW_STATE vm.override_cleared ids=[\(resolvedSummary)]")
    }

    /// Executes summarizeRowState.

    func summarizeRowState(_ tasks: [TaskDefinition], limit: Int = 4) -> String {
        let summary = tasks.prefix(limit).map { task in
            let state = task.isComplete ? "done" : "open"
            return "\(task.id.uuidString.prefix(8)):\(state):\(task.title)"
        }.joined(separator: "|")
        return "[\(summary)] total=\(tasks.count)"
    }

    static func makeHabitMutationFeedbackDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }

    static func summaryDate(from dateStamp: String?) -> Date? {
        guard let dateStamp, dateStamp.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: dateStamp)
    }

    static func summaryDateStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    static func buildHomeCalendarSnapshot(
        from snapshot: LifeBoardCalendarSnapshot,
        selectedDate: Date,
        accessAction: CalendarAccessAction
    ) -> HomeCalendarSnapshot {
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) ?? selectedDayStart
        let selectedDayEvents = snapshot.eventsInRange
            .filter { event in
                event.endDate > selectedDayStart && event.startDate < selectedDayEnd
            }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
        let selectedDayTimelineEvents = selectedDayEvents.filter { event in
            event.isAllDay == false && event.isBusy
        }
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let todayCount = snapshot.eventsInRange.filter { event in
            event.endDate > startOfToday && event.startDate < endOfToday
        }.count

        let moduleState: HomeCalendarModuleState
        if snapshot.authorizationStatus.isAuthorizedForRead == false {
            moduleState = .permissionRequired
        } else if let error = snapshot.errorMessage, error.isEmpty == false {
            moduleState = .error(message: error)
        } else if snapshot.selectedCalendarIDs.isEmpty {
            moduleState = .noCalendarsSelected
        } else if selectedDayEvents.isEmpty == false && selectedDayTimelineEvents.isEmpty {
            moduleState = .allDayOnly
        } else if selectedDayTimelineEvents.isEmpty {
            moduleState = .empty
        } else {
            moduleState = .active
        }

        return HomeCalendarSnapshot(
            moduleState: moduleState,
            selectedDate: selectedDate,
            authorizationStatus: snapshot.authorizationStatus,
            accessAction: accessAction,
            selectedCalendarCount: snapshot.selectedCalendarIDs.count,
            availableCalendarCount: snapshot.availableCalendars.count,
            nextMeeting: snapshot.nextMeeting,
            busyBlocks: snapshot.busyBlocks,
            freeUntil: snapshot.freeUntil,
            selectedDayEvents: selectedDayEvents,
            selectedDayTimelineEvents: selectedDayTimelineEvents,
            eventsTodayCount: todayCount,
            isLoading: snapshot.isLoading,
            errorMessage: snapshot.errorMessage
        )
    }

    static func isSameCalendarDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}
