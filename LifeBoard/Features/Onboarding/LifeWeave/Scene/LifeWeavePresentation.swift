import Foundation
import LifeBoardDomain
import LifeBoardTokens

/// One area, as the map needs to draw it.
struct LifeWeaveAreaPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    /// `nil` only for a user-created custom area, which keeps its stored hex.
    let accentRole: LifeAreaAccentRole?
    let fallbackColorHex: String
    let isPrimary: Bool
}

/// One of the five operating strands.
///
/// A strand is *structure*, not a label. Through the whole of setup these are
/// faint unlabelled geometry, and `showsLabels` is false until the reveal.
///
/// That restraint is the entire reconciliation of this design. The five roots
/// and the user's life areas answer different questions — the roots are how you
/// operate on a life, the areas are the life — and drawing them as labelled
/// peers on the same diagram was the single clearest defect in the old orbit.
/// Keeping the strands present but unnamed lets the map be a weave rather than a
/// constellation of unrelated points, without telling a first-time user that
/// "Insights" is a part of their life alongside "Health".
struct LifeWeaveStrandPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    /// Raised slightly when the user's intent makes this strand relevant.
    let emphasis: Double
}

/// The window the day arc describes, normalised to a 24-hour span.
struct LifeWeaveDayWindow: Equatable {
    let start: Double
    let end: Double

    init?(dayShape: OnboardingDayShapeDraft) {
        let start = Double(dayShape.weekdayStartMinute) / (24 * 60)
        let end = Double(dayShape.weekdayEndMinute) / (24 * 60)
        guard end > start else { return nil }
        self.start = min(max(0, start), 1)
        self.end = min(max(0, end), 1)
    }
}

/// Everything the canvas draws, and nothing it decides.
///
/// The canvas receives this and owns no onboarding state, which is what makes
/// the map testable and its geometry a pure function. Node coordinates are
/// deliberately **not** here and are never persisted: position is derived from
/// size, count, primary, layout direction and Dynamic Type at draw time, so the
/// user's stored data stays semantic rather than graphical.
struct LifeWeavePresentation: Equatable {
    var strands: [LifeWeaveStrandPresentation]
    var areas: [LifeWeaveAreaPresentation]
    var dayWindow: LifeWeaveDayWindow?
    /// The first capture, once it exists. It travels to its area only after the
    /// record is persisted — success motion never runs ahead of the write.
    var capturedObjectTitle: String?
    var capturedObjectAreaID: String?
    var phase: LifeWeaveStep

    /// Labels are the reveal's privilege. See `LifeWeaveStrandPresentation`.
    var showsStrandLabels: Bool { phase == .reveal }

    static func make(from draft: LifeWeaveDraft) -> LifeWeavePresentation {
        let templates = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }
        }
        let areas = templates.map { template in
            LifeWeaveAreaPresentation(
                id: template.id,
                title: template.name,
                symbol: template.icon,
                accentRole: LifeAreaAccentRole(lifeAreaTemplateID: template.id),
                fallbackColorHex: template.colorHex,
                isPrimary: template.id == draft.primaryLifeAreaTemplateID
            )
        }
        return LifeWeavePresentation(
            strands: strands(emphasising: draft.intent),
            areas: areas,
            dayWindow: draft.step.rawValue >= LifeWeaveStep.dayShape.rawValue
                ? LifeWeaveDayWindow(dayShape: draft.dayShape)
                : nil,
            capturedObjectTitle: draft.stagedCapture?.text,
            capturedObjectAreaID: draft.stagedCapture?.lifeAreaTemplateID,
            phase: draft.step
        )
    }

    /// The five strands, derived from `Destination`.
    ///
    /// Derived rather than transcribed: the old orbit kept its own hardcoded
    /// copy of the five roots and zipped it positionally against
    /// `Destination.allCases`, and the two had already drifted — different
    /// symbols and a different spelling of Eva's name — with nothing asserting
    /// the counts even matched.
    private static func strands(emphasising intent: LifeWeaveIntent?) -> [LifeWeaveStrandPresentation] {
        Destination.allCases.map { destination in
            LifeWeaveStrandPresentation(
                id: destination.rawValue,
                title: destination.title,
                symbol: destination.systemImage,
                emphasis: emphasis(for: destination, intent: intent)
            )
        }
    }

    /// A quiet acknowledgement that the user's answer changed something.
    ///
    /// Bounded to a narrow range on purpose: this is a hairline getting slightly
    /// more definite, not a strand growing. Weight here must never read as "this
    /// part of the app matters more", which is a claim the product does not make.
    private static func emphasis(for destination: Destination, intent: LifeWeaveIntent?) -> Double {
        guard let intent else { return 1 }
        let raised: Destination? = switch intent {
        case .clarityToday: .home
        case .reduceMentalLoad: .home
        case .resilientPlanning: .plan
        case .steadyRoutines: .track
        case .wholeLifeView: .insights
        case .somethingElse: nil
        }
        return destination == raised ? 1.35 : 1
    }

    /// What VoiceOver hears instead of the geometry.
    ///
    /// The map is decorative to assistive technology — the selectable rows below
    /// it already carry every actionable state — so it publishes one sentence
    /// rather than exploding a dozen paths into the accessibility tree.
    var accessibilitySummary: String {
        guard areas.isEmpty == false else {
            return "Your Life Map. No areas chosen yet."
        }
        let names = areas.map(\.title)
        var sentence = "Your Life Map. "
            + onboardingNaturalLanguageList(names, fallback: "no areas yet")
        if let primary = areas.first(where: \.isPrimary) {
            sentence += ". \(primary.title) is currently first"
        }
        if capturedObjectTitle != nil {
            sentence += ". One thing has been captured"
        }
        return sentence + "."
    }
}
