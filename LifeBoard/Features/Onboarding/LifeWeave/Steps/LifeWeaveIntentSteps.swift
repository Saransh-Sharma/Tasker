import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The promise, and nothing else.
///
/// No feature bullets, no root names, no percentage, no integration claims, and
/// no mention of permissions beyond the fact that none are needed. The user is
/// deciding whether this is worth two minutes, and every extra sentence on this
/// screen is an argument against that.
struct LifeWeaveArrivalStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            LifeMapEyebrow("LIFEBOARD")
            Text("Make room for the life you actually have.")
                .lifeboardFont(.heroDisplay)
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            Text("Bring plans, routines, health, and everything you're carrying into one calm system.")
                .lifeboardFont(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            // One text run rather than an icon beside a label: in an HStack the
            // glyph takes its intrinsic width first and the sentence gets what is
            // left, so at accessibility sizes the second half — "Nothing connects
            // without you" — was truncated away. That is the half that carries
            // the promise.
            Text("\(Image(systemName: "lock.fill")) Private by design. Nothing connects without you.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One question where v5 asked two.
///
/// The intent and the blockers are the same conversation. Charging a separate
/// mandatory screen for "what usually gets in the way?" bought a signal the
/// product reads only lightly, at the cost of a whole extra beat before the user
/// had seen anything. Here the blockers unfold *under* the chosen intent, are
/// explicitly optional, and never gate the primary action.
struct LifeWeaveIntentStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What would make this week feel lighter?",
            support: "Pick the change you want LifeBoard to protect first."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(LifeWeaveIntent.allCases) { intent in
                    LifeMapChoiceRow(
                        title: intent.title,
                        subtitle: intent.subtitle,
                        symbol: intent.symbol,
                        isSelected: model.draft.intent == intent
                    ) {
                        model.selectIntent(intent)
                    }
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.intent(intent.id))
                }

                if model.draft.intent != nil {
                    blockers
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .lifeBoardMotion(.contentInsertion, value: model.draft.intent)
        }
    }

    private var blockers: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("What usually gets in the way?")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Text("Optional. Choose up to two.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))

            LifeWeaveChipFlow(
                items: LifeMapFriction.allCases.map { ($0.id, $0.title) },
                isSelected: { model.draft.blockerIDs.contains($0) },
                isDisabled: { id in
                    model.draft.blockerIDs.contains(id) == false
                        && model.draft.blockerIDs.count >= LifeWeaveDraft.maximumBlockers
                },
                identifier: LifeWeaveAccessibilityID.blocker,
                action: model.toggleBlocker
            )
        }
        .padding(.top, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The user's own structure, and the only labelled objects on the map.
struct LifeWeaveLifeAreasStep: View {
    @ObservedObject var model: LifeWeaveOnboardingModel

    private var canSelectMore: Bool {
        model.draft.orderedLifeAreaTemplateIDs.count < LifeWeaveDraft.maximumLifeAreas
    }

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What deserves space right now?",
            support: "Choose 2–5. This isn't permanent — it's the season you're in."
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(StarterWorkspaceCatalog.allLifeAreas) { template in
                    let isSelected = model.draft.orderedLifeAreaTemplateIDs.contains(template.id)
                    LifeMapChoiceRow(
                        title: template.name,
                        subtitle: template.subtitle,
                        symbol: template.icon,
                        isSelected: isSelected,
                        isDisabled: isSelected == false && canSelectMore == false
                    ) {
                        model.toggleLifeArea(template)
                    }
                    .accessibilityIdentifier(LifeWeaveAccessibilityID.lifeArea(template.id))
                }

                if model.draft.orderedLifeAreaTemplateIDs.count >= LifeWeaveDraft.minimumLifeAreas {
                    primaryPicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .lifeBoardMotion(.contentInsertion, value: model.draft.orderedLifeAreaTemplateIDs)
        }
    }

    /// One tap replaces v5's drag-to-rank list.
    ///
    /// A full ranking asks for precision the product does not need — what it
    /// actually wants to know is which area deserves extra salience — and drag
    /// ordering is the one interaction here that would have needed a separate
    /// keyboard, VoiceOver, and Switch Control equivalent to be usable at all.
    private var primaryPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Which one needs the clearest path first?")
                .lifeboardFont(.bodyStrong)
                .foregroundStyle(Color.lifeboard(.textPrimary))

            LifeWeaveChipFlow(
                items: model.selectedAreaTemplates.map { ($0.id, $0.name) },
                isSelected: { model.draft.primaryLifeAreaTemplateID == $0 },
                isDisabled: { _ in false },
                identifier: LifeWeaveAccessibilityID.primaryArea,
                action: model.selectPrimaryLifeArea
            )
        }
        .padding(.top, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A wrapping chip row.
///
/// `Layout`-free on purpose: `WrappingHStack` does not exist in the design
/// system, and a flexible grid is enough for four to seven short labels while
/// staying predictable under Dynamic Type.
struct LifeWeaveChipFlow: View {
    let items: [(id: String, title: String)]
    let isSelected: (String) -> Bool
    let isDisabled: (String) -> Bool
    let identifier: (String) -> String
    let action: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: Theme.Spacing.xs, alignment: .leading)],
            alignment: .leading,
            spacing: Theme.Spacing.xs
        ) {
            ForEach(items, id: \.id) { item in
                LifeWeaveChip(
                    title: item.title,
                    isSelected: isSelected(item.id),
                    isDisabled: isDisabled(item.id)
                ) {
                    action(item.id)
                }
                .accessibilityIdentifier(identifier(item.id))
            }
        }
    }
}
