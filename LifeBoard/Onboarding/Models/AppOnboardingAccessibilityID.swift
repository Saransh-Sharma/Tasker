import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum AppOnboardingAccessibilityID {
    static let flow = "onboarding.flow"
    static let progress = "onboarding.header.progress"
    static let backdropVideo = "onboarding.backdrop.video"
    static let backdropGrain = "onboarding.backdrop.grain"
    static let welcome = "onboarding.welcome"
    static let welcomeHeroVideo = "onboarding.welcome.heroVideo"
    static let welcomeVideoGrain = "onboarding.welcome.videoGrain"
    static let welcomeIntroOverlay = "onboarding.welcome.introOverlay"
    static let welcomeIntroTitleCard = "onboarding.welcome.introTitleCard"
    static let welcomeIntroContinue = "onboarding.welcome.introContinue"
    static let goal = "onboarding.goal"
    static let pain = "onboarding.pain"
    static let evaValue = "onboarding.evaValue"
    static let lifeAreas = "onboarding.lifeAreas"
    static let habitSetup = "onboarding.habitSetup"
    static let workStyle = "onboarding.workStyle"
    static let workBlockers = "onboarding.workBlockers"
    static let weeklyOutcomes = "onboarding.weeklyOutcomes"
    static let streakPreview = "onboarding.streakPreview"
    static let evaStyle = "onboarding.evaStyle"
    static let processing = "onboarding.processing"
    static let firstTask = "onboarding.firstTask"
    static let homeDemo = "onboarding.homeDemo"
    static let focusRoom = "onboarding.focusRoom"
    static let habitCheckIn = "onboarding.habitCheckIn"
    static let calendarPermission = "onboarding.calendarPermission"
    static let notificationPermission = "onboarding.notificationPermission"
    static let success = "onboarding.success"
    static let skipButton = "onboarding.skipButton"
    static let nextButton = "onboarding.cta.next"
    static let frictionHelper = "onboarding.friction.helper"
    static let useAreas = "onboarding.cta.useAreas"
    static let customHabit = "onboarding.cta.customHabit"
    static let customTask = "onboarding.cta.customTask"
    static let goFinishTask = "onboarding.cta.goFinishTask"
    static let focusPrimary = "onboarding.cta.focusPrimary"
    static let markComplete = "onboarding.cta.markComplete"
    static let startNow = "onboarding.cta.startNow"
    static let breakDown = "onboarding.cta.breakDown"
    static let goHome = "onboarding.cta.goHome"
    static let breakdownNext = "onboarding.cta.breakdownNext"
    static let prompt = "onboarding.prompt"
    static let promptStart = "onboarding.prompt.start"
    static let promptDismiss = "onboarding.prompt.dismiss"
    static let calendarPermissionHero = "onboarding.calendarPermission.hero"
    static let notificationPermissionHero = "onboarding.notificationPermission.hero"
    static let weeklyOutcomeAdd = "onboarding.weeklyOutcomes.add"
    static let homeDemoTimeline = "onboarding.homeDemo.timeline"
    static let homeDemoHabits = "onboarding.homeDemo.habits"
    static let primaryTaskAction = "onboarding.taskTemplate.primaryAction"

    static func lifeArea(_ id: String) -> String { "onboarding.lifeArea.\(id)" }
    static func primaryGoal(_ id: String) -> String { "onboarding.primaryGoal.\(id)" }
    static func workingStyle(_ id: String) -> String { "onboarding.workingStyle.\(id)" }
    static func momentumBlocker(_ id: String) -> String { "onboarding.momentumBlocker.\(id)" }
    static func taskTemplate(_ id: String) -> String { "onboarding.taskTemplate.\(id)" }
    static func habitTemplate(_ id: String) -> String { "onboarding.habitTemplate.\(id)" }
    static func mascotPersona(_ id: String) -> String { "onboarding.mascot.persona.\(id)" }
    static func weeklyOutcomeField(_ index: Int) -> String { "onboarding.weeklyOutcomes.field.\(index)" }
}
