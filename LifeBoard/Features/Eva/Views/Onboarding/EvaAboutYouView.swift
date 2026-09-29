import SwiftUI

struct EvaAboutYouView: View {
    @Environment(\.lifeboardTokens) private var tokens

    @Binding var draft: EvaProfileDraft

    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var isWorkingStyleNoteExpanded = false
    @State private var isMomentumNoteExpanded = false
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    private var canContinue: Bool {
        draft.selectedWorkingStyleIDs.isEmpty == false
            || draft.selectedMomentumBlockerIDs.isEmpty == false
            || (draft.customWorkingStyleNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || (draft.customMomentumNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: String(localized: "Continue"),
                    secondaryTitle: String(localized: "Back"),
                    isPrimaryDisabled: !canContinue,
                    onPrimary: onContinue,
                    onSecondary: onBack
                )
            }
        ) {
            mainContent
        }
        .accessibilityIdentifier("eva.activation.about_you")
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            EvaContentHeader(
                title: String(localized: "How can \(assistantIdentity.snapshot.displayName) help?"),
                bodyText: String(localized: "Pick what fits you.")
            )
            .enhancedStaggeredAppearance(index: 0)

            EvaSectionCard(
                title: String(localized: "Working style"),
                subtitle: String(localized: "Choose up to 3"),
                accessibilityIdentifier: "eva.activation.about_you.working_style"
            ) {
                EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                    ForEach(Array(EvaWorkingStyleID.allCases.enumerated()), id: \.element.id) { _, style in
                        EvaSelectionChip(
                            title: style.title,
                            isSelected: draft.selectedWorkingStyleIDs.contains(style.rawValue),
                            accessibilityIdentifier: "eva.activation.style.\(style.rawValue)"
                        ) {
                            toggle(style.rawValue, in: &draft.selectedWorkingStyleIDs, limit: 3)
                        }
                    }
                }

                EvaCollapsedNoteField(
                    title: String(localized: "Anything else?"),
                    collapsedTitle: String(localized: "Add a note"),
                    placeholder: String(localized: "Your note"),
                    accessibilityIdentifier: "eva.activation.about_you.working_style_note",
                    text: Binding(
                        get: { draft.customWorkingStyleNote ?? "" },
                        set: { draft.customWorkingStyleNote = $0 }
                    ),
                    isExpanded: $isWorkingStyleNoteExpanded
                )
            }
            .enhancedStaggeredAppearance(index: 1)

            EvaSectionCard(
                title: String(localized: "Blockers"),
                subtitle: String(localized: "Choose up to 3"),
                accessibilityIdentifier: "eva.activation.about_you.blockers"
            ) {
                EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                    ForEach(Array(EvaMomentumBlockerID.allCases.enumerated()), id: \.element.id) { _, blocker in
                        EvaSelectionChip(
                            title: blocker.title,
                            isSelected: draft.selectedMomentumBlockerIDs.contains(blocker.rawValue),
                            accessibilityIdentifier: "eva.activation.blocker.\(blocker.rawValue)"
                        ) {
                            toggle(blocker.rawValue, in: &draft.selectedMomentumBlockerIDs, limit: 3)
                        }
                    }
                }

                EvaCollapsedNoteField(
                    title: String(localized: "Anything to watch for?"),
                    collapsedTitle: String(localized: "Add a note"),
                    placeholder: String(localized: "Your note"),
                    accessibilityIdentifier: "eva.activation.about_you.momentum_note",
                    text: Binding(
                        get: { draft.customMomentumNote ?? "" },
                        set: { draft.customMomentumNote = $0 }
                    ),
                    isExpanded: $isMomentumNoteExpanded
                )
            }
            .enhancedStaggeredAppearance(index: 2)

            Text("Saved on \(DeviceNoun.this). Edit it anytime.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .enhancedStaggeredAppearance(index: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ rawValue: String, in values: inout [String], limit: Int) {
        if values.contains(rawValue) {
            values.removeAll { $0 == rawValue }
            return
        }

        guard values.count < limit else { return }
        values.append(rawValue)
    }
}
