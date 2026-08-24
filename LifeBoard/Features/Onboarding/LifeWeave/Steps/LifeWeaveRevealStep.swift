import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The personalised sentence, built from templates.
///
/// Deliberately not generated. Core completion must not depend on a model being
/// available, on a network, or on an account — and making the emotional high
/// point of the first run the one thing that can fail offline would be a strange
/// place to spend that dependency. Templates also mean the sentence is testable
/// and says the same thing twice.
enum LifeWeaveRevealCopy {

    /// Names what the user actually chose, in their own terms.
    static func sentence(for draft: LifeWeaveDraft) -> String {
        let names = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }?.name
        }
        guard let primary = names.first else {
            return "Your map is ready to grow whenever you are."
        }
        let rest = Array(names.dropFirst())

        if rest.isEmpty {
            return "\(primary) has the clearest path."
        }
        let others = onboardingNaturalLanguageList(rest, fallback: "the rest")
        // One other area takes a singular verb. The sentence is the emotional
        // high point of the first run; "Health & Self stay in view" reads as a
        // template that was not written for this person.
        let verb = rest.count == 1 ? "stays" : "stay"
        return "\(primary) gets the clearest path. \(others) \(verb) in view without competing for today."
    }

    /// One line about what the user said they wanted, phrased as a promise the
    /// product can actually keep.
    static func intentLine(for intent: LifeWeaveIntent?) -> String? {
        switch intent {
        case .clarityToday: "The next useful thing will be waiting on Home."
        case .reduceMentalLoad: "LifeBoard is ready to hold the loose ends so you don't have to."
        case .resilientPlanning: "Your plan now has room to change without becoming a failed plan."
        // Matches the product's position that missing evidence is not failure —
        // Track deliberately does not moralise about a skipped day.
        case .steadyRoutines: "Your routines can stay visible without becoming another score to protect."
        case .wholeLifeView: "Work, health, and the rest can meet in one place without becoming one list."
        case .somethingElse, .none: nil
        }
    }

    /// The receipt. Facts only, and only facts that are true.
    static func receipt(for draft: LifeWeaveDraft) -> [String] {
        var parts: [String] = []
        let count = draft.orderedLifeAreaTemplateIDs.count
        parts.append("\(count) life area\(count == 1 ? "" : "s")")

        let start = OnboardingDayShapeDraft.label(forMinute: draft.dayShape.weekdayStartMinute)
        let end = OnboardingDayShapeDraft.label(forMinute: draft.dayShape.weekdayEndMinute)
        parts.append("Weekdays \(start)–\(end)")

        // Only claimed when something was actually reviewed and written. A
        // skipped capture is an honest empty state, never dressed up.
        if draft.stagedCapture?.isReviewed == true {
            parts.append("1 thing captured")
        }
        return parts
    }
}

/// The payoff.
///
/// Reward and invitation, nothing else. This screen used to carry Cloud EVA's
/// disclosure, four protected-context toggles, a progress spinner, an error
/// line, and an offline escape hatch — so the emotional high point of the first
/// run was buried under infrastructure the user had no reason to read yet, and
/// the dominant action ran a network call that could fail on the last screen of
/// setup. All of it moved into the optional Power-Up phase, which begins only
/// after this LifeBoard is committed and recorded as complete.
struct LifeWeaveRevealStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    private var draft: LifeWeaveDraft { model.draft }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LifeMapEyebrow("READY")
            Text("Your LifeBoard is ready.")
                .lifeboardFont(.screenTitle)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            Text(LifeWeaveRevealCopy.sentence(for: draft))
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if let intentLine = LifeWeaveRevealCopy.intentLine(for: draft.intent) {
                Text(intentLine)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            receipt

            if model.isPowerUpAvailable {
                powerUpInvitation
            }

            if draft.stagedCapture?.isReviewed != true {
                Text("Start with an empty day. Add something whenever it becomes useful.")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Names the second phase, its cost, and that it is optional — before the
    /// user commits attention to it. Three plain rows, no toggles: the decision
    /// here is only "do I want to spend another minute", and every consent
    /// question belongs to the connector that actually needs it.
    private var powerUpInvitation: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            LifeMapEyebrow("POWER UP · OPTIONAL, ABOUT A MINUTE")
            Text("Bring your real world in.")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            HStack(spacing: Theme.Spacing.md) {
                ForEach(LifeWeavePowerUpStep.connectors) { connector in
                    HStack(spacing: 6) {
                        Image(systemName: Self.symbolName(for: connector))
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                            .accessibilityHidden(true)
                        Text(connector.spokenName)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
            }
            Text("Your LifeBoard is already saved. You can add these now or any time from Settings.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.lifeweave.reveal.powerUpInvitation")
    }

    private static func symbolName(for connector: LifeWeavePowerUpStep) -> String {
        switch connector {
        case .calendar: "calendar"
        case .health: "heart.fill"
        case .eva: "sparkles"
        case .complete: "circle"
        }
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(LifeWeaveRevealCopy.receipt(for: draft), id: \.self) { line in
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                    Text(line)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(LifeWeaveAccessibilityID.revealReceipt)
    }
}
