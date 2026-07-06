import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

/// Per-step Sunrise Glass accents: pastel role washes with deep semantic
/// accents. The CTA is always the violet primary action per the design
/// language; only the welcome step keeps a dark on-video treatment.
struct OnboardingStepVisualTheme: Equatable {
    let id: String
    let backdrop: Color
    let accent: Color
    let next: Color
    let nextForeground: Color

    static func == (lhs: OnboardingStepVisualTheme, rhs: OnboardingStepVisualTheme) -> Bool {
        lhs.id == rhs.id
    }

    private static let primaryCTA = "#6842FF"
    private static let ctaForeground = "#FFFFFF"

    static func theme(for step: OnboardingStep) -> OnboardingStepVisualTheme {
        switch step.normalizedForCurrentFlow {
        case .welcome:
            return theme(id: "welcome", backdrop: "#101827", accent: "#F4C95D", next: "#F4C95D", nextForeground: "#101827")
        case .goal:
            return sunriseTheme(id: "goal", backdrop: "#EAF6FF", accent: "#1266D6")
        case .pain:
            return sunriseTheme(id: "pain", backdrop: "#FFE3EE", accent: "#D92772")
        case .evaValue:
            return sunriseTheme(id: "eva-value", backdrop: "#F6F2FF", accent: "#4F2CFF")
        case .lifeAreas:
            return sunriseTheme(id: "life-areas", backdrop: "#F5F0FF", accent: "#5D2CC6")
        case .habitSetup, .streakPreview, .habitCheckIn:
            return sunriseTheme(id: "habit", backdrop: "#EFF9EC", accent: "#15952B")
        case .evaStyle, .workBlockers, .weeklyOutcomes:
            return sunriseTheme(id: "eva-style", backdrop: "#EEE3FF", accent: "#7332C9")
        case .processing:
            return sunriseTheme(id: "processing", backdrop: "#EAF6FF", accent: "#1266D6")
        case .firstTask, .focusRoom, .homeDemo:
            return sunriseTheme(id: "demo", backdrop: "#FFF1E9", accent: "#C74716")
        case .calendarPermission:
            return sunriseTheme(id: "calendar", backdrop: "#F4F0FF", accent: "#5230F3")
        case .notificationPermission:
            return sunriseTheme(id: "notifications", backdrop: "#FFF7DF", accent: "#D88900")
        case .success:
            return sunriseTheme(id: "success", backdrop: "#EFF9EC", accent: "#15952B")
        case .blocker, .projects, .habits:
            return theme(for: step.normalizedForCurrentFlow)
        }
    }

    static func sunriseTheme(id: String, backdrop: String, accent: String) -> OnboardingStepVisualTheme {
        theme(id: id, backdrop: backdrop, accent: accent, next: primaryCTA, nextForeground: ctaForeground)
    }

    static func theme(id: String, backdrop: String, accent: String, next: String, nextForeground: String) -> OnboardingStepVisualTheme {
        OnboardingStepVisualTheme(
            id: id,
            backdrop: Color(uiColor: UIColor(lifeboardHex: backdrop)),
            accent: Color(uiColor: UIColor(lifeboardHex: accent)),
            next: Color(uiColor: UIColor(lifeboardHex: next)),
            nextForeground: Color(uiColor: UIColor(lifeboardHex: nextForeground))
        )
    }
}
