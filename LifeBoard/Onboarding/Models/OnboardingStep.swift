import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingStep: Int, CaseIterable, Codable {
    case welcome = 0
    case lifeAreas = 1
    case projects = 2
    case habits = 3
    case firstTask = 4
    case focusRoom = 5
    case blocker = 6
    case goal = 7
    case pain = 8
    case evaValue = 9
    case habitSetup = 10
    case streakPreview = 11
    case evaStyle = 12
    case processing = 13
    case habitCheckIn = 14
    case calendarPermission = 15
    case notificationPermission = 16
    case success = 17
    case workBlockers = 18
    case weeklyOutcomes = 19
    case homeDemo = 20

    static let orderedFlow: [OnboardingStep] = [
        .goal,
        .pain,
        .evaValue,
        .lifeAreas,
        .habitSetup,
        .evaStyle,
        .workBlockers,
        .weeklyOutcomes,
        .firstTask,
        .homeDemo,
        .calendarPermission,
        .notificationPermission,
        .success
    ]

    var progressIndex: Int {
        OnboardingProgress(step: self)?.current ?? 0
    }

    var progressLabel: String {
        OnboardingProgress(step: self)?.label ?? ""
    }

    var eyebrowTitle: String {
        switch self {
        case .welcome:
            return "Setup"
        case .goal:
            return "Priority"
        case .pain:
            return "Friction"
        case .evaValue:
            return "Assistant"
        case .blocker:
            return "Setup"
        case .lifeAreas:
            return "Areas"
        case .projects:
            return "Projects"
        case .habits:
            return "Habits"
        case .habitSetup:
            return "Habit"
        case .streakPreview:
            return "Streak"
        case .evaStyle:
            return "Work style"
        case .workBlockers:
            return "Blockers"
        case .weeklyOutcomes:
            return "Outcomes"
        case .processing:
            return "Build"
        case .firstTask:
            return "Task"
        case .homeDemo:
            return "Demo"
        case .focusRoom:
            return "Focus"
        case .habitCheckIn:
            return "Check-in"
        case .calendarPermission:
            return "Calendar"
        case .notificationPermission:
            return "Notifications"
        case .success:
            return "Ready"
        }
    }

    var accessibilitySummary: String {
        OnboardingCopy.Header.accessibilitySummary(for: self)
    }

    var evaMascotPlacement: EvaMascotPlacement {
        switch self {
        case .welcome:
            return .onboardingWelcome
        case .goal, .pain:
            return .onboardingNextStep
        case .evaValue, .evaStyle, .workBlockers, .weeklyOutcomes:
            return .onboardingEvaValue
        case .lifeAreas, .projects, .habits, .habitSetup, .firstTask, .homeDemo:
            return .onboardingCaptureSetup
        case .streakPreview, .habitCheckIn:
            return .habitStreakWin
        case .processing:
            return .onboardingProcessing
        case .focusRoom:
            return .focusStart
        case .calendarPermission:
            return .onboardingCalendarPermission
        case .notificationPermission:
            return .onboardingNotificationPermission
        case .success:
            return .onboardingSuccess
        case .blocker:
            return .taskDeadlineRisk
        }
    }

    var normalizedForCurrentFlow: OnboardingStep {
        switch self {
        case .blocker:
            return .goal
        case .projects:
            return .lifeAreas
        case .habits:
            return .habitSetup
        case .streakPreview:
            return .evaStyle
        case .processing:
            return .firstTask
        case .focusRoom, .habitCheckIn:
            return .homeDemo
        default:
            return self
        }
    }

    var voiceOverTitle: String {
        switch normalizedForCurrentFlow {
        case .welcome:
            return "Welcome setup"
        case .goal:
            return "Choose goal"
        case .pain:
            return "Choose blockers"
        case .evaValue:
            return "Choose guide"
        case .lifeAreas:
            return "Choose focus areas"
        case .habitSetup:
            return "Pick one habit"
        case .streakPreview:
            return "Preview streak"
        case .evaStyle:
            return "Choose working style"
        case .workBlockers:
            return "Choose work blockers"
        case .weeklyOutcomes:
            return "Add weekly outcomes"
        case .processing:
            return "Preparing setup"
        case .firstTask:
            return "Add today's task"
        case .homeDemo:
            return "Try Home demo"
        case .focusRoom:
            return "Finish task"
        case .habitCheckIn:
            return "Check in habit"
        case .calendarPermission:
            return "Connect calendar"
        case .notificationPermission:
            return "Enable reminders"
        case .success:
            return "Setup complete"
        case .blocker, .projects, .habits:
            return normalizedForCurrentFlow.voiceOverTitle
        }
    }

    var voiceOverInstruction: String {
        switch normalizedForCurrentFlow {
        case .welcome:
            return "Start when you are ready."
        case .goal:
            return "Select one goal to continue."
        case .pain:
            return "Select at least one blocker."
        case .evaValue:
            return "Swipe the carousel and choose a guide."
        case .lifeAreas:
            return "Pick up to 3 areas."
        case .habitSetup:
            return "Select one starter habit."
        case .streakPreview:
            return "Review your starter streak."
        case .evaStyle:
            return "Choose how Eva should work."
        case .workBlockers:
            return "Choose blockers or add your own."
        case .weeklyOutcomes:
            return "Add at least one outcome."
        case .processing:
            return "Wait while LifeBoard prepares your setup."
        case .firstTask:
            return "Choose or create a task for today."
        case .homeDemo:
            return "Try the demo actions or continue when ready."
        case .focusRoom:
            return "Start focus or break the task down."
        case .habitCheckIn:
            return "Log today's habit status."
        case .calendarPermission:
            return "Allow or skip calendar access."
        case .notificationPermission:
            return "Allow or skip reminders."
        case .success:
            return "Go to Home."
        case .blocker, .projects, .habits:
            return normalizedForCurrentFlow.voiceOverInstruction
        }
    }
}
