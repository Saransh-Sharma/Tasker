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
        .welcome,
        .goal,
        .lifeAreas,
        .evaValue,
        .habitSetup,
        .firstTask,
        .homeDemo,
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
        case .pain, .blocker:
            return .goal
        case .projects:
            return .lifeAreas
        case .evaStyle, .workBlockers, .weeklyOutcomes:
            return .evaValue
        case .habits, .streakPreview:
            return .habitSetup
        case .processing:
            return .firstTask
        case .focusRoom, .habitCheckIn:
            return .homeDemo
        case .calendarPermission, .notificationPermission:
            return .success
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
        case .evaValue:
            return "Choose assistant"
        case .lifeAreas:
            return "Choose focus areas"
        case .habitSetup:
            return "Create starter habit"
        case .firstTask:
            return "Create first task"
        case .homeDemo:
            return "Preview Home"
        case .success:
            return "Setup complete"
        case .pain, .blocker, .projects, .habits, .streakPreview, .evaStyle, .workBlockers, .weeklyOutcomes, .processing, .focusRoom, .habitCheckIn, .calendarPermission, .notificationPermission:
            return normalizedForCurrentFlow.voiceOverTitle
        }
    }

    var voiceOverInstruction: String {
        switch normalizedForCurrentFlow {
        case .welcome:
            return "Start when you are ready."
        case .goal:
            return "Select one goal to continue."
        case .evaValue:
            return "Choose how the assistant should support your day."
        case .lifeAreas:
            return "Pick up to 3 areas."
        case .habitSetup:
            return "Select one starter habit."
        case .firstTask:
            return "Choose or create a task for today."
        case .homeDemo:
            return "Review the Home preview or continue when ready."
        case .success:
            return "Go to Home."
        case .pain, .blocker, .projects, .habits, .streakPreview, .evaStyle, .workBlockers, .weeklyOutcomes, .processing, .focusRoom, .habitCheckIn, .calendarPermission, .notificationPermission:
            return normalizedForCurrentFlow.voiceOverInstruction
        }
    }
}
