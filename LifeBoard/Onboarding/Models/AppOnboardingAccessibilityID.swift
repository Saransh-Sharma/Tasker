import Foundation

/// Accessibility identifiers for the guided setup.
///
/// Kept in step with the nine live steps — the previous list still named a
/// backdrop video, a friction helper, a focus room, and a processing screen,
/// none of which existed any more.
enum AppOnboardingAccessibilityID {
    static let flow = "onboarding.flow"
    static let progress = "onboarding.header.progress"
    static let welcome = "onboarding.welcome"
    static let welcomeIntroOverlay = "onboarding.welcome.introOverlay"
    static let welcomeIntroTitleCard = "onboarding.welcome.introTitleCard"
    static let welcomeIntroContinue = "onboarding.welcome.introContinue"

    // Steps, in flow order.
    static let goal = "onboarding.goal"
    static let lifeAreas = "onboarding.lifeAreas"
    static let evaValue = "onboarding.evaValue"
    static let dayShape = "onboarding.dayShape"
    static let modules = "onboarding.modules"
    static let habitSetup = "onboarding.habitSetup"
    static let permissions = "onboarding.permissions"
    static let success = "onboarding.success"

    // Controls.
    static let skipButton = "onboarding.skipButton"
    static let nextButton = "onboarding.cta.next"
    static let useAreas = "onboarding.cta.useAreas"
    static let customHabit = "onboarding.cta.customHabit"
    static let customTask = "onboarding.cta.customTask"
    static let goFinishTask = "onboarding.cta.goFinishTask"
    static let goHome = "onboarding.cta.goHome"
    static let breakdownNext = "onboarding.cta.askGuide"
    static let worksWeekends = "onboarding.dayShape.worksWeekends"
    static let weekStartsOn = "onboarding.dayShape.weekStartsOn"
    static let primaryTaskAction = "onboarding.taskTemplate.primaryAction"

    // Re-entry prompt.
    static let prompt = "onboarding.prompt"
    static let promptStart = "onboarding.prompt.start"
    static let promptDismiss = "onboarding.prompt.dismiss"

    static func lifeArea(_ id: String) -> String { "onboarding.lifeArea.\(id)" }
    static func primaryGoal(_ id: String) -> String { "onboarding.primaryGoal.\(id)" }
    static func module(_ id: String) -> String { "onboarding.module.\(id)" }
    static func permission(_ id: String) -> String { "onboarding.permission.\(id)" }
    static func taskTemplate(_ id: String) -> String { "onboarding.taskTemplate.\(id)" }
    static func habitTemplate(_ id: String) -> String { "onboarding.habitTemplate.\(id)" }
    static func mascotPersona(_ id: String) -> String { "onboarding.mascot.persona.\(id)" }
}
