//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension InsightsActionIntent {
    var telemetryName: String {
        switch self {
        case .addTask:
            return "add_task"
        case .openToday:
            return "open_today"
        case .startNextDecision:
            return "start_next_decision"
        case .protectFocus:
            return "protect_focus"
        case .openYesterdayReview:
            return "open_yesterday_review"
        case .openHabitCheck:
            return "open_habit_check"
        case .openBacklogRecovery:
            return "open_backlog_recovery"
        case .openProjectMix:
            return "open_project_mix"
        case .openWeeklyReview:
            return "open_weekly_review"
        case .openWeeklyPlanner:
            return "open_weekly_planner"
        case .openReminderSettings:
            return "open_reminder_settings"
        case .expandDetails(let anchor):
            return "expand_details_\(anchor.rawValue)"
        }
    }
}
