import Foundation

/// The guided setup, in order.
///
/// Nine steps, each of which changes something real. The previous enum carried
/// twenty-two cases of which thirteen were unreachable — kept only so old
/// journey snapshots could decode — plus a normalisation table that quietly
/// remapped them. `AppOnboardingState.currentVersion` now invalidates those
/// snapshots outright, so the cases are gone and the raw values are contiguous
/// again. `OnboardingJourneySnapshot` decodes anything it does not recognise as
/// `.welcome` rather than throwing.
enum OnboardingStep: Int, CaseIterable, Codable {
    case welcome = 0
    case intent = 1
    case lifeAreas = 2
    case guide = 3
    case dayShape = 4
    case modules = 5
    case firstWin = 6
    case permissions = 7
    case success = 8

    static let orderedFlow: [OnboardingStep] = [
        .welcome,
        .intent,
        .lifeAreas,
        .guide,
        .dayShape,
        .modules,
        .firstWin,
        .permissions,
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
        case .welcome: return "Setup"
        case .intent: return "Focus"
        case .lifeAreas: return "Areas"
        case .guide: return "Guide"
        case .dayShape: return "Your day"
        case .modules: return "Tracking"
        case .firstWin: return "Start"
        case .permissions: return "Access"
        case .success: return "Ready"
        }
    }

    var accessibilitySummary: String {
        OnboardingCopy.Header.accessibilitySummary(for: self)
    }

    var evaMascotPlacement: EvaMascotPlacement {
        switch self {
        case .welcome: return .onboardingWelcome
        case .intent: return .onboardingNextStep
        case .lifeAreas, .modules: return .onboardingCaptureSetup
        case .guide: return .onboardingEvaValue
        case .dayShape: return .onboardingCalendarPermission
        case .firstWin: return .habitStreakWin
        case .permissions: return .onboardingNotificationPermission
        case .success: return .onboardingSuccess
        }
    }

    var voiceOverTitle: String {
        switch self {
        case .welcome: return "Welcome"
        case .intent: return "Choose what needs attention"
        case .lifeAreas: return "Choose focus areas"
        case .guide: return "Choose your guide"
        case .dayShape: return "Set your day"
        case .modules: return "Choose what to track"
        case .firstWin: return "Add a habit and a task"
        case .permissions: return "Choose what LifeBoard can use"
        case .success: return "Setup complete"
        }
    }

    var voiceOverInstruction: String {
        switch self {
        case .welcome: return "Start when you are ready."
        case .intent: return "Select one to continue."
        case .lifeAreas: return "Pick up to three."
        case .guide: return "Choose a guide to continue."
        case .dayShape: return "Adjust your hours, or continue to accept them."
        case .modules: return "Select anything you want to track. You can change this later."
        case .firstWin: return "Choose a habit and a task for today."
        case .permissions: return "Allow each one, or skip and decide later."
        case .success: return "Go to Home."
        }
    }
}
