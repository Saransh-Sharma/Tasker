import Foundation

/// Every user-facing string in the guided setup.
///
/// One surface on purpose: the journey views used to carry dozens of bare
/// literals alongside this file, which is how the Calendar screen ended up
/// stating its reason twice and "change this later" ended up promised in two
/// places. Copy rules here: a short heading, at most one supporting line, a
/// verb-first button, and nothing that explains how the product thinks.
enum OnboardingCopy {
    enum Welcome {
        static let title = String(localized: "Welcome to LifeBoard")
        static let primaryCTA = String(localized: "Start")
        static let durationChip = String(localized: "2 minutes")
        static let changeLaterChip = String(localized: "Change anything later")
    }

    enum Header {
        static func accessibilitySummary(for step: OnboardingStep) -> String {
            guard let progress = OnboardingProgress(step: step) else {
                return String(localized: "Setup screen.")
            }
            return String(
                localized: "\(step.voiceOverTitle). \(progress.label). \(step.voiceOverInstruction)"
            )
        }
    }

    enum Intent {
        static let title = String(localized: "What needs attention?")
        static let cta = String(localized: "Continue")
    }

    enum LifeAreas {
        static let title = String(localized: "Choose your areas")
        static let subtitle = String(localized: "Up to three.")
        static let cta = String(localized: "Continue")
        static let showMore = String(localized: "More areas")
    }

    enum Guide {
        static let title = String(localized: "Pick your guide")
        static let cta = String(localized: "Continue")
    }

    enum DayShape {
        static let title = String(localized: "When are you usually on?")
        static let subtitle = String(localized: "Plans are built to fit these hours.")
        static let weekdays = String(localized: "Weekdays")
        static let weekends = String(localized: "Weekends")
        static let worksWeekends = String(localized: "Weekends too")
        static let weekStarts = String(localized: "Week starts")
        static let cta = String(localized: "Continue")
    }

    enum Modules {
        static let title = String(localized: "What do you want to track?")
        static let subtitle = String(localized: "Pick any. Add more later.")
        static let cta = String(localized: "Continue")
    }

    enum FirstWin {
        static let title = String(localized: "Pick a habit and a task")
        static let habitHeading = String(localized: "A habit")
        static let taskHeading = String(localized: "Something for today")
        static let customHabit = String(localized: "Write your own")
        static let customTask = String(localized: "Write your own")
        static let cta = String(localized: "Continue")
    }

    enum Permissions {
        static let title = String(localized: "What LifeBoard can use")
        static let subtitle = String(localized: "Allow what you want. Skip the rest.")
        static let allow = String(localized: "Allow")
        static let allowed = String(localized: "Allowed")
        static let skip = String(localized: "Not now")
        static let atFirstUse = String(localized: "Asked the first time you use it.")
        static let cta = String(localized: "Continue")
    }

    enum Success {
        static let title = String(localized: "You’re set")
        static let inPlace = String(localized: "In place")
        static let goHomeCTA = String(localized: "Go to Home")
        static let nextCTA = String(localized: "Ask your guide")
    }

    enum Error {
        static let chooseGoal = String(localized: "Choose one to continue.")
        static let chooseAreas = String(localized: "Pick one to three areas.")
        static let chooseHabit = String(localized: "Pick a habit to continue.")
        static let firstTaskMissing = String(localized: "Couldn’t prepare your task.")
        static let starterTaskFailed = String(localized: "Couldn’t create that task. Try again.")
        static let customTaskFailed = String(localized: "Couldn’t open the task composer. Try again.")
        static let customHabitFailed = String(localized: "Couldn’t open the habit composer. Try again.")
    }

    /// Phrases a previous copy pass banned and this one keeps banned. The list is
    /// asserted against `reviewedStrings`, so a regression fails the test rather
    /// than shipping.
    static let regressionPhrases = [
        "momentum",
        "first win",
        "background stress",
        "chief of staff",
        "Relief first",
        "Get your days back under control",
        "Assistant gets ready in the background",
        // Added this pass: hedging and product-philosophy tics that made the old
        // copy read as reassurance rather than instruction.
        "when you’re ready",
        "when you are ready",
        "helps you",
        "lets you",
        "without judgment",
        "no penalty"
    ]

    static let reviewedStrings: [String] = [
        Welcome.title,
        Welcome.primaryCTA,
        Welcome.durationChip,
        Welcome.changeLaterChip,
        Intent.title,
        Intent.cta,
        LifeAreas.title,
        LifeAreas.subtitle,
        LifeAreas.cta,
        LifeAreas.showMore,
        Guide.title,
        Guide.cta,
        DayShape.title,
        DayShape.subtitle,
        DayShape.weekdays,
        DayShape.weekends,
        DayShape.worksWeekends,
        DayShape.weekStarts,
        DayShape.cta,
        Modules.title,
        Modules.subtitle,
        Modules.cta,
        FirstWin.title,
        FirstWin.habitHeading,
        FirstWin.taskHeading,
        FirstWin.customHabit,
        FirstWin.customTask,
        FirstWin.cta,
        Permissions.title,
        Permissions.subtitle,
        Permissions.allow,
        Permissions.allowed,
        Permissions.skip,
        Permissions.atFirstUse,
        Permissions.cta,
        Success.title,
        Success.inPlace,
        Success.goHomeCTA,
        Success.nextCTA,
        Error.chooseGoal,
        Error.chooseAreas,
        Error.chooseHabit,
        Error.firstTaskMissing,
        Error.starterTaskFailed,
        Error.customTaskFailed,
        Error.customHabitFailed
    ]
}
