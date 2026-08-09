import SwiftUI

/// The per-step accent wash behind the guided setup.
///
/// This used to hold twenty-two hand-picked hex pairs — a second, parallel colour
/// system that knew nothing about the daypart palette or the semantic roles every
/// other screen resolves through. It now derives everything from the canonical
/// tokens, so onboarding inherits the same warmth, the same dark-mode behaviour,
/// and the same contrast guarantees as the rest of the app.
struct OnboardingStepVisualTheme: Equatable {
    let id: String
    let backdrop: Color
    let accent: Color
    let next: Color
    let nextForeground: Color

    static func == (lhs: OnboardingStepVisualTheme, rhs: OnboardingStepVisualTheme) -> Bool {
        lhs.id == rhs.id
    }

    /// Steps are grouped by what they ask for, not decorated individually — the
    /// wash should mark a change of subject, not flicker on every screen.
    static func theme(for step: OnboardingStep) -> OnboardingStepVisualTheme {
        switch step {
        case .welcome:
            return make(id: "welcome", role: .brandHighlight)
        case .intent, .lifeAreas:
            return make(id: "orient", role: .accentSecondary)
        case .guide:
            return make(id: "guide", role: .brandPrimary)
        case .dayShape, .modules:
            return make(id: "shape", role: .accentPrimary)
        case .firstWin:
            return make(id: "start", role: .statusSuccess)
        case .permissions:
            return make(id: "access", role: .brandSecondary)
        case .success:
            return make(id: "success", role: .statusSuccess)
        }
    }

    private static func make(id: String, role: ColorRole) -> OnboardingStepVisualTheme {
        OnboardingStepVisualTheme(
            id: id,
            // A wash, not a fill: the daypart atmosphere stays readable behind it.
            backdrop: Color.lifeboard(role).opacity(0.10),
            accent: Color.lifeboard(role),
            next: Color.lifeboard(.actionPrimary),
            nextForeground: Color.lifeboard(.onAccent, on: .accent)
        )
    }
}
