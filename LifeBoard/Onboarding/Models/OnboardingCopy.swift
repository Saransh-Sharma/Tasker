import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingCopy {
    enum Welcome {
        static let primaryCTA = String(localized: "Start setup")
        static let setupChip = String(localized: "Guided setup")
        static let durationChip = String(localized: "~2 min")
        static let changeLaterChip = String(localized: "Change this later")
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

    enum Goal {
        static let title = String(localized: "What needs attention first?")
        static let subtitle = String(localized: "LifeBoard will shape your setup around this priority.")
        static let cta = String(localized: "Choose goal")
    }

    enum Pain {
        static let title = String(localized: "What gets in the way?")
        static let subtitle = String(localized: "Pick the patterns LifeBoard should help you manage.")
        static let cta = String(localized: "Choose blockers")
    }

    enum EvaValue {
        static let title = String(localized: "Pick your guide")
        static let subtitle = String(localized: "Choose the mascot that will guide your day, habits, and priorities.")
        static let cta = String(localized: "Choose guide")
    }

    enum LifeAreas {
        static let title = String(localized: "Choose focus areas")
        static let subtitle = String(localized: "Pick up to 3 areas to start.")
        static let cta = String(localized: "Use areas")
        static let helper = String(localized: "You can edit these later.")
    }

    enum HabitSetup {
        static let title = String(localized: "Pick one habit")
        static let subtitle = String(localized: "Start with a routine you want visible on Home.")
        static let cta = String(localized: "Set habit")
    }

    enum Streak {
        static let title = String(localized: "Preview your streak")
        static let subtitle = String(localized: "Your board starts today. No fake history.")
        static let cta = String(localized: "Continue")
    }

    enum EvaStyle {
        static let title = String(localized: "How do you work best?")
        static let subtitle = String(localized: "Pick the style Eva should respect.")
        static let blockerTitle = String(localized: "Work blockers")
        static let cta = String(localized: "Save style")
    }

    enum WorkBlockers {
        static let title = String(localized: "What blocks your work?")
        static let subtitle = String(localized: "Choose the patterns Eva should watch for.")
        static let cta = String(localized: "Save blockers")
    }

    enum WeeklyOutcomes {
        static let title = String(localized: "This week, I want to…")
        static let subtitle = String(localized: "Name the outcomes worth protecting this week.")
        static let cta = String(localized: "Save outcomes")
    }

    enum Processing {
        static let title = String(localized: "Preparing your setup")
        static let subtitle = String(localized: "LifeBoard is creating your areas, habit, and first task.")
    }

    enum FirstTask {
        static let title = String(localized: "Add a task for today")
        static let subtitle = String(localized: "Pick a suggestion or create the exact task you want to move.")
        static let ctaReady = String(localized: "Use task")
        static let ctaMissing = String(localized: "Choose task")
    }

    enum HomeDemo {
        static let title = String(localized: "Try your day")
        static let subtitle = String(localized: "Try the demo actions or continue when you’re ready.")
        static let cta = String(localized: "Continue")
    }

    enum Focus {
        static let title = String(localized: "Finish this task")
        static let subtitle = String(localized: "Start now or break it into smaller steps.")
        static let startCTA = String(localized: "Start focus")
        static let completeCTA = String(localized: "Mark complete")
        static let breakDownCTA = String(localized: "Break into steps")
    }

    enum HabitCheckIn {
        static let title = String(localized: "Check in today")
        static let subtitle = String(localized: "Log today so the habit appears on Home.")
    }

    enum Calendar {
        static let title = String(localized: "Connect calendar")
        static let subtitle = String(localized: "Full calendar access lets LifeBoard read your schedule and fit tasks around your day.")
        static let cta = String(localized: "Allow Full Calendar Access")
    }

    enum Notifications {
        static let title = String(localized: "Enable reminders")
        static let subtitle = String(localized: "Get timely reminders for your task and starter habit.")
        static let cta = String(localized: "Allow reminders")
    }

    enum Success {
        static let title = String(localized: "Setup is ready")
        static let subtitle = String(localized: "Your guide, habit, task, and day view are ready.")
        static let goHomeCTA = String(localized: "Go to Home")
        static let nextCTA = String(localized: "Ask assistant")
    }

    enum Error {
        static let chooseGoal = String(localized: "Choose one goal to continue.")
        static let choosePain = String(localized: "Choose at least one blocker.")
        static let chooseAreas = String(localized: "Pick 1 to 3 areas to continue.")
        static let chooseHabit = String(localized: "Pick one habit to continue.")
        static let chooseEvaPreference = String(localized: "Choose at least one assistant preference.")
        static let firstTaskMissing = String(localized: "LifeBoard could not prepare your first task.")
        static let starterTaskFailed = String(localized: "LifeBoard could not create a starter task. Try again.")
        static let customTaskFailed = String(localized: "LifeBoard could not open the task composer. Try again.")
        static let customHabitFailed = String(localized: "LifeBoard could not open the habit composer. Try again.")
    }

    static let regressionPhrases = [
        "momentum",
        "first win",
        "background stress",
        "chief of staff",
        "Relief first",
        "Get your days back under control",
        "Assistant gets ready in the background"
    ]

    static let reviewedStrings: [String] = [
        Welcome.primaryCTA,
        Welcome.setupChip,
        Welcome.changeLaterChip,
        Goal.title,
        Goal.subtitle,
        Goal.cta,
        Pain.title,
        Pain.subtitle,
        Pain.cta,
        EvaValue.title,
        EvaValue.subtitle,
        EvaValue.cta,
        LifeAreas.title,
        LifeAreas.subtitle,
        LifeAreas.cta,
        LifeAreas.helper,
        HabitSetup.title,
        HabitSetup.subtitle,
        HabitSetup.cta,
        Streak.title,
        Streak.subtitle,
        EvaStyle.title,
        EvaStyle.subtitle,
        EvaStyle.blockerTitle,
        EvaStyle.cta,
        WorkBlockers.title,
        WorkBlockers.subtitle,
        WorkBlockers.cta,
        WeeklyOutcomes.title,
        WeeklyOutcomes.subtitle,
        WeeklyOutcomes.cta,
        Processing.title,
        Processing.subtitle,
        FirstTask.title,
        FirstTask.subtitle,
        FirstTask.ctaReady,
        FirstTask.ctaMissing,
        HomeDemo.title,
        HomeDemo.subtitle,
        HomeDemo.cta,
        Focus.title,
        Focus.subtitle,
        Focus.breakDownCTA,
        HabitCheckIn.title,
        HabitCheckIn.subtitle,
        Calendar.title,
        Calendar.subtitle,
        Calendar.cta,
        Notifications.title,
        Notifications.subtitle,
        Notifications.cta,
        Success.title,
        Success.subtitle,
        Success.nextCTA
    ]
}
