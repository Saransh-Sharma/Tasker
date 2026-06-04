import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingStepVisualTheme: Equatable {
    let id: String
    let backdrop: Color
    let accent: Color
    let next: Color
    let nextForeground: Color

    static func == (lhs: OnboardingStepVisualTheme, rhs: OnboardingStepVisualTheme) -> Bool {
        lhs.id == rhs.id
    }

    static func theme(for step: OnboardingStep) -> OnboardingStepVisualTheme {
        switch step.normalizedForCurrentFlow {
        case .welcome:
            return theme(id: "welcome", backdrop: "#101827", accent: "#F4C95D", next: "#F4C95D", nextForeground: "#101827")
        case .goal:
            return theme(id: "goal", backdrop: "#122B48", accent: "#4FB3FF", next: "#4FB3FF", nextForeground: "#07121F")
        case .pain:
            return theme(id: "pain", backdrop: "#3A1833", accent: "#FF7AA8", next: "#FF7AA8", nextForeground: "#230817")
        case .evaValue:
            return theme(id: "eva-value", backdrop: "#14352D", accent: "#5FE2B8", next: "#5FE2B8", nextForeground: "#082018")
        case .lifeAreas:
            return theme(id: "life-areas", backdrop: "#2E2559", accent: "#B8A7FF", next: "#B8A7FF", nextForeground: "#16102F")
        case .habitSetup, .streakPreview, .habitCheckIn:
            return theme(id: "habit", backdrop: "#173B25", accent: "#8FEA8B", next: "#8FEA8B", nextForeground: "#071B0E")
        case .evaStyle, .workBlockers, .weeklyOutcomes:
            return theme(id: "eva-style", backdrop: "#38213F", accent: "#DFA7FF", next: "#DFA7FF", nextForeground: "#1D0928")
        case .processing:
            return theme(id: "processing", backdrop: "#153544", accent: "#77D6F4", next: "#77D6F4", nextForeground: "#08202B")
        case .firstTask, .focusRoom, .homeDemo:
            return theme(id: "demo", backdrop: "#402713", accent: "#FFBA6A", next: "#FFBA6A", nextForeground: "#261103")
        case .calendarPermission:
            return theme(id: "calendar", backdrop: "#11345B", accent: "#7EC8FF", next: "#7EC8FF", nextForeground: "#061B31")
        case .notificationPermission:
            return theme(id: "notifications", backdrop: "#3B244A", accent: "#F8A9FF", next: "#F8A9FF", nextForeground: "#210A2B")
        case .success:
            return theme(id: "success", backdrop: "#163A2A", accent: "#9BF3BE", next: "#9BF3BE", nextForeground: "#061A10")
        case .blocker, .projects, .habits:
            return theme(for: step.normalizedForCurrentFlow)
        }
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
