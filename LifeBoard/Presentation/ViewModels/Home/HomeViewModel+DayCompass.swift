//
//  HomeViewModel+DayCompass.swift
//  LifeBoard
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension HomeViewModel {
    func installDayCompassForegroundObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleHomeRenderStateRefresh([.chrome])
            }
            .store(in: &cancellables)
        #endif
    }

    func resolveDayCompass(now: Date = Date(), calendar: Calendar = .current) -> DayCompassCardModel? {
        let replanCandidates = dayCompassReplanCandidates
        let inboxCandidates = dayCompassInboxCandidates
        let snoozes = dayCompassSnoozeStore.load(
            now: now,
            calendar: calendar,
            resumeDismissedForSession: resumeDismissedForSession
        )
        let signals = DayCompassSignals(
            now: now,
            selectedDate: selectedDate,
            calendar: calendar,
            isViewingTodayLens: activeScope.quickView == .today,
            isAnotherFlowPresented: isDayCompassSuppressedByActiveFlow,
            replanCandidateCount: replanCandidates.count,
            replanEarliestTitle: replanCandidates.first?.task.title,
            hasCommittedDailyPlan: dailyPlanDraftForSelectedDate() != nil,
            hasOpenReflectionTarget: hasOpenDayCompassReflectionTarget(now: now, calendar: calendar),
            todayOpenTaskCount: todayOpenTaskCount,
            todayDoneTaskCount: completedTasks.count,
            rescueEligibleCount: dayCompassRescueEligibleCount(now: now),
            inboxReadyCount: inboxCandidates.count,
            resume: dayCompassResumeSignal(now: now, calendar: calendar),
            isQuietHours: isDayCompassQuietHours(now: now, calendar: calendar),
            snoozes: snoozes,
            allClearFlow: dayCompassAllClearFlow,
            allClearExpiresAt: dayCompassAllClearExpiresAt
        )
        return DayCompassEngine().resolve(signals: signals)
    }

    func startDayCompassReplanSession() {
        let candidates = dayCompassReplanCandidates
        guard candidates.isEmpty == false else { return }
        dayCompassLaunchedFlow = .replan
        beginReplanLauncher(with: candidates, scopedTo: nil)
        startNeedsReplanSession()
    }

    func startDayCompassInboxSession() {
        let candidates = dayCompassInboxCandidates
        guard candidates.isEmpty == false else { return }
        dayCompassLaunchedFlow = .inbox
        beginReplanLauncher(with: candidates, scopedTo: nil)
        startNeedsReplanSession()
    }

    func startDayCompassRescueSession() {
        dayCompassLaunchedFlow = .rescue
        openOverdueRescueFromHome(source: "day_compass")
    }

    /// Arms the all-clear moment when a compass-launched replan or inbox
    /// session finishes; abandoned sessions clear the stamp silently.
    func completeDayCompassPlacementSessionIfNeeded() {
        guard let flow = dayCompassLaunchedFlow, flow == .replan || flow == .inbox else { return }
        dayCompassLaunchedFlow = nil
        showDayCompassAllClear(after: flow)
    }

    func abandonDayCompassPlacementSessionIfNeeded() {
        guard dayCompassLaunchedFlow == .replan || dayCompassLaunchedFlow == .inbox else { return }
        dayCompassLaunchedFlow = nil
    }

    /// Arms the all-clear moment when a compass-launched rescue run drained
    /// the eligible queue; otherwise the compass simply resurfaces rescue.
    func completeDayCompassRescueIfNeeded(now: Date = Date()) {
        guard dayCompassLaunchedFlow == .rescue else { return }
        dayCompassLaunchedFlow = nil
        guard dayCompassRescueEligibleCount(now: now) == 0 else { return }
        showDayCompassAllClear(after: .rescue)
    }

    func handleDayCompassResumeTask(taskID: UUID) {
        _ = pinTaskToFocus(taskID)
        resumeDismissedForSession = true
        showDayCompassAllClear(after: .resumeTask)
        scheduleHomeRenderStateRefresh([.chrome, .tasks])
    }

    func snoozeDayCompass(_ flow: DayCompassFlow) {
        if flow == .resumeTask {
            resumeDismissedForSession = true
        } else {
            dayCompassSnoozeStore.snoozeUntilEndOfDay(flow: flow)
        }
        clearDayCompassAllClear()
        scheduleHomeRenderStateRefresh([.chrome])
    }

    /// Reflection-target lookup cached per day so frequent `.chrome` refreshes
    /// don't re-run the use case; invalidated when a reflection is saved.
    func hasOpenDayCompassReflectionTarget(now: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let dayKey = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        if dayCompassReflectionTargetCacheDayKey == dayKey {
            return dayCompassReflectionTargetCacheValue
        }
        let hasTarget = useCaseCoordinator.resolveDailyReflectionTarget.execute() != nil
        dayCompassReflectionTargetCacheDayKey = dayKey
        dayCompassReflectionTargetCacheValue = hasTarget
        return hasTarget
    }

    func invalidateDayCompassReflectionTargetCache() {
        dayCompassReflectionTargetCacheDayKey = nil
    }

    func showDayCompassAllClear(after flow: DayCompassFlow, durationSeconds: TimeInterval = 4) {
        dayCompassAllClearTask?.cancel()
        dayCompassAllClearFlow = flow
        dayCompassAllClearExpiresAt = Date().addingTimeInterval(durationSeconds)
        scheduleHomeRenderStateRefresh([.chrome])

        let duration = Duration.milliseconds(max(1, Int(durationSeconds * 1000)))
        dayCompassAllClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard Task.isCancelled == false else { return }
            self?.clearDayCompassAllClear()
            self?.scheduleHomeRenderStateRefresh([.chrome])
        }
    }

    func clearDayCompassAllClear() {
        dayCompassAllClearTask?.cancel()
        dayCompassAllClearTask = nil
        dayCompassAllClearFlow = nil
        dayCompassAllClearExpiresAt = nil
    }

    var dayCompassReplanCandidates: [HomeReplanCandidate] {
        needsReplanCandidates.filter { $0.kind != .unscheduledBacklog }
    }

    var dayCompassInboxCandidates: [HomeReplanCandidate] {
        needsReplanCandidates.filter { $0.kind == .unscheduledBacklog }
    }

    var isDayCompassSuppressedByActiveFlow: Bool {
        if evaRescueSheetPresented { return true }
        if evaRescueLauncherState == .loading || evaRescueLauncherState == .ready { return true }
        switch homeReplanState.phase {
        case .trayHidden, .trayVisible:
            return false
        case .launcher, .card, .placement, .summary, .skippedReview:
            return true
        }
    }

    func dayCompassRescueEligibleCount(now: Date) -> Int {
        guard V2FeatureFlags.evaRescueEnabled else { return 0 }
        return overdueTasks.filter { isOverdueRescueDeckEligibleTask($0, on: now) }.count
    }

    func dayCompassResumeSignal(now: Date, calendar: Calendar) -> DayCompassResumeSignal? {
        let hour = calendar.component(.hour, from: now)
        guard hour >= 11, hour < 18 else { return nil }
        guard let session = HomeSessionContextStore.load(now: now),
              let taskID = session.lastActiveTaskID,
              let task = taskSnapshot(for: taskID),
              task.isComplete == false else {
            return nil
        }
        let minutes = max(1, Int(now.timeIntervalSince(session.lastActiveAt) / 60))
        return DayCompassResumeSignal(title: task.title, pausedMinutesAgo: minutes, taskID: taskID)
    }

    func isDayCompassQuietHours(now: Date, calendar: Calendar) -> Bool {
        let preferences = LifeBoardNotificationPreferencesStore.shared.load()
        guard preferences.quietHoursEnabled else { return false }

        let startMinutes = preferences.quietHoursStartHour * 60 + preferences.quietHoursStartMinute
        let endMinutes = preferences.quietHoursEndHour * 60 + preferences.quietHoursEndMinute
        guard startMinutes != endMinutes else { return false }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
        return currentMinutes >= startMinutes || currentMinutes < endMinutes
    }
}
