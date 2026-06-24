//
//  HomeViewModel+Resume.swift
//  LifeBoard
//
//  Resolves the calm, context-aware Resume surface from the persisted session
//  context. Mode is chosen by time of day; the prompt only appears when there is
//  something genuine to resume, and never after the user dismisses it for the session.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension HomeViewModel {

    /// Installs a foreground observer so the Resume surface re-evaluates when the
    /// user returns to the app. Called once from `setupBindings()`.
    func installResumeForegroundObserver() {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleHomeRenderStateRefresh([.chrome])
            }
            .store(in: &cancellables)
        #endif
    }

    /// Resolves the Resume context for the current moment, or nil when nothing
    /// should be shown (dismissed, off-Today, stale/empty session, or empty day).
    func resolveResumeContext(now: Date = Date(), calendar: Calendar = .current) -> HomeResumeContext? {
        guard resumeDismissedForSession == false else { return nil }
        // Only on the Today lens, viewing today — avoids surprising context on other days/scopes.
        guard activeScope.quickView == .today, calendar.isDateInToday(selectedDate) else { return nil }
        guard let session = HomeSessionContextStore.load(now: now) else { return nil }

        let hour = calendar.component(.hour, from: now)

        switch hour {
        case ..<11:
            guard todayOpenTaskCount > 0 else { return nil }
            return HomeResumeContext(mode: .morningBrief(taskCount: todayOpenTaskCount, nextItem: nil))
        case 18...:
            let done = completedTasks.count
            guard done > 0 || todayOpenTaskCount > 0 else { return nil }
            return HomeResumeContext(mode: .eveningWrap(doneCount: done, openCount: todayOpenTaskCount))
        default:
            guard let taskID = session.lastActiveTaskID,
                  let task = taskSnapshot(for: taskID),
                  task.isComplete == false else { return nil }
            let minutes = max(1, Int(now.timeIntervalSince(session.lastActiveAt) / 60))
            return HomeResumeContext(mode: .resumeTask(title: task.title, pausedMinutesAgo: minutes, taskID: taskID))
        }
    }

    /// Acts on the Resume prompt and dismisses it for the session.
    func handleResume(_ context: HomeResumeContext) {
        switch context.mode {
        case .resumeTask(_, _, let taskID):
            _ = pinTaskToFocus(taskID)
        case .morningBrief, .eveningWrap:
            break
        }
        resumeDismissedForSession = true
        scheduleHomeRenderStateRefresh([.chrome, .tasks])
    }

    /// Dismisses the Resume prompt for the remainder of the session.
    func dismissResumeForSession() {
        guard resumeDismissedForSession == false else { return }
        resumeDismissedForSession = true
        scheduleHomeRenderStateRefresh([.chrome])
    }
}
