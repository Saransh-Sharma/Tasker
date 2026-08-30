import Foundation

/// Which of a screen's candidate actions is *the* primary one.
///
/// This was `CTABezelResolver`, living inside `LifeBoardCTABezel.swift`. The
/// bezel was a liquid-metal treatment for primary actions — a sixth material in
/// a system whose elevation model has five planes, none of them metal — and it
/// has been removed. The resolver is not a visual concern at all: it reads
/// feature state and answers which action should be highlighted, which is the
/// half worth keeping, and it has its own tests.

enum PrimaryActionResolver {
    static func highlightedOnboardingTemplateID(
        primarySuggestionIDs: [String],
        taskTemplateStates: [String: OnboardingTaskTemplateState]
    ) -> String? {
        for templateID in primarySuggestionIDs {
            switch taskTemplateStates[templateID] ?? .idle {
            case .created:
                continue
            case .idle, .creating, .failed:
                return templateID
            }
        }
        return nil
    }

    static func dailySummaryPrimaryCTAIdentifier(for summary: DailySummaryModalData) -> String {
        switch summary {
        case .morning:
            return "home.dailySummary.cta.startToday"
        case .nightly:
            return "home.dailySummary.cta.planTomorrow"
        }
    }
}
